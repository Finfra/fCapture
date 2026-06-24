---
title: issue-hwm
description: "Issue.md HWM(High Water Mark) 확인 및 Self-Healing 동기화"
date: 2026-03-30
---

> **기반**: `~/.claude/skills/issue-m/SKILL.md` → `~/.claude/skills/issue-g/SKILL.md`
> HWM 개념 및 이슈 ID 형식은 **issue-g에서 정의**. 이 문서는 실행 절차만 담당.

---

# A. HWM 확인

## 목적

`Issue.md`의 현재 HWM을 확인하여 다음 이슈 번호를 결정.

## 절차

1. `Issue.md` 상단 확인:
   ```
   * Issue HWM: N
   ```

2. 다음 이슈 번호 = HWM + 1

---

# D. HWM Self-Healing (동기화)

## 목적

`Issue.md`의 HWM이 실제 이슈 내역과 일치하지 않을 때 자동 보정.

## 자동화 스크립트

```bash
python3 .claude/skills/issue-hwm/scripts/issue-hwm.py sync --file "Issue.md"
```
