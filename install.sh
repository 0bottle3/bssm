#!/bin/bash
set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 bssm 설치를 시작합니다...${NC}"

# 시스템 체크
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    OS="windows"
    echo -e "${YELLOW}⚠️  Windows 환경이 감지되었습니다.${NC}"
    echo -e "${YELLOW}💡 Windows에서는 WSL 사용을 권장합니다.${NC}"
else
    echo -e "${RED}❌ 지원하지 않는 운영체제입니다: $OSTYPE${NC}"
    echo -e "${YELLOW}💡 지원 OS: macOS, Linux${NC}"
    exit 1
fi

# Python 체크
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3가 필요합니다.${NC}"
    echo -e "${YELLOW}💡 Python 3를 설치해주세요: https://www.python.org/downloads/${NC}"
    exit 1
fi

# AWS CLI 체크
if ! command -v aws &> /dev/null; then
    echo -e "${YELLOW}⚠️  AWS CLI가 설치되어 있지 않습니다.${NC}"
    echo -e "${YELLOW}💡 AWS CLI를 설치해주세요: https://aws.amazon.com/cli/${NC}"
    echo -e "${YELLOW}   bssm은 AWS CLI를 사용하여 SSM 세션을 시작합니다.${NC}"
fi

# Session Manager Plugin 설치
install_session_manager_plugin() {
    echo -e "${YELLOW}🔧 Session Manager Plugin을 설치 중...${NC}"
    
    if [[ "$OS" == "macos" ]]; then
        # macOS 설치
        if command -v brew &> /dev/null; then
            echo -e "${BLUE}ℹ️  Homebrew를 사용하여 설치합니다.${NC}"
            brew install --cask session-manager-plugin
        else
            echo -e "${BLUE}ℹ️  수동으로 설치합니다.${NC}"
            TEMP_SM_DIR=$(mktemp -d)
            cd "$TEMP_SM_DIR"
            curl -s "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac/sessionmanager-bundle.zip" -o "sessionmanager-bundle.zip"
            unzip -q sessionmanager-bundle.zip
            sudo ./sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin
            cd - > /dev/null
            rm -rf "$TEMP_SM_DIR"
        fi
    elif [[ "$OS" == "linux" ]]; then
        # Linux 설치
        echo -e "${BLUE}ℹ️  Linux용 Session Manager Plugin을 설치합니다.${NC}"
        TEMP_SM_DIR=$(mktemp -d)
        cd "$TEMP_SM_DIR"
        
        # 아키텍처 확인
        ARCH=$(uname -m)
        if [[ "$ARCH" == "x86_64" ]]; then
            SM_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm"
            SM_FILE="session-manager-plugin.rpm"
        elif [[ "$ARCH" == "aarch64" ]]; then
            SM_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_arm64/session-manager-plugin.rpm"
            SM_FILE="session-manager-plugin.rpm"
        else
            echo -e "${RED}❌ 지원하지 않는 아키텍처입니다: $ARCH${NC}"
            return 1
        fi
        
        curl -s "$SM_URL" -o "$SM_FILE"
        
        # 패키지 매니저에 따른 설치
        if command -v yum &> /dev/null; then
            sudo yum install -y "$SM_FILE"
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y "$SM_FILE"
        elif command -v apt &> /dev/null; then
            # Ubuntu/Debian의 경우 deb 패키지 사용
            rm "$SM_FILE"
            if [[ "$ARCH" == "x86_64" ]]; then
                SM_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb"
            else
                SM_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_arm64/session-manager-plugin.deb"
            fi
            SM_FILE="session-manager-plugin.deb"
            curl -s "$SM_URL" -o "$SM_FILE"
            sudo dpkg -i "$SM_FILE"
        else
            echo -e "${YELLOW}⚠️  패키지 매니저를 찾을 수 없습니다. 수동 설치를 시도합니다.${NC}"
            # 수동 설치 (바이너리 직접 설치)
            rm "$SM_FILE"
            if [[ "$ARCH" == "x86_64" ]]; then
                SM_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm"
            else
                SM_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_arm64/session-manager-plugin.rpm"
            fi
            curl -s "$SM_URL" -o "session-manager-plugin.rpm"
            rpm2cpio session-manager-plugin.rpm | cpio -idmv
            sudo cp usr/local/sessionmanagerplugin/bin/session-manager-plugin /usr/local/bin/
            sudo chmod +x /usr/local/bin/session-manager-plugin
        fi
        
        cd - > /dev/null
        rm -rf "$TEMP_SM_DIR"
    fi
}

