---
name: brew-deploy-design
description: fCapture Homebrew 배포 설계 — tap repo·Formula·VERSION SSOT·릴리즈 흐름
date: 2026-06-24
---

# 개요

fCapture(macOS Swift CLI)를 Homebrew 로 설치 가능하게 하는 배포 설계.
현재 배포는 `buildAndTest.sh` → `~/.bin/fCapture` 로컬 복사뿐이며 외부 사용자 설치 경로가 없음.
본 문서는 `brew install` 단일 명령으로 설치·업그레이드하는 구조와 그 운영 흐름을 정의함.

스코프:

* 배포 채널: Homebrew custom tap (별도 `homebrew-*` repo)
* 배포 방식 선택 근거 (source-build vs pre-built binary)
* VERSION SSOT 와 Formula 버전 동기화
* 릴리즈 절차(태그 → tap Formula 갱신)

# 관련 자료

* 버전 SSOT 규칙: `~/.claude/skills/version-manager-m/version-manager-rules.md` (Formula.rb 는 VERSION 참조, `sed` 동기화)
* 배포 규칙: [`.claude/rules/deploy-rules.md`](../.claude/rules/deploy-rules.md) (현 로컬 배포 절차)
* 빌드 스크립트: `buildAndTest.sh` (Release 빌드 → `bin/` 복사)
* 패키지 정의: [`fCapture/Package.swift`](../fCapture/Package.swift) (SPM, macOS 13+, executable + resources)
* 캡처 모드 용어: [`_doc_arch/Glossary.md`](./Glossary.md)

# 선결 조건 (현재 미충족)

🚧 [TODO] 아래 2개는 brew 배포 착수 전 필수. 현재 프로젝트에 미존재.

* **GitHub repo (origin remote)**: `git remote -v` 결과 비어 있음. Formula `url`·릴리즈 태그·source tarball 의 호스트가 필요함.
    - ✅ 결정(2026-06-24): owner = **Finfra** org. `github.com/Finfra/fCapture` (소스) + `Finfra/homebrew-tap` (tap).
* **VERSION 파일**: git root 에 `VERSION` 파일 미존재. 현재 버전 문자열은 코드 하드코딩(`ScreenCaptureApp.swift:420 appVersion = "1.0.18"`).
    - version-manager-m 규칙상 `{git_root}/VERSION` 이 단일 SSOT. brew 도입과 함께 생성 + 빌드 시 sed 주입.

# 배포 방식 결정

Homebrew CLI 배포는 2가지 경로가 있음. fCapture 특성(Screen Recording 권한 필요, 단일 SPM 타깃, arm64+x86_64)을 기준으로 비교.

| 기준               | A. source-build (채택)                          | B. pre-built binary (release asset)              |
| :----------------- | :---------------------------------------------- | :----------------------------------------------- |
| Formula 동작       | `swift build -c release` 후 `bin.install`       | release 에 올린 바이너리 tarball download         |
| 빌드 의존성        | 사용자 Xcode CLT 필요                            | 없음 (다운로드만)                                |
| 아키텍처 처리      | arch 무관 (현장 빌드)                            | arm64/x86_64 별 asset + sha256 각각 관리          |
| Gatekeeper/공증    | **불필요** (사용자가 직접 빌드)                  | 필요 — 미서명 바이너리는 quarantine 차단 위험     |
| 설치 속도          | 느림 (컴파일)                                   | 빠름                                             |
| 유지 비용          | 낮음 (source tarball sha256 1개)                | 높음 (arch별 빌드·서명·공증·sha256 갱신)          |

**채택: A. source-build**

* 사유: notarization/codesign 파이프라인 없이 즉시 배포 가능. 단일 SPM 타깃이라 Formula 빌드 블록이 단순. arch 분기 불필요.
* B 는 설치 속도 이점이 있으나 미서명 바이너리 download 는 Gatekeeper 차단 → 공증 필요 → 비용 과다. 향후 설치 빈도가 높아지면 bottle 로 전환 검토(아래 "향후 확장").

# tap repo 구조

Homebrew 는 core 외 Formula 를 `homebrew-{name}` 명명 repo(=tap)에서 가져옴.

```
github.com/{owner}/homebrew-tap        # tap repo (이름은 homebrew- 접두 필수)
└── Formula/
    └── fcapture.rb                     # Formula (소문자 파일명 = 명령 이름)
```

설치 사용자 흐름:

```bash
brew tap {owner}/tap                    # 최초 1회 (또는 brew install {owner}/tap/fcapture 한 줄)
brew install fcapture
fcapture --version
```

# Formula 설계 (source-build)

`Formula/fcapture.rb` 스켈레톤. `{owner}`·`VERSION`·`sha256` 은 릴리즈 시 주입.

```ruby
class Fcapture < Formula
  desc "macOS screen capture CLI (CoreGraphics) with JSON/YAML presets"
  homepage "https://github.com/Finfra/fCapture"
  url "https://github.com/Finfra/fCapture/archive/refs/tags/v1.0.18.tar.gz"
  sha256 "<source tarball sha256>"
  license "PolyForm-Noncommercial-1.0.0"  # 소스 공개/비상업 무료/상업 유료 (prj1 모델)

  depends_on xcode: ["15.0", :build]   # swift 5.9 toolchain (rubocop: xcode 가 macos 보다 먼저)
  depends_on :macos

  def install
    cd "fCapture" do
      system "swift", "build", "-c", "release", "--disable-sandbox"
      bin.install ".build/release/fCapture" => "fcapture"
    end
  end

  test do
    assert_match "fCapture", shell_output("#{bin}/fcapture --version")
  end
end
```

설계 포인트:

