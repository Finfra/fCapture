---
title: fCapture MCP 서버 — prj20 이관 명세
description: Issue26_1 산출물. prj20 f-claude-plugins/fCapture/ 에 그대로 복사해 배치할 구현체와 검증 절차
date: 2026.09.09
---

# 왜 이 문서가 prj51 에 있는가

Issue26_1 은 MCP 서버 구현체를 **prj20 `f-claude-plugins`** 에 두라고 명시한다. 본 세션은 위임 세션이라 타 저장소 파일을 수정·커밋할 수 없다. 그래서 prj20 이 그대로 복사해 쓸 수 있는 **완성된 구현체와 검증 절차**를 이 저장소에 남기고, 배치는 prj20 세션 또는 사용자에게 넘긴다.

CLI 쪽 몫(종료 코드 규약·출력 스트림 분리)은 본 세션에서 이미 구현·검증을 마쳤다. 계약 정본은 [cli-contract-design.md](_doc_arch/cli-contract-design.md) 다.

# 이관할 파일

| 이 저장소의 파일 | prj20 배치 경로 |
| :--- | :--- |
| [mcp-server.js](_doc_work/report/mcp-server/mcp-server.js) | `~/_git/__all/f-claude-plugins/fCapture/mcp-server.js` |
| [plugin.json](_doc_work/report/mcp-server/plugin.json) | `~/_git/__all/f-claude-plugins/fCapture/plugin.json` |

`README.md`·`README_kr.md` 는 기존 6종 플러그인의 형식을 따라 prj20 에서 작성한다 — 그 저장소의 문체·목차 관행을 따라야 하므로 여기서 미리 쓰지 않았다.

# 기존 6종과의 구조적 차이

fBanner·fSnippet 등은 macOS **앱**의 REST API(포트 3011~3016)를 호출한다. fCapture 는 앱이 아니라 **CLI** 라 서버 포트가 없다. 따라서 `http.request` 대신 `child_process.execFile` 로 바이너리를 직접 실행한다. 포트 할당이 필요 없고, 앱이 떠 있는지 확인하는 헬스체크도 필요 없다.

대신 CLI 고유의 문제가 생긴다. **바이너리를 찾아야 하고, 종료 코드를 해석해야 하며, 실행이 끝날 때까지 기다려야 한다.** 아래 셋이 그에 대한 대응이다.

## 바이너리 탐색

`FCAPTURE_BIN` 환경변수 → `/opt/homebrew/bin/fcapture` → `/usr/local/bin/fcapture` → PATH 순으로 찾는다. 환경변수를 맨 앞에 둔 것은 소스 빌드본으로 검증할 때 필요하기 때문이다. brew 설치본은 릴리스 시점에 고정되므로 CLI 를 갓 고친 상태에서는 구버전을 실행하게 된다.

## 종료 코드 해석

`isError` 를 상수로 두지 않는다. 기존 6종은 `isError: false` 를 하드코딩하는데, 이러면 실패한 호출도 Claude 에게 성공으로 보고된다. 본 구현은 종료 코드를 그대로 판정에 쓴다.

| 종료 코드 | MCP 응답 |
| :--- | :--- |
| 0 | `isError: false`, `files` 배열 반환 |
| 4 (부분 실패) | `isError: false`, `files` + `warning` — 성공분은 유효하므로 버리지 않는다 |
| 1·2·3 | `isError: true`, 사람이 읽을 수 있는 `error` 문구 + `exitCode` + stderr 원문 |
| 실행 자체 실패 | `isError: true`, 설치 안내 문구 |

권한 거부(2)의 문구에는 **어디를 어떻게 허용해야 하는지**를 담았다. Claude 가 그대로 사용자에게 전달하면 되도록 하기 위해서다.

## 진행 중 요청 보호

