---
title: fCapture 용어 사전
description: fCapture 프로젝트에서 사용하는 핵심 용어 정의
date: 2026-06-15
---

> 개정 (2026-07-20, Issue23): `_doc_arch` ↔ 소스 정합성 감사. alias 표를 CLI(`parseTargetType`)와 JSON decoder(`TargetType.init(from:)`) 두 경로로 분리 기술함 — `region` 은 CLI 전용 alias 이며 설정 파일에서는 동작하지 않음. 버전 하드코딩을 VERSION 파일 참조로 치환하고, 코드측 오기 2건에 🔧 [FIXME] 를 부착함.
>
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

신규 작성 시 canonical 사용 권장. **alias 인식 범위가 경로에 따라 다르다** — CLI `-t` 인자는 `parseTargetType` 이, JSON/YAML 설정 값은 `TargetType.init(from:)`(decoder) 가 각각 해석하며 둘의 동의어 목록이 같지 않다.

| alias        | canonical 매핑 | CLI (`parseTargetType`) | JSON decoder (`init(from:)`)          |
| ------------ | -------------- | :---------------------: | :------------------------------------ |
| window       | window_pointer | ✅ `.single("window")`  | ✅ `.single("window")`                |
| staticRegion | region_static  | ✅ `.staticRegion`      | ✅ `.staticRegion`                    |
| region       | region_user    | ✅ `.region`            | ❌ `.single("region")` 로 떨어짐      |
| scroll       | scroll_capture | ✅ `.scrollCapture`     | ✅ `.scrollCapture`                   |

* `window` 는 두 경로 모두 `.single(원문)` 으로 전달되고, 최종 분기는 `captureSingleImage` 가 `window_pointer` 와 동일하게 처리한다.
* ⚠️ **`region` 은 CLI 전용 alias 다.** decoder 의 특수 분기는 `all`·`staticRegion`/`region_static`·`region_user`·`scroll_capture`/`scroll` 뿐이라, JSON 설정에 `"target": "region"` 을 적으면 `.region`(인터랙티브 선택)이 아니라 `.single("region")` 이 된다. 설정 파일에서는 반드시 canonical `region_user` 를 쓸 것.

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
| -v/--version | 버전 출력 — 값은 git root [VERSION](../VERSION) 파일이 SSOT (빌드 시 `appVersion` 에 주입) |

* 영역 캡처 프리셋은 **`-r` 단독 형태만** 인식된다(`parseArguments`). `--region` 은 프리셋이 아니라 정적 영역 좌표 옵션(`--region x,y,w,h`)이다.
    - 🔧 [FIXME] 번들 `Usage.txt` 는 `-r, --region` 을 프리셋으로 병기하고 있어 오기다. 또한 프리셋 분기 `case "-r", "--region":` 의 `"--region"` 은 `parseArguments` 가 그 값을 프리셋으로 넘기지 않으므로 도달 불가(dead branch)다. 코드 변경이므로 별도 이슈 후보.
    - 🔧 [FIXME] `printHelp` 의 fallback 출력(번들 `Usage.txt` 미탑재 시 사용)은 `--no-flash` 를 기본값이라고 표기하나, 실제 기본은 flash **ON**(`config.windowFlash ?? true`)이다. 번들 `Usage.txt` 쪽 표기가 맞다.

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
