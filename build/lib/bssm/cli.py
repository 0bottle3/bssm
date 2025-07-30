#!/usr/bin/env python3
"""
CLI interface for bssm
"""

import click
from rich.console import Console
from rich.table import Table
from rich.prompt import Prompt
from rich.panel import Panel
from rich import print as rprint

from .auth import SSOAuth
from .ssm import SSMManager
from .config import Config
from .ui import UI

console = Console()
ui = UI()

@click.group()
@click.version_option(version="1.0.0")
def cli():
    """🚀 AWS SSM을 더 쉽게 사용하는 CLI 도구"""
    pass

@cli.command()
@click.option('--profile', default='default', help='AWS 프로필 이름')
@click.option('--region', help='AWS 리전 (기본값: 프로필 설정 사용)')
def connect(profile, region):
    """EC2 인스턴스에 SSM으로 연결"""
    try:
        ui.show_header("AWS SSM 연결")
        
        # AWS 인증
        auth = SSOAuth(profile_name=profile, region=region)
        session = auth.get_session()
        
        # SSM 매니저 초기화
        ssm_manager = SSMManager(session)
        
        # 인스턴스 목록 가져오기
        with console.status("[bold green]인스턴스 목록을 가져오는 중..."):
            instances = ssm_manager.get_instances()
        
        if not instances:
            rprint("[red]❌ SSM 연결 가능한 인스턴스가 없습니다.[/red]")
            return
        
        # 인스턴스 선택 UI
        selected_instance = ui.select_instance(instances)
        
        if selected_instance:
            # SSM 세션 시작
            ssm_manager.start_session(selected_instance['InstanceId'])
        
    except KeyboardInterrupt:
        rprint("\n[yellow]👋 연결이 취소되었습니다.[/yellow]")
    except Exception as e:
        rprint(f"[red]❌ 오류가 발생했습니다: {str(e)}[/red]")

@cli.command()
@click.option('--profile', default='default', help='AWS 프로필 이름')
def list(profile):
    """SSM 연결 가능한 인스턴스 목록 보기"""
    try:
        auth = SSOAuth(profile_name=profile)
        session = auth.get_session()
        ssm_manager = SSMManager(session)
        
        with console.status("[bold green]인스턴스 목록을 가져오는 중..."):
            instances = ssm_manager.get_instances()
        
        ui.show_instances_table(instances)
        
    except Exception as e:
        rprint(f"[red]❌ 오류가 발생했습니다: {str(e)}[/red]")

@cli.command()
@click.argument('instance_id')
def add_favorite(instance_id):
    """즐겨찾기에 인스턴스 추가"""
    config = Config()
    config.add_favorite(instance_id)
    rprint(f"[green]✅ {instance_id}를 즐겨찾기에 추가했습니다.[/green]")

@cli.command()
def favorites():
    """즐겨찾기 목록 보기"""
    config = Config()
    favs = config.get_favorites()
    
    if not favs:
        rprint("[yellow]📝 즐겨찾기가 비어있습니다.[/yellow]")
        return
    
    table = Table(title="즐겨찾기 인스턴스")
    table.add_column("Instance ID", style="cyan")
    table.add_column("추가 날짜", style="green")
    
    for fav in favs:
        table.add_row(fav['instance_id'], fav['added_at'])
    
    console.print(table)

@cli.command()
@click.option('--profile', help='테스트할 AWS 프로필')
def test_auth(profile):
    """AWS 인증 테스트"""
    try:
        profile = profile or 'default'
        auth = SSOAuth(profile_name=profile)
        
        with console.status(f"[bold green]{profile} 프로필로 인증 테스트 중..."):
            session = auth.get_session()
            
            # STS로 현재 자격증명 확인
            sts = session.client('sts')
            identity = sts.get_caller_identity()
        
        rprint(f"[green]✅ 인증 성공![/green]")
        rprint(f"[cyan]Account ID:[/cyan] {identity['Account']}")
        rprint(f"[cyan]User ARN:[/cyan] {identity['Arn']}")
        
    except Exception as e:
        error_msg = str(e)
        if "InvalidClientTokenId" in error_msg or "SignatureDoesNotMatch" in error_msg:
            rprint(f"[red]❌ AWS 자격증명이 유효하지 않습니다.[/red]")
            rprint("[yellow]💡 다음을 확인해주세요:[/yellow]")
            rprint(f"  1. Access Key 재설정: [blue]aws configure --profile {profile}[/blue]")
            rprint(f"  2. SSO 재로그인: [blue]aws sso login --profile {profile}[/blue]")
            rprint("  3. 자격증명 확인: [blue]aws sts get-caller-identity[/blue]")
        elif "ExpiredToken" in error_msg:
            rprint(f"[red]❌ AWS 토큰이 만료되었습니다.[/red]")
            rprint("[yellow]💡 다음을 시도해주세요:[/yellow]")
            rprint(f"  1. SSO 재로그인: [blue]aws sso login --profile {profile}[/blue]")
            rprint(f"  2. Access Key 갱신: [blue]aws configure --profile {profile}[/blue]")
        else:
            rprint(f"[red]❌ 인증 실패: {error_msg}[/red]")
            rprint("[yellow]💡 AWS 자격증명을 확인해주세요.[/yellow]")
            rprint("  - Access Key: [blue]aws configure[/blue]")
            rprint("  - SSO: [blue]aws sso login[/blue]")

def main():
    """Main entry point"""
    cli()

if __name__ == '__main__':
    main()