stdin 이 닫혀도 진행 중인 캡처의 응답을 흘려보내지 않는다. 기존 6종은 `rl.on('close', () => process.exit(0))` 로 즉시 종료하는데, REST 호출은 밀리초 단위라 문제가 드러나지 않았지만 **캡처는 수 초가 걸려 실제로 응답이 유실된다.** 검증 중 `get_version` 응답이 누락되는 형태로 재현되어, in-flight 카운터를 두고 0 이 될 때까지 종료를 미루도록 고쳤다.

# 노출 도구

| 도구 | CLI 매핑 | 비고 |
| :--- | :--- | :--- |
| `capture_screen` | `-t screen:N` 또는 `-t all` | `display` 생략 시 전체 디스플레이 |
| `capture_window` | `-t window_pointer` / `-t window_active` | `mode` 로 선택, 기본 pointer |
| `capture_region` | `-t region_static --region x,y,w,h` | 좌표 지정. 드래그 선택(`region_user`)은 제외 |
| `capture_with_preset` | `<preset.json>` | 스크롤 캡처 등 복합 시나리오 |
| `get_version` | `--version` | |

`region_user`(마우스 드래그 선택)는 **의도적으로 노출하지 않았다.** 사람의 드래그 입력을 기다리는 대화형 동작이라 MCP 호출이 무한정 블로킹된다. 필요하면 별도 결정으로 추가하되 타임아웃 정책을 함께 정해야 한다 🚧

반환값은 `-R json` 을 쓴다. Issue26_1 은 `--result onlyPath` 를 지정했으나, `-R json` 이 경로에 더해 `target`·`fileName`·`id` 를 함께 주면서도 **이미지 바이너리를 stdout 으로 흘리지 않는다**는 요건을 똑같이 만족한다. 다중 타겟에서 어느 파일이 어느 대상인지 구분되므로 이쪽이 낫다.

# 검증 절차

## 이관 전 (본 세션에서 수행함)

JSON-RPC 를 직접 흘려 넣어 확인했다.

```bash
cd _doc_work/report/mcp-server
printf '%s\n' \
 '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
 '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
 '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_version","arguments":{}}}' \
 | node mcp-server.js
```

| 항목 | 결과 |
| :--- | :--- |
| `initialize` 응답 | ✅ `serverInfo.name = fCapture` |
| `tools/list` 5종 노출 | ✅ capture_screen·capture_window·capture_region·capture_with_preset·get_version |
| `get_version` | ✅ `fCapture 1.0.18` |
| `capture_screen` 성공 | ✅ `isError: false`, 파일 1건 반환 후 경로에 파일 존재 |
| 알 수 없는 도구 | ✅ `isError: true` |
| stdin 조기 종료 시 응답 보존 | ✅ in-flight 카운터 적용 후 누락 없음 |

## 이관 후 (prj20 세션이 수행)

1. 두 파일을 배치하고 `plugin.json` 의 `args` 경로가 실제 배치 경로와 일치하는지 확인
2. `claude mcp list` 에 `fcapture` 노출 확인
3. Claude Code 에서 `capture_window` 호출 → 반환 경로에 파일이 실제로 존재하는지 확인
4. **화면 기록 권한**: MCP 서버는 Claude Code 의 프로세스 트리에서 실행되므로, 터미널에 준 권한과 별개로 허용이 필요할 수 있다. 검증 중 같은 바이너리가 node 하위에서 권한 거부로 실패했다가 이후 성공하는 현상을 관측했다 — 최초 호출이 권한 오류를 내면 시스템 설정에서 Claude Code 를 화면 기록에 추가하고 재시도한다

# 미검증 사항

* **종료 코드 2(권한 거부) 실측 미완** — 개발 환경에 화면 기록 권한이 이미 허용되어 재현되지 않는다. 코드 경로(`performCapture` 의 권한 guard)는 확인했으나 실제 반환값은 확인하지 못했다. 권한을 회수한 환경에서 확인 필요 🚧
* **`capture_with_preset` 의 스크롤 캡처 경로 미검증** — 스크롤 캡처는 대상 앱의 상태에 의존해 자동 검증이 어렵다. 단순 프리셋(`01_screen1.json`)으로만 확인했다 🚧
