---
name: deployment
description: fCapture 배포 전용 에이전트
model: haiku
color: blue
date: 2026-03-27
---

# fCapture 배포 전용 Agent

Release 빌드 및 배포를 자동화하는 전문 에이전트

## 전문 분야
- Release 빌드
- `~/.bin/fCapture` 배포
- 배포 기록 및 커밋

## 핵심 배포 명령어

### 수동 배포 단계
```bash
# 1. Release 빌드
cd fCapture && swift build -c release

# 2. 로컬(jm4) 배포
cp fCapture/.build/release/fCapture ~/.bin/fCapture

# 3. 로컬 확인
ls -lh ~/.bin/fCapture
fCapture

# 4. jma.local 배포 (동일 경로)
scp fCapture/.build/release/fCapture jma:~/.bin/fCapture
```
> `bin/fCapture`는 빌드 바이너리를 직접 참조하는 쉘 래퍼 — 복사 불필요

### 스크립트 배포
```bash
./buildAndTest.sh
```

## 배포 프로세스

1. **빌드**: Release 스킴으로 빌드
2. **로컬 배포**: `~/.bin/fCapture`로 복사 (`bin/fCapture`는 쉘 래퍼라 복사 불필요)
3. **리모트 배포**: `scp`로 jma.local의 `~/.bin/fCapture`에 복사
4. **확인**: 바이너리 크기 및 실행 테스트
5. **기록**: Issue.md 업데이트 및 커밋

## 문제 해결

### 빌드 실패 시
```bash
cd fCapture && swift package clean
cd fCapture && swift build -c release
```

## 관련 커맨드
- `/deploy` - 배포 워크플로우
- `/verify` - 빌드만 검증 (배포 없음)
