"""
사용자 인터페이스 관리
"""

from typing import List, Dict, Optional
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.prompt import Prompt, IntPrompt
from rich.text import Text
from rich import print as rprint

console = Console()

class UI:
    def __init__(self):
        self.console = console
    
    def show_header(self, title: str):
        """헤더 표시"""
        panel = Panel(
            f"[bold blue]{title}[/bold blue]",
            style="blue",
            padding=(1, 2)
        )
        self.console.print(panel)
    
    def show_instances_table(self, instances: List[Dict]):
        """인스턴스 목록 테이블 표시"""
        if not instances:
            rprint("[yellow]📝 SSM 연결 가능한 인스턴스가 없습니다.[/yellow]")
            return
        
        table = Table(title=f"SSM 연결 가능한 인스턴스 ({len(instances)}개)")
        table.add_column("번호", style="cyan", width=4)
        table.add_column("이름", style="green", min_width=20)
        table.add_column("Instance ID", style="blue", min_width=19)
        table.add_column("상태", style="yellow", width=10)
        table.add_column("타입", style="magenta", width=12)
        table.add_column("Private IP", style="cyan", width=15)
        table.add_column("플랫폼", style="white", width=8)
        
        for i, instance in enumerate(instances):
            # 상태에 따른 색상
            state = instance['State']
            if state == 'running':
                state_color = "[green]running[/green]"
            elif state == 'stopped':
                state_color = "[red]stopped[/red]"
            else:
                state_color = f"[yellow]{state}[/yellow]"
            
            table.add_row(
                str(i + 1),
                instance['Name'],
                instance['InstanceId'],
                state_color,
                instance['InstanceType'],
                instance['PrivateIpAddress'],
                instance['Platform']
            )
        
        self.console.print(table)
    
    def select_instance(self, instances: List[Dict]) -> Optional[Dict]:
        """인스턴스 선택 UI"""
        self.show_instances_table(instances)
        
        if not instances:
            return None
        
        try:
            rprint()  # 빈 줄
            choice = IntPrompt.ask(
                "연결할 인스턴스 번호를 선택하세요",
                default=1,
                show_default=True
            )
            
            if 1 <= choice <= len(instances):
                selected = instances[choice - 1]
                
                # 선택 확인
                rprint(f"[green]✅ 선택된 인스턴스:[/green] {selected['Name']} ({selected['InstanceId']})")
                return selected
            else:
                rprint(f"[red]❌ 잘못된 번호입니다. 1-{len(instances)} 사이의 숫자를 입력하세요.[/red]")
                return None
                
        except KeyboardInterrupt:
            rprint("\n[yellow]👋 선택이 취소되었습니다.[/yellow]")
            return None
        except Exception as e:
            rprint(f"[red]❌ 입력 오류: {str(e)}[/red]")
            return None
    
    def show_error(self, message: str):
        """에러 메시지 표시"""
        panel = Panel(
            f"[red]❌ {message}[/red]",
            style="red",
            title="오류"
        )
        self.console.print(panel)
    
    def show_success(self, message: str):
        """성공 메시지 표시"""
        panel = Panel(
            f"[green]✅ {message}[/green]",
            style="green",
            title="성공"
        )
        self.console.print(panel)
    
    def show_info(self, message: str):
        """정보 메시지 표시"""
        panel = Panel(
            f"[blue]ℹ️ {message}[/blue]",
            style="blue",
            title="정보"
        )
        self.console.print(panel)
    
    def confirm(self, message: str, default: bool = True) -> bool:
        """확인 대화상자"""
        try:
            return Prompt.ask(
                f"{message} [y/N]" if not default else f"{message} [Y/n]",
                choices=["y", "n", "Y", "N", ""],
                default="y" if default else "n"
            ).lower() in ["y", "yes", ""]
        except KeyboardInterrupt:
            return False