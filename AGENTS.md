# Repository Guidelines

## 프로젝트 구조
* 소스: `fCapture/` (Swift Package Manager). 주요 파일: `ScreenCapture.swift`, `ScreenCaptureApp.swift`
* 빌드 시스템: Swift Package Manager (SPM), `Package.swift` 정의
* 바이너리: `bin/fCapture` (프로젝트 내), `~/.bin/fCapture` (글로벌)
* 예제: `data/` (8개 JSON 설정 예제)
* 스크립트: `buildAndTest.sh`, `captureTest.sh`
* 문서: `_doc/`, `_tool/`
* 로그: `/tmp/fCapture.log`
* 상태: `~/.fCapture/info_stateManager.json`

## 사용자 설정 (User Preferences)
* Language: Korean(한국어) — 모든 커뮤니케이션과 주석, 사고 과정까지 한국어 기준
* Notification: 작업 완료 시 `say 'Complished'` 실행
* Issue Completion: 이슈 완료(✅) 시 Commit Hash를 `Issue.md`에 기록. 프로토콜: Code Commit → Hash 확인 → Issue.md 업데이트 → Issue.md 커밋

## 중요 관련 파일

| 카테고리 | 파일명                                                      | 설명             | 사용 시점         |
| -------- | ----------------------------------------------------------- | ---------------- | ----------------- |
| 필수     | [README.md](README.md)                                      | 기술 아키텍처    | 기술 구조 파악 시 |
| 필수     | [Issue.md](Issue.md)                                        | 이슈 관리        | 이슈 프로세스 시  |
| 소스     | [ScreenCapture.swift](fCapture/ScreenCapture.swift)         | 핵심 캡처 모듈   | 캡처 기능 수정 시 |
| 소스     | [ScreenCaptureApp.swift](fCapture/ScreenCaptureApp.swift)   | CLI 앱 진입점    | 설정/로직 수정 시 |
| 소스     | [Package.swift](fCapture/Package.swift)                     | SPM 프로젝트     | 빌드 설정 변경 시 |
| 설정     | [.fCapture.json](.fCapture.json)                            | 기본 설정 파일   | 기본 캡처 설정 시 |
| 예제     | [data/README.md](data/README.md)            | JSON 예제 가이드 | 설정 예제 참조 시 |

## 개발 환경
* macOS: 13.0+ (타겟), 15.5+ (현재 개발 환경)
* Swift: 5.9 (Swift Package Manager)
* 프레임워크: Foundation, CoreGraphics, AppKit
* 권한: 스크린 녹화 권한 (Screen Recording) 필수

## 빌드/테스트 명령

```bash
# 자동 빌드 + 테스트 + ~/.bin 배포
./buildAndTest.sh

# Clean 빌드
./buildAndTest.sh clean

# 수동 빌드 (Release)
cd fCapture && swift build -c release

# 캡처 테스트
./captureTest.sh

# 실행
./bin/fCapture                              # 기본 설정
./bin/fCapture data/settings/01_screen1.json # JSON 설정 지정
```

## 코딩 스타일 & 네이밍 규칙
* Swift: 4칸 들여쓰기
* 타입: `UpperCamelCase`
* 변수/함수: `lowerCamelCase`

## 로그 시스템
* 로그 파일: `/tmp/fCapture.log`
* 실시간: `tail -f /tmp/fCapture.log`
* 로그 레벨: INFO, WARN, ERROR
* 형식: `[YYYY-MM-DD HH:mm:ss] [LEVEL] 메시지`

## 커밋 & PR 가이드
* 커밋: 컨벤션 + 이슈 연결
    - ex) `fix: issue1 - OS 기본 폴더 동기화`
    - ex) `feat: backupOtherScreen 기능 추가`
    - ex) `docs: Issue.md 업데이트`
* 이슈 완료 시: Commit Hash를 Issue.md에 기록

## 아키텍처 개요
* **ScreenCapture**: CoreGraphics 기반 캡처 엔진 (화면/디스플레이/윈도우/영역)
* **ScreenCaptureApp**: CLI 진입점, JSON 설정 로딩, 캡처 실행 흐름
* **ScreenCaptureConfig**: JSON 설정 구조 (capturePath, target, fileFormat, staticRegion, backupOtherScreen, result)
* **StateManager**: ID 카운터 관리, 기본 결과 형식 저장 (`~/.fCapture/info_stateManager.json`)
* **Logger**: 콘솔 + 파일 로깅 (`/tmp/fCapture.log`)

### 캡처 흐름
```
CLI 실행 → 설정 로딩 → 권한 확인 → 경로 결정 → 캡처 → 저장 (폴백: ~/Desktop) → 백업 → 결과 출력
```

### 설정 우선순위
```
명령줄 인수 > ~/.fCapture/defaultSetting.json > 코드 기본값
```

## 관련 문서
* **CLAUDE.md**: AI 에이전트용 프로젝트 컨텍스트
* **README.md**: 기술 아키텍처 및 사용법
* **Issue.md**: 이슈 현황 및 진행 프로세스
* **data/README.md**: JSON 설정 예제 가이드

## 문서 경로 규칙
* 모든 문서 링크는 리포지토리 루트 기준 상대 경로 사용
* 절대 경로 하드코딩 금지
