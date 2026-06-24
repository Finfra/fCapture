---
title: run
name: run
description: "fCapture 빌드 및 실행 테스트"
date: 2026-03-27
---

인자: $ARGUMENTS

## 인자 처리

- **인자 없음** (`/run`): 빌드 후 기본 설정으로 실행
- **`run-only`** (`/run run-only`): 빌드 없이 실행만
- **JSON 경로** (`/run example.json`): 해당 설정 파일로 실행

## 실행 절차

### Step 1: 빌드 (run-only가 아닌 경우)
```bash
cd fCapture && swift build -c release
```

### Step 2: 실행
```bash
# 기본 설정으로 실행
./fCapture/.build/release/fCapture

# 또는 특정 설정 파일로 실행
./fCapture/.build/release/fCapture example_json/01_screen1.json
```

### Step 3: 결과 확인
```bash
# 로그 확인
tail -20 /tmp/fCapture.log

# 캡처된 파일 확인
ls -lt ~/Desktop/*.png | head -5
```

## 문제 해결 (Troubleshooting)
빌드 실패 시:
```bash
cd fCapture && swift package clean
cd fCapture && swift build -c release
```

스크린 녹화 권한이 없는 경우:
- **시스템 설정 > 개인정보 보호 및 보안 > 화면 녹화**에서 터미널 앱 허용 필요
