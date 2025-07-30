#!/usr/bin/env python3
"""
bssm - Better AWS SSM CLI Tool

🚀 AWS SSM을 더 쉽고 빠르게 사용할 수 있는 CLI 도구입니다.

Entry point for the application.

Features:
- AWS SSO v2 완벽 지원
- Access Key 호환
- 0.7초 이내 빠른 실행
- 아름다운 터미널 UI
- Session Manager Plugin 자동 설치

Usage:
    python main.py connect --profile my-profile
    python main.py list --profile prod-profile
    python main.py test-auth --profile dev-profile
"""

from bssm.cli import main

if __name__ == "__main__":
    main()