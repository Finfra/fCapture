---
name: cli-contract-design
description: fCapture CLI 를 사람이 아닌 프로그램(MCP 서버·쉘 스크립트·Keyboard Maestro)이 호출할 때의 계약 — 종료 코드·stdout/stderr 분리·출력 형식
date: 2026.09.09
---

# 개요

fCapture 는 사람이 터미널에서 치는 도구인 동시에, **다른 프로그램이 호출하는 하위 도구**다. 호출자는 캡처가 성공했는지, 실패했다면 왜 실패했는지를 **기계적으로** 판정해야 한다. 본 문서는 그 판정 수단인 종료 코드와 출력 스트림 분리를 정의한다.

이 계약을 소비하는 쪽은 셋이다. Claude Code 의 MCP 서버(prj20 `f-claude-plugins/fCapture/`), 쉘 래퍼 스크립트, 그리고 Keyboard Maestro 매크로다. 셋 모두 stdout 을 파싱하기 전에 종료 코드를 먼저 본다는 전제로 작성한다.

# 종료 코드 규약

`ScreenCaptureApp.swift` 의 `ExitCode` 열거형이 정본이며, `exitWith(_:)` 를 거치지 않는 종료는 두지 않는다.

| 코드 | 이름 | 의미 | 호출자가 할 일 |
| :--- | :--- | :--- | :--- |
| 0 | `success` | 요청한 모든 타겟을 캡처·저장함 | stdout 을 결과로 신뢰 |
| 1 | `usage` | 잘못된 인자, 설정 파일 부재·파싱 실패, 저장 경로 생성 실패 | 호출 인자를 고친다. 재시도해도 같다 |
| 2 | `permissionDenied` | 화면 기록 권한 없음 | 사용자에게 시스템 설정 안내. 재시도 무의미 |
| 3 | `noTarget` | 요청한 타겟을 하나도 캡처하지 못함 | 타겟 지정을 재검토. stdout 은 빈 배열 |
| 4 | `partial` | 다중 타겟 중 일부만 성공 | stdout 의 성공분은 유효, 실패분은 stderr 확인 |

## 왜 2·3·4 를 나눴는가

이전 버전은 실패를 두 가지로만 표현했다. 인자 검증 단계에서 걸리면 1, 그 외에는 전부 0 이었다. 문제는 **캡처 자체가 실패해도 0** 이었다는 점이다. `fcapture -t screen:99` 는 존재하지 않는 디스플레이를 요청해 한 장도 저장하지 못했는데도 종료 코드 0 과 빈 JSON 배열 `[]` 을 내보냈다. 호출자 입장에서 이것은 "성공했고 결과가 0건" 과 구별되지 않는다.

MCP 서버는 이 값을 그대로 도구 호출 결과의 `isError` 로 옮긴다. 0 만 보고 판정하면 캡처에 실패한 요청이 Claude 에게 성공으로 보고되고, Claude 는 존재하지 않는 파일 경로를 다음 단계에 넘긴다. 조용한 실패가 한 단계 아래로 전파되는 경로였다.

권한 거부(2)를 사용법 오류(1)에서 분리한 것도 같은 이유다. 둘은 호출자가 취할 행동이 다르다. 1 은 인자를 고쳐 재시도할 수 있지만, 2 는 **사람이 시스템 설정을 열어 허용하기 전까지 무엇을 해도 실패한다**. 재시도 루프를 도는 자동화가 이 둘을 구분하지 못하면 권한 문제를 만났을 때 무한히 같은 호출을 반복한다.

부분 실패(4)는 다중 타겟에서만 나온다. `-t screen:1 -t screen:99` 처럼 일부만 성공한 경우, 성공분을 버리는 것도 실패를 감추는 것도 옳지 않다. stdout 에는 성공분을 정상 형식으로 내보내고, 종료 코드로 "전부는 아니다" 를 알린다.

# 출력 스트림 분리

**stdout 은 결과 데이터 전용, stderr 는 사람이 읽는 메시지 전용**이다.

`-R json` 과 `-R onlyPath` 는 stdout 에 각각 JSON 배열과 개행 구분 경로만 쓴다. 진행 로그·경고·실패 사유는 형식과 무관하게 stderr 로 나간다. 호출자가 stdout 을 그대로 `JSON.parse` 하거나 경로 목록으로 읽을 수 있어야 하기 때문이다.

