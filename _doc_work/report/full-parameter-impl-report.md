---
title: CLI 파라미터 세분화 구현 결과 레포트
description: full-parameter-plan.md 기반 Issue11~14 구현 및 QA 검증 결과 정리
date: 2026-03-28
---

# 개요

* **계획 문서**: `_doc_work/plan/full-parameter-plan.md`
* **관련 이슈**: Issue11 (구현), Issue12~14 (QA 후속 수정)
* **구현 기간**: 2026-03-28
* **최종 커밋**: `5bbc09c`

# 구현 결과

## Phase 1: CLI 파서 확장

* `CLIOverrides` 구조체 신규 추가
* `parseArguments(_ args: [String])` 함수 구현
    - 반환: `(configFile: String?, presetFlag: String?, overrides: CLIOverrides)`
    - 기존 `-s`, `-w`, `-r`, `-f`, `-h` 스위치 100% 유지

### 신규 CLI 옵션 목록

| CLI 옵션                       | 단축키 | JSON 키              | 설명                                     |
| ------------------------------ | ------ | -------------------- | ---------------------------------------- |
| `--target <value>`             | `-t`   | `target`             | 캡처 대상 (반복 가능 → 다중 타겟)        |
| `--path <path>`                | `-p`   | `capturePath`        | 저장 경로                                |
| `--format <template>`          | `-F`   | `fileFormat`         | 파일명 템플릿                            |
| `--result <format>`            | `-R`   | `result`             | 출력 형식 (text / json / onlyPath)       |
| `--shadow` / `--no-shadow`     |        | `shadow`             | 윈도우 그림자 포함/제거                  |
| `--flash` / `--no-flash`       |        | `window_flash`       | 캡처 플래시 피드백                       |
| `--region <x,y,w,h>`           |        | `staticRegion`       | 고정 영역 좌표                           |
| `--backup <path>`              |        | `backupOtherScreen`  | 다른 화면 백업 저장 경로                 |

## Phase 2: 하이브리드 모드

* `mergeConfig(base: ScreenCaptureConfig, overrides: CLIOverrides)` 함수 구현
* JSON 파일 + CLI 옵션 동시 사용 시 CLI 옵션이 오버라이드
* `ScreenCaptureConfig` 프로퍼티 `let` → `var` 변경 (mergeConfig 지원)

### 설정 우선순위 (변경 후)

```
CLI 개별 옵션 (--target, --path 등)
  ↓ (없으면)
CLI JSON 파일 인수
  ↓ (없으면)
CLI 프리셋 스위치 (-s, -w, -r → ~/.fCapture/default*.json)
  ↓ (없으면)
~/.fCapture/defaultSetting.json
  ↓ (없으면)
코드 기본값
```

## Phase 3: QA 검증

* 검증 기준: `_doc_work/parameter.yml` (T01~T11, 총 45건)
* 1차 QA → FAIL 11건 발견 → 수정 → 재검증 순으로 진행

### QA 이력

| 회차 | PASS | WARN | FAIL | SKIP |
| ---- | ---- | ---- | ---- | ---- |
| 1차  | 27   | 3    | 11   | 2    |
| 2차  | 32   | 7    | 1    | 2    |
| 3차  | 36   | 5    | 0    | 2    |

### 최종 QA 결과 (3차)

