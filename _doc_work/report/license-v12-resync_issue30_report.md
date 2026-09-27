---
name: license-v12-resync_issue30_report
description: Issue30 라이선스 훅 v1.1 → v1.2 재동기 + Official Build 구분 표식 결과 — 변경 파일·검증·설계 선택·후속 과제
date: 2026.09.27
issue: Issue30
---

# 요약

* **1단계 (문서, `b082473`)**: `DISTRIBUTION-TERMS.md`·`TRADEMARK.md`·`COMMERCIAL.md`·`NOTICE` 를 템플릿 v1.2 로 교체. README 설치 명령 **바로 앞**에 약관 2줄
* **2단계 (코드, TDD)**: 공식 빌드에만 `resources/official/`(배너·아이콘)을 Mach-O 섹션으로 링크 → `fcapture --version` 2줄째 `Finfra Official Build`. 소스 빌드는 1줄 그대로
* `git push`·`Finfra/homebrew-tap` 수정·태그 변경·npm publish 는 **하지 않았다**
* 근거: 템플릿 `___architect/data/template/license/` v1.2 (prj6 `3195f25`) · 검토 처분표 `license-hook-review_issue17_report.md` §반영 결과 · 정본 `license-profiles.md` §3-2·§5

# 1단계 — 문서 재동기

| 파일 | 내용 |
| :--- | :--- |
| [DISTRIBUTION-TERMS.md](DISTRIBUTION-TERMS.md) | v1.2 전문. `{{EFFECTIVE_DATE}}`=2026-09-27 — v1.1 발효일과 같지만 그 사이 나간 공식 빌드는 0건(최신 v1.0.18 은 PolyForm 시절)이라 충돌 없음 |
| [TRADEMARK.md](TRADEMARK.md) · [NOTICE](NOTICE) | `{{MARKS}}` = `"fCapture", "fcapture", the fCapture icon` — 양쪽 같은 값 |
| [COMMERCIAL.md](COMMERCIAL.md) | 테마 행 삭제(fCapture 는 테마 없음) — 템플릿 지시대로 |
| [README.md](README.md) | 설치 명령 앞 «설치 전 확인» 2줄(§0 요약 + 설치=동의) · 라이선스 절 bullet 을 v1.2 문구로(개인 용도=조직 비관리 기기, VM·컨테이너·CI 산입, Apache 추출 허용) |
| [Formula/fcapture.rb](Formula/fcapture.rb) | caveats 문구를 v1.2 §0 과 맞춤(`personal use … other organizations`) — **로컬만** |
| `LICENSE_ko.md` | 변경 없음 (Apache 참고 번역) |

* 템플릿 대조: 템플릿을 같은 자리표 값으로 다시 렌더해 비교 — `DISTRIBUTION-TERMS.md`·`TRADEMARK.md` **바이트 동일**, `COMMERCIAL.md` 는 테마 행만, `NOTICE` 는 줄바꿈 + 2단계의 `resources/official/` 문단만 다르다
* ⚠️ 이슈 검증 항목 «4개 문서 `Version 1.2`» — 템플릿 자체가 `Version 1.2` 문자열을 `DISTRIBUTION-TERMS.md` 에만 둔다. 나머지 3종에 문자열을 덧붙이면 템플릿에서 벗어나므로, 위 **렌더본 대조**로 v1.2 여부를 판정했다

# 2단계 — Official Build 구분 표식

## 무엇을 했나

| 파일 | 내용 |
| :--- | :--- |
| [resources/official/](resources/official/README.md) | `banner.txt`(2줄) · `icon.png`(`data/app-icon.png` 256px 축소) · README(Apache 대상 아님 안내) |
| [fCapture/ScreenCaptureApp.swift](fCapture/ScreenCaptureApp.swift) | `officialBuildBanner()` — `getsectiondata(#dsohandle, "__TEXT", "__fc_banner")` 로 읽어 `--version` 뒤에 출력. 섹션이 없으면 nil |
| [deploy-brew.sh](deploy-brew.sh) | 공식 빌드 = `-Xlinker -sectcreate` 2종 + `--scratch-path .build/official` · 빌드 전 `rm -f "$BIN"`(재링크 강제) · 빌드 후 섹션 2종 존재 검사 · `--build-only` 신설 |
| [NOTICE](NOTICE) · [README.md](README.md) | `resources/official/` 는 Official Build Components 라 Apache 대상 아님 — 문단 1개·표 1행 |
| [_doc_arch/brew-deploy-design.md](_doc_arch/brew-deploy-design.md) | 릴리즈 절차 2단계를 «공식 빌드» 로, «공식 빌드 구분 표식» 절 신설 |
| [tdd/playlist.md](tdd/playlist.md) · [tdd/tdd-test.sh](tdd/tdd-test.sh) | 목표 #11 `official-build-marker` |

## 왜 링크 섹션인가

* brew formula 는 tarball 의 `fcapture` **하나만** 설치한다(SPM 리소스 번들 없음). 구성요소가 설치본에 남으려면 바이너리 안에 있어야 한다
* Swift 소스(Apache)에는 섹션을 읽는 일반 코드만 있고 **배너 문구는 없다** — 문구는 `resources/official/banner.txt`(Apache 밖)에 산다. 조건부 컴파일(`#if OFFICIAL`)로 문구를 소스에 두면 그 문구가 Apache 로 공개되어 §1(b) 의 «Apache 가 아닌 구성요소» 가 다시 빈다
* 약관 §1(b) 정의의 «brand assets embedded in the build (… icons, logos, banners, about/version text)» 와 문자 그대로 일치한다

