---
title: fCapture 기술 진단 사례
description: 증상·원인·오진 경로·해결·계측 함정 기록. 버그 신고를 받으면 코드 grep 보다 이 파일을 먼저 본다
date: 2026.09.09
---

# 2026-09-09 · 캡처 실패인데 종료 코드 0 (Issue26_1)

## 증상

`fcapture -t screen:99` 처럼 존재하지 않는 대상을 요청하면 한 장도 저장하지 못하는데도 종료 코드 **0** 과 빈 JSON 배열 `[]` 을 반환했다. 호출자는 "성공했고 결과가 0건" 과 구별할 수 없다. 다중 타겟 중 일부만 실패하는 경우도 마찬가지로 0 이었다.

## 원인

`performCapture` 의 캡처 루프가 개별 실패를 `catch` 로 잡아 `logE` 만 하고 다음 타겟으로 넘어간다. 루프가 끝나면 `outputResults` 를 호출하고 함수가 정상 반환하므로 프로세스는 0 으로 끝난다. **실패를 집계하는 변수 자체가 없었다.**

부수적으로, 바탕화면 폴백까지 실패한 경우의 보고가 `if resultFormat == .text` 안에 들어 있어 `-R json` 으로 호출하면 실패 사유가 어디에도 남지 않았다.

## ⚠️ 오진 경로 — 계측을 잘못해 하마터면 놓칠 뻔했다

처음에 종료 코드를 이렇게 쟀다.

```bash
fcapture -t screen:99 -R json -p /tmp/x 2>&1 | head -20; echo "exit=${PIPESTATUS[0]}"
```

zsh 에서 `PIPESTATUS` 는 **비어서 출력된다**(zsh 는 `pipestatus` 소문자 배열을 쓰고, 인덱스도 1부터다). 그래서 빈 값이 나왔고, 이어서 `for` 루프로 다시 쟀을 때는 **모든 케이스가 exit=1** 로 나왔다. 그 값을 믿고 *"실패는 전부 1 로 잘 처리되는구나"* 라고 판단할 뻔했다.

실제로는 정반대였다. 리다이렉트로 분리해 다시 재니 `screen:99` 는 **0** 이었다.

```bash
fcapture -t screen:99 -R json -p /tmp/x >/tmp/o.txt 2>/tmp/e.txt; echo "exit=$?"
```

**교훈**: 종료 코드를 잴 때 파이프·`$(...)`·루프를 끼우지 않는다. 명령을 단독 실행하고 곧바로 `$?` 를 읽는다. 파이프를 통과시키면 마지막 명령의 코드가 잡히고, zsh/bash 의 배열 이름 차이까지 겹치면 조용히 틀린 값이 나온다.

## 해결

`ExitCode` 열거형을 두고 실패 타겟을 집계해 반영했다(commit `fe68bf5`).

| 코드 | 의미 |
| :--- | :--- |
| 0 | 전건 성공 |
| 1 | 사용법·설정 오류 |
| 2 | 화면 기록 권한 거부 |
| 3 | 전건 실패·대상 없음 |
| 4 | 부분 실패 |

계약 정본은 [cli-contract-design.md](_doc_arch/cli-contract-design.md).

# 2026-09-09 · 화면 기록 권한(TCC)은 재현이 안 된다

## 증상

종료 코드 2(권한 거부)를 검증하려 했으나 **의도적으로 권한 거부 상태를 만들 수 없었다.**

## 시도한 것과 결과

| 시도 | 결과 |
| :--- | :--- |
| 바이너리를 `/tmp` 의 새 경로로 복사해 실행 | 성공(권한 있음) — TCC 는 경로만으로 갈리지 않는다 |
| node 하위 프로세스로 brew 설치본 실행 | **1회 거부됨** — 그 뒤 같은 명령이 성공으로 바뀜 |
| node 하위에서 세 바이너리 전부 재실행 | 전부 성공 — 거부 재현 실패 |

권한 귀속은 **responsible process**(터미널·Claude Code 등 조상 프로세스) 기준이며, 한 번 허용되면 그 세션 동안 하위 프로세스가 상속한다. 그래서 "이미 허용된 환경" 안에서는 거부 상태를 만들 수 없다.

## 함정

* 최초 거부를 관측했을 때 *"권한 경로를 실측했다"* 고 판단했으나, 그때 실행된 것은 **brew 설치본(v1.0.18, 수정 전 바이너리)** 이라 exit 1 을 반환했다. 새 코드의 exit 2 를 본 것이 아니다
* 권한 체크는 `CGDisplayStream` 생성 성공 여부로 판정한다 — **프롬프트를 띄우지 않는다**(`CGRequestScreenCaptureAccess` 가 아님). 그래서 거부돼도 다이얼로그 없이 조용히 실패한다. 진단 시 "다이얼로그가 안 떴으니 권한 문제가 아니다" 는 성립하지 않는다

## 결론

exit 2 는 **코드 경로만 확인된 상태**다. 권한을 회수한 환경에서 수동 확인이 필요하다. 자동 회귀에 넣을 수 없다.

# 2026-09-09 · MCP 서버가 진행 중인 캡처 응답을 잃는다