# Session Manager Plugin 체크 및 설치
if ! command -v session-manager-plugin &> /dev/null; then
    echo -e "${YELLOW}⚠️  Session Manager Plugin이 설치되어 있지 않습니다.${NC}"
    read -p "Session Manager Plugin을 설치하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_session_manager_plugin
        
        # 설치 확인
        if command -v session-manager-plugin &> /dev/null; then
            echo -e "${GREEN}✅ Session Manager Plugin 설치 완료${NC}"
        else
            echo -e "${RED}❌ Session Manager Plugin 설치 실패${NC}"
            echo -e "${YELLOW}💡 수동으로 설치해주세요: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Session Manager Plugin 없이 설치를 계속합니다.${NC}"
        echo -e "${YELLOW}💡 나중에 SSM 연결을 위해서는 Session Manager Plugin이 필요합니다.${NC}"
    fi
else
    echo -e "${GREEN}✅ Session Manager Plugin이 이미 설치되어 있습니다.${NC}"
fi

echo -e "${YELLOW}📦 설치 준비 중...${NC}"

# 현재 디렉토리가 bssm 프로젝트 디렉토리인지 확인
if [[ ! -f "src/main.py" ]] || [[ ! -f "requirements.txt" ]]; then
    echo -e "${RED}❌ bssm 프로젝트 디렉토리에서 실행해주세요.${NC}"
    echo -e "${YELLOW}💡 사용법:${NC}"
    echo -e "${BLUE}  git clone https://github.com/juniper-31/bssm.git${NC}"
    echo -e "${BLUE}  cd bssm${NC}"
    echo -e "${BLUE}  ./install.sh${NC}"
    exit 1
fi

echo -e "${BLUE}ℹ️  로컬 소스코드를 사용합니다.${NC}"

echo -e "${YELLOW}📦 Python 패키지로 설치 중...${NC}"

# 사용자 가상환경 체크 (설치 스크립트 실행 전)
if [[ -n "$VIRTUAL_ENV" ]]; then
    echo -e "${YELLOW}⚠️  가상환경이 활성화되어 있습니다.${NC}"
    echo -e "${YELLOW}💡 가상환경을 비활성화하고 다시 실행해주세요:${NC}"
    echo -e "${BLUE}deactivate${NC}"
    echo -e "${BLUE}./install.sh${NC}"
    exit 1
fi

echo -e "${YELLOW}🔧 설치 방법을 확인 중...${NC}"

# pipx 사용 가능한지 확인
if command -v pipx &> /dev/null; then
    echo -e "${BLUE}📦 pipx를 사용하여 설치합니다...${NC}"
    pipx install .
    pipx ensurepath
    INSTALL_METHOD="pipx"
    PYTHON_BIN_DIR="$HOME/.local/bin"
