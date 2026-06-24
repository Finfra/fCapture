---
title: 경로 및 디렉토리 규칙
description: fCapture의 파일 경로 처리 및 디렉토리 구조 규칙
date: 2026-03-27
---

# 1. 하드코딩된 절대 경로 금지
- `/Users/nowage/...` 같은 절대 경로를 코드에 넣지 마십시오.
- `FileManager.default.homeDirectoryForCurrentUser` 사용

# 2. 핵심 경로 참조

## 소스 코드
```
fCapture/Package.swift              # SPM 프로젝트 정의
fCapture/ScreenCapture.swift        # 핵심 캡처 모듈
fCapture/ScreenCaptureApp.swift     # CLI 진입점
```

## 빌드 결과물
```
fCapture/.build/release/fCapture    # Release 빌드 바이너리
fCapture/.build/debug/fCapture      # Debug 빌드 바이너리
```

## 배포 경로
```
~/.bin/fCapture                     # 글로벌 배포 위치
bin/fCapture                        # 프로젝트 내 바이너리
```

## 설정 파일
```
~/.fCapture/defaultSetting.json     # 사용자 기본 설정 (없으면 자동 생성)
~/.fCapture/info_stateManager.json  # 상태 파일 (ID 카운터 등)
```

## 문서
```
Issue.md                            # 이슈 관리
README.md                           # 프로젝트 문서
data/                       # JSON 설정 예제
```

# 3. 스크립트 실행 경로

```bash
# 빌드: 항상 fCapture 디렉토리에서 실행
cd fCapture && swift build -c release

# 테스트: 프로젝트 루트에서 실행
./buildAndTest.sh
./captureTest.sh
```
