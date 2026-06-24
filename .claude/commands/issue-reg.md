---
name: issue-reg
description: 이슈 등록 (HWM 확인 -> ID 발급 -> 파일 업데이트)
date: 2026-03-31
---

> **기반**: 이 커맨드는 `~/.claude/commands/issue-reg-m.md` (macOS 앱 범용)를 기반으로 합니다.
> 프로젝트 특화 사항만 이 파일에서 관리하며, 공통 절차는 글로벌 커맨드를 참조합니다.

**역할**: 새로운 이슈를 `Issue.md`에 등록합니다.

> [!IMPORTANT]
> **등록 및 계획 전담 원칙**: 이 워크플로우는 이슈를 정식 ID로 등록하고 **계획(Planning)**을 수립하는 작업까지만 수행합니다.
> 1. 사용자가 명시적으로 해결(Fix) 또는 구현(Implement)을 요청하기 전까지는 **절대로 코드를 수정하지 않습니다.**
> 2. 계획을 승인받았더라도, 다음 단계인 구현으로 넘어가기 전 반드시 사용자의 확인을 한 번 더 받습니다.

# 워크플로우 단계

## 0. 분석 및 계획 (Analysis & Planning) (필수)
* **Context Discovery (자산 탐색) (Critical)**:
    - **기존 자산 확인**: 관련 파일이 이미 존재하는지 확인합니다.
    - **규칙 대조**: `.claude/rules/` 프로젝트 규칙과 상충되지 않는지 확인합니다.
    - **가정 금지**: 모호한 표현은 추측하지 말고, 확인된 사실(Fact) 기반으로 계획을 세웁니다.
* `Issue.md`의 `## 🌱 이슈후보` 섹션과 사용자 입력을 분석합니다.
* 구체적 설계 포함 (필수):
    - **Bad**: "로직 수정", "버그 픽스"
    - **Good**: "`ScreenCapture.swift`의 `captureRegion()` 함수 내 좌표 계산 수정"

## 1. 프로세스 규칙 검증 (Verify Process Rules)
* **언어 준수**: 제목과 상세 내용은 반드시 **한국어**로 작성해야 합니다.
* **포맷 준수**: 목적(Purpose)과 상세(Details) 섹션을 포함해야 합니다.

## 2. HWM 확인

> **`issue` 스킬 참조**: HWM 동기화 (`sync`)

`Issue.md`의 HWM(High Water Mark)을 동기화합니다:

```bash
python3 .claude/skills/issue-hwm/scripts/issue-hwm.py sync --file "Issue.md"
```

## 3. 이슈 등록 (issue 스킬 자동 등록)

> **`issue` 스킬 참조**: 이슈 등록 (`register`)

Python 스크립트를 사용하여 이슈를 등록합니다:

```bash
python3 .claude/skills/issue-manager/scripts/issue-manager.py register \
  --title "이슈 제목" \
  --type normal \
  --purpose "목적 한 줄 요약" \
  --detail "- 상세 사항 1\n- 상세 사항 2" \
  --file "Issue.md"
```

**Type 옵션**:
* `critical` → `📕 중요` 섹션
* `normal` (Default) → `📙 일반` 섹션
* `optional` → `📗 선택` 섹션

## 4. 후보 정리 (Cleanup Candidates)

`Issue.md`의 `## 🌱 이슈후보` 섹션에서 **등록된 항목을 삭제**합니다. (이중 등록 방지)

## 5. Git 저장
```bash
git add Issue.md
git commit -m "Docs: Register Issue[번호]"
```

## 6. 종료 및 보고
* **작업 중단**: 이슈 등록이 완료되었습니다. 여기서 작업을 **즉시 종료**하십시오.
* **자동 진행 금지**: 절대로 `/issue-fix`로 넘어가거나 코드를 수정하지 마십시오.
* 사용자에게 "이슈 [ID]가 등록되었습니다."라고만 보고하고 대화를 마치십시오.
