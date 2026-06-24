---
title: fCapture 배포 가이드
description: fCapture Release 빌드 및 배포 절차
date: 2026-03-27
---

# 1. 배포 절차 (Release Build & Copy)

Swift Package Manager로 Release 빌드 후 `~/.bin/`으로 복사하는 방식입니다.

## 1.1 배포 정보
- **소스 위치**: `fCapture/.build/release/fCapture`
- **타겟 위치**: `~/.bin/fCapture` (글로벌)
- **🚫 금지**: `./bin/fCapture`는 배포 대상이 아님. 빌드 바이너리를 직접 참조하는 **쉘 래퍼 스크립트(static code)**이므로 절대 덮어쓰거나 수정하지 말 것

## 1.2 배포 명령어

```bash
# 1. Release 빌드
cd fCapture && swift build -c release

# 2. 글로벌 배포
cp .build/release/fCapture ~/.bin/fCapture

# 3. 확인
ls -lh ~/.bin/fCapture
```

## 1.3 빌드 스크립트
```bash
# 통합 빌드/테스트/배포
./buildAndTest.sh

# Clean 빌드
./buildAndTest.sh clean
```

# 2. 검증
- `fCapture --help` 또는 기본 실행으로 동작 확인
- `captureTest.sh`로 캡처 테스트
