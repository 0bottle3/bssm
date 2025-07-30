"""
AWS SSO 인증 관리
"""

import boto3
import subprocess
import sys
from botocore.exceptions import TokenRetrievalError, NoCredentialsError, ProfileNotFound
from rich import print as rprint

class SSOAuth:
    def __init__(self, profile_name='default', region=None):
        self.profile_name = profile_name
        self.region = region
        
    def get_session(self):
        """AWS 세션 가져오기 (SSO 지원)"""
        try:
            # 세션 생성
            session_kwargs = {'profile_name': self.profile_name}
            if self.region:
                session_kwargs['region_name'] = self.region
                
            session = boto3.Session(**session_kwargs)
            
            # 자격증명 테스트
            sts = session.client('sts')
            sts.get_caller_identity()
            
            return session
            
        except TokenRetrievalError:
            rprint(f"[yellow]🔐 SSO 토큰이 만료되었습니다. 다시 로그인합니다...[/yellow]")
            self._refresh_sso_token()
            return boto3.Session(profile_name=self.profile_name)
            
        except Exception as e:
            error_msg = str(e)
            if "InvalidClientTokenId" in error_msg or "SignatureDoesNotMatch" in error_msg:
                rprint(f"[red]❌ AWS 자격증명이 유효하지 않습니다.[/red]")
                rprint("[yellow]💡 다음을 확인해주세요:[/yellow]")
                rprint(f"  1. Access Key 재설정: aws configure --profile {self.profile_name}")
                rprint(f"  2. SSO 재로그인: aws sso login --profile {self.profile_name}")
                rprint("  3. 자격증명 확인: aws sts get-caller-identity")
            elif "ExpiredToken" in error_msg:
                rprint(f"[red]❌ AWS 토큰이 만료되었습니다.[/red]")
                rprint("[yellow]💡 다음을 시도해주세요:[/yellow]")
                rprint(f"  1. SSO 재로그인: aws sso login --profile {self.profile_name}")
                rprint(f"  2. Access Key 갱신: aws configure --profile {self.profile_name}")
            else:
                rprint(f"[red]❌ 인증 실패: {error_msg}[/red]")
                rprint("[yellow]💡 AWS 자격증명을 확인해주세요.[/yellow]")
            sys.exit(1)
            
        except NoCredentialsError:
            rprint(f"[red]❌ '{self.profile_name}' 프로필의 자격증명을 찾을 수 없습니다.[/red]")
            rprint("[yellow]💡 다음 중 하나를 확인해주세요:[/yellow]")
            rprint("  1. Access Key 설정: aws configure --profile {profile_name}")
            rprint("  2. SSO 설정: aws configure sso --profile {profile_name}")
            rprint("  3. 프로필 확인: aws configure list-profiles")
            rprint("  4. 환경 변수: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY")
            sys.exit(1)
            
        except ProfileNotFound:
            rprint(f"[red]❌ '{self.profile_name}' 프로필을 찾을 수 없습니다.[/red]")
            rprint("[yellow]💡 사용 가능한 프로필 목록:[/yellow]")
            self._show_available_profiles()
            sys.exit(1)
            
    def _refresh_sso_token(self):
        """SSO 토큰 갱신"""
        try:
            rprint(f"[blue]🔄 AWS SSO 로그인을 실행합니다...[/blue]")
            result = subprocess.run(
                ['aws', 'sso', 'login', '--profile', self.profile_name],
                capture_output=False,
                text=True
            )
            
            if result.returncode != 0:
                rprint(f"[red]❌ SSO 로그인에 실패했습니다.[/red]")
                sys.exit(1)
                
            rprint(f"[green]✅ SSO 로그인이 완료되었습니다.[/green]")
            
        except FileNotFoundError:
            rprint("[red]❌ AWS CLI가 설치되어 있지 않습니다.[/red]")
            rprint("[yellow]💡 AWS CLI를 설치해주세요: https://aws.amazon.com/cli/[/yellow]")
            sys.exit(1)
            
    def _show_available_profiles(self):
        """사용 가능한 프로필 목록 표시"""
        try:
            result = subprocess.run(
                ['aws', 'configure', 'list-profiles'],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0 and result.stdout.strip():
                profiles = result.stdout.strip().split('\n')
                for profile in profiles:
                    rprint(f"  - {profile}")
            else:
                rprint("  (설정된 프로필이 없습니다)")
                
        except FileNotFoundError:
            rprint("  (AWS CLI가 설치되어 있지 않습니다)")
            
    def get_current_identity(self):
        """현재 AWS 자격증명 정보 반환"""
        session = self.get_session()
        sts = session.client('sts')
        return sts.get_caller_identity()