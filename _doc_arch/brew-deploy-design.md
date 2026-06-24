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

**채택: B. pre-built binary (release asset)** — 2026-06-24 실행 중 변경

* 초기 설계는 A(source-build) 였으나, 실행 중 기존 `Finfra/homebrew-tap` 에 형제 Formula(`fsnippet-cli`·`fwarrange-cli`)가 **이미 바이너리 release asset 방식**을 사용 중임을 발견 → 컨벤션 일치.
* A 의 치명적 UX 결함: `depends_on xcode: :build` 는 최종 사용자에게 **전체 Xcode(~10GB) 설치를 강제**. CLI 도구 설치치고 과도.
* B 의 Gatekeeper 우려는 실제로 해소됨: ① Homebrew download 는 quarantine 미부여, ② SPM release 바이너리는 arm64 ad-hoc 서명 보유(+추가 `codesign -s -` 적용), ③ universal2(`swift build --arch arm64 --arch x86_64`) 단일 tarball 로 arch 분기 불요.
* 검증: `brew install finfra/tap/fcapture` → `fCapture 1.0.18` 출력, `brew test` 통과(Phase3).

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

`Formula/fcapture.rb` (실제 배포본 — `version`·`sha256` 은 릴리즈마다 갱신). SSOT 는 tap repo `Finfra/homebrew-tap`, 소스 repo 의 `Formula/fcapture.rb` 는 동기화 사본.

```ruby
class Fcapture < Formula
  desc "macOS screen capture CLI (CoreGraphics) with JSON/YAML presets"
  homepage "https://github.com/Finfra/fCapture"
  url "https://github.com/Finfra/fCapture/releases/download/v1.0.18/fCapture-1.0.18.tar.gz"
  version "1.0.18"
  sha256 "<release tarball sha256>"
  license "PolyForm-Noncommercial-1.0.0"  # 소스 공개/비상업 무료/상업 유료 (prj1 모델)

  depends_on :macos

  def install
    bin.install "fcapture"
  end

  def caveats
    # 화면 녹화 권한 + 라이선스 안내
  end

  test do
    assert_match "fCapture", shell_output("#{bin}/fcapture --version")
  end
end
```

설계 포인트:

* **바이너리 release asset**: tarball 안에 universal2 `fcapture` 바이너리 1개. `bin.install "fcapture"` 만. Xcode 의존·`--disable-sandbox` 불요(빌드 안 함).
* **명령 이름 소문자 `fcapture`**: brew 관례. macOS case-insensitive APFS 에서 로컬 `~/.bin/fCapture` 와 동일 경로 취급 → 개발 머신은 로컬 배포본이 PATH shadow. 최종 사용자(로컬 배포본 없음)는 영향 없음.
* **resources**: `.build/release/fCapture_fCapture.bundle` 이 분리 생성되나 코드가 `Bundle.main` 사용(`ScreenCaptureApp.swift:858,887,922,960`) → **미인식**. 바이너리만 배포해도 캡처 동작 무지장(모든 접근부 graceful fallback). 누락 영향은 `~/.fCapture/` 템플릿 자동생성(편의 기능) 스킵뿐 → tarball 에 bundle 미포함.
    - 🔧 [FIXME] 정석은 코드를 `Bundle.module` 로 전환. 현 fallback 의존은 기능상 OK 이나 템플릿 자동생성 무동작 → 별도 이슈 후보.

# VERSION SSOT 동기화

version-manager-m 규칙 준수: `{git_root}/VERSION` 이 단일 진실 원천.

| 소비처                | 동기화 방법                                          | 시점              |
| :-------------------- | :-------------------------------------------------- | :---------------- |
| `fCapture --version`  | `buildAndTest.sh` 가 빌드 전 `appVersion` 라인 sed  | swift build       |
| GitHub Release 태그   | `gh release create v$(cat VERSION) ...`             | 릴리즈 publish    |
| Formula `url`/`version` | release asset URL 의 `vX.Y.Z` 를 VERSION 으로 치환 | 릴리즈 시         |
| Formula `sha256`      | `shasum -a 256 {tarball}` 결과 주입                  | 릴리즈 시         |

# 릴리즈 절차

신규 버전 배포 1회 흐름(수동 기준, 추후 스크립트화):

```bash
# 1. 버전 갱신
echo "1.0.19" > VERSION

# 2. universal2 빌드 (appVersion 자동 주입은 buildAndTest.sh, 여기선 직접)
cd fCapture && swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/fCapture

# 3. tarball 패키징 (바이너리명 소문자 fcapture) + ad-hoc 서명
cp "$BIN" /tmp/pkg/fcapture && codesign -s - -f /tmp/pkg/fcapture
tar -czf fCapture-1.0.19.tar.gz -C /tmp/pkg fcapture
SHA=$(shasum -a 256 fCapture-1.0.19.tar.gz | awk '{print $1}')

# 4. GitHub release + asset 업로드
gh release create v1.0.19 fCapture-1.0.19.tar.gz --repo Finfra/fCapture --title "fCapture v1.0.19"

# 5. tap repo Formula/fcapture.rb 의 url·version·sha256 갱신 후 commit/push

# 6. 검증
brew update && brew upgrade fcapture && fcapture --version
```

🚧 [TODO] 위 흐름을 `bin/deploy-brew.sh`(또는 `/deploy brew` 커맨드)로 자동화. version-manager-m 의 `fsc-deploy-brew.sh` 패턴 참조.

# 향후 확장

* ~~**brew core 등재**~~: 🚫 불가 — homebrew-core 는 오픈소스(자유 재배포) 라이선스만 수용. PolyForm Noncommercial 은 비상업 제한 → custom tap 한정 영구.
* **공증(notarize)**: 현재 ad-hoc 서명 + brew(quarantine 미부여)로 동작. 직접 tarball 배포(brew 외) 시작하면 `xcrun notarytool` 공증 필요.
* **fAppCli 공용 tap**: 이미 `Finfra/homebrew-tap` 에 `fsnippet-cli`·`fwarrange-cli`·`fcapture` 공존. 신규 형제 CLI 는 동일 tap 에 Formula 추가.

# 설계 결정 요약

* 배포 채널: **custom tap** `Finfra/homebrew-tap` (형제 CLI 공유). core 등재 불가(noncommercial).
* 배포 방식: **pre-built binary release asset** (universal2) — 형제 tap 컨벤션 일치 + Xcode 의존 제거. (초기 source-build 안에서 변경)
* 버전 SSOT: `{git_root}/VERSION` 단일 원천 → `buildAndTest.sh` 가 빌드 전 `appVersion` sed 주입. Formula `version`·`sha256` 는 릴리즈 시 갱신.
* 라이선스: PolyForm Noncommercial 1.0.0 (소스 공개/비상업 무료/상업 유료).
* 명령 이름: brew 설치본 `fcapture`(소문자). case-insensitive APFS 라 개발 머신은 로컬 `~/.bin/fCapture` 가 PATH shadow(사용자 무관).

# 변경 이력 기준

* 본 문서가 fCapture brew 배포 설계 SSOT. 배포 방식·tap 구조·릴리즈 절차 변경 시 본 문서 직접 갱신.
* 버전 동기화 메커니즘은 version-manager-m 규칙이 상위 SSOT — 충돌 시 그쪽 우선, 본 문서는 fCapture 적용 사례.
* 미해결 마커(🚧 TODO·🔧 FIXME) 해소 시 해당 항목에서 마커 제거 + 결정 내용 반영.
