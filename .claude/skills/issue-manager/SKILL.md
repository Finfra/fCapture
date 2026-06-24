---
title: issue-manager
description: "이슈 등록/종결 절차 (issue-m → issue-g 기반)"
date: 2026-03-30
---

> **기반**: `~/.claude/skills/issue-m/SKILL.md` → `~/.claude/skills/issue-g/SKILL.md`
> 이슈 형식, HWM 개념, 섹션 구조 → **issue-g 정의**. 이 문서는 실행 절차만 담당.

---

# B. 이슈 등록 절차 (Register)

## 등록 절차

1. `issue-hwm` 스킬로 현재 HWM 확인
2. 대상 섹션(`# 📙 일반` 등) 찾기
3. 이슈 블록을 섹션 최하단에 추가
4. `Issue HWM` 값 업데이트
5. Git 커밋: `Docs: Register Issue[번호]`

## 자동화 스크립트

```bash
python3 .claude/skills/issue-manager/scripts/issue-manager.py register \
  --title "이슈 제목" --type normal --file "Issue.md"
```

---

# C. 이슈 종결 절차 (Close)

## 종결 절차

1. 이슈를 `# ✅ 완료` 섹션으로 이동
2. 제목에 날짜, 커밋 해시 추가
3. `* 구현 명세` 섹션 추가
4. Git 커밋: `Docs: Close Issue[번호] (Hash: [hash])`

## 자동화 스크립트

```bash
python3 .claude/skills/issue-manager/scripts/issue-manager.py close \
  --id "Issue[번호]" --hash "[hash]" --file "Issue.md"
```