| ID      | 테스트명                          | JSON | CLI  | 판정 |
| ------- | --------------------------------- | ---- | ---- | ---- |
| T01-01  | window (기본 윈도우)              | PASS | PASS | PASS |
| T01-02  | window_active (활성 윈도우)       | PASS | PASS | PASS |
| T01-03  | window_pointer (포인터 위치)      | PASS | PASS | PASS |
| T01-04  | window_flash (플래시 피드백)      | WARN | PASS | WARN |
| T01-05  | screen:1 (첫 번째 디스플레이)     | PASS | PASS | PASS |
| T01-06  | screen:2 (두 번째 디스플레이)     | PASS | PASS | PASS |
| T01-07  | 다중 스크린 (배열)                | PASS | PASS | PASS |
| T01-08  | all (모든 디스플레이)             | PASS | PASS | PASS |
| T01-09  | region_static (고정 영역)         | PASS | PASS | PASS |
| T01-10  | region_user (사용자 선택 영역)    | SKIP | SKIP | SKIP |
| T02-01  | 문자열 경로 직접 지정             | PASS | PASS | PASS |
| T02-02  | capturePathArray 인덱스 0         | PASS | PASS | PASS |
| T02-03  | capturePathArray 인덱스 1         | PASS | PASS | PASS |
| T02-04  | 존재하지 않는 경로                | N/A  | PASS | PASS |
| T03-01  | %d 변수 (날짜)                    | N/A  | PASS | PASS |
| T03-02  | %T 변수 (시간)                    | N/A  | PASS | PASS |
| T03-03  | %target 변수                      | N/A  | PASS | PASS |
| T03-04  | %id 변수 (ID 카운터)              | N/A  | WARN | WARN |
| T03-05  | 모든 변수 조합                    | N/A  | WARN | WARN |
| T03-06  | 변수 없는 고정 파일명             | N/A  | PASS | PASS |
| T04-01  | 그림자 제거 (false)               | PASS | PASS | PASS |
| T04-02  | 그림자 포함 (true)                | PASS | PASS | PASS |
| T05-01  | 플래시 활성화                     | N/A  | PASS | PASS |
| T05-02  | 플래시 비활성화                   | N/A  | PASS | PASS |
| T06-01  | text 형식 (기본)                  | PASS | PASS | PASS |
| T06-02  | json 형식                         | PASS | PASS | PASS |
| T06-03  | onlyPath 형식                     | PASS | PASS | PASS |
| T07-01  | screen:1 캡처 + 백업              | WARN | PASS | WARN |
| T07-02  | 윈도우 캡처 시 백업 미동작        | N/A  | PASS | PASS |
| T08-01  | 유효한 영역 좌표                  | PASS | PASS | PASS |
| T08-02  | region 누락 에러                  | N/A  | PASS | PASS |
| T08-03  | 잘못된 좌표 형식                  | N/A  | PASS | PASS |
| T09-01  | -h (도움말)                       | N/A  | WARN | WARN |
| T09-02  | -s (스크린 캡처)                  | N/A  | PASS | PASS |
| T09-03  | -w (윈도우 캡처)                  | N/A  | PASS | PASS |
| T09-04  | -r (영역 캡처)                    | SKIP | SKIP | SKIP |
| T09-05  | -f (영역 좌표 고정)               | N/A  | PASS | PASS |
| T09-06  | 인수 없이 실행                    | N/A  | PASS | PASS |
| T10-01  | JSON + result 오버라이드          | PASS | N/A  | PASS |
| T10-02  | JSON + path 오버라이드            | PASS | N/A  | PASS |
| T10-03  | JSON + shadow 오버라이드          | PASS | N/A  | PASS |
| T10-04  | JSON + 다중 오버라이드            | PASS | N/A  | PASS |
| T11-01  | 존재하지 않는 JSON 파일           | N/A  | PASS | PASS |
| T11-02  | 잘못된 target 값                  | N/A  | PASS | PASS |
| T11-03  | 알 수 없는 CLI 옵션               | N/A  | PASS | PASS |
| T11-04  | --result에 잘못된 값              | N/A  | PASS | PASS |

## Phase 4: 문서화

* `README.md`: 신규 CLI 옵션(v0.11+) 섹션 추가 (옵션 테이블 + 사용 예시)
* `fCapture/Usage.txt`: 신규 옵션 블록 및 예시 5개 추가
* `data/README.md`: JSON ↔ CLI 동등 명령 테이블 추가

# 후속 이슈 (QA 발견 → 해결 완료)

## Issue12 — 잘못된 target 값 에러 미처리 ✅

* **증상**: `-t invalid_target` 입력 시 에러 없이 빈 배열 + exit 0
* **수정**: `parseTargetType()`에서 유효 target 외 값 → 에러 메시지 + exit(1)
* **커밋**: `c2bab0b`

## Issue13 — %id 3자리 제로패딩 ✅

* **분석**: `String(format: "%03d", currentID)` 이미 구현되어 있었음
* **결론**: QA 오판 (ID 300번대는 이미 3자리 → 패딩 정상)
* **조치**: 코드 변경 없음, 이슈 종결

## Issue14 — 에러 케이스 exit code 미통일 ✅

* **증상**: 저장 경로 미존재 / region 누락 시 exit 0
* **수정**: 두 케이스 모두 exit(1) 처리
* **커밋**: `c2bab0b`

# 잔여 WARN 항목

| ID             | 내용                                                           | 조치 권고                                   |
| -------------- | -------------------------------------------------------------- | ------------------------------------------- |
| T01-04 JSON    | `09_window_flash.json`의 `~/Desktop/capture` 경로 미존재 폴백 | 예제 JSON 저장 경로 수정 (이슈 후보)        |
| T03-04 / T03-05 | `%id`가 300번대 출력 (ID 리셋 미발생)                         | 스펙 재확인 (3시간+날짜 리셋 정책 그대로)   |
| T07-01 JSON    | `14_option_backupOtherScreen.json` target이 `window_pointer`  | 예제 JSON target을 `screen:1`으로 수정 필요 |
| T09-01         | 도움말(`-h`)에 `-r` 옵션 누락                                  | `printHelp()` 수정 (이슈 후보)              |

# 커밋 이력

| 커밋      | 내용                                           |
| --------- | ---------------------------------------------- |
| `2853777` | Issue11 등록 (HWM 9→11)                        |
| `c088db7` | Feat: CLI 파라미터 세분화 구현 (Phase 1+2)     |
| `44699d9` | Fix: CLI 옵션 파싱 및 에러 처리 강화 (1차 QA) |
| `a18a43a` | Fix: -r 스위치 복구 + 문서화 (Phase 4)         |
| `d29cc22` | Docs: Issue11 완료 처리                        |
| `c2bab0b` | Fix: Issue12, 14 에러 처리 강화                |
| `5bbc09c` | Docs: Issue12~14 완료 처리                     |
