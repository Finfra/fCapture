---
title: Naming Rules (명명 규칙)
description: 프로젝트 파일 및 디렉토리 명명 규칙 (Naming Conventions)
date: 2026-03-27
---

이 문서는 fCapture 프로젝트의 파일, 디렉토리, 및 리소스 명명에 대한 표준을 정의합니다.

# 1. Skills, Rules, Workflows (Agent Directories)
Agent 관련 디렉토리(`.claude/`) 내의 **모든 파일 및 디렉토리**는 **kebab-case** (소문자 및 하이픈)를 엄격히 준수해야 합니다. **밑줄(`_`) 사용은 엄격히 금지됩니다.**

* **Skills**: `.claude/skills/skill-name.md`
    - ✅ `.claude/skills/issue-manager.md`
    - ❌ `.claude/skills/issue_manager.md`
* **Rules**: `.claude/rules/rule-name.md`
    - ✅ `.claude/rules/naming-rules.md`
    - ❌ `.claude/rules/naming_rules.md`
* **Commands**: `.claude/commands/command-name.md`
    - ✅ `.claude/commands/issue-fix.md`
    - ❌ `.claude/commands/issue_fix.md`

> [!IMPORTANT]
> `.claude/` 내에 생성되는 모든 파일은 절대 `_`를 포함해서는 안 됩니다.

# 2. 이유 (Rationale)
* **일관성**: CLI 도구 및 URL 등에서 하이픈이 더 널리 사용됨.
* **가독성**: 밑줄(_)보다 하이픈(-)이 시각적으로 단어를 더 명확하게 구분함.

# 3. 마이그레이션 가이드
기존의 `snake_case`로 작성된 이름은 발견 즉시 `kebab-case`로 변경하고, 관련 참조를 업데이트해야 합니다.
