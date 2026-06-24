---
name: issue-rules
description: fCapture 이슈 관리 규칙 (issue-g 기반)
date: 2026-04-04
---

> 공통 규칙은 `~/.claude/rules/issue-g.md` 참조.
> 아래는 fCapture 프로젝트 고유 규칙만 기재.

# 완료 섹션

* 완료 섹션명: `# ✅ 완료` (기본값 사용)

# Issue Completion Protocol

* 완료(✅) 처리 시 Commit Hash 필수 기록
* **순서**: Code Commit → Get Hash → Update Issue.md → Commit Issue.md