## 증상

MCP 서버(`_doc_work/report/mcp-server/mcp-server.js`)에 JSON-RPC 3건을 파이프로 흘려 넣으면 마지막 `tools/call` 응답이 오지 않았다.

## 원인

기존 f-claude-plugins 6종이 공유하는 패턴 `rl.on('close', () => process.exit(0))` 이 원인이다. stdin 이 닫히는 즉시 프로세스를 죽이므로, `execFile` 로 실행 중인 캡처가 끝나기 전에 종료된다.

**기존 6종에서는 드러나지 않는다** — 그것들은 로컬 REST API를 호출해 응답이 밀리초 단위다. fCapture 는 실제 화면을 캡처하고 파일로 저장해 수 초가 걸리므로 창이 넓어 재현된다.

## 해결

in-flight 카운터를 두고 stdin 이 닫혀도 처리 중인 요청이 0 이 될 때까지 종료를 미룬다. prj20 이관 시 이 수정이 포함된 버전을 써야 한다.

# 2026-09-11 · KM 에서만 안 되는 window_pointer — 코드는 그대로였고, 계측 3종으로 원인을 좁혔다 (Issue27)

## 증상

Keyboard Maestro 매크로 `CaptureWithPointer` 의 예전 명령 `fcapture -t window_pointer --result onlyPath` 가 오작동한다는 보고. 같은 매크로 군의 스크린 캡처(`{hostname}_Screen.json` 방식)는 정상이었다.

## 계측 — 터미널에서는 어떤 경로도 실패하지 않았다

| 실행 형태 | 종료 코드 | stdout |
| :--- | :--- | :--- |
| `-t window_pointer --result onlyPath` (일반 터미널) | 0 | 경로 1줄 (`~/Desktop/` 직하) |
| 같은 명령, `env -i HOME=… PATH=/usr/bin:/bin /bin/sh -c` (KM 최소 환경 모사) | 0 | 경로 1줄 |
| `jm4_Window.json --result onlyPath` | 0 | `~/df/..._window_pointer.png` |
| `jm4_Window.json -t window_pointer --result onlyPath` | 0 | `~/df/..._window_pointer.png` |
| `jm4_Screen.json --result onlyPath` (비교) | 0 | `~/df/..._screen1.png` |
| `-t screen:9 --result onlyPath` (실패 경로, brew 본) | **0** | 빈 문자열 |

## 원인 후보를 좁힌 근거

* **코드는 예전과 같다** — `backup/pre-brew` 와 HEAD 의 `captureWindowPoint` 본문을 `awk` 로 뽑아 `diff` 하니 동일. CLI 옵션만 줄 때 내장 기본값을 쓰는 분기도 동일
* **환경변수 차이도 아니다** — `env -i` 최소 환경에서 성공
* **KM 이 실행하는 brew 본은 6월 릴리즈 그대로다** — 같은 실패 명령(`screen:9`)을 brew 본은 exit 0, 로컬 `.build/release`(9월 9일 빌드)는 exit 3. brew Formula 의 tarball 이 `v1.0.18`(= `6ebd1f5`)이고 Issue26_1 은 그 뒤 커밋이다
* 남는 차이는 **트리거 시점의 마우스 위치**뿐이다. 포인터 아래 layer 0 윈도우가 없으면 "마우스 포인터 위치에 윈도우가 없습니다" 로 실패하고, brew 본은 exit 0 + 빈 stdout 을 돌려준다. KM 은 성공으로 보고 빈 경로를 후속 액션에 넘긴다 — [cli-contract-design.md](../_doc_arch/cli-contract-design.md) 가 경고한 바로 그 오독이다

## 함정

* `/tmp/fCapture.log` 는 **onlyPath 성공 시 아무것도 남기지 않는다.** 로그가 비어 있어도 "실패한 적 없음" 과 "실행한 적 없음" 을 구분할 수 없다
* `strings` 로 한글 문자열 유무를 세어 바이너리 버전을 판정하려 했으나 UTF-8 한글은 기본 필터에 잡히지 않아 0 이 나온다(오진 위험). **바이너리 버전 판정은 같은 입력에 대한 exit code 비교**로 한다
* `jm4_Window.json` 에 `target` 키가 두 번 있었다. "마지막 값이 이긴다" 고 가정했으나 실측은 **첫 번째 값**(`window_pointer`) 채택 — 파서 구현 의존이므로 중복 키 자체를 없애야 한다
* KM 매크로 본체(plist)·Engine.log 는 타앱 데이터라 직접 읽지 않았다. 대신 매크로 스크립트에 `2>>/tmp/km_fcapture.err; echo "exit=$?" >>/tmp/km_fcapture.err` 를 붙이는 진단 1줄로 사용자 실측에 위임했다

## 해결

권장 명령은 스크린 매크로와 대칭인 JSON 방식 + 타겟 강제다.

```bash
/opt/homebrew/bin/fcapture ~/.fCapture/$KMVAR_hostname/${KMVAR_hostname}_Window.json -t window_pointer --result onlyPath
```

