---
title: fCapture 전체 파라미터 CLI 세분화 계획
description: JSON 파일 없이도 CLI 파라미터만으로 모든 캡처 기능을 사용할 수 있도록 파라미터를 세분화하는 계획
date: 2026-03-28
---

# 배경 및 동기

## 현재 한계

| 구분         | 현재 상태                                        | 한계                                   |
| ------------ | ------------------------------------------------ | -------------------------------------- |
| 세부 기능    | JSON 파일에 모든 옵션을 묶어서 전달              | 간단한 옵션 하나 바꾸려면 JSON 파일 필요 |
| CLI 스위치   | `-s`, `-w`, `-r` 등 5개만 존재                   | 사전 등록된 설정 파일 로드만 가능      |
| 조합 사용    | 옵션 조합마다 JSON 파일 생성 필요                | 파일 관리 부담, 파일 수 증가           |
| 테스트       | `data/settings/*.json` 파일 단위 수동 실행       | 개별 파라미터 단위 검증 불가           |

## 목표

* CLI 파라미터를 세분화하여 **JSON 파일 없이** 개별 옵션 지정 가능
* 기존 JSON 파일 기반 자동화는 **100% 유지** (하위 호환)
* `_doc_work/parameter.yml`을 QA 검증 기준으로 사용

## 설계 원칙

* **추가만, 삭제 없음**: 기존 JSON 방식은 그대로 유지하고 CLI 옵션을 추가
* **1 파라미터 = 1 CLI 옵션**: JSON의 각 키를 독립된 CLI 옵션으로 분리
* **하이브리드**: JSON 파일 + CLI 옵션 동시 사용 시, CLI 옵션이 오버라이드
* **검증 가능**: 모든 파라미터는 CLI 단독으로 동작하며, QA로 검증 가능해야 함

# 파라미터 세분화 설계

## CLI 옵션 매핑

| JSON 키              | CLI 옵션 (신규)             | 짧은 형태 | 값 타입      | 기본값           |
| -------------------- | --------------------------- | --------- | ------------ | ---------------- |
| `target`             | `--target <value>`          | `-t`      | String       | `window_pointer` |
| `capturePath`        | `--path <path>`             | `-p`      | String       | `~/Desktop`      |
| `fileFormat`         | `--format <template>`       | `-F`      | String       | `%d_%T_%target`  |
| `shadow`             | `--shadow` / `--no-shadow`  |           | Bool (flag)  | `false`          |
| `window_flash`       | `--flash` / `--no-flash`    |           | Bool (flag)  | `true`           |
| `result`             | `--result <format>`         | `-R`      | String       | `text`           |
| `staticRegion`       | `--region <x,y,w,h>`       |           | String→4값   | (없음)           |
| `backupOtherScreen`  | `--backup <path>`           |           | String       | (없음)           |
| `capturePathArray`   | (CLI 미지원)                |           |              | JSON 전용        |

* `capturePathArray`는 배열 구조라 CLI 인자로 표현이 복잡 → JSON 전용 유지
* `--path`로 직접 경로를 지정하면 `capturePathArray` 불필요

## target 값별 CLI 사용법

| target 값        | CLI 명령 예시                                            | 비고                     |
| ---------------- | -------------------------------------------------------- | ------------------------ |
| `window`         | `fCapture -t window`                                     | `window_active`와 동일   |
| `window_active`  | `fCapture -t window_active`                              |                          |
| `window_pointer` | `fCapture -t window_pointer` 또는 `fCapture` (기본값)    |                          |
| `window_flash`   | `fCapture -t window_flash`                               |                          |
| `screen:1`       | `fCapture -t screen:1`                                   |                          |
| `screen:2`       | `fCapture -t screen:2`                                   |                          |
| 다중 스크린      | `fCapture -t screen:1 -t screen:2`                       | -t 반복으로 배열 구성    |
| `all`            | `fCapture -t all`                                        |                          |
| `region_static`  | `fCapture -t region_static --region 100,100,800,600`     | --region 필수            |
| `region_user`    | `fCapture -t region_user`                                | 인터랙티브               |

## 설정 우선순위 (변경 후)

```
CLI 개별 옵션 (--target, --path 등)
  ↓ (없으면)
CLI JSON 파일 인수 (fCapture config.json)
  ↓ (없으면)
CLI 프리셋 스위치 (-s, -w, -r → ~/.fCapture/default*.json)
  ↓ (없으면)
~/.fCapture/defaultSetting.json
  ↓ (없으면)
코드 기본값
```

* **하이브리드 모드**: `fCapture config.json --result json` → JSON 로드 후 result만 오버라이드

# 구현 계획

## Phase 1: CLI 파서 확장

* **대상**: [ScreenCaptureApp.swift](../../fCapture/ScreenCaptureApp.swift)
* **작업**:
    - `CLIOverrides` 구조체 신규 (각 파라미터 Optional)
    - `parseArguments()` 함수: `CommandLine.arguments` → `(configFile?, CLIOverrides)` 반환
    - `mergeConfig(base:overrides:)` 함수: JSON 설정 + CLI 옵션 병합
    - 기존 `-s`, `-w`, `-r`, `-f`, `-h` 스위치 동작 유지
* **제약**: 기존 동작 변경 없음. 새 옵션이 없으면 기존과 완전 동일하게 동작

## Phase 2: 하이브리드 모드

* **작업**:
    - JSON 파일 + CLI 옵션 동시 전달 시 병합 로직
    - ex) `fCapture data/settings/01_screen1.json --result json`
    - CLI 옵션이 JSON의 동일 키를 오버라이드
* **핵심**: JSON은 base config, CLI는 override layer

## Phase 3: QA 검증

* **기준 문서**: `_doc_work/parameter.yml`
* **검증 방식**:
    - parameter.yml의 각 테스트 케이스를 QA 에이전트가 실행
    - JSON 방식과 CLI 방식 양쪽 모두 테스트
    - 동일 파라미터 조합의 JSON/CLI 결과가 동등한지 비교
* **자동화 불가 항목**: `region_user` (인터랙티브), `window_flash` 시각 피드백

## Phase 4: 문서화

* README.md에 새 CLI 옵션 섹션 추가
* Usage.txt (번들 리소스) 업데이트
* data/README.md에 JSON ↔ CLI 동등 명령 예시 추가

# 구현 순서

| Phase | 작업             | 산출물                        | 의존성  |
| ----- | ---------------- | ----------------------------- | ------- |
| 1     | CLI 파서 확장    | ScreenCaptureApp.swift 수정   | 없음    |
| 2     | 하이브리드 모드  | 병합 로직 구현                | Phase 1 |
| 3     | QA 검증          | parameter.yml 기반 테스트     | Phase 2 |
| 4     | 문서화           | README, Usage 업데이트        | Phase 3 |

# 위험 요소

| 위험                               | 대응                                              |
| ---------------------------------- | ------------------------------------------------- |
| 기존 `-s`와 `--target screen:1` 중복 | 양쪽 모두 유지. `-s`는 프리셋(JSON 로드), `--target`은 직접 지정 |
| `-t` 반복 시 다중 target 파싱      | 반복 플래그 → 배열 수집 패턴 적용                 |
| `--region` 좌표 파싱 실패          | 쉼표 구분 4값 검증, 실패 시 에러 메시지 출력      |
| 하위 호환 깨짐                     | 새 옵션 없이 실행하면 기존과 100% 동일 동작 보장  |
