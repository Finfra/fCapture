---
name: brew-deploy_task
description: fCapture Homebrew 배포 실행 태스크 체크리스트
date: 2026-06-24
issue: Issue22
plan: _doc_work/plan/brew-deploy_plan.md
---

# 개요

[`brew-deploy_plan.md`](../plan/brew-deploy_plan.md) 실행 태스크. Phase 0(가역) → 1(승인) → 2 → 3 순.

# Phase 0 — 로컬 준비 (팀 병렬, 승인 불요)

## T0-1 VERSION SSOT
* [ ] git root 에 `VERSION` 파일 생성 (내용: `1.0.18`)
* [ ] `buildAndTest.sh` 에 빌드 전 sed 단계 추가: `appVersion = "<VERSION>"` 치환
* [ ] release 빌드 후 `fcapture --version` == `cat VERSION` 검증
* [ ] version-manager-m 규칙 준수(다중 하드코딩 금지)

## T0-2 LICENSE 교체
* [ ] 기존 독점 `LICENSE` → PolyForm Noncommercial 1.0.0 영문 전문
* [ ] `LICENSE_ko.md` 한글본 추가 (prj1 `~/_git/___pm/LICENSE_ko.md` 참조)
* [ ] Required Notice: `Copyright Finfra Co., Ltd. (https://finfra.kr)`
* [ ] README 에 라이선스 배지/문구 + 상업 사용 문의 안내

## T0-3 Formula 초안 + README
* [ ] `Formula/fcapture.rb` 작성 (source-build, license `PolyForm-Noncommercial-1.0.0`, `--disable-sandbox`, test 블록)
* [ ] resource bundle 검증: `ls fCapture/.build/release/*.bundle` → 분리 시 `prefix.install` 추가
* [ ] README 에 `brew install finfra/tap/fcapture` 설치 섹션
* [ ] `.gitignore` 에 `.build/`·`bin/` 산출물 제외 확인

# Phase 1 — repo 생성 [승인 게이트]

* [ ] **사용자 승인 확인**
* [ ] `gh repo create Finfra/fCapture --public --source=. --remote=origin`
* [ ] 코드 push (main) — `.build`/바이너리 제외 확인 후
* [ ] `gh repo create Finfra/homebrew-tap --public`
* [ ] org push 권한 실패 시 보고·대안 제시

# Phase 2 — 릴리즈

* [ ] `git tag v1.0.18 && git push origin v1.0.18`
* [ ] `SHA=$(curl -sL https://github.com/Finfra/fCapture/archive/refs/tags/v1.0.18.tar.gz | shasum -a 256)`
* [ ] `Formula/fcapture.rb` `url`·`sha256` 채움
* [ ] tap repo 에 Formula push

# Phase 3 — 검증 + 종결

* [ ] `brew tap finfra/tap`
* [ ] `brew install finfra/tap/fcapture` 성공
* [ ] `fcapture --version` → `1.0.18`
* [ ] 기본 캡처 1회 동작 확인
* [ ] report 작성
* [ ] Issue22 ✅ 종결 (hash 기록 → commit)
