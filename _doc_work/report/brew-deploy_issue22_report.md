---
name: brew-deploy_issue22_report
description: Issue22 Homebrew 배포 완료 리포트 — 결과·검증 증거·설계 변경·후속
date: 2026-06-24
issue: Issue22
plan: _doc_work/plan/brew-deploy_plan.md
---

# 개요

fCapture 를 `brew install finfra/tap/fcapture` 로 설치 가능하게 함. GitHub 소스 repo + tap Formula 신규 구축, 검증 완료.

# 결과 요약

| 항목 | 결과 |
| :--- | :--- |
| 설치 명령 | `brew install finfra/tap/fcapture` |
| 소스 repo | https://github.com/Finfra/fCapture (public, 단일 클린 커밋) |
| Release | https://github.com/Finfra/fCapture/releases/tag/v1.0.18 (universal2 tarball) |
| tap Formula | `Finfra/homebrew-tap/Formula/fcapture.rb` |
| 라이선스 | PolyForm Noncommercial 1.0.0 (비상업 무료 / 상업 유료) |
| 검증 | `brew install` 성공 + `fcapture --version` → `fCapture 1.0.18` + `brew test` 통과 |

# 검증 증거

* `/opt/homebrew/bin/fcapture --version` → `fCapture 1.0.18` (exit 0)
* `file` → `Mach-O universal binary with 2 architectures: [x86_64] [arm64]`
* `brew test finfra/tap/fcapture` → `--version` 실행 통과
* tarball sha256: `4fbba5c9c834838db2b230c7781bd698536fc2e35729ecd05fc271dfb9745cde`

# 설계 변경 (실행 중 발생)

1. **라이선스 충돌 해소**: 기존 독점 LICENSE("재배포 금지")가 brew 공개 배포와 충돌 → prj1 모델인 PolyForm Noncommercial 1.0.0 으로 교체(소스 공개/비상업 무료/상업 유료). 영문 `LICENSE` + 한글 `LICENSE_ko.md`.
2. **배포 방식 전환 (source-build → binary)**: 기존 `Finfra/homebrew-tap` 형제 Formula(`fsnippet-cli`·`fwarrange-cli`)가 바이너리 release asset 방식 사용 중 발견 + source-build 는 사용자에게 전체 Xcode(~10GB) 강제 → universal2 바이너리 release asset 으로 전환.
3. **클린 히스토리 공개**: 기존 57커밋 히스토리에 Issue.md(22커밋)·`.build`(268MB) 포함 → public 노출 회피 위해 orphan 단일 커밋(6ebd1f5)으로 공개. 원본 57커밋은 로컬 `backup/pre-brew` 태그로 보존.

# 부수 정비

* `VERSION` 파일 SSOT 도입(`1.0.18`) + `buildAndTest.sh` 빌드 전 `appVersion` sed 주입(멱등)
* `.gitignore` 에 `.build/`·`bin/`·`.swiftpm/`·`Package.resolved` 추가 (산출물 4618개 untrack)
* `Issue.md` untrack(내부 유지) — `noteForHuman.md` 는 원래 미추적
* README 에 brew 설치 섹션 + 라이선스 섹션 추가

# 미해결·후속 (이슈 후보)

* 🔧 resource bundle 미인식: 코드가 `Bundle.main` 사용(`ScreenCaptureApp.swift:858,887,922,960`) → `fCapture_fCapture.bundle` 못 읽음. 캡처 동작 무지장이나 `~/.fCapture/` 템플릿 자동생성 무동작. 정석은 `Bundle.module` 전환.
* 🔧 버전 SSOT 정합: `appVersion` 은 빌드 시 sed 주입이나, 소스 자체엔 여전히 리터럴 존재. CI 빌드 등에서 buildAndTest 미경유 시 불일치 가능 → 빌드플러그인/생성파일 전환 검토.
* 🚧 릴리즈 자동화: `bin/deploy-brew.sh`(빌드→tarball→release→Formula 갱신→push) 미작성. 현재 수동.
* 📌 문서/실제 불일치: CLAUDE.md 가 `bin/fCapture` 를 "쉘 래퍼 스크립트"라 기술하나 실제는 buildAndTest 가 복사하는 컴파일 바이너리.
* 📌 공개 범위: `.claude/`·`_doc_work/` 가 public repo 에 포함됨(Issue.md 만 내부 유지 요청). 추가 제외 원하면 후속 정리.

# 관련 자료

* 설계 SSOT: `_doc_arch/brew-deploy-design.md`
* plan: `_doc_work/plan/brew-deploy_plan.md`
* task: `_doc_work/tasks/brew-deploy_task.md`
