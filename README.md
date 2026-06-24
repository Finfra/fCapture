---
title: fCapture - macOS 스크린 캡처 CLI 도구
description: CoreGraphics 기반 macOS 스크린 캡처 CLI. JSON 설정으로 다양한 캡처 시나리오를 자동화함.
date: 2026-03-27
---

# 주요 특징
* 전체 화면 / 특정 디스플레이 / 윈도우 / 영역 캡처
* JSON 설정 파일 기반 자동화
* CLI 단축 옵션 (`-s`, `-r`, `-w`, `-f`, `-h`)
* 윈도우 캡처 시 flash 피드백 (파란 테두리 오버레이)
* 듀얼 모니터 자동 백업
* 파이프라인 친화적 출력 (text / json / onlyPath)
* ID 자동 증가 및 동적 파일명
* Swift Package Manager 빌드

## 설치 (Homebrew)

```bash
brew install finfra/tap/fcapture
fcapture --version
```

> 비상업 사용 무료. 상업 사용은 별도 라이선스 필요 — 아래 [라이선스](#라이선스) 참조.

## Quick Start

```bash
# 빌드
./buildAndTest.sh

# 기본 실행 (윈도우 캡처 → ~/Desktop)
./bin/fCapture

# JSON 설정 파일로 실행
./bin/fCapture data/settings/01_screen1.json

# 단축 옵션으로 실행
./bin/fCapture -s    # 스크린 캡처
./bin/fCapture -w    # 윈도우 캡처
./bin/fCapture -r    # 인터랙티브 영역 캡처
./bin/fCapture -f    # 마지막 영역을 고정 영역으로 저장

# 글로벌 실행 (~/.bin 배포 후)
fCapture
```

## CLI 옵션

| 옵션            | 설명                                          | 로드 설정                        |
| --------------- | --------------------------------------------- | -------------------------------- |
| `-h`, `--help`  | 도움말 출력                                   | -                                |
| `-s`, `--screen`| 스크린 캡처                                   | `~/.fCapture/defaultScreen.json` |
| `-r`, `--region`| 마우스로 영역 선택 캡처                       | `~/.fCapture/defaultRegion.json` |
| `-w`, `--window`| 윈도우 캡처                                   | `~/.fCapture/defaultWindow.json` |
| `-f`, `--fixRegion` | 마지막 영역 좌표를 고정 영역으로 저장     | -                                |
| `<파일경로>`    | JSON 설정 파일 지정                           | 지정된 파일                      |
| (없음)          | 기본 설정으로 실행                            | `~/.fCapture/defaultSetting.json`|

## 캡처 모드

| 모드             | target 값                            | 설명                            | 예제 JSON                                                    |
| ---------------- | ------------------------------------ | ------------------------------- | ------------------------------------------------------------ |
| 활성 윈도우      | `"window_active"`                    | frontmost 윈도우 캡처 (기본값)  | [07_window_active.json](data/settings/07_window_active.json) |
| 클릭 윈도우      | `"window_pointer"`                   | 마우스 클릭으로 윈도우 선택     | [08_window_pointer.json](data/settings/08_window_pointer.json)|
| 윈도우 + Flash   | `"window_flash"`                     | 캡처 후 파란 테두리 피드백 표시 | [09_window_flash.json](data/settings/09_window_flash.json)   |
| 단일 화면        | `"screen:1"` ~ `"screen:N"`         | 특정 디스플레이 캡처            | [01_screen1.json](data/settings/01_screen1.json)             |
| 모든 화면        | `"all"`                              | 모든 디스플레이 자동 감지       | [04_screenAll.json](data/settings/04_screenAll.json)         |
| 다중 선택        | `["screen:1","screen:2","screen:3"]` | 여러 대상 동시 캡처             | [03_screen123.json](data/settings/03_screen123.json)         |
| 정적 영역        | `"region_static"`                    | JSON 좌표 기반 영역 캡처        | [05_region_static.json](data/settings/05_region_static.json) |
| 인터랙티브 영역  | `"region_user"`                      | 마우스로 영역 선택              | [06_region_user.json](data/settings/06_region_user.json)     |

* `"window"`는 `"window_active"`의 별칭 (하위 호환)

## JSON 설정 옵션

| 옵션                | 타입               | 기본값      | 설명                                     |
| ------------------- | ------------------ | ----------- | ---------------------------------------- |
| `capturePath`       | `String` \| `Int`  | `~/Desktop` | 저장 경로 또는 `capturePathArray` 인덱스 |
| `capturePathArray`  | `[String]`         | -           | 인덱스 기반 경로 배열                    |
| `target`            | `String` \| `[String]` | `"window"`  | 캡처 대상                            |
| `shadow`            | `Bool`             | `false`     | 윈도우 그림자 포함 여부                  |
| `window_flash`      | `Bool`             | `true`      | 캡처 후 파란 테두리 flash 표시 여부      |
| `fileFormat`        | `String`           | `"%d_%T"`   | 파일명 형식                              |
| `staticRegion`      | `Object`           | -           | `{x, y, width, height}` 영역 좌표       |
| `backupOtherScreen` | `String`           | -           | 듀얼 모니터 백업 저장 경로               |
| `result`            | `String`           | `"text"`    | 출력 형식: `text`, `json`, `onlyPath`    |

### 파일명 변수
* `%d`: 날짜 (yyyyMMdd) → `20260327`
* `%T`: 시간 (HHmmss) → `164110`
* `%target`: 캡처 대상 → `window`, `screen1`, `screen2`
* `%id`: ID 카운터 (001, 002...) → 3시간+날짜 변경 시 리셋

### 설정 파일 예시

```json
{
  "capturePath": 1,
  "target": "screen:1",
  "fileFormat": "nowage@gmail.com_%d_%T",
  "capturePathArray": [
    "~/Desktop",
    "~/df"
  ],
  "backupOtherScreen": "~/Desktop",
  "window_flash": true,
  "result": "text"
}
```

### 신규 CLI 옵션 (v0.11+)

JSON 파일 없이 직접 CLI 파라미터로 캡처 제어 가능:

| 옵션                       | 짧은 형태 | 설명                                      | 기본값           |
| -------------------------- | --------- | ----------------------------------------- | ---------------- |
| `--target <value>`         | `-t`      | 캡처 대상 (반복 가능)                     | `window_pointer` |
| `--path <path>`            | `-p`      | 저장 경로                                 | `~/Desktop`      |
| `--format <template>`      | `-F`      | 파일명 템플릿                             | `%d_%T_%target`  |
| `--result <format>`        | `-R`      | 출력 형식 (text/json/onlyPath)            | `text`           |
| `--shadow` / `--no-shadow` |           | 윈도우 그림자 포함/제거                   | `false`          |
| `--flash` / `--no-flash`   |           | 캡처 플래시 피드백                        | `true`           |
| `--region <x,y,w,h>`       |           | 고정 영역 좌표 (region_static 타겟 필수)  |                  |
| `--backup <path>`          |           | 다른 화면 백업 저장 경로                  |                  |

#### 사용 예시

```bash
# screen:1 캡처, JSON 출력
fCapture -t screen:1 -R json

# 다중 스크린 동시 캡처
fCapture -t screen:1 -t screen:2 -p ~/Desktop/caps -F %d_%target

# 그림자 없는 윈도우 캡처
fCapture -t window_pointer --no-shadow -p /tmp

# 고정 영역 캡처
fCapture --region 100,100,800,600 -p ~/Desktop

# JSON 설정 + CLI 오버라이드 (하이브리드)
fCapture data/settings/01_screen1.json -R json --no-shadow
```

## 설정 우선순위

```
명령줄 인수 (-s/-r/-w/-f/파일) > ~/.fCapture/defaultSetting.json > 코드 기본값
```

## 아키텍처

### 소스 구조
```
fCapture/
├── Package.swift              # SPM 정의 (macOS 13+, executable)
├── ScreenCapture.swift        # CoreGraphics 기반 캡처 엔진
├── ScreenCaptureApp.swift     # CLI 진입점 + 설정/상태/로그 관리
├── Usage.txt                  # --help 출력 내용 (번들 리소스)
├── default*.json              # 기본 설정 템플릿 (번들 → ~/.fCapture/)
└── default.yml                # YAML 기본 설정
```

### 주요 클래스

| 클래스/구조체          | 역할                                                  |
| ---------------------- | ----------------------------------------------------- |
| `ScreenCapture`        | CoreGraphics 캡처 (화면/윈도우/영역)                  |
| `ScreenCaptureApp`     | CLI 진입점, 설정 로딩, 캡처 실행 흐름                 |
| `ScreenCaptureConfig`  | JSON 설정 구조 (Codable, `window_flash` 등 snake_case 매핑) |
| `StateManager`         | 상태 저장 (`~/.fCapture/info_stateManager.json`, `lastRegion` 포함) |
| `Logger`               | 콘솔 + `/tmp/fCapture.log` 로깅                      |
| `CaptureResult`        | 캡처 결과 데이터 (경로, 파일명, 타겟, ID)             |

### 캡처 흐름

```
CLI 실행
  → 기본 설정 파일 초기화 (~/.fCapture/)
  → CLI 옵션 파싱 (-s/-r/-w/-f/파일/기본)
  → 설정 파일 로딩 (JSON)
  → 권한 확인 (Screen Recording)
  → 저장 경로 결정
  → 대상별 캡처 실행 (CoreGraphics)
  → flash 피드백 표시 (윈도우 캡처 시)
  → 이미지 저장 (실패 시 ~/Desktop 폴백)
  → 백업 캡처 (설정된 경우)
  → 결과 출력 (text/json/onlyPath)
```

### 프레임워크

| 프레임워크   | 용도                              |
| ------------ | --------------------------------- |
| Foundation   | 파일 I/O, JSON, 날짜 처리        |
| CoreGraphics | 화면/윈도우 캡처 API              |
| AppKit       | NSImage 처리, 앱 정보, Alert 표시 |

## 빌드

```bash
# 자동 빌드 + 테스트 + ~/.bin 배포
./buildAndTest.sh

# Clean 빌드
./buildAndTest.sh clean

# 수동 빌드 (Release)
cd fCapture && swift build -c release

# 바이너리 위치
./bin/fCapture           # 프로젝트 내
~/.bin/fCapture          # 글로벌 (buildAndTest.sh 실행 시)
```

## 권한
* **스크린 녹화 권한** 필수
* 시스템 환경설정 > 보안 및 개인 정보 보호 > 화면 및 시스템 오디오 녹화

## 로그
* **파일**: `/tmp/fCapture.log`
* **실시간**: `tail -f /tmp/fCapture.log`
* **레벨**: INFO, WARN, ERROR

## 관련 문서
* [CLAUDE.md](./CLAUDE.md) — AI 에이전트용 프로젝트 컨텍스트
* [AGENTS.md](./AGENTS.md) — 개발 가이드라인
* [Issue.md](./Issue.md) — 이슈 트래킹
* [data/README.md](./data/README.md) — JSON 설정 예제 가이드

## 라이선스

[PolyForm Noncommercial License 1.0.0](./LICENSE) ([한글 참고 번역](./LICENSE_ko.md)).

* **비상업 사용**: 무료 — 개인 학습·연구·취미·비영리 조직 등
* **상업 사용**: 별도 상업 라이선스 필요 — 문의 [finfra.kr](https://finfra.kr)
* Copyright Finfra Co., Ltd.
