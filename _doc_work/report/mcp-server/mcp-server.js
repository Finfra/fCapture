#!/usr/bin/env node
/**
 * fCapture MCP Server
 *
 * 기존 f-claude-plugins 6종(fBanner·fSnippet 등)은 macOS 앱의 REST API 를 호출하지만,
 * fCapture 는 앱이 아니라 CLI 다. 서버 포트가 없으므로 execFile 로 바이너리를 직접 실행한다.
 *
 * 계약 정본: fCapture repo `_doc_arch/cli-contract-design.md`
 *   - 종료 코드 0 성공 / 1 사용법 / 2 권한거부 / 3 대상없음 / 4 부분실패
 *   - stdout 은 결과 데이터 전용(`-R json`), stderr 는 사람이 읽는 실패 사유
 */

const readline = require('readline');
const { execFile } = require('child_process');
const fs = require('fs');

/**
 * 실행할 바이너리. FCAPTURE_BIN 으로 덮어쓸 수 있다 — 소스 빌드본 검증·비표준 설치 경로용.
 * 그 외에는 brew 설치본을 우선하고, 없으면 PATH 탐색에 맡긴다.
 */
const CANDIDATES = ['/opt/homebrew/bin/fcapture', '/usr/local/bin/fcapture'];
const BIN = process.env.FCAPTURE_BIN
  || CANDIDATES.find((p) => { try { fs.accessSync(p, fs.constants.X_OK); return true; } catch { return false; } })
  || 'fcapture';

/** 종료 코드 → 사람이 읽는 사유. 계약 문서의 표와 1:1 로 대응한다. */
const EXIT_REASON = {
  0: null,
  1: '사용법 오류 — 인자·설정 파일·저장 경로를 확인하십시오',
  2: '화면 기록 권한이 없습니다. 시스템 설정 > 개인정보 보호 및 보안 > 화면 기록에서 이 터미널(또는 Claude Code)을 허용한 뒤 다시 시도하십시오',
  3: '요청한 타겟을 하나도 캡처하지 못했습니다 — 대상이 존재하는지 확인하십시오',
  4: '일부 타겟만 캡처했습니다 — 성공분은 결과에 포함되어 있습니다'
};

/**
 * fcapture 를 1회 실행한다. 재시도하지 않는다 — 실패 원인이 권한·인자면 재시도가 무의미하고,
 * 캡처는 화면 상태를 바꾸는 부작용이 있어 자동 반복이 안전하지 않다.
 */
function runCapture(args) {
  return new Promise((resolve) => {
    execFile(BIN, args, { timeout: 120000, maxBuffer: 8 * 1024 * 1024 }, (err, stdout, stderr) => {
      // execFile 은 종료 코드가 0 이 아니면 err 를 준다. err.code 에 실제 종료 코드가 담긴다.
      const code = err && typeof err.code === 'number' ? err.code : (err ? -1 : 0);
      resolve({ code, stdout: (stdout || '').trim(), stderr: (stderr || '').trim() });
    });
  });
}

/** 실행 결과를 MCP 도구 응답으로 변환한다. 종료 코드가 성공/실패 판정의 유일한 근거다. */
function toToolResult(run) {
  const { code, stdout, stderr } = run;

  if (code === -1) {
    return {
      isError: true,
      text: JSON.stringify({
        error: `fcapture 실행 실패 — 바이너리를 찾을 수 없거나 실행할 수 없습니다 (${BIN})`,
        hint: 'brew install finfra/tap/fcapture 로 설치하십시오',
        stderr
      }, null, 2)
    };
  }

  // 0(전건 성공)과 4(부분 성공)만 결과를 신뢰한다. 4 는 실패분을 함께 알린다.
  const ok = code === 0 || code === 4;
  let files = [];
  if (ok && stdout) {
    try { files = JSON.parse(stdout); } catch { files = []; }
  }

  if (!ok) {
    return {
      isError: true,
      text: JSON.stringify({
        error: EXIT_REASON[code] || `알 수 없는 실패 (exit ${code})`,
        exitCode: code,
        detail: stderr
      }, null, 2)
    };
  }

  const payload = { files, count: files.length };
  if (code === 4) {
    payload.warning = EXIT_REASON[4];
    payload.detail = stderr;
  }
  return { isError: false, text: JSON.stringify(payload, null, 2) };
}