* **`--disable-sandbox`**: Homebrew 빌드는 sandbox 안에서 도는데, SPM 이 build 캐시·홈 접근 시 충돌. CLI 빌드는 sandbox 해제 권장.
* **명령 이름 소문자 `fcapture`**: brew 관례. 기존 `~/.bin/fCapture`(대문자)와 공존 가능(다른 경로). 충돌 회피 위해 별칭 통일 여부 결정 필요.
    - 🔧 [FIXME] 대소문자 정책: brew 설치본은 `fcapture`, 로컬 개발본은 `fCapture` → 사용자 혼란. caveat 또는 symlink 안내 필요.
* **resources**: ✅ 검증 완료(Phase0). `swift build -c release` 시 `.build/release/fCapture_fCapture.bundle` 분리 생성됨(7개 리소스). **그러나 코드가 `Bundle.main` 사용(`ScreenCaptureApp.swift:858,887,922,960)` → 옆의 `fCapture_fCapture.bundle` 미인식.** bundle 동봉/미동봉 모두 `--help` 가 하드코딩 fallback 출력 → 캡처 동작 무지장(모든 접근부 graceful fallback). 누락 영향은 `~/.fCapture/` 템플릿 자동생성(편의 기능) 스킵뿐.
    - Formula 처리: `bin.install bundle if File.exist?(bundle)` 안전장치로 동봉(무해·미래 회귀 방지).
    - 🔧 [FIXME] 정석은 코드를 `Bundle.module` 로 전환해 bundle 인식되게 하는 것. 현 fallback 의존은 기능상 OK 이나 템플릿 자동생성 무동작 → 별도 이슈 후보.

# VERSION SSOT 동기화

version-manager-m 규칙 준수: `{git_root}/VERSION` 이 단일 진실 원천.

| 소비처                | 동기화 방법                                          | 시점              |
| :-------------------- | :-------------------------------------------------- | :---------------- |
| `fCapture --version`  | 빌드 시 VERSION 주입 (현재 하드코딩 → 개선 대상)     | swift build       |
| GitHub Release 태그   | `git tag v$(cat VERSION)`                            | 릴리즈 publish    |
| Formula `url`         | tarball URL 의 `vX.Y.Z` 를 VERSION 으로 `sed` 치환  | 릴리즈 시         |
| Formula `sha256`      | `curl -sL {tarball} \| shasum -a 256` 결과 주입     | 릴리즈 시         |

🔧 [FIXME] 현재 버전 문자열이 소스 하드코딩(`1.0.18`). VERSION 파일 도입 후 빌드 타임 주입(`-Xswiftc -DVERSION=...` 또는 생성 Swift 파일)으로 전환해야 SSOT 일치.

# 릴리즈 절차

신규 버전 배포 1회 흐름(수동 기준, 추후 스크립트화):

```bash
# 1. 버전 결정 — VERSION 파일 갱신
echo "1.0.19" > VERSION

# 2. 코드 commit + 태그
git add -A && git commit -m "Release v1.0.19"
git tag v1.0.19 && git push origin main --tags

# 3. source tarball sha256 산출
URL="https://github.com/{owner}/fCapture/archive/refs/tags/v1.0.19.tar.gz"
SHA=$(curl -sL "$URL" | shasum -a 256 | awk '{print $1}')

# 4. tap repo 의 Formula/fcapture.rb 갱신 (url 의 vX.Y.Z + sha256)
#    sed 로 version·sha256 라인 교체 후 commit/push

# 5. 검증
brew update && brew upgrade fcapture && fcapture --version
```

🚧 [TODO] 위 흐름을 `bin/deploy-brew.sh`(또는 `/deploy brew` 커맨드)로 자동화. version-manager-m 의 `fsc-deploy-brew.sh` 패턴 참조.

# 향후 확장

* **bottle(pre-built binary) 전환**: 설치 빈도 증가 시 B 방식 병행. 단 codesign + notarize(`xcrun notarytool`) 파이프라인 선결.
* ~~**brew core 등재**~~: 🚫 불가 — homebrew-core 는 오픈소스(자유 재배포) 라이선스만 수용. PolyForm Noncommercial 은 비상업 제한 → custom tap 한정 영구.
* **fAppCli 공용 tap**: fSnippet/fWarrange 등 형제 CLI 와 `homebrew-tap` 단일 repo 공유 → Formula 다수 수용. capture-rules 처럼 글로벌 표준화 여지.

# 설계 결정 요약

* 배포 채널: **custom tap** (`homebrew-tap` repo), core 등재는 후순위.
* 배포 방식: **source-build Formula** 채택 — notarization 불필요·arch 무관·유지비 최소. binary bottle 은 향후 옵션.
* 버전 SSOT: `{git_root}/VERSION` 단일 원천, Formula `url`·`sha256` 는 릴리즈 시 `sed`/`curl` 로 동기화.
* 명령 이름: brew 설치본 `fcapture`(소문자), 로컬 개발본 `fCapture` 공존 — 대소문자 정책 확정 필요(FIXME).
* 선결 조건: GitHub repo(origin) + VERSION 파일 생성이 brew 배포 착수 전 필수(TODO).

# 변경 이력 기준

* 본 문서가 fCapture brew 배포 설계 SSOT. 배포 방식·tap 구조·릴리즈 절차 변경 시 본 문서 직접 갱신.
* 버전 동기화 메커니즘은 version-manager-m 규칙이 상위 SSOT — 충돌 시 그쪽 우선, 본 문서는 fCapture 적용 사례.
* 미해결 마커(🚧 TODO·🔧 FIXME) 해소 시 해당 항목에서 마커 제거 + 결정 내용 반영.