## TDD 경과

| 단계 | 결과 |
| :--- | :--- |
| red ① | `--build-only` 부재로 공식 빌드 산출 실패 — 기능 부재가 원인인 실패 |
| red ② | `FCAPTURE_OFFICIAL_BIN=bin/fCapture`(소스 빌드를 공식 자리에) → 표식 3단언(배너 표기·섹션 2종) 모두 ❌ — 단언이 판별력을 가짐을 확인 |
| green | `./tdd/tdd-test.sh version-flag official-build-marker` → **PASS 2 / FAIL 0** (jm4) |

* 도중 오진 1건: 스크립트가 «섹션 누락» 이라 했으나 섹션은 있었다 — `pipefail` + `otool | grep -q` SIGPIPE 오판(20/20). 진단 전문은 [debug_TECH.md](_doc_work/debug_TECH.md) 2026-09-27 항목

## 추가 실측

| 항목 | 결과 |
| :--- | :--- |
| 공식 빌드 `--version` arm64 · x86_64(Rosetta) | 두 슬라이스 모두 3줄(버전 + 배너 2줄) |
| 아이콘 섹션 추출(`segedit -extract`) vs `icon.png` | `cmp` 동일 |
| minos (`LC_BUILD_VERSION`) | 13.0 — Package.swift `.macOS(.v13)` 과 일치 |
| 배너에 한 줄 추가 → `--build-only` | 새 줄 반영(재링크 강제 동작) → 원복 후 재빌드, 원본 `cmp` 동일 |
| `--dry-run` 전 경로 | exit 0 · Formula md5 불변 · gh release 미호출 · tarball 의 `fcapture --version` 에 배너 · ad-hoc 서명 유지 |
| 소스 빌드 `bin/fCapture` | 섹션 0 · `--version` 1줄 (`version-flag` 기존 계약 유지) |

* 부수: `--dry-run` 은 설계상 루트에 `fCapture-1.0.18.tar.gz` 를 다시 만든다(gitignore 대상). 실제 v1.0.18 릴리스 에셋은 GitHub 에 있으므로 영향 없음
* Screen Recording 이 필요한 나머지 목표(#2~#10)는 이번 변경(`--version` 분기·배포 스크립트)과 무관해 돌리지 않았다 — 특히 #8 은 마우스 포인터를 옮기므로 사용 중인 jm4 에서 돌리지 않는다

## 독립 리뷰 (code-reviewer) 처분

| 지적 | 심각도 | 처분 |
| :--- | :--- | :--- |
| `--build-only` 가 TDD 러너에서 불리는데 `appVersion` 을 `sed -i` 로 **추적 소스에 다시 씀** — `VERSION` 을 먼저 올린 시점에 돌리면 의도치 않은 변경이 남는다 | HIGH | **수용** — `--build-only` 는 주입 생략, `--version` 과의 조합은 거부. 실측: 실행 전후 `ScreenCaptureApp.swift` mtime·md5 불변 |
| `--build-only` 실패 원인이 `check` 출력에 안 보임 | MEDIUM | 수용 — 산출 실패 시 빌드 stderr 끝 5줄 출력 |
| 이 목표만 universal2 빌드가 돈다 | MEDIUM | 수용(문서) — 재생목록·러너 주석에 `FCAPTURE_OFFICIAL_BIN` 재사용 안내. scratch path 가 남아 2회차부터는 증분(실측 약 12초) |
| 배너에 NUL·비 UTF-8 바이트가 섞이면 그대로 출력 | LOW | 보류 — `banner.txt` 는 이 repo 가 관리하는 ASCII 2줄이라 실제 위험 없음 |

* 확인된 무결: `#dsohandle` + `mach_header_64` 는 두 슬라이스에서 안전 · 새 실패 경로는 전부 `exit 1` · 단언이 공허하지 않음 · 소스 빌드 1줄 계약과 formula `assert_match` 회귀 없음

# tap 반영 (미실행 — 다음 릴리스 때)

다음 `./deploy-brew.sh` 실행이 공식 빌드 tarball 을 만든다. 그 뒤 로컬 [Formula/fcapture.rb](Formula/fcapture.rb) 를 tap 에 통째로 복사한다(Issue29 리포트의 절차와 같다). formula `test do` 의 `assert_match "fCapture"` 는 1줄째가 그대로라 통과한다.

# 후속 (범위 밖)

* **`tdd/release.md` 에 출고 목표 추가** — «설치본 `fcapture --version` 2줄째 `Finfra Official Build`». 이 파일은 작업 중 다른 세션(prj3#Issue741, `e6a29ca`)이 수정·커밋하고 있어 손대지 않았다
* **`_doc_arch/*-design.md` 2종 rename** (`brew-deploy-design`·`cli-contract-design`) — naming-rules. 참조 16곳이 `tdd/release.md`·z_done 문서에 걸쳐 있어 별도 이슈로 — Issue.md 이슈후보 등록
* **형제 repo 재사용**: prj25 Issue238 · prj26 Issue105 가 같은 2단계를 갖는다. 이 리포트의 «링크 섹션» 방식(소스엔 리더만, 문구는 `resources/official/`)을 그대로 옮길 수 있다
* 공증(notarize)은 여전히 없음 — 약관 정의는 «where the target platform supports it» 이라 위반은 아니나, 직접 tarball 배포를 시작하면 필요(설계 문서 «향후 확장»)