/** 공통 옵션(저장 경로·지연·그림자)을 CLI 인자로 편다. */
function commonArgs(input) {
  const args = [];
  if (input.output_dir) args.push('-p', String(input.output_dir));
  if (input.delay_seconds) args.push('--relay', String(input.delay_seconds));
  if (input.shadow === true) args.push('--shadow');
  if (input.shadow === false) args.push('--no-shadow');
  // 캡처 플래시는 MCP 호출에서 시각적 방해가 되므로 기본으로 끈다. 명시 요청 시에만 켠다.
  args.push(input.flash === true ? '--flash' : '--no-flash');
  return args;
}

async function handleToolCall(toolName, input = {}) {
  switch (toolName) {
    case 'get_version': {
      const run = await runCapture(['--version']);
      if (run.code !== 0) {
        return { isError: true, text: JSON.stringify({ error: 'fcapture --version 실패', detail: run.stderr }) };
      }
      return { isError: false, text: run.stdout };
    }

    case 'capture_screen': {
      // display 미지정이면 전체 디스플레이(all), 지정하면 screen:N
      const target = input.display ? `screen:${input.display}` : 'all';
      return toToolResult(await runCapture(['-t', target, '-R', 'json', ...commonArgs(input)]));
    }

    case 'capture_window': {
      // pointer: 마우스 아래 윈도우 / active: 최상단 윈도우
      const target = input.mode === 'active' ? 'window_active' : 'window_pointer';
      return toToolResult(await runCapture(['-t', target, '-R', 'json', ...commonArgs(input)]));
    }

    case 'capture_region': {
      const { x, y, width, height } = input;
      if ([x, y, width, height].some((v) => typeof v !== 'number')) {
        return { isError: true, text: JSON.stringify({ error: 'x·y·width·height 를 모두 숫자로 지정해야 합니다' }) };
      }
      return toToolResult(await runCapture([
        '-t', 'region_static', '--region', `${x},${y},${width},${height}`, '-R', 'json', ...commonArgs(input)
      ]));
    }

    case 'capture_with_preset': {
      if (!input.preset) {
        return { isError: true, text: JSON.stringify({ error: 'preset 경로 또는 이름이 필요합니다' }) };
      }
      return toToolResult(await runCapture([String(input.preset), '-R', 'json', ...commonArgs(input)]));
    }

    default:
      return { isError: true, text: JSON.stringify({ error: `Unknown tool: ${toolName}` }) };
  }
}

const COMMON_PROPS = {
  output_dir: { type: 'string', description: '저장 폴더 (기본: ~/Desktop)' },
  delay_seconds: { type: 'number', description: '캡처 전 지연 초' },
  shadow: { type: 'boolean', description: '윈도우 그림자 포함 여부' },
  flash: { type: 'boolean', description: '캡처 플래시 피드백 (기본 false)' }
};

