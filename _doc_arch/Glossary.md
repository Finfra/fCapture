---
title: fCapture 용어 사전
description: fCapture 프로젝트에서 사용하는 핵심 용어 정의
date: 2026-06-15
---

> 개정 (2026-06-15): 코드(`ScreenCaptureApp.swift` TargetType·parseTargetType·captureSingleImage, `Usage.txt`)와 대조하여 target 값 목록을 정정함.
> 구 표기(`window`/`screen:N`/`region`/`staticRegion`)는 코드 진화 과정에서 canonical 이 `_` 접미 명칭(`window_pointer`/`window_active`/`window_flash`/`region_user`/`region_static`)으로 분화됨(Issue8 이후). 누락되어 있던 `scroll_capture` 모드와 `relay`·`window_flash`·결과 형식 용어를 추가함.

# 캡처 모드 용어 (target)

`target` 은 캡처 대상을 결정함. CLI `-t/--target <value>` 또는 설정 파일(JSON/companion YAML) 로 지정.
canonical 값은 `_` 접미 명칭이며, 일부 구 표기는 코드에서 alias 로 계속 인식됨.

## canonical target 값

| target 값       | 설명                                                       | 예시                          |
| --------------- | ---------------------------------------------------------- | ----------------------------- |
| window_pointer  | 마우스 포인터 위치의 윈도우 캡처 (**기본값**)              | `-t window_pointer`           |
| window_active   | 현재 활성(frontmost) 윈도우 캡처                           | `-t window_active`            |
| window_flash    | 활성 윈도우 캡처 + 캡처 후 파란 테두리 플래시 피드백       | `-t window_flash`             |
| screen:N        | N번째 디스플레이 전체 캡처 (1부터)                         | `-t screen:1`                 |
| all             | 모든 디스플레이 캡처                                       | `-t all`                      |
| region_user     | 마우스로 영역 선택하여 캡처 (인터랙티브)                   | `-t region_user`              |
| region_static   | 고정 좌표 기반 정적 영역 캡처 (`--region` 또는 staticRegion 설정 필수) | `-t region_static --region 100,100,800,600` |
| scroll_capture  | 활성 윈도우를 자동 스크롤하며 반복 캡처 → 수직 스티칭      | `-t scroll_capture`           |

* 기본값: target 미지정 시 `window_pointer` (코드 `config.target ?? .single("window_pointer")`).

## target alias (코드 인식 호환 표기)

`TargetType.init(from:)` / `parseTargetType` / `captureSingleImage` 가 인식하는 동의어. 신규 작성 시 canonical 사용 권장.

| alias         | canonical 매핑      | 비고                                                |
| ------------- | ------------------- | --------------------------------------------------- |
| window        | window_pointer      | bare `window` → `captureSingleImage` 에서 동일 처리 |
| staticRegion  | region_static       | decoder 가 `.staticRegion` 으로 직접 매핑           |
| region        | region_user         | bare `region` → 인터랙티브 영역 선택 처리           |
| scroll        | scroll_capture      | parseTargetType / decoder 동의어                    |

# 옵션 용어

## shadow (윈도우 그림자)

| 구분        | 기본값 | 설명                                    |
| ----------- | ------ | --------------------------------------- |
| macOS (OS)  | true   | 시스템 스크린샷 기본 동작 (그림자 포함) |
| fCapture 앱 | false  | 앱 기본값 (그림자 제외, 깔끔한 캡처)    |

* CLI: `--shadow`(포함) / `--no-shadow`(제외, 기본). 설정 키: `shadow` (Bool).
* window 계열·scroll_capture 캡처 시 적용됨. `config.shadow ?? false`.

## window_flash (플래시 피드백)

* 캡처 후 대상 윈도우에 파란 테두리를 0.5초 표시하는 시각 피드백.
* CLI: `--flash` / `--no-flash`. 설정 키: `window_flash` (Bool, JSON CodingKey `window_flash` ↔ Swift `windowFlash`).
* `window_active`/`window_pointer` 캡처 시 `config.windowFlash ?? true` 로 적용. `window_flash` target 은 이 피드백을 항상 켠 변형.

## relay (지연 캡처)

* 캡처를 N초 지연 후 실행. 모든 캡처 모드 공통.
* CLI: `--relay <N>` (0 이상 숫자, 초). 설정 키: `relay` (Double). 우선순위: **CLI `--relay` > 설정 파일 `relay`**.
* Issue20(CLI 옵션) → Issue21(설정 파일/companion YAML 지원). 상세: `yaml-companion-config.md`.

## result (출력 형식)

| 값       | 설명                          |
| -------- | ----------------------------- |
| text     | 상세 로그 메시지 (**기본값**) |
| json     | CaptureResult JSON 배열       |
| onlyPath | 저장 파일 경로만 출력         |

* CLI: `-R/--result <format>`. 설정 키: `result`. 마지막 사용 형식은 `StateManager` 에 기본값으로 저장됨.

## fileFormat (파일명 템플릿)

* 토큰: `%d`(날짜 yyyyMMdd), `%T`(시간 HHmmss), `%target`(대상명, `screen:N`→`screenN`), `%id`(3자리 ID 카운터).
* 기본값: `%d_%T` (코드). 번들 `default.yml` 템플릿값: `%d_%T_%target`.
* 확장자 없으면 `.png` 자동 추가.

## capturePath / capturePathArray (저장 경로)

* `capturePath` 가 **정수**면 `capturePathArray` 의 인덱스, **문자열**이면 직접 경로.
* CLI: `-p/--path <path>` (문자열 경로로 오버라이드).
* 미지정 시 시스템 Desktop(`~/Desktop`) 사용. CLI help(`printHelp` fallback·번들 `Usage.txt`) 와 코드 fallback 모두 `~/Desktop` 으로 일치 (과거 printHelp fallback 의 "~/Pictures" 오기 수정됨).

# 프리셋 플래그

| 플래그       | 동작                                          |
| ------------ | --------------------------------------------- |
| -s/--screen  | 스크린 전체 캡처 (`defaultScreen.json` 사용)  |
| -w/--window  | 윈도우 캡처 (`defaultWindow.json` 사용)       |
| -r           | 영역 캡처 (`defaultRegion.json` 사용)         |
| -f/--fixRegion | 마지막 region 좌표를 `defaultRegion.json` 에 고정 |
| -h/--help    | 도움말 출력                                   |
| -v/--version | 버전 출력 (현재 1.0.18)                       |

# 용어 변경 이력

## window_pointer/window_active/window_flash 분화 (Issue8, 2026-03-27 이후)
* `window_pointer`(마우스 위치) / `window_active`(활성) / `window_flash`(활성+플래시) 로 세분화.
* 구 단일 `window`(=구 `active`) 표기는 `window_pointer` alias 로 잔존.

## region_user/region_static 명칭 도입
* 인터랙티브 영역 = `region_user`, 고정 좌표 = `region_static`.
* 구 `region`/`staticRegion` 은 alias 로 잔존.

## scroll_capture 모드 추가 (Issue17~19)
* 활성 윈도우 자동 스크롤 + 수직 스티칭 캡처 모드 신규 추가.

## relay 도입 (Issue20~21)
* `--relay` CLI(Issue20) → 설정 파일/companion YAML 지원(Issue21).
