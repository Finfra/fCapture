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

부수 발견: ① `jm4_Window.json` 의 `target` 중복 ② `~/.fCapture/jma/` 파일명이 전부 `jm4_*` 접두(jma 에서 exit 1) ③ brew 본에 Issue26_1 종료 코드 규약 미반영 — 새 릴리스 필요(Issue26_3 결정 근거).
