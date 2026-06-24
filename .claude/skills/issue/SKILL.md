---
title: issue
description: Issue.md 수명 주기 관리 (상태 분석 → 자동 결정 → 등록/해결/종결)
date: 2026-03-31
---

> **기반**: 이 스킬은 `~/.claude/skills/issue-m/SKILL.md` (macOS 앱 특화)를 기반으로 합니다.
> `issue-m` → `issue-g` 순서로 글로벌 패턴을 상속합니다.
> - Issue.md 구조, HWM, 이슈 형식, 워크플로우 → **issue-g** 정의
> - Swift CLI 빌드, Python 자동화, Save Point 패턴 → **issue-m** 정의
> - 이 문서는 **fCapture 특화 내용만** 추가 정의합니다.

## 역할

`Issue.md`의 상태를 분석하여 다음에 무엇을 해야 할지 **자동으로 결정하고 실행**합니다.

---

# 1. 이슈 상태 분석 및 자동 결정

`Issue.md` 파일을 읽고 아래 우선순위에 따라 작업을 수행합니다.

## Priority 1: 이슈 후보 처리

* **대상**: `# 🌱 이슈후보` 섹션
* **조건**: 해당 섹션에 내용이 있는 경우
* **행동**: `/issue-reg` 워크플로우 실행

## Priority 2: 진행 중인 이슈 해결

* **대상**: `# 🚧 진행중` 섹션
* **조건**: 해당 섹션에 이슈가 할당되어 있는 경우
* **행동**: `/issue-fix` 워크플로우 실행

## Priority 3: 중요 이슈 착수

* **대상**: `# 📕 중요` 섹션
* **행동**:
    1. `# 📕 중요` 섹션의 첫 번째 이슈를 선택
    2. 해당 이슈를 `# 🚧 진행중` 섹션으로 이동
    3. `/issue-fix` 워크플로우 실행

## Priority 4: 일반 이슈 착수

* **대상**: `# 📙 일반` 섹션
* **조건**: 중요 이슈도 없는 경우
* **행동**:
    1. `# 📙 일반` 섹션의 첫 번째 이슈를 선택
    2. 해당 이슈를 `# 🚧 진행중` 섹션으로 이동
    3. `/issue-fix` 워크플로우 실행

---

# 2. fCapture 이슈 자동화 스크립트

각 워크플로우에서 사용하는 Python 스크립트 경로:

| 함수          | 스크립트                                                   | 역할           |
| ------------- | ---------------------------------------------------------- | -------------- |
| **sync**      | `.claude/skills/issue-hwm/scripts/issue-hwm.py`            | HWM 동기화     |
| **register**  | `.claude/skills/issue-manager/scripts/issue-manager.py`    | 이슈 등록      |
| **close**     | `.claude/skills/issue-manager/scripts/issue-manager.py`    | 이슈 종결      |
| **savepoint** | `.claude/skills/save-point-update/scripts/save-point.py`   | SavePoint 기록 |

## `/issue-reg` 커맨드 스크립트 흐름

```
1. HWM 동기화
   python3 .claude/skills/issue-hwm/scripts/issue-hwm.py sync --file "Issue.md"

2. 이슈 등록
   python3 .claude/skills/issue-manager/scripts/issue-manager.py register \
     --title "..." --type normal --purpose "..." --detail "..." --file "Issue.md"
```

## `/issue-closer` 커맨드 스크립트 흐름

```
1. 이슈 종결
   python3 .claude/skills/issue-manager/scripts/issue-manager.py close \
     --id "Issue[N]" --hash "[hash]" --file "Issue.md"

2. Save Point 업데이트
   python3 .claude/skills/save-point-update/scripts/save-point.py \
     --hash "[hash]" --msg "Docs: Close Issue[N]" --file "Issue.md"
```

---

# 3. 참조

* `.claude/rules/issue-rules.md` — 이슈 작성 및 배분 규칙
