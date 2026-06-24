---
title: Git 워크플로우 가이드
description: fCapture Git 워크플로우 가이드
date: 2026-03-27
---

# Git 워크플로우 (서브태스크 완료 프로토콜)

각 서브태스크 완료 후 **필수 사항**:
1. **변경사항 검토**: `git --no-pager status` 및 `git --no-pager diff`로 확인
2. **스테이징**: `git add .` 또는 선택적 스테이징
3. **커밋**: 설명적 커밋 메시지 생성
4. **Issue.md 업데이트**: 완료된 이슈에 커밋 해시 기록

> 커밋·push 사용자 확인 의무는 글로벌 시스템 프롬프트 기본 동작("Commit or push only when the user asks")이 적용됨 — 프로젝트 로컬 강제 확인 규칙·체크리스트는 제거됨 (Issue103, 2026-05-24).

# 이슈 관리 프로세스

1. **구현**: Issue 해결을 위한 코딩 작업
2. **내부 테스트**: 빌드 및 기본 동작 확인
3. **Issue.md 업데이트**: 해결된 이슈를 완료 섹션으로 이동 (**커밋 전 필수**)
4. **커밋**: 이슈 해결과 문서 업데이트를 모두 포함

# 커밋 메시지 형식

```bash
Type(Scope): Subject

# 예시
Feat(Capture): 인터랙티브 영역 선택 캡처 추가
Fix(Config): JSON 설정 파일 파싱 오류 수정
Docs: Issue.md 업데이트
Chore: 빌드 스크립트 개선
```

## Type 종류
- `Feat`: 새 기능
- `Fix`: 버그 수정
- `Docs`: 문서 변경
- `Refactor`: 코드 개선
- `Chore`: 빌드/설정 변경
