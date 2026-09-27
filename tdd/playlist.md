---
title: fCapture TDD 재생목록
description: prj51 fCapture 의 TDD 목표를 재생 순서로 나열한 목록 (prj6#Issue16)
date: 2026.09.26
---

# 무엇을 지키나

JSON/CLI 설정으로 화면·윈도우·영역을 캡처하는 CLI 의 옵션 해석·파일명·종료 코드 계약을 지킨다

* 기존 러너: `cd ~/_git/__all/fCapture && ./buildAndTest.sh && ./captureTest.sh`
* 신규 러너: `./tdd/tdd-test.sh [id ...]` — Screen Recording 권한이 있는 GUI 세션 필요(jma 는 GUI tmux 경유), HOME·CFFIXED_USER_HOME 격리
* 최종 green: 2026-09-27 jma (prj5#Issue100) — tdd-test 8/8 + captureTest 전 단계(1디스플레이라 screen2 예제는 SKIP)
* 목표 10개 중 기존 테스트로 덮인 것 2개 · 신규 8개

# 재생목록

위에서 아래로 돈다 — 빠르고 기초적인 것이 먼저, 통합·E2E 가 뒤다. 앞 항목이 깨지면 뒤 항목의 실패는 원인이 아니라 결과일 수 있다.

| # | id | 목표 | 근거 | 실행 | 상태 |
| :- | :- | :- | :- | :- | :- |
| 1 | `version-flag` | -v/--version 출력이 VERSION 파일 값과 일치한다(빌드 시 appVersion 주입) | Issue18 버전 확인 기능; buildAndTest.sh VERSION → ScreenCaptureApp.swift appVersion 주입 | `cd ~/_git/__all/fCapture && ./tdd/tdd-test.sh version-flag` | ✅ 신규 |
| 2 | `invalid-target-exit1` | 유효하지 않은 target(-t invalid_target) 입력 시 에러 메시지와 exit 1 을 반환한다 | Issue12 잘못된 target 값 에러 미처리 | `cd ~/_git/__all/fCapture && ./tdd/tdd-test.sh invalid-target-exit1` | ✅ 신규 |
| 3 | `failure-exit-code-nonzero` | 저장 경로 생성 실패·region_static 에 staticRegion 없음 등 실패 케이스는 빈 stdout 과 exit 0 이 아니라 exit 1 로 끝난다 | Issue14 에러 exit code 통일; Issue27 구버전은 실패 시 exit 0 + 빈 stdout (KM 매크로 오작동) | `cd ~/_git/__all/fCapture && ./tdd/tdd-test.sh failure-exit-code-nonzero` | ✅ 신규 |
| 4 | `filename-id-zeropad` | 파일명 %id 변수가 3자리 제로패딩으로 치환된다 | Issue13 %id 3자리 제로패딩 | `cd ~/_git/__all/fCapture && ./tdd/tdd-test.sh filename-id-zeropad` | ✅ 신규 |
| 5 | `companion-yaml-lookup` | companion YAML 탐색이 default.yaml·default.yml·yaml·yml 8종 후보를 모두 인식한다 | Issue24 findCompanionYAML 확장자 배열 결함 수정 | `cd ~/_git/__all/fCapture && ./tdd/tdd-test.sh companion-yaml-lookup` | ✅ 신규 |
| 6 | `missing-config-error` | 존재하지 않는 설정 파일 인자 시 설정 파일 오류 메시지를 출력한다 | captureTest.sh Test 3 Error handling test | `cd ~/_git/__all/fCapture && ./captureTest.sh` | ✅ 기존 |
| 7 | `example-configs-capture` | 기본 실행과 data/settings 예제 JSON 각각이 스크린샷 저장에 성공한다 | captureTest.sh Test 2/4/5 | `cd ~/_git/__all/fCapture && ./captureTest.sh` | ✅ 기존 |
| 8 | `window-pointer-onlypath` | -t window_pointer --result onlyPath 실행 시 저장된 파일 경로 1줄만 stdout 에 출력되고 파일이 존재한다 | Issue27 KM 윈도우 캡처 매크로 오작동 — 권장 명령 실측 | `cd ~/_git/__all/fCapture && ./tdd/tdd-test.sh window-pointer-onlypath` | ✅ 신규 |
| 9 | `relay-delay` | --relay N 또는 config relay 지정 시 캡처가 N초 지연 후 실행된다 | Issue20 --relay 지연 캡처; Issue21 yml/config 기반 relay | `cd ~/_git/__all/fCapture && ./tdd/tdd-test.sh relay-delay` | ✅ 신규 |
| 10 | `path-array-dir-create` | capturePath 배열 인덱스가 가리키는 폴더가 없으면 생성해 그곳에 저장한다(바탕화면 폴백으로 새지 않는다) | prj5#Issue100 중 jma 실측 — `capturePath: 0` → `~/Desktop/capture` 미존재 시 저장 실패·바탕화면 폴백, captureTest Test 2 red | `cd ~/_git/__all/fCapture && ./tdd/tdd-test.sh path-array-dir-create` | ✅ 신규 |

# 규약

* **목표는 «검증 가능한 성질»** 이다 — *"잘 동작한다"* 는 목표가 아니다
* 새 버그를 고치면 **재현 테스트를 먼저** 여기 한 줄로 올리고(⬜), 테스트가 생기면 실행 열을 채워 ✅ 로 바꾼다
* 실패를 삼키는 패턴(`2>/dev/null || true` 등)을 테스트 안에 쓰지 않는다 — 실패는 실패로 드러나야 한다
* 판정 출처: prj6 `_doc_work/report/tdd-coverage_report.md` (이 프로젝트가 왜 TDD 대상인가)