const TOOLS = [
  {
    name: 'capture_screen',
    description: '디스플레이 전체를 캡처하고 저장된 파일 경로를 반환합니다. display 를 생략하면 모든 디스플레이를 캡처합니다.',
    inputSchema: {
      type: 'object',
      properties: { display: { type: 'integer', description: '디스플레이 번호 (1부터). 생략 시 전체' }, ...COMMON_PROPS }
    }
  },
  {
    name: 'capture_window',
    description: '단일 윈도우를 캡처합니다. mode=pointer 는 마우스 커서 아래 윈도우, mode=active 는 최상단 윈도우입니다.',
    inputSchema: {
      type: 'object',
      properties: { mode: { type: 'string', enum: ['pointer', 'active'], description: '기본: pointer' }, ...COMMON_PROPS }
    }
  },
  {
    name: 'capture_region',
    description: '지정한 좌표 영역을 캡처합니다. 사용자 드래그 선택이 아니라 좌표 지정 방식입니다.',
    inputSchema: {
      type: 'object',
      properties: {
        x: { type: 'number' }, y: { type: 'number' },
        width: { type: 'number' }, height: { type: 'number' },
        ...COMMON_PROPS
      },
      required: ['x', 'y', 'width', 'height']
    }
  },
  {
    name: 'capture_with_preset',
    description: 'JSON 설정 파일(프리셋) 경로로 캡처합니다. 스크롤 캡처 등 복합 시나리오에 사용합니다.',
    inputSchema: {
      type: 'object',
      properties: { preset: { type: 'string', description: '설정 JSON 파일 경로' }, ...COMMON_PROPS },
      required: ['preset']
    }
  },
  {
    name: 'get_version',
    description: '설치된 fCapture 버전을 반환합니다.',
    inputSchema: { type: 'object', properties: {} }
  }
];

function send(obj) { process.stdout.write(JSON.stringify(obj) + '\n'); }

/**
 * 처리 중인 요청 수. stdin 이 닫혀도 진행 중인 캡처의 응답을 흘려보내지 않기 위해 센다.
 * 이 카운터가 없으면 rl 'close' 가 즉시 process.exit(0) 을 호출해 execFile 대기 중이던
 * tools/call 응답이 유실된다(캡처는 수 초가 걸리므로 실제로 재현된다).
 */
let inFlight = 0;
let stdinClosed = false;
function maybeExit() {
  if (stdinClosed && inFlight === 0) process.exit(0);
}

async function main() {
  const rl = readline.createInterface({ input: process.stdin });

  rl.on('line', async (line) => {
    inFlight += 1;
    try {
      await handleLine(line);
    } finally {
      inFlight -= 1;
      maybeExit();
    }
  });

  rl.on('close', () => { stdinClosed = true; maybeExit(); });

  async function handleLine(line) {
    let msg;
    try {
      msg = JSON.parse(line);
    } catch (err) {
      send({ jsonrpc: '2.0', id: null, error: { code: -32700, message: `Parse error: ${err.message}` } });
      return;
    }

    try {
      if (msg.method === 'server/discover') {
        // MCP 2026-07-28 무상태 코어 — 핸드셰이크 없이 지원 버전을 광고한다.
        // 구 클라이언트는 이 메서드를 보내지 않고 곧바로 initialize 로 오므로 아래 분기가 처리한다.
        send({
          jsonrpc: '2.0', id: msg.id,
          result: {
            ttlMs: 60000, cacheScope: 'private',
            supportedVersions: ['2026-07-28'],
            capabilities: { tools: { listChanged: false } }
          }
        });
      } else if (msg.method === 'initialize') {
        send({
          jsonrpc: '2.0', id: msg.id,
          result: {
            protocolVersion: '2024-11-05',
            capabilities: { tools: { listChanged: false } },
            serverInfo: { name: 'fCapture', version: '1.0.0' }
          }
        });
      } else if (msg.method === 'tools/list') {
        send({ jsonrpc: '2.0', id: msg.id, result: { ttlMs: 60000, cacheScope: 'private', tools: TOOLS } });
      } else if (msg.method === 'tools/call') {
        const r = await handleToolCall(msg.params && msg.params.name, (msg.params && msg.params.arguments) || {});
        send({
          jsonrpc: '2.0', id: msg.id,
          result: {
            content: [{ type: 'text', text: r.text }],
            // ⚠️ isError 를 상수로 두지 않는다 — 실패를 성공으로 보고하면 조용한 실패가 Claude 로 전파된다
            isError: r.isError,
            resultType: 'complete'
          }
        });
      } else if (msg.id !== undefined) {
        send({ jsonrpc: '2.0', id: msg.id, error: { code: -32601, message: `Method not found: ${msg.method}` } });
      }
    } catch (err) {
      send({ jsonrpc: '2.0', id: msg.id !== undefined ? msg.id : null, error: { code: -32603, message: err.message } });
    }
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
