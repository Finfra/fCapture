#!/bin/bash

# fCapture Homebrew 릴리즈 자동화 스크립트
# _doc_arch/brew-deploy-design.md "릴리즈 절차" 를 스크립트화 (Issue25).
#
# 동작: VERSION SSOT 를 읽어 universal2 빌드 → tarball 패키징(ad-hoc 서명)
#       → sha256 산출 → GitHub Release 생성/에셋 업로드 → 로컬 Formula/fcapture.rb 갱신.
#       tap repo(Finfra/homebrew-tap) push 는 수동(안내만) — 로컬 clone 의존 제거.
#
# Usage:
#   ./deploy-brew.sh              # VERSION 파일 버전으로 릴리즈
#   ./deploy-brew.sh --version 1.0.19   # 버전 갱신 후 릴리즈 (VERSION 파일에 기록)
#   ./deploy-brew.sh --dry-run    # 빌드·패키징·sha256 까지만, gh release 미실행
#
# 선결: gh CLI 인증(gh auth status), Finfra/fCapture repo push 권한.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

REPO="Finfra/fCapture"
PROJECT_DIR="fCapture"
FORMULA="Formula/fcapture.rb"
DRY_RUN=false
NEW_VERSION=""

# --- 인자 파싱 ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) NEW_VERSION="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help)
            grep -E '^#( |$)' "$0" | sed -E 's/^# ?//'; exit 0 ;;
        *) echo -e "${RED}❌ 알 수 없는 인자: $1${NC}"; exit 1 ;;
    esac
done

echo -e "${BLUE}📦 fCapture Homebrew 릴리즈${NC}"
echo "=================================="

# --- 선결 확인 ---
if ! command -v gh >/dev/null 2>&1; then
    echo -e "${RED}❌ gh CLI 미설치${NC}"; exit 1
fi
if [[ "$DRY_RUN" == false ]] && ! gh auth status >/dev/null 2>&1; then
    echo -e "${RED}❌ gh 미인증 — 'gh auth login' 후 재시도${NC}"; exit 1
fi

# --- 1. VERSION SSOT ---
if [[ -n "$NEW_VERSION" ]]; then
    echo "$NEW_VERSION" > VERSION
    echo -e "${GREEN}✅ VERSION → $NEW_VERSION${NC}"
fi
if [[ ! -f VERSION ]]; then
    echo -e "${RED}❌ VERSION 파일 없음${NC}"; exit 1
fi
VER=$(cat VERSION)
TAG="v$VER"
echo -e "${BLUE}🏷  버전: $VER (태그 $TAG)${NC}"

# 이미 릴리즈된 태그면 중단 (덮어쓰기 사고 방지)
if [[ "$DRY_RUN" == false ]] && gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    echo -e "${RED}❌ 릴리즈 $TAG 이미 존재 — VERSION 을 올리거나 gh release delete 후 재시도${NC}"
    exit 1
fi

# --- 2. appVersion 주입 + universal2 빌드 ---
echo -e "${BLUE}🏷  appVersion 주입...${NC}"
sed -i '' -E 's/(static let appVersion = )"[^"]*"/\1"'"$VER"'"/' "$PROJECT_DIR/ScreenCaptureApp.swift"

echo -e "${BLUE}🔨 universal2 (arm64 + x86_64) 빌드...${NC}"
( cd "$PROJECT_DIR" && swift build -c release --arch arm64 --arch x86_64 )
BIN=$(cd "$PROJECT_DIR" && swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/fCapture
if [[ ! -f "$BIN" ]]; then
    echo -e "${RED}❌ 빌드 산출 바이너리 없음: $BIN${NC}"; exit 1
fi
echo -e "${GREEN}✅ 빌드 완료${NC}"
file "$BIN" | sed 's/^/   /'

# --- 3. tarball 패키징 (소문자 fcapture) + ad-hoc 서명 ---
PKG=$(mktemp -d)
cp "$BIN" "$PKG/fcapture"
codesign -s - -f "$PKG/fcapture" 2>/dev/null || echo -e "${YELLOW}⚠️  ad-hoc 서명 skip${NC}"
TARBALL="$SCRIPT_DIR/fCapture-$VER.tar.gz"
tar -czf "$TARBALL" -C "$PKG" fcapture
rm -rf "$PKG"
SHA=$(shasum -a 256 "$TARBALL" | awk '{print $1}')
echo -e "${GREEN}✅ tarball: $TARBALL${NC}"
echo -e "   sha256: $SHA"

# --- 4. GitHub Release ---
URL="https://github.com/$REPO/releases/download/$TAG/fCapture-$VER.tar.gz"
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}🧪 --dry-run: gh release 생략${NC}"
else
    echo -e "${BLUE}🚀 GitHub Release 생성...${NC}"
    gh release create "$TAG" "$TARBALL" --repo "$REPO" --title "fCapture $TAG" \
        --notes "fCapture $VER — universal2 binary. \`brew upgrade fcapture\`"
    echo -e "${GREEN}✅ Release $TAG 생성${NC}"
fi

# --- 5. 로컬 Formula 갱신 ---
# dry-run 은 gh release 를 안 하므로 로컬 재빌드 tarball 의 sha256 이 실제 릴리즈 에셋과
# 다를 수 있다. 그 해시로 Formula 를 덮어쓰면 기존 릴리즈와 불일치하므로 dry-run 은 갱신 생략.
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}🧪 --dry-run: Formula 갱신 생략 (아래는 실 릴리즈 시 적용될 값)${NC}"
    echo -e "   url    = $URL"
    echo -e "   version= $VER"
    echo -e "   sha256 = $SHA"
else
    echo -e "${BLUE}📝 $FORMULA 갱신...${NC}"
    sed -i '' -E \
        -e 's|(url ")[^"]*(")|\1'"$URL"'\2|' \
        -e 's/(version ")[^"]*(")/\1'"$VER"'\2/' \
        -e 's/(sha256 ")[^"]*(")/\1'"$SHA"'\2/' \
        "$FORMULA"
    echo -e "${GREEN}✅ Formula 갱신 (url/version/sha256)${NC}"
fi

# --- 6. tap repo push 안내 (로컬 clone 의존 제거) ---
printf '%b\n' "
${YELLOW}▶ 다음 수동 단계 (tap repo):${NC}
  1. Finfra/homebrew-tap 의 Formula/fcapture.rb 를 위와 동일하게 갱신
     (로컬 이 repo 의 $FORMULA 내용을 복사)
  2. tap repo commit & push
  3. 검증: brew update && brew upgrade fcapture && fcapture --version
           → $VER 출력 확인

${GREEN}✅ 릴리즈 준비 완료 (버전 $VER)${NC}"
