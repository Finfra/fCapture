---
title: save-point-update
description: "커밋 후 커밋 해시를 Issue.md의 Save Point에 기록"
date: 2026-03-30
---

> **기반**: `~/.claude/skills/issue-m/SKILL.md` → `~/.claude/skills/issue-g/SKILL.md`
> Save Point 패턴은 issue-g에서 정의. 이 문서는 실행 절차만 담당.


# Save Point Update Skill

변경사항을 커밋하고, 커밋 해시를 `Issue.md`의 `* Save Point:` 항목에 추가함.

# 실행 프로세스

## 1. 변경사항 확인 및 커밋

```bash
git add -A && git commit -m "커밋 메시지"
```

## 2. 커밋 해시 + 날짜 확인

```bash
git log -1 --format="%h %cd" --date=format:"%Y-%m-%d"
```

## 3. Issue.md Save Point 업데이트

`* Save Point:` 항목에 새 줄 누적 추가. 기존 항목 삭제 금지.

## 4. Issue.md 변경 커밋

```bash
git add Issue.md && git commit -m "Docs: Save Point 업데이트"
```

## 자동화 스크립트

```bash
python3 .claude/skills/save-point-update/scripts/save-point.py \
  --hash "[hash]" --file "Issue.md"
```
