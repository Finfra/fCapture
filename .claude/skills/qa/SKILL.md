---
title: qa
description: "fCapture 설정 파일 기반 QA 테스트. data/settings/ 내 모든 JSON을 자동 감지하여 바이너리 실행 테스트를 수행하고 결과를 테이블로 보고함."
date: 2026-03-30
---

# QA 테스트 스킬

`data/settings/` 디렉토리의 JSON 설정 파일들을 fCapture 바이너리로 실행하여 정상 동작을 검증함.

## 사전 조건

* 실행 래퍼: `bin/fCapture` (쉘 스크립트 — 빌드 바이너리 직접 참조)
* 빌드 바이너리 없으면 먼저 실행: `cd fCapture && swift build -c release` (복사 불필요)

## 테스트 절차

1. `ls data/settings/*.json` 으로 설정 파일 목록 수집
2. 각 파일에 대해 `timeout 15 ./bin/fCapture <파일>` 실행
3. exit code, stdout, 생성된 파일 경로 기록
4. 결과를 테이블로 정리

## 실행 규칙

* 각 명령어에 `timeout 15` 적용 (인터랙티브 모드 대비)
* `region_user` 등 인터랙티브 설정은 타임아웃 시 "인터랙티브 - 스킵"으로 기록
* exit code 0 = 성공, 그 외 = 실패
* 생성된 캡처 파일 경로도 출력에서 추출하여 기록

## 결과 보고 형식

```markdown
| #  | 설정 파일       | 결과 | 비고          |
| -- | --------------- | ---- | ------------- |
| 1  | 00_default.json | ✅   | window 캡처   |
| 2  | ...             | ❌   | 에러 메시지   |
```

마지막에 요약: `성공: N/M (N%)`, 실패 항목 상세
