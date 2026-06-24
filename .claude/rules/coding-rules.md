---
title: 코딩 및 설계 정책
description: fCapture 코딩 표준 (Coding Standards)
date: 2026-03-27
---

# 1. 앱 개요

fCapture는 **macOS Swift CLI 기반의 스크린 캡처 도구**입니다.
- CoreGraphics를 활용한 화면 캡처
- JSON 설정 파일로 다양한 캡처 시나리오 자동화
- 전체 화면, 특정 디스플레이, 윈도우, 영역 캡처 지원

# 2. 소스 파일 구조

```
fCapture/
├── Package.swift              # SPM 정의 (macOS 13+, executable)
├── ScreenCapture.swift        # 핵심 캡처 모듈 (CoreGraphics)
├── ScreenCaptureApp.swift     # CLI 진입점 + 설정/상태 관리
└── .fCapture.json             # 기본 설정
```

# 3. 코딩 규칙

## 하드코딩 경로 금지
- `/Users/nowage/...` 같은 절대 경로 금지
- `FileManager.default.homeDirectoryForCurrentUser` 또는 `Bundle.main` 사용

## 빌드 시스템
- Swift Package Manager (SPM) 사용
- `swift build -c release` 로 빌드
- Xcode 프로젝트 파일 없음

## JSON 설정 관리
- `ScreenCaptureConfig` 구조체로 디코딩
- 설정 파일 우선순위: 명령줄 인수 > DefaultSettingPath.txt > .fCapture.json > 기본값

# 4. 에러 처리 규칙
- 설정 파일 로드 실패 시: 기본값 사용
- 캡처 실패 시: 로그 출력 후 다음 대상으로 진행
- 로그 파일: `/tmp/fCapture.log`

# 5. 네이밍 규칙
- 타입: `UpperCamelCase`
- 변수/함수: `lowerCamelCase`
- 들여쓰기: 4칸 스페이스
