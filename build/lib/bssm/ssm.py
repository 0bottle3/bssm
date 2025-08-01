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
        """SSM 연결 가능한 EC2 인스턴스 목록 가져오기 (페이지네이션 지원)"""
        try:
            # SSM 관리 인스턴스 목록 (페이지네이션 처리)
            ssm_instances = {}
            next_token = None
            
            while True:
                if next_token:
                    ssm_response = self.ssm_client.describe_instance_information(
                        NextToken=next_token,
                        MaxResults=50  # 한 번에 최대 50개씩
                    )
                else:
                    ssm_response = self.ssm_client.describe_instance_information(
                        MaxResults=50
                    )
                
                # 온라인 상태인 인스턴스만 수집
                for instance in ssm_response['InstanceInformationList']:
                    if instance['PingStatus'] == 'Online':
                        ssm_instances[instance['InstanceId']] = instance
                
                # 다음 페이지가 있는지 확인
                next_token = ssm_response.get('NextToken')
                if not next_token:
                    break
            
            if not ssm_instances:
                return []
            
            # EC2 인스턴스 세부 정보 (배치 처리로 최적화)
            all_instances = []
            instance_ids = list(ssm_instances.keys())
            
            # EC2 describe_instances는 한 번에 많은 인스턴스를 처리할 수 있지만
            # 너무 많으면 타임아웃이 날 수 있으므로 100개씩 배치 처리
            batch_size = 100
            for i in range(0, len(instance_ids), batch_size):
                batch_ids = instance_ids[i:i + batch_size]
                
                # EC2 인스턴스 정보 조회 (InstanceIds 사용시 MaxResults 불가)
                ec2_response = self.ec2_client.describe_instances(
                    InstanceIds=batch_ids
                )
                
                # 인스턴스 정보 처리
                for reservation in ec2_response['Reservations']:
                    for instance in reservation['Instances']:
                        all_instances.append(instance)
            
            # 수집된 모든 인스턴스 정보 처리
            instances = []
            for instance in all_instances:
                instance_id = instance['InstanceId']
                
                # SSM에 등록되지 않은 인스턴스는 제외
                if instance_id not in ssm_instances:
                    continue
                
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
            
            # 총 개수 로그 출력
            rprint(f"[green]✅ 총 {len(instances)}개의 SSM 연결 가능한 인스턴스를 찾았습니다.[/green]")
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