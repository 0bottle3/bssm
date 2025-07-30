"""
AWS SSM 연결 관리
"""

import subprocess
import sys
from typing import List, Dict, Optional
from rich import print as rprint

class SSMManager:
    def __init__(self, session):
        self.session = session
        self.ssm_client = session.client('ssm')
        self.ec2_client = session.client('ec2')
        
    def get_instances(self) -> List[Dict]:
        """SSM 연결 가능한 EC2 인스턴스 목록 가져오기"""
        try:
            # SSM 관리 인스턴스 목록
            ssm_response = self.ssm_client.describe_instance_information()
            ssm_instances = {
                instance['InstanceId']: instance 
                for instance in ssm_response['InstanceInformationList']
                if instance['PingStatus'] == 'Online'
            }
            
            if not ssm_instances:
                return []
            
            # EC2 인스턴스 세부 정보
            ec2_response = self.ec2_client.describe_instances(
                InstanceIds=list(ssm_instances.keys())
            )
            
            instances = []
            for reservation in ec2_response['Reservations']:
                for instance in reservation['Instances']:
                    instance_id = instance['InstanceId']
                    
                    # 인스턴스 이름 찾기
                    name = instance_id
                    for tag in instance.get('Tags', []):
                        if tag['Key'] == 'Name':
                            name = tag['Value']
                            break
                    
                    instances.append({
                        'InstanceId': instance_id,
                        'Name': name,
                        'State': instance['State']['Name'],
                        'InstanceType': instance['InstanceType'],
                        'PrivateIpAddress': instance.get('PrivateIpAddress', 'N/A'),
                        'PublicIpAddress': instance.get('PublicIpAddress', 'N/A'),
                        'LaunchTime': instance['LaunchTime'],
                        'SSMStatus': ssm_instances[instance_id]['PingStatus'],
                        'Platform': ssm_instances[instance_id].get('PlatformType', 'Unknown')
                    })
            
            # 이름순으로 정렬
            instances.sort(key=lambda x: x['Name'].lower())
            return instances
            
        except Exception as e:
            rprint(f"[red]❌ 인스턴스 목록을 가져오는데 실패했습니다: {str(e)}[/red]")
            return []
    
    def start_session(self, instance_id: str):
        """SSM 세션 시작"""
        try:
            rprint(f"[green]🚀 {instance_id}에 연결 중...[/green]")
            rprint("[yellow]💡 세션을 종료하려면 'exit' 또는 Ctrl+D를 입력하세요.[/yellow]")
            
            # AWS CLI를 통해 SSM 세션 시작
            cmd = [
                'aws', 'ssm', 'start-session',
                '--target', instance_id
            ]
            
            # 프로필이 default가 아닌 경우 추가
            if hasattr(self.session, 'profile_name') and self.session.profile_name != 'default':
                cmd.extend(['--profile', self.session.profile_name])
            
            # 세션 시작 (인터랙티브)
            result = subprocess.run(cmd)
            
            if result.returncode == 0:
                rprint(f"[green]✅ {instance_id} 세션이 종료되었습니다.[/green]")
            else:
                rprint(f"[red]❌ 세션 연결에 실패했습니다.[/red]")
                
        except KeyboardInterrupt:
            rprint(f"\n[yellow]👋 {instance_id} 세션이 중단되었습니다.[/yellow]")
        except FileNotFoundError:
            rprint("[red]❌ AWS CLI가 설치되어 있지 않거나 PATH에 없습니다.[/red]")
            rprint("[yellow]💡 AWS CLI를 설치해주세요: https://aws.amazon.com/cli/[/yellow]")
        except Exception as e:
            rprint(f"[red]❌ 세션 시작 중 오류가 발생했습니다: {str(e)}[/red]")
    
    def start_port_forward(self, instance_id: str, local_port: int, remote_port: int):
        """포트 포워딩 세션 시작"""
        try:
            rprint(f"[green]🔗 포트 포워딩 시작: localhost:{local_port} -> {instance_id}:{remote_port}[/green]")
            
            cmd = [
                'aws', 'ssm', 'start-session',
                '--target', instance_id,
                '--document-name', 'AWS-StartPortForwardingSession',
                '--parameters', f'portNumber={remote_port},localPortNumber={local_port}'
            ]
            
            if hasattr(self.session, 'profile_name') and self.session.profile_name != 'default':
                cmd.extend(['--profile', self.session.profile_name])
            
            subprocess.run(cmd)
            
        except KeyboardInterrupt:
            rprint(f"\n[yellow]👋 포트 포워딩이 중단되었습니다.[/yellow]")
        except Exception as e:
            rprint(f"[red]❌ 포트 포워딩 중 오류가 발생했습니다: {str(e)}[/red]")