`-R text`(기본)에서는 사람이 읽을 것을 전제로 진행 상황을 stderr 에 풀어 쓴다. 이 형식에서만 나오는 안내 문구가 있으나, **실패 메시지는 형식과 무관하게 항상 나간다**. 과거에는 저장 실패 보고가 `resultFormat == .text` 조건 안에 들어 있어 JSON 형식으로 호출하면 실패 사유가 어디에도 남지 않았다. 지금은 그 조건을 걷어냈다.

로그 파일 `/tmp/fCapture.log` 는 stderr 와 같은 내용을 누적한다. 호출자가 stderr 를 버렸을 때의 사후 추적용이며, 계약의 일부가 아니다.

# 출력 형식

`-R json` 의 스키마는 배열이며, 각 원소는 `id`·`fileName`·`filePath`·`target` 네 필드를 가진다.

```json
[
  {
    "id": 1,
    "fileName": "20260909_001755.png",
    "filePath": "/tmp/fcap_test/20260909_001755.png",
    "target": "screen:1"
  }
]
```

이 스키마에 **실패 항목을 섞지 않는다.** 배열은 "저장에 성공한 파일" 만 담는다. 실패는 종료 코드와 stderr 가 표현한다. 실패 정보를 배열 안에 넣으려면 원소마다 성공/실패 판별 필드가 필요하고, 그러면 기존 소비자(Keyboard Maestro 매크로 등)가 실패 항목을 파일 경로로 오독한다. 계약을 바꾸는 대신 이미 있는 채널을 쓰는 쪽을 택했다.

`-R onlyPath` 는 성공한 파일 경로만 개행으로 구분해 출력한다. 단일 캡처를 셸에서 `$(...)` 로 받는 용도이며, 종료 코드 확인이 특히 중요하다. 실패 시 빈 문자열이 반환되므로 이를 경로로 오인하면 빈 경로를 다음 명령에 넘기게 된다.

# 호출자 구현 지침

호출자는 다음 순서를 지킨다.

```bash
out=$(fcapture -t window_active -R json -p /tmp/caps 2>/tmp/err.txt)
rc=$?
case $rc in
  0) ;;                                   # 전건 성공
  4) ;;                                   # 부분 성공 — out 의 성공분은 유효
  2) echo "화면 기록 권한을 허용해야 합니다" >&2; exit $rc ;;
  *) cat /tmp/err.txt >&2; exit $rc ;;    # 1·3 — 실패 사유는 stderr 에
esac
echo "$out" | ...                         # 여기서 처음으로 stdout 을 파싱한다
```

종료 코드를 보기 전에 stdout 을 파싱하지 않는다. 1·2 에서는 stdout 이 비어 있어 파싱 자체가 실패하고, 3 에서는 빈 배열이 넘어와 "결과 0건" 으로 오독된다.

# 검증

계약 변경 시 아래를 실측한다. 권한 거부(2)는 개발 환경에 권한이 이미 허용되어 있어 자동 검증이 불가능하며, 권한을 회수한 환경에서 수동 확인해야 한다 🚧

| 호출 | 기대 종료 코드 |
| :--- | :--- |
| `-t screen:1 -R json -p <쓰기가능경로>` | 0 |
| `-t bogus -R json` | 1 |
| `<존재하지 않는 설정파일>.json` | 1 |
| `-t screen:1 -p /nonexistent_root_dir/xx` | 1 |
| `-t region_static -R json` (좌표 없음) | 1 |
| `-t screen:99 -R json` | 3 |
| `-t screen:1 -t screen:99 -R json` | 4 |

`data/settings/` 의 설정 파일 전수 실행이 모두 0 을 반환하는지도 함께 확인한다 — 종료 코드 판정이 정상 경로를 실패로 잘못 분류하지 않는지 보는 회귀다.

# 관련 문서

* 배포·릴리스 절차: [brew-deploy-design.md](_doc_arch/brew-deploy-design.md)
* 설정 파일 스키마: [yaml-companion-config.md](_doc_arch/yaml-companion-config.md)
* MCP 서버 이관 명세(prj20 인계용): [_doc_work/report/mcp-server-handoff.md](_doc_work/report/mcp-server-handoff.md)
