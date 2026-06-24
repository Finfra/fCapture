---
title: dev
description: "fCapture 개발 주기 (dev-m 기반, Swift CLI 도구 특화)"
date: 2026-03-31
---

> **기반**: 이 스킬은 `~/.claude/skills/dev-m/SKILL.md` (macOS 앱 특화)를 기반으로 합니다.
> `dev-m` → `dev-g` 순서로 글로벌 패턴을 상속합니다.
> - 개발 주기 패턴(Case A/B, 완료 프로토콜) → dev-g 정의
> - Swift 빌드, 테스트 → dev-m 정의
> - 이 문서는 **fCapture 프로젝트 특화 내용만** 추가 정의합니다.

# fCapture 특화 설정

## 이슈후보 참조 경로

* `Issue.md`의 `# 🌱 이슈후보` 섹션

## 빌드/검증

```bash
# Release 빌드
cd fCapture && swift build -c release

# 빌드 + 배포
./buildAndTest.sh
```

## 완료 알림

```bash
say 'Complished'
```

## QA 검증

* CLI 캡처 테스트: `/run` 커맨드로 빌드 및 기본 동작 확인
* 설정 파일 전수 테스트: `qa` 스킬 사용 (`data/settings/` 전수 실행)
