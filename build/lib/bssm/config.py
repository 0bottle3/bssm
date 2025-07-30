"""
설정 관리
"""

import json
import os
from datetime import datetime
from pathlib import Path
from typing import List, Dict

class Config:
    def __init__(self):
        self.config_dir = Path.home() / '.bssm'
        self.config_file = self.config_dir / 'config.json'
        self.ensure_config_dir()
        
    def ensure_config_dir(self):
        """설정 디렉토리 생성"""
        self.config_dir.mkdir(exist_ok=True)
        
    def load_config(self) -> Dict:
        """설정 파일 로드"""
        if not self.config_file.exists():
            return {
                'favorites': [],
                'history': [],
                'settings': {
                    'default_profile': 'default',
                    'max_history': 50
                }
            }
        
        try:
            with open(self.config_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            return self.load_config()  # 기본값 반환
    
    def save_config(self, config: Dict):
        """설정 파일 저장"""
        try:
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(config, f, indent=2, ensure_ascii=False, default=str)
        except IOError as e:
            print(f"설정 저장 실패: {e}")
    
    def add_favorite(self, instance_id: str):
        """즐겨찾기 추가"""
        config = self.load_config()
        
        # 중복 체크
        for fav in config['favorites']:
            if fav['instance_id'] == instance_id:
                return
        
        config['favorites'].append({
            'instance_id': instance_id,
            'added_at': datetime.now().isoformat()
        })
        
        self.save_config(config)
    
    def remove_favorite(self, instance_id: str):
        """즐겨찾기 제거"""
        config = self.load_config()
        config['favorites'] = [
            fav for fav in config['favorites'] 
            if fav['instance_id'] != instance_id
        ]
        self.save_config(config)
    
    def get_favorites(self) -> List[Dict]:
        """즐겨찾기 목록 반환"""
        config = self.load_config()
        return config['favorites']
    
    def add_history(self, instance_id: str, instance_name: str):
        """연결 히스토리 추가"""
        config = self.load_config()
        
        # 기존 항목 제거 (중복 방지)
        config['history'] = [
            item for item in config['history'] 
            if item['instance_id'] != instance_id
        ]
        
        # 새 항목 추가 (맨 앞에)
        config['history'].insert(0, {
            'instance_id': instance_id,
            'instance_name': instance_name,
            'connected_at': datetime.now().isoformat()
        })
        
        # 최대 개수 제한
        max_history = config['settings'].get('max_history', 50)
        config['history'] = config['history'][:max_history]
        
        self.save_config(config)
    
    def get_history(self) -> List[Dict]:
        """연결 히스토리 반환"""
        config = self.load_config()
        return config['history']
    
    def get_setting(self, key: str, default=None):
        """설정값 가져오기"""
        config = self.load_config()
        return config['settings'].get(key, default)
    
    def set_setting(self, key: str, value):
        """설정값 저장"""
        config = self.load_config()
        config['settings'][key] = value
        self.save_config(config)