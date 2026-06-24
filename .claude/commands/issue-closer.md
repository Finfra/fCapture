---
name: issue-closer
description: 이슈 종결 및 문서 업데이트 (Hash 확보 -> 완료 이동 -> Doc 커밋)
date: 2026-03-31
---

> **기반**: 이 커맨드는 `~/.claude/commands/issue-closer-m.md` (macOS 앱 범용)를 기반으로 합니다.
> 프로젝트 특화 사항만 이 파일에서 관리하며, 공통 절차는 글로벌 커맨드를 참조합니다.

**역할**: 해결된 이슈를 `Issue.md`에서 '완료' 상태로 변경하고, **Commit Hash**를 기록하여 추적 가능성을 보장합니다.

> [!NOTE] 파라미터 없이 실행 시 자동 모드
> 인자 없이 `/issue-closer`만 실행하면, 최근 작업 내용을 분석하여 자동으로 이슈를 종료합니다.

# 자동 모드 (파라미터 없이 실행 시)

## 0. 작업 내용 파악
```bash
git --no-pager log --oneline -5
git --no-pager diff --stat HEAD~1
git --no-pager diff --cached --stat
```
* 최근 커밋과 변경사항을 분석하여 **무슨 작업을 했는지** 파악합니다.

## 1. 이슈 매칭
* `Issue.md`의 `🚧 진행중` 섹션에 관련 이슈가 있는지 확인합니다.
* **이슈가 있으면** → 해당 이슈를 종료 대상으로 선정합니다.
* **이슈가 없으면** → 작업 내용 기반으로 새 이슈를 자동 등록합니다:
  - `Issue HWM`을 +1 증가시켜 새 번호 발급
  - 작업 내용을 분석하여 이슈 제목과 목적을 자동 생성
  - `📙 일반` 또는 적절한 카테고리에 등록 후 즉시 완료 처리

이후 아래 **공통 절차**의 Step 1부터 진행합니다.

---

# 공통 절차

## 1. 커밋 해시 확보 (Retrieve Commit Hash)
```bash
git --no-pager log -1 --format="%h"
```
* **중요**: 이 Hash는 이슈 해결의 증거이므로 반드시 정확해야 합니다.

## 2. 이슈 내용 업데이트 (issue 스킬 자동 처리)

> **`issue` 스킬 참조**: 이슈 종결 (`close`)

Python 스크립트를 사용하여 이슈를 자동으로 완료 처리합니다:

```bash
python3 .claude/skills/issue-manager/scripts/issue-manager.py close \
  --id "Issue[N]" \
  --hash "[commit-hash]" \
  --file "Issue.md"
```

스크립트가 자동으로 다음을 처리합니다:
* 이슈를 `🚧 진행중` → `✅ 완료` 섹션으로 이동
* 제목에 해결 날짜 및 커밋 해시 추가
* 필수 섹션 포맷 검증

## 3. Save Point 업데이트 (issue 스킬 자동 기록)

> **`issue` 스킬 참조**: Save Point 업데이트 (`savepoint`)

Python 스크립트를 사용하여 Save Point를 기록합니다:

```bash
python3 .claude/skills/save-point-update/scripts/save-point.py \
  --hash "[commit-hash]" \
  --msg "Docs: Close Issue[N]" \
  --file "Issue.md"
```

## 4. 문서 커밋
```bash
git add Issue.md
git commit -m "Docs: Close Issue[번호] (Hash: [hash])"
```

## 5. 완료 알림
```bash
say 'Complished'
```
