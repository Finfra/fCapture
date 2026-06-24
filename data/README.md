---
title: fCapture JSON 설정 파일 예제 모음
description: fCapture CLI에서 사용할 수 있는 JSON 설정 파일 예제 및 옵션 가이드
date: 2026-03-27
---

# 사용법

```bash
./bin/fCapture data/settings/01_screen1.json
./bin/fCapture data/settings/05_region_static.json
./bin/fCapture data/settings/14_option_backupOtherScreen.json
```

# target 값 종류

| target 값                            | 설명                      | 예제 JSON                | 비고                                    |
| ------------------------------------ | ------------------------- | ------------------------ | --------------------------------------- |
| `"window"`                           | 활성 윈도우 캡처          | `00_default.json`        | 기본값. frontmost 윈도우 자동 선택      |
| `"screen:1"` ~ `"screen:N"`          | 특정 디스플레이 전체 캡처 | `01_screen1.json`        | 멀티모니터 지원                         |
| `["screen:1","screen:2","screen:3"]` | 다중 대상 동시 캡처       | `03_screen123.json`      | 배열 형식                               |
| `"all"`                              | 모든 디스플레이 캡처      | `04_screenAll.json`      | 자동 감지                               |
| `"region_static"`                    | 좌표 지정 영역 캡처       | `05_region_static.json`  | `staticRegion: {x,y,width,height}` 필요 |
| `"region_user"`                      | 마우스로 영역 선택 캡처   | `06_region_user.json`    | `/usr/sbin/screencapture -i` 호출       |
| `"window_active"`                    | 활성 윈도우 캡처          | `07_window_active.json`  | `"window"`와 동일                       |
| `"window_pointer"`                   | 마우스 클릭 윈도우 캡처   | `08_window_pointer.json` | 사용자가 캡처할 윈도우를 클릭           |

* 특정 windowID 지정 캡처: 엔진(`captureWindow(windowID:)`)은 있지만 CLI 미노출

# options

| 키                  | 타입              | 설명                                         | 기본값      | 예제 JSON                          |
| ------------------- | ----------------- | -------------------------------------------- | ----------- | ---------------------------------- |
| `capturePath`       | `String` \| `Int` | 저장 경로 (문자열 또는 인덱스)               | `~/Desktop` | `00_default.json`                  |
| `fileFormat`        | `String`          | 파일명 템플릿                                | -           | `00_default.json`                  |
| `staticRegion`      | `Object`          | 정적 영역 좌표 `{x,y,width,height}`          | -           | `05_region_static.json`            |
| `shadow`            | `Bool`            | 윈도우 그림자 포함 여부                      | -           | `15_option_shadow_false.json`      |
| `backupOtherScreen` | `String`          | 다른 화면 백업 저장 경로                     | -           | `14_option_backupOtherScreen.json` |
| `capturePathArray`  | `[String]`        | 경로 배열 (`capturePath`가 인덱스일 때 참조) | -           | `12_option_capturePathArray0.json` |
| `result`            | `String`          | 출력 형식 (`text`/`json`/`onlyPath`)         | `text`      | `17_option_result_text.json`       |

## fileFormat 변수

| 변수      | 치환값                                        | 예시       |
| --------- | --------------------------------------------- | ---------- |
| `%d`      | 날짜 (`yyyyMMdd`)                             | `20260327` |
| `%T`      | 시간 (`HHmmss`)                               | `143052`   |
| `%target` | 캡처 대상 (`window`, `screen1`, `screen2` 등) | `screen1`  |
| `%id`     | ID 카운터 (3자리, 리셋: 3시간+날짜 변경)      | `001`      |

## capturePath 사용법
* **문자열**: `"capturePath": "~/Desktop"` → 해당 경로에 직접 저장
* **인덱스**: `"capturePath": 0` → `capturePathArray[0]` 경로 사용

# 예제 파일 목록

## 기본 캡처 (00~08)

| 파일명                   | target             | 설명                    |
| ------------------------ | ------------------ | ----------------------- |
| `00_default.json`        | `window`           | 기본 윈도우 캡처        |
| `01_screen1.json`        | `screen:1`         | 첫 번째 디스플레이      |
| `02_screen2.json`        | `screen:2`         | 두 번째 디스플레이      |
| `03_screen123.json`      | `[screen:1,2,3]`   | 다중 스크린 동시 캡처   |
| `04_screenAll.json`      | `all`              | 모든 디스플레이         |
| `05_region_static.json`  | `region_static`    | 좌표 지정 영역 캡처     |
| `06_region_user.json`    | `region_user`      | 마우스로 영역 선택      |
| `07_window_active.json`  | `window_active`    | 활성 윈도우 캡처        |
| `08_window_pointer.json` | `window_pointer`   | 마우스 클릭 윈도우 캡처 |

## 옵션 예제 (11~19)

| 파일명                              | 옵션                | 설명                           |
| ----------------------------------- | ------------------- | ------------------------------ |
| `11_option_basePath.json`           | `capturePath`       | basePath 참조 경로             |
| `12_option_capturePathArray0.json`  | `capturePathArray`  | 경로 배열 인덱스 0             |
| `13_option_capturePathArray1.json`  | `capturePathArray`  | 경로 배열 인덱스 1             |
| `14_option_backupOtherScreen.json`  | `backupOtherScreen` | 다른 화면 자동 백업            |
| `15_option_shadow_false.json`       | `shadow: false`     | 윈도우 그림자 제거             |
| `16_option_shadow_true.json`        | `shadow: true`      | 윈도우 그림자 포함             |
| `17_option_result_text.json`        | `result: text`      | 텍스트 출력 (기본)             |
| `18_option_result_json.json`        | `result: json`      | JSON 출력                      |
| `19_option_result_onlyPath.json`    | `result: onlyPath`  | 파일 경로만 출력               |

# JSON ↔ CLI 동등 명령

| 기능                   | JSON 방식                                          | CLI 방식                                       |
| ---------------------- | -------------------------------------------------- | ---------------------------------------------- |
| screen:1 캡처          | `fCapture data/settings/01_screen1.json`           | `fCapture -t screen:1`                         |
| window_active          | `fCapture data/settings/07_window_active.json`     | `fCapture -t window_active`                    |
| 전체 화면 캡처         | `fCapture data/settings/04_screenAll.json`         | `fCapture -t all`                              |
| 고정 영역 캡처         | `fCapture data/settings/05_region_static.json`     | `fCapture --region 100,100,800,600`            |
| JSON 출력              | result: json 키를 JSON에 설정                      | `fCapture -t window_pointer -R json`           |
| 그림자 제거            | shadow: false 키를 JSON에 설정                     | `fCapture -t window_pointer --no-shadow`       |
| 하이브리드 (오버라이드)| -                                                  | `fCapture config.json -R json --no-shadow`     |

# 테스트

```bash
# 모든 예제 한 번에 테스트
for file in data/settings/*.json; do
    echo "Testing: $file"
    ./bin/fCapture "$file"
done
```