부수 발견: ① `jm4_Window.json` 의 `target` 중복 ② jm4 로컬의 `~/.fCapture/jma/` 사본 폴더 파일명이 전부 `jm4_*` 접두(jma 실기 폴더는 `jma_*.json` 으로 정상 — 2026-09-13 ssh 실측으로 정정) ③ brew 본에 Issue26_1 종료 코드 규약 미반영 — 새 릴리스 필요(Issue26_3 결정 근거).

# 2026-09-27 — TDD 재생목록 green 중 발견 3건 (prj5#Issue100)

## ① capturePath 배열 인덱스 경로 미생성 → 바탕화면 조용한 폴백

* 증상: jma `captureTest.sh` Test 2 red. 출력이 `스크린샷이 저장되었습니다` 가 아니라 `바탕화면에 저장되었습니다` — exit 0 이라 호출자는 모름
* 원인: `defaultSetting.json` 의 `capturePath: 0` → `capturePathArray[0]` = `~/Desktop/capture` 가 jma 에 없음. `performCapture` 는 `-p` 문자열 경로만 생성하고 `.index` 는 *"검증 불필요"* 로 건너뜀
* 해결: `.index` 도 배열 경로를 `pathToCheck` 로 삼아 생성. 재현 목표 `path-array-dir-create`
* 함정: jm4 에서는 폴더가 이미 있어 재현 안 됨 — 머신 상태 의존 버그

## ② HOME 을 바꿔도 ~/.fCapture 가 격리되지 않음

* 증상: `HOME=<tmp>` 로 돌린 `%id` 테스트가 `tdd_001` 이 아니라 `tdd_017` (jma 실제 카운터)
* 원인: `FileManager.homeDirectoryForCurrentUser` 는 `HOME` env 를 무시한다. **`CFFIXED_USER_HOME`** 을 함께 지정해야 격리된다
* 함정: 첫 실행은 우연히 green — 실제 카운터가 3시간·날짜 리셋 직후라 001 이었다. 한 번 green 을 격리 증명으로 믿지 말 것

## ③ captureTest.sh 이식성 — macOS 에 `timeout` 없음

* `timeout 10s` 는 GNU coreutils 라 jma(brew coreutils 미설치)에서 `command not found` → grep 실패 → 오판. `perl -e 'alarm N; exec @ARGV'` 로 대체
* Test 5 는 실패를 출력만 하고 성공 종료하던 것을 exit 1 로, Test 3 은 문구 변경(`설정 파일을 찾을 수 없습니다`) 반영 + exit 1 단언

# 2026-09-27 · 공식 빌드에 섹션이 있는데 스크립트는 «누락» 이라 했다 — `pipefail` + `grep -q` (Issue30)

## 증상

`deploy-brew.sh --build-only` 가 universal2 공식 빌드를 끝낸 뒤 `❌ 공식 빌드 섹션 누락: __fc_banner` 로 exit 1. 그런데 같은 바이너리를 `otool -l | grep -c "sectname __fc"` 로 보면 **4**(아치 2 × 섹션 2)로 섹션은 멀쩡히 있었다.

## ⚠️ 오진 경로

* 1차 가설: multi-arch 빌드는 XCBuild(swiftbuild) 백엔드로 가는데, 거기서 `-Xlinker -sectcreate` 가 링커까지 전달되지 않는다 — **틀렸다.** 같은 인자로 손으로 빌드하자 섹션이 들어갔다
* 2차 가설 `pipefail` 을 `bash -c 'set -o pipefail; otool -l … | grep -q …'` 로 재현하려 했을 때 **rc=0 이라 기각할 뻔했다.** 그때 쓴 바이너리는 배너 섹션 하나만 넣은 수동 빌드라 otool 출력이 짧았다

## 원인

`set -euo pipefail` 스크립트에서 `otool -l "$BIN" | grep -q PATTERN` — `grep -q` 는 첫 일치에서 바로 종료한다. otool 출력(이 바이너리 34KB)이 파이프 버퍼보다 크면 otool 이 쓰는 도중 SIGPIPE 를 받아 비정상 종료하고, `pipefail` 이 그 실패를 파이프라인 결과로 올린다. 일치했는데 «불일치» 로 판정된다. 실측: 같은 바이너리로 20회 반복 → **파이프 방식 20/20 오판, 출력 캡처 방식 0/20**.

## 해결

출력을 변수로 먼저 받고 here-string 으로 grep 한다 — `LOAD_CMDS=$(otool -l "$BIN"); grep -q "sectname $sect" <<<"$LOAD_CMDS"`. TDD 러너(`tdd/tdd-test.sh` `has_section`)는 `pipefail` 을 쓰지 않아 영향이 없었지만 같은 방식으로 맞췄다.

## 계측 함정

* 재현 실험은 **증상이 난 바로 그 산출물**로 한다. 출력 크기에 좌우되는 경합이라 다른 바이너리로는 재현되지 않는다
* 일반화: `pipefail` 아래에서 «앞 명령 출력이 크고 뒤 명령이 조기 종료하는» 파이프(`| grep -q`, `| head -n 1`)는 성공을 실패로 뒤집는다
