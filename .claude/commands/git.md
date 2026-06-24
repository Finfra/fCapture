---
title: git
name: git
description: "Git 작업 수행 (status, add, commit, push 또는 일괄 처리)"
date: 2026-03-27
---

**사용법**: `/git [command] [options]`
- `/git`: (기본값) 전체 흐름 진행 (Status -> Add -> Commit -> Push)
- `/git status`: 상태 확인
- `/git add`: 변경사항 스테이징
- `/git commit`: 커밋 (메시지 필요)
- `/git pull`: 원격 풀
- `/git push`: 원격 푸시

---

1. **상태 확인**:
   ```bash
   git --no-pager status
   git --no-pager diff
   ```

2. **스테이징**:
   ```bash
   git add .
   # 또는 특정 파일
   # git add [파일경로]
   ```

3. **커밋**:
   ```bash
   git commit -m "[메시지]"
   ```

4. **푸시**:
   ```bash
   git push
   ```

5. **검증**:
   - 각 단계의 Exit Code가 0인지 확인합니다.
   - `git --no-pager log --oneline -5`로 커밋 확인
