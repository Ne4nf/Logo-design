#!/bin/bash

set -e # Dừng ngay nếu có lỗi

# --- MÀU SẮC CHO ĐẸP ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting SpecLedger Environment Setup...${NC}"

# ==========================================
# 1. CẤP QUYỀN CHO SPECLEDGER SCRIPTS
# ==========================================
echo -e "\n${YELLOW}🔐 Setting permissions for SpecLedger scripts...${NC}"
if [ -d ".specify/scripts/bash" ]; then
    chmod +x .specify/scripts/bash/*.sh
    echo "   - Bash scripts: Executable ✅"
else
    echo -e "   ${RED}⚠️ Warning: .specify directory not found. Are you in the root?${NC}"
fi

# ==========================================
# 2. CÀI ĐẶT BEADS (bd)
# ==========================================
echo -e "\n${YELLOW}📦 Checking for Beads (bd)...${NC}"

if command -v bd &> /dev/null; then
    echo -e "${GREEN}✅ Beads is already installed!${NC}"
else
    echo "   Beads not found. Attempting installation..."

    # CÁCH 1: ƯU TIÊN DÙNG GO INSTALL (Ngon nhất cho mọi OS)
    if command -v go &> /dev/null; then
        echo "   🐹 Go detected. Installing via 'go install'..."
        
        # Cài đặt từ repo chính chủ
        go install github.com/steveyegge/beads/cmd/bd@latest
        
        # Kiểm tra xem GOBIN có trong PATH không
        GOBIN=$(go env GOPATH)/bin
        if [[ ":$PATH:" != *":$GOBIN:"* ]]; then
            echo -e "   ${YELLOW}⚠️  Warning: $GOBIN is not in your PATH.${NC}"
            echo "   Please add it to run 'bd' globally."
            # Thử copy ra /usr/local/bin nếu user có quyền (cho tiện)
            if [ -w "/usr/local/bin" ]; then
                 cp "$GOBIN/bd" /usr/local/bin/
                 echo "   (Copied binary to /usr/local/bin for convenience)"
            fi
        fi
        echo -e "${GREEN}✅ Beads installed via Go!${NC}"
        
    # CÁCH 2: TẢI BINARY (FALLBACK NẾU KHÔNG CÓ GO)
    else
        echo "   🚫 Go not found. Attempting binary download..."
        
        # Phát hiện OS
        OS="$(uname -s)"
        ARCH="$(uname -m)"
        
        case "${OS}" in
            Linux*)     os_name=linux;;
            Darwin*)    os_name=darwin;;
            MINGW*|CYGWIN*|MSYS*) os_name=windows;;
            *)          os_name="UNKNOWN:${OS}"
        esac

        # Mapping kiến trúc CPU
        case "${ARCH}" in
            x86_64)    arch_name=amd64;;
            arm64)     arch_name=arm64;;
            *)         arch_name="386";;
        esac

        echo "   Detected System: $os_name / $arch_name"
        
        # Link tải (Giả định Beads có Release assets chuẩn)
        # Lưu ý: Repo beads hiện tại chưa có Release binary chính thức build sẵn
        # Nên nếu không có Go, ta sẽ báo lỗi hướng dẫn.
        
        echo -e "   ${RED}❌ Error: Cannot install Beads automatically without Go.${NC}"
        echo "   SpecLedger relies on 'beads' (bd) for task management."
        echo "   👉 Please install Go: https://go.dev/dl/"
        echo "   👉 Or install Beads manually: https://github.com/steveyegge/beads"
        exit 1
    fi
fi

echo -e "\n${GREEN}🎉 Setup Complete! You are ready to rock.${NC}"
echo "   Try running: /specledger.audit"