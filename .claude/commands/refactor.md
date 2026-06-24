---
title: refactor
name: refactor
description: "리팩토링 및 구조 개선 워크플로우"
date: 2026-03-27
---

1. **범위 설정**:
   - 리팩토링할 클래스/파일을 명확히 선정합니다.
   - 기능 변경 없이 구조만 개선함을 원칙으로 합니다.

2. **Save Point 확보 (필수)**:
   - 대규모 리팩토링 전에는 반드시 커밋을 하여 Save Point를 만듭니다.
   ```bash
   git add .
   git commit -m "Chore: 리팩토링 전 Save Point"
   ```

3. **코드 개선**:
   - 코드 가독성 향상, 중복 제거 등을 수행합니다.

4. **검증**:
   ```bash
   cd fCapture && swift build -c release && echo "✅ Build OK"
   ```

5. **커밋**:
   ```bash
   git add .
   git commit -m "Refactor: [설명]"
   ```
