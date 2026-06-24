---
title: build
name: build
description: "fCapture Release 빌드만 수행 (배포 없음)"
date: 2026-03-27
---

아래 절차를 **순서대로 bash 명령으로 직접 실행**할 것. 설명만 하지 말고 실행해야 함.

1. **Release 빌드** (셸 기반):
   ```bash
   cd fCapture && swift build -c release
   ```

2. **빌드 결과 확인**:
   - 빌드 성공 시: "빌드 완료" 메시지 출력
   - 빌드 실패 시: 에러 메시지 출력 후 중단

## 문제 해결 (Troubleshooting)
빌드 실패 시:
```bash
cd fCapture && swift package clean
cd fCapture && swift build -c release
```