else
    # externally-managed-environment 에러 체크
    if python3 -c "import sys; exit(0 if hasattr(sys, 'base_prefix') else 1)" 2>/dev/null && \
       python3 -c "import pip._internal.utils.misc; pip._internal.utils.misc.check_externally_managed()" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  시스템에서 pip 직접 설치가 제한되어 있습니다.${NC}"
        echo -e "${BLUE}📦 pipx를 설치하고 다시 시도합니다...${NC}"
        
        # pipx 설치 시도
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y pipx
        elif command -v yum &> /dev/null; then
            sudo yum install -y pipx
        elif command -v brew &> /dev/null; then
            brew install pipx
        else
            echo -e "${RED}❌ pipx 자동 설치 실패. 수동으로 설치해주세요.${NC}"
            echo -e "${YELLOW}💡 Ubuntu/Debian: sudo apt install pipx${NC}"
            echo -e "${YELLOW}💡 CentOS/RHEL: sudo yum install pipx${NC}"
            echo -e "${YELLOW}💡 macOS: brew install pipx${NC}"
            exit 1
        fi
        
        pipx install .
        pipx ensurepath
        INSTALL_METHOD="pipx"
        PYTHON_BIN_DIR="$HOME/.local/bin"
    else
        echo -e "${BLUE}📦 pip를 사용하여 설치합니다...${NC}"
        # 의존성 확인
        python3 -c "import boto3, click, rich, pydantic, keyring" 2>/dev/null || {
            echo -e "${YELLOW}📦 필요한 의존성을 설치합니다...${NC}"
            pip3 install --user boto3 click rich pydantic keyring
        }
        
        pip3 install --user .
        INSTALL_METHOD="pip"
        PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        PYTHON_BIN_DIR="$HOME/.local/bin"
    fi
fi

# Python 사용자 bin 디렉토리 확인
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PYTHON_BIN_DIR="$HOME/Library/Python/$PYTHON_VERSION/bin"

# 설치 확인 (직접 경로로)
if [[ -f "$PYTHON_BIN_DIR/bssm" ]]; then
    echo -e "${GREEN}✅ 설치 성공: $PYTHON_BIN_DIR/bssm${NC}"
    
    # PATH 설정 확인 및 추가
    if [[ ":$PATH:" != *":$PYTHON_BIN_DIR:"* ]]; then
        echo -e "${YELLOW}🔧 PATH 설정을 추가합니다...${NC}"
        if [[ "$SHELL" == *"zsh"* ]]; then
            echo "export PATH=\"$PYTHON_BIN_DIR:\$PATH\"" >> ~/.zshrc
            echo -e "${GREEN}✅ ~/.zshrc에 PATH를 추가했습니다.${NC}"
            echo -e "${YELLOW}💡 새 터미널을 열거나 다음 명령어를 실행하세요:${NC}"
            echo -e "${BLUE}source ~/.zshrc${NC}"
        else
            echo "export PATH=\"$PYTHON_BIN_DIR:\$PATH\"" >> ~/.bashrc
            echo -e "${GREEN}✅ ~/.bashrc에 PATH를 추가했습니다.${NC}"
            echo -e "${YELLOW}💡 새 터미널을 열거나 다음 명령어를 실행하세요:${NC}"
            echo -e "${BLUE}source ~/.bashrc${NC}"
        fi
        
        # 현재 세션에서도 PATH 업데이트
        export PATH="$PYTHON_BIN_DIR:$PATH"
        echo -e "${GREEN}✅ 현재 세션에서도 bssm을 사용할 수 있습니다.${NC}"
    fi
    
    # 최종 테스트
    if command -v bssm &> /dev/null; then
        echo -e "${GREEN}🎉 bssm이 정상적으로 설치되었습니다!${NC}"
    else
        echo -e "${YELLOW}⚠️  설치는 완료되었지만 PATH 설정이 필요합니다.${NC}"
        echo -e "${BLUE}export PATH=\"$PYTHON_BIN_DIR:\$PATH\"${NC}"
    fi
else
    echo -e "${RED}❌ 설치 실패${NC}"
    echo -e "${YELLOW}💡 다음 위치를 확인해주세요: $PYTHON_BIN_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 설치가 완료되었습니다!${NC}"
echo -e "${GREEN}📍 설치 위치: $(which bssm)${NC}"

echo -e "${GREEN}🚀 사용법:${NC}"
echo -e "${BLUE}  bssm connect          # 인스턴스 연결${NC}"
echo -e "${BLUE}  bssm list             # 인스턴스 목록${NC}"
echo -e "${BLUE}  bssm test-auth        # 인증 테스트${NC}"
echo -e "${BLUE}  bssm --help           # 도움말${NC}"

echo -e "${YELLOW}💡 AWS SSO를 사용하는 경우 먼저 로그인하세요:${NC}"
echo -e "${BLUE}aws sso login --profile your-profile${NC}"