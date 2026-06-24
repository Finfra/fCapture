---
name: brew-deploy_plan
description: fCapture Homebrew 배포 — GitHub repo 생성 + tap + Formula 배포 계획
date: 2026-06-24
issue: Issue22
arch: _doc_arch/brew-deploy-design.md
---

# 개요

fCapture 를 `brew install finfra/tap/fcapture` 단일 명령으로 설치 가능하게 함.
설계 SSOT 는 [`_doc_arch/brew-deploy-design.md`](../../_doc_arch/brew-deploy-design.md).
본 plan 은 실행 단계·완료 조건·승인 게이트를 정의함.

# 확정 결정 (사용자 승인 2026-06-24)

* **owner**: Finfra (org) — `github.com/Finfra/fCapture`, `Finfra/homebrew-tap`
* **tap**: 공용 `Finfra/homebrew-tap` (추후 fAppCli 형제 CLI Formula 수용)
* **배포 방식**: source-build Formula (notarization 불필요·arch 무관)
* **실행**: 단계별 승인 (외부 공개·push 직전 게이트)
* **라이선스**: PolyForm Noncommercial 1.0.0 (prj1 모델) — 소스 공개 / 비상업 무료 / 상업 유료
    - SPDX `PolyForm-Noncommercial-1.0.0` → Formula `license` 표기 가능
    - PolyForm 은 Distribution License 명시 허용 → 공개 tap 배포 정합. 단 homebrew-core 등재 불가 → custom tap 한정

# Needs Exploration (탐색 결과)

* git remote 없음 — fCapture 소스 repo 자체가 미생성 → **소스 repo + tap repo 2개** 신규 생성 필요
* `gh` 인증: nowage 계정, Finfra org 멤버 (push 권한 가정, Phase1 에서 검증)
* 기존 LICENSE = 독점("재배포 금지") → brew 공개 배포와 충돌 → PolyForm Noncommercial 로 교체 결정
* 버전 하드코딩: `ScreenCaptureApp.swift:420 appVersion = "1.0.18"` → VERSION 파일 SSOT + 빌드 시 sed 주입
* `Package.swift` resources(`.copy()` JSON/YAML/Usage.txt) → SPM 빌드 시 `fCapture_fCapture.bundle` 생성 여부 Phase0 검증 (bundle 분리 시 Formula 에 `prefix.install` 추가)

# 실행 단계

## Phase 0 — 로컬 준비 (가역, 팀 병렬)

승인 불요(로컬 파일 변경만). 3개 독립 작업 병렬:

* **VERSION SSOT**: git root 에 `VERSION` 생성(`1.0.18`). `buildAndTest.sh`·배포 스크립트가 빌드 전 `appVersion` 라인을 VERSION 값으로 sed. `--version` 출력 일치 검증
* **LICENSE 교체**: 독점 LICENSE → PolyForm Noncommercial 1.0.0 (영문 `LICENSE` + 한글 `LICENSE_ko.md`), Required Notice = `Copyright Finfra Co., Ltd. (https://finfra.kr)`. README 에 라이선스·상업 문의 안내 추가
* **Formula 초안**: `Formula/fcapture.rb` (source-build, `license "PolyForm-Noncommercial-1.0.0"`, `--disable-sandbox`, `test do`). resource bundle 처리 포함. README 에 `brew install` 섹션 추가

## Phase 1 — GitHub repo 생성 [승인 게이트]

⚠️ 외부 공개·되돌리기 어려움 → **사용자 승인 후 실행**.

* `gh repo create Finfra/fCapture --public` + 현재 코드 push (main)
* `gh repo create Finfra/homebrew-tap --public`
* push 전 `.gitignore` 확인(.build/ 산출물·바이너리 제외)

## Phase 2 — 릴리즈

* `git tag v1.0.18 && git push --tags`
* source tarball sha256 산출: `curl -sL {archive_url} | shasum -a 256`
* `Formula/fcapture.rb` 의 `url`·`sha256` 채움 → tap repo push

## Phase 3 — 검증 + 종결 (팀)

* `brew tap finfra/tap && brew install finfra/tap/fcapture`
* `fcapture --version` → `1.0.18` 일치, 기본 캡처 동작 확인
* report 작성(`_doc_work/report/brew-deploy_issue22_report.md`)
* Issue22 종결 (commit hash 기록)

# 완료 조건

* [ ] VERSION SSOT 생성 + `--version` 일치
* [ ] LICENSE = PolyForm Noncommercial (영/한) + README 안내
* [ ] `Finfra/fCapture` public repo + 코드 push
* [ ] `Finfra/homebrew-tap` + `Formula/fcapture.rb` (url·sha256 채움)
* [ ] `brew install finfra/tap/fcapture` 성공 + 동작 확인
* [ ] Issue22 ✅ 종결 (hash 기록)

# 리스크

* org push 권한 부족 가능 → Phase1 에서 `gh repo create Finfra/...` 실패 시 사용자에 권한/대안(nowage owner) 보고
* resource bundle 미동봉 시 런타임 설정 로드 실패 → Phase0 검증 필수
* `--disable-sandbox` 없으면 brew sandbox 에서 SPM 빌드 실패 가능
