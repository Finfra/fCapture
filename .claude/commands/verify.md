---
title: verify
name: verify
description: "배포하지 않고 빌드만 검증합니다."
date: 2026-03-27
---

이 워크플로우는 Release 스킴을 사용하여 프로젝트를 컴파일하고 문법 오류나 빌드 실패가 없는지 확인합니다.
다음 작업은 **수행하지 않습니다**:
- `~/.bin/`에 배포
- 앱 실행

1. **빌드 검증**:
   다음 명령어를 실행하세요:
   ```bash
   cd fCapture && swift build -c release && echo "✅ Build OK"
   ```

2. **에러 상세 확인** (실패 시):
   ```bash
   cd fCapture && swift build -c release 2>&1 | grep -E "error:"
   ```
