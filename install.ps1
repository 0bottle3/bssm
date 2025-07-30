# bssm Windows 설치 스크립트
# PowerShell 실행 정책: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

param(
    [switch]$SkipSessionManager,
    [switch]$Force
)

# 색상 함수
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    else {
        $input | Write-Output
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Success { Write-ColorOutput Green $args }
function Write-Warning { Write-ColorOutput Yellow $args }
function Write-Error { Write-ColorOutput Red $args }
function Write-Info { Write-ColorOutput Cyan $args }

Write-Info "🚀 bssm - Better AWS SSM CLI Tool"
Write-Info "Windows 설치를 시작합니다..."
Write-Info ""

# 관리자 권한 확인
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "⚠️  관리자 권한이 필요할 수 있습니다."
    Write-Info "💡 Session Manager Plugin 설치를 위해 관리자 권한으로 실행하는 것을 권장합니다."
}

# Python 설치 확인
Write-Info "🐍 Python 설치 확인 중..."
try {
    $pythonVersion = python --version 2>$null
    if ($pythonVersion) {
        Write-Success "✅ Python이 설치되어 있습니다: $pythonVersion"
    } else {
        throw "Python not found"
    }
} catch {
    Write-Error "❌ Python이 설치되어 있지 않습니다."
    Write-Warning "💡 Python을 설치해주세요: https://www.python.org/downloads/"
    Write-Warning "💡 또는 Microsoft Store에서 Python을 설치하세요."
    exit 1
}

# AWS CLI 설치 확인
Write-Info "☁️  AWS CLI 설치 확인 중..."
try {
    $awsVersion = aws --version 2>$null
    if ($awsVersion) {
        Write-Success "✅ AWS CLI가 설치되어 있습니다: $awsVersion"
    } else {
        throw "AWS CLI not found"
    }
} catch {
    Write-Error "❌ AWS CLI가 설치되어 있지 않습니다."
    Write-Warning "💡 AWS CLI를 설치해주세요: https://aws.amazon.com/cli/"
    exit 1
}

# Session Manager Plugin 설치 확인 및 설치
if (-not $SkipSessionManager) {
    Write-Info "🔌 Session Manager Plugin 확인 중..."
    try {
        $sessionManagerCheck = session-manager-plugin 2>$null
        Write-Success "✅ Session Manager Plugin이 이미 설치되어 있습니다."
    } catch {
        Write-Warning "⚠️  Session Manager Plugin이 설치되어 있지 않습니다."
        
        if ($Force -or (Read-Host "Session Manager Plugin을 설치하시겠습니까? (y/N)") -eq 'y') {
            Write-Info "📦 Session Manager Plugin 다운로드 중..."
            
            $downloadUrl = "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe"
            $installerPath = "$env:TEMP\SessionManagerPluginSetup.exe"
            
            try {
                Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath
                Write-Success "✅ 다운로드 완료"
                
                Write-Info "🔧 Session Manager Plugin 설치 중..."
                Start-Process -FilePath $installerPath -ArgumentList "/quiet" -Wait
                
                # 설치 확인
                try {
                    session-manager-plugin 2>$null
                    Write-Success "✅ Session Manager Plugin 설치 완료"
                } catch {
                    Write-Warning "⚠️  설치 확인 실패. 수동으로 확인해주세요."
                }
                
                # 임시 파일 정리
                Remove-Item $installerPath -ErrorAction SilentlyContinue
                
            } catch {
                Write-Error "❌ Session Manager Plugin 설치 실패"
                Write-Warning "💡 수동으로 설치해주세요: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html"
            }
        } else {
            Write-Warning "⚠️  Session Manager Plugin 없이 설치를 계속합니다."
            Write-Warning "💡 나중에 SSM 연결을 위해서는 Session Manager Plugin이 필요합니다."
        }
    }
} else {
    Write-Info "🔌 Session Manager Plugin 설치를 건너뜁니다."
}

# 현재 디렉토리가 bssm 프로젝트 디렉토리인지 확인
if (-not (Test-Path "src\main.py") -or -not (Test-Path "requirements.txt")) {
    Write-Error "❌ bssm 프로젝트 디렉토리에서 실행해주세요."
    Write-Warning "💡 사용법:"
    Write-Info "  git clone https://github.com/juniper-31/bssm.git"
    Write-Info "  cd bssm"
    Write-Info "  .\install.ps1"
    exit 1
}

Write-Info "📦 Python 패키지로 설치 중..."

# pip 설치 시도
try {
    Write-Info "🔧 의존성 설치 중..."
    pip install --user -r requirements.txt
    
    Write-Info "📦 bssm 설치 중..."
    pip install --user .
    
    Write-Success "✅ 설치 완료!"
    
} catch {
    Write-Error "❌ 설치 실패: $_"
    Write-Warning "💡 다음을 시도해보세요:"
    Write-Info "  1. 관리자 권한으로 PowerShell 실행"
    Write-Info "  2. pip install --user . --force-reinstall"
    Write-Info "  3. 가상환경 사용: python -m venv venv && .\venv\Scripts\Activate.ps1"
    exit 1
}

# Python Scripts 디렉토리 확인
$pythonScriptsDir = python -c "import site; print(site.USER_BASE + '\\Scripts')" 2>$null
if (-not $pythonScriptsDir) {
    $pythonScriptsDir = "$env:APPDATA\Python\Scripts"
}

# PATH 확인 및 추가
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentPath -notlike "*$pythonScriptsDir*") {
    Write-Info "🔧 PATH 환경변수에 Python Scripts 디렉토리 추가 중..."
    try {
        [Environment]::SetEnvironmentVariable("PATH", "$pythonScriptsDir;$currentPath", "User")
        Write-Success "✅ PATH 환경변수가 업데이트되었습니다."
        Write-Warning "💡 새 터미널을 열어야 변경사항이 적용됩니다."
    } catch {
        Write-Warning "⚠️  PATH 자동 설정 실패. 수동으로 추가해주세요:"
        Write-Info "  PATH에 추가할 경로: $pythonScriptsDir"
    }
}

# 현재 세션에서 PATH 업데이트
$env:PATH = "$pythonScriptsDir;$env:PATH"

# 설치 확인
Write-Info "🧪 설치 확인 중..."
try {
    $bssmPath = Get-Command bssm -ErrorAction Stop
    Write-Success "🎉 bssm이 정상적으로 설치되었습니다!"
    Write-Success "📍 설치 위치: $($bssmPath.Source)"
} catch {
    Write-Warning "⚠️  bssm 명령어를 찾을 수 없습니다."
    Write-Info "💡 다음 위치를 확인해주세요: $pythonScriptsDir"
    Write-Info "💡 새 터미널을 열고 다시 시도해보세요."
}

Write-Success ""
Write-Success "🎉 설치가 완료되었습니다!"
Write-Info ""
Write-Success "🚀 사용법:"
Write-Info "  bssm connect          # 인스턴스 연결"
Write-Info "  bssm list             # 인스턴스 목록"
Write-Info "  bssm test-auth        # 인증 테스트"
Write-Info "  bssm --help           # 도움말"
Write-Info ""
Write-Warning "💡 AWS SSO를 사용하는 경우 먼저 로그인하세요:"
Write-Info "  aws sso login --profile your-profile"
Write-Info ""
Write-Info "🔄 새 터미널을 열어서 bssm을 사용하세요!"