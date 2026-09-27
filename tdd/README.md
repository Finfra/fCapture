---
title: tdd
description: prj51 fCapture TDD 폴더 — 재생목록과 테스트 실물의 자리 (prj6#Issue16)
date: 2026.09.26
---

# 구조

| 경로 | 내용 |
| :--- | :--- |
| [playlist.md](playlist.md) | **재생목록** — 무엇을 어떤 순서로 검증하나 |
| [tdd-test.sh](tdd/tdd-test.sh) | 신규 목표 블랙박스 러너 — `./tdd/tdd-test.sh [id ...]`, 실패 시 exit 1 |
| [pointer-to-front-window.swift](tdd/pointer-to-front-window.swift) | window_pointer 목표용 헬퍼 — 포인터를 최전면 윈도우 중앙으로 이동 |

* 형식 선례: prj1 `tdd/`(케이스 yml + 러너) · prj7 `tdd/`(파이프라인 E2E 카드)
