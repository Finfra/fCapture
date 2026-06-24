#!/bin/bash

# fCapture 캡처 테스트 스크립트
# Usage: ./captureTest.sh

set -e  # 에러 발생시 스크립트 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 헤더 출력
echo -e "${BLUE}🧪 fCapture Capture Tests${NC}"
echo "===================================="

# 실행 파일 존재 확인
if [[ ! -x "bin/fCapture" ]]; then
    echo -e "${RED}❌ Executable not found: bin/fCapture${NC}"
    echo "Please run './buildAndTest.sh' first to build the project"
    exit 1
fi

# 빌드된 실행 파일 정보
echo -e "${BLUE}📊 Executable Information:${NC}"
ls -lh bin/fCapture
echo ""

# 기본 기능 테스트
echo -e "${BLUE}🧪 Running Capture Tests...${NC}"
echo ""

# 테스트 1: 실행 파일 유효성 검사
echo -e "${YELLOW}Test 1: Executable check${NC}"
if [[ -x "bin/fCapture" ]]; then
    echo -e "${GREEN}✅ Executable is valid${NC}"
else
    echo -e "${RED}❌ Executable is not valid${NC}"
    exit 1
fi

# 테스트 2: 설정 파일 없이 실행 (기본값 테스트)
echo -e "${YELLOW}Test 2: Default execution test${NC}"
cd bin
if timeout 10s ./fCapture 2>&1 | grep -q "스크린샷이 저장되었습니다\|기본값으로 실행합니다"; then
    echo -e "${GREEN}✅ Default execution successful${NC}"
else
    echo -e "${RED}❌ Default execution failed${NC}"
    cd ..
    exit 1
fi
cd ..

# 테스트 3: 존재하지 않는 설정 파일로 오류 처리 테스트
echo -e "${YELLOW}Test 3: Error handling test${NC}"
cd bin
if ./fCapture nonexistent.json 2>&1 | grep -q "설정 파일을 읽을 수 없습니다\|설정 파일이 존재하지 않습니다"; then
    echo -e "${GREEN}✅ Error handling works correctly${NC}"
else
    echo -e "${RED}❌ Error handling failed${NC}"
    cd ..
    exit 1
fi
cd ..

# 테스트 4: 설정 파일이 있으면 해당 설정으로 테스트
if [[ -f "bin/.fCapture.json" ]]; then
    echo -e "${YELLOW}Test 4: Configuration file test${NC}"
    cd bin
    if timeout 10s ./fCapture .fCapture.json 2>&1 | grep -q "스크린샷이 저장되었습니다"; then
        echo -e "${GREEN}✅ Configuration file execution successful${NC}"
    else
        echo -e "${RED}❌ Configuration file execution failed${NC}"
        cd ..
        exit 1
    fi
    cd ..
fi

# 테스트 5: 예제 파일 테스트 (있는 경우)
if [[ -d "data" ]]; then
    echo -e "${YELLOW}Test 5: Example JSON files test${NC}"
    
    # 몇 가지 예제 파일 테스트
    test_files=("data/settings/00_default.json" "data/settings/01_screen1.json" "data/settings/02_screen2.json")
    
    for test_file in "${test_files[@]}"; do
        if [[ -f "$test_file" ]]; then
            echo -e "  Testing: ${test_file}"
            if timeout 10s ./bin/fCapture "$test_file" 2>&1 | grep -q "스크린샷이 저장되었습니다"; then
                echo -e "  ${GREEN}✅ $test_file test successful${NC}"
            else
                echo -e "  ${RED}❌ $test_file test failed${NC}"
            fi
        fi
    done
fi

# 테스트 완료
echo ""
echo -e "${GREEN}🎉 All capture tests completed!${NC}"
echo ""

# 사용법 안내
echo -e "${BLUE}📖 Usage Instructions:${NC}"
echo "1. Run with default settings:"
echo "   ./bin/fCapture"
echo ""
echo "2. Run with custom config:"
echo "   ./bin/fCapture config.json"
echo ""
echo "3. Run with example configs:"
echo "   ./bin/fCapture data/settings/00_default.json"
echo "   ./bin/fCapture data/settings/01_screen1.json"
echo ""

# 생성된 파일 목록
echo -e "${BLUE}📁 Available Files:${NC}"
echo "Executable: bin/fCapture"
if [[ -f "bin/.fCapture.json" ]]; then
    echo "Config: bin/.fCapture.json"
fi
if [[ -d "data" ]]; then
    echo "Examples: data/ directory"
fi
echo ""

echo -e "${GREEN}✅ Capture testing completed successfully!${NC}"