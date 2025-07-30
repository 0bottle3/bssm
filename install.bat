@echo off
setlocal enabledelayedexpansion

:: bssm Windows 설치 스크립트 (CMD 버전)
echo.
echo 🚀 bssm - Better AWS SSM CLI Tool
echo Windows 설치를 시작합니다...
echo.

:: Python 설치 확인
echo 🐍 Python 설치 확인 중...
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python이 설치되어 있지 않습니다.
    echo 💡 Python을 설치해주세요: https://www.python.org/downloads/
    echo 💡 또는 Microsoft Store에서 Python을 설치하세요.
    pause
    exit /b 1
) else (
    for /f "tokens=*" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
    echo ✅ Python이 설치되어 있습니다: !PYTHON_VERSION!
)

:: AWS CLI 설치 확인
echo.
echo ☁️  AWS CLI 설치 확인 중...
aws --version >nul 2>&1
if errorlevel 1 (
    echo ❌ AWS CLI가 설치되어 있지 않습니다.
    echo 💡 AWS CLI를 설치해주세요: https://aws.amazon.com/cli/
    pause
    exit /b 1
) else (
    for /f "tokens=*" %%i in ('aws --version 2^>^&1') do set AWS_VERSION=%%i
    echo ✅ AWS CLI가 설치되어 있습니다: !AWS_VERSION!
)

:: Session Manager Plugin 확인
echo.
echo 🔌 Session Manager Plugin 확인 중...
session-manager-plugin >nul 2>&1
if errorlevel 1 (
    echo ⚠️  Session Manager Plugin이 설치되어 있지 않습니다.
    echo 💡 수동으로 설치해주세요:
    echo    https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
    echo.
    set /p CONTINUE="계속 진행하시겠습니까? (y/N): "
    if /i not "!CONTINUE!"=="y" (
        echo 설치를 취소합니다.
        pause
        exit /b 1
    )
) else (
    echo ✅ Session Manager Plugin이 설치되어 있습니다.
)

:: 프로젝트 디렉토리 확인
echo.
echo 📁 프로젝트 디렉토리 확인 중...
if not exist "src\main.py" (
    echo ❌ bssm 프로젝트 디렉토리에서 실행해주세요.
    echo 💡 사용법:
    echo   git clone https://github.com/juniper-31/bssm.git
    echo   cd bssm
    echo   install.bat
    pause
    exit /b 1
)
if not exist "requirements.txt" (
    echo ❌ requirements.txt 파일이 없습니다.
    pause
    exit /b 1
)

echo ✅ 프로젝트 디렉토리 확인 완료

:: Python 패키지 설치
echo.
echo 📦 Python 패키지 설치 중...
echo 🔧 의존성 설치 중...
pip install --user -r requirements.txt
if errorlevel 1 (
    echo ❌ 의존성 설치 실패
    pause
    exit /b 1
)

echo 📦 bssm 설치 중...
pip install --user .
if errorlevel 1 (
    echo ❌ bssm 설치 실패
    echo 💡 다음을 시도해보세요:
    echo   1. 관리자 권한으로 명령 프롬프트 실행
    echo   2. pip install --user . --force-reinstall
    pause
    exit /b 1
)

:: Python Scripts 디렉토리 확인
echo.
echo 🔧 PATH 설정 확인 중...
for /f "tokens=*" %%i in ('python -c "import site; print(site.USER_BASE + '\\Scripts')" 2^>nul') do set PYTHON_SCRIPTS_DIR=%%i
if "!PYTHON_SCRIPTS_DIR!"=="" (
    set PYTHON_SCRIPTS_DIR=%APPDATA%\Python\Scripts
)

:: PATH에 영구적으로 추가
echo 🔧 PATH 환경변수에 Python Scripts 디렉토리 추가 중...
reg query "HKCU\Environment" /v PATH >nul 2>&1
if errorlevel 1 (
    :: PATH 환경변수가 없으면 새로 생성
    reg add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "!PYTHON_SCRIPTS_DIR!" /f >nul 2>&1
    if not errorlevel 1 echo ✅ PATH 환경변수를 생성했습니다.
) else (
    :: 기존 PATH에 추가 (중복 체크)
    for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set CURRENT_PATH=%%b
    echo !CURRENT_PATH! | findstr /i "!PYTHON_SCRIPTS_DIR!" >nul
    if errorlevel 1 (
        reg add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "!PYTHON_SCRIPTS_DIR!;!CURRENT_PATH!" /f >nul 2>&1
        if not errorlevel 1 echo ✅ PATH 환경변수가 업데이트되었습니다.
    ) else (
        echo ✅ PATH에 이미 추가되어 있습니다.
    )
)

:: 현재 세션에서도 바로 사용 가능하도록
set PATH=!PYTHON_SCRIPTS_DIR!;%PATH%

:: 설치 확인
echo.
echo 🧪 설치 확인 중...
bssm --help >nul 2>&1
if errorlevel 1 (
    echo ⚠️  bssm 명령어를 찾을 수 없습니다.
    echo 💡 다음 디렉토리를 PATH에 추가해주세요: !PYTHON_SCRIPTS_DIR!
    echo 💡 또는 새 명령 프롬프트를 열고 다시 시도해보세요.
) else (
    echo ✅ bssm이 정상적으로 설치되었습니다!
)

echo.
echo 🎉 설치가 완료되었습니다!
echo.
echo 🚀 사용법:
echo   bssm connect          # 인스턴스 연결
echo   bssm list             # 인스턴스 목록  
echo   bssm test-auth        # 인증 테스트
echo   bssm --help           # 도움말
echo.
echo 💡 AWS SSO를 사용하는 경우 먼저 로그인하세요:
echo   aws sso login --profile your-profile
echo.
echo 🔄 새 명령 프롬프트를 열어서 bssm을 사용하세요!
echo.
pause