---
name: issue-fix
description: 이슈 해결 및 완료 처리 (Fix -> Verify -> Doc -> Close)
date: 2026-03-31
---

> **기반**: 이 커맨드는 `~/.claude/commands/issue-fix-m.md` (macOS 앱 범용)를 기반으로 합니다.
> 프로젝트 특화 사항만 이 파일에서 관리하며, 공통 절차는 글로벌 커맨드를 참조합니다.

이슈를 분석하고, 구현하고, 검증한 뒤 종결하는 전체 흐름을 수행합니다.

# 절차

## 1. 문제 분석 및 재현 (Analyze & Reproduce)
* `Issue.md`에서 이슈 내용 확인 (목적 / 상세)
* 관련 파일 파악:
  - **캡처 로직**: `fCapture/ScreenCapture.swift`
  - **CLI/설정**: `fCapture/ScreenCaptureApp.swift`
  - **SPM**: `fCapture/Package.swift`

## 2. 구현 (Implement Fix)
* 코드를 수정합니다.
* **커밋 메시지 규칙**: `Fix(Scope): Issue[번호] [제목]` 형식으로 작성합니다.

## 3. 검증 (Verify)

### 빌드 확인
```bash
cd fCapture && swift build -c release 2>&1 | grep -E "error:|Build complete"
```

### 동작 확인
```bash
./bin/fCapture
```

## 4. 문서화 (Document)
* **필수**: `* 구현 명세` 섹션에 변경 내용 기술 (어떤 파일의 어떤 로직을 어떻게 변경했는지)

## 5. 이슈 종결 (Close Issue)
* **`/issue-closer` 워크플로우를 실행합니다.**
