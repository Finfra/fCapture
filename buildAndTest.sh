#!/bin/bash

# fCapture 빌드 및 테스트 스크립트
# Usage: ./buildAndTest.sh [clean]

set -e  # 에러 발생시 스크립트 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 프로젝트 디렉토리 설정
PROJECT_DIR="fCapture"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 헤더 출력
echo -e "${BLUE}📸 fCapture Build & Test${NC}"
echo "=================================="

# 디렉토리 확인
if [[ ! -d "$PROJECT_DIR" ]]; then
    echo -e "${RED}❌ Project directory '$PROJECT_DIR' not found${NC}"
    echo "Please run this script from the main project directory"
    exit 1
fi

# Clean 옵션 처리
if [[ "$1" == "clean" ]]; then
    echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
    rm -rf "$PROJECT_DIR/.build"
    rm -rf bin
    echo -e "${GREEN}✅ Clean completed${NC}"
    echo ""
fi

# bin 디렉토리 생성 (상위 폴더에)
echo -e "${BLUE}📁 Creating bin directory...${NC}"
mkdir -p bin

# VERSION SSOT 주입 (빌드 전 소스에 버전 동기화)
if [[ -f "VERSION" ]]; then
    VER=$(cat VERSION)
    echo -e "${BLUE}🏷  Injecting VERSION ($VER) into ScreenCaptureApp.swift...${NC}"
    sed -i '' -E 's/(static let appVersion = )"[^"]*"/\1"'"$VER"'"/' "$PROJECT_DIR/ScreenCaptureApp.swift"
    echo -e "${GREEN}✅ Version injected${NC}"
else
    echo -e "${YELLOW}⚠️  VERSION file not found. Skipping version injection.${NC}"
fi

# 프로젝트 디렉토리로 이동
echo -e "${BLUE}📂 Entering project directory: $PROJECT_DIR${NC}"
cd "$PROJECT_DIR"

# 1. Swift Package 빌드 (Release 모드)
echo -e "${BLUE}🔨 Building fCapture (Release)...${NC}"
if swift build -c release; then
    echo -e "${GREEN}✅ Build successful${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

# 2. 실행 파일을 상위 bin 폴더로 복사
echo -e "${BLUE}📦 Copying executable to ../bin/...${NC}"
if cp .build/release/fCapture ../bin/; then
    echo -e "${GREEN}✅ Executable copied to bin/fCapture${NC}"
else
    echo -e "${RED}❌ Failed to copy executable${NC}"
    exit 1
fi

# 3. 설정 파일도 상위 bin 폴더로 복사 (있는 경우)
if [[ -f ".fCapture.json" ]]; then
    cp .fCapture.json ../bin/
    echo -e "${GREEN}✅ Configuration file copied${NC}"
fi

# 4. ~/.bin/ 디렉토리로도 복사 (시스템 전역 사용을 위해)
echo -e "${BLUE}📦 Copying to ~/.bin/ for global access...${NC}"
mkdir -p ~/.bin
if cp .build/release/fCapture ~/.bin/; then
    echo -e "${GREEN}✅ Executable copied to ~/.bin/fCapture${NC}"
    
    # PATH에 ~/.bin이 없으면 안내 메시지
    if [[ ":$PATH:" != *":$HOME/.bin:"* ]]; then
        echo -e "${YELLOW}💡 Tip: Add ~/.bin to your PATH for global access:${NC}"
        echo "   echo 'export PATH=\"\$HOME/.bin:\$PATH\"' >> ~/.zshrc"
        echo "   source ~/.zshrc"
    fi
else
    echo -e "${YELLOW}⚠️  Failed to copy to ~/.bin/ (not critical)${NC}"
fi

# 상위 디렉토리로 돌아가기
cd ..

# 4. 빌드된 실행 파일 정보
echo ""
echo -e "${BLUE}📊 Build Information:${NC}"
ls -lh bin/fCapture
echo ""

# 5. 캡처 테스트 실행
echo -e "${BLUE}🧪 Running Capture Tests...${NC}"
if [[ -f "captureTest.sh" ]]; then
    chmod +x captureTest.sh
    ./captureTest.sh
else
    echo -e "${YELLOW}⚠️  captureTest.sh not found. Skipping capture tests.${NC}"
fi
echo ""

# 빌드 완료
echo -e "${GREEN}✅ Build completed successfully!${NC}"
echo "Executable is ready at: bin/fCapture"
echo ""

# 사용법 안내
echo -e "${BLUE}📖 Usage Instructions:${NC}"
echo "1. Run with default settings:"
echo "   ./bin/fCapture"
echo ""
echo "2. Run with custom config:"
echo "   ./bin/fCapture config.json"
echo ""
echo "3. Global access (if ~/.bin is in PATH):"
echo "   fCapture"
echo "   fCapture config.json"
echo ""
echo "4. Clean and rebuild:"
echo "   ./buildAndTest.sh clean"
echo ""
echo "5. Run additional tests:"
echo "   ./captureTest.sh"
echo ""

# 생성된 파일 목록
echo -e "${BLUE}📁 Generated Files:${NC}"
ls -la bin/
echo ""

echo -e "${GREEN}✅ Build completed successfully!${NC}"