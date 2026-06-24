---
name: test
description: fCapture QA 테스트 (설정 파일 전수 실행)
date: 2026-03-31
---

`data/settings/` 내 JSON 설정 파일들로 fCapture를 실행하여 정상 동작을 검증합니다.

# 1. 빌드 확인

```bash
cd fCapture && swift build -c release 2>&1 | grep -E "error:|Build complete"
```

# 2. 설정 파일 전수 테스트

```bash
ls data/settings/*.json
```

각 파일에 대해:

```bash
timeout 15 ./bin/fCapture data/settings/<파일>.json 2>&1
echo "EXIT_CODE=$?"
```

# 3. 결과 보고

```markdown
| #  | 설정 파일       | 결과 | 비고          |
| -- | --------------- | ---- | ------------- |
| 1  | 00_default.json | ✅   | window 캡처   |
```

요약: `성공: N/M (N%)`
