---
title: 프로젝트 규칙(.claude/rules/) 관리 워크플로우
description: "프로젝트 규칙(.claude/rules/) 관리 워크플로우"
date: 2026-03-27
---

# /rule-mgr - 규칙 관리

프로젝트 규칙(`.claude/rules/`)을 관리합니다.

## 1. 규칙 목록 확인
```bash
ls -la .claude/rules/
```

## 2. 새 규칙 등록 (Register)
1. `.claude/rules/[규칙명].md` 파일 생성 (kebab-case 필수)
2. 규칙 내용 작성
3. 커밋

### 네이밍 규칙
- kebab-case만 허용: `my-rule.md`
- snake_case 금지: `my_rule.md`

## 3. 규칙 업데이트 (Update)
1. `.claude/rules/[규칙명].md` 파일 직접 편집
2. 변경 내역 커밋

## 4. 규칙 삭제 (Delete)
1. 해당 규칙 파일 삭제
2. 다른 문서에서 해당 규칙 참조 제거
3. 커밋

## 현재 규칙 파일 목록
- `coding-rules.md` — 앱 개요, 소스 구조, 코딩 규칙
- `deploy-rules.md` — 배포 절차
- `git-rules.md` — Git 워크플로우
- `issue-rules.md` — 이슈 관리
- `language-rules.md` — 언어 규칙
- `naming-rules.md` — 네이밍 규칙
- `path-rules.md` — 경로 규칙
- `terminal-rules.md` — 터미널 규칙
