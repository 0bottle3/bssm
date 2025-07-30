# bssm Makefile

.PHONY: install dev test clean build

# 개발 환경 설정
dev:
	python3 -m venv venv
	. venv/bin/activate && pip install --upgrade pip
	. venv/bin/activate && pip install -r requirements.txt
	. venv/bin/activate && pip install -e .

# 로컬 설치 (개발용)
install:
	pip3 install --user .

# 개발 모드 설치 (소스 변경시 자동 반영)
install-dev:
	pip3 install --user -e .

# 실행파일 빌드 (선택사항 - 느림)
build:
	. venv/bin/activate && pyinstaller --onefile --name bssm src/main.py \
		--hidden-import=bssm.cli \
		--hidden-import=bssm.auth \
		--hidden-import=bssm.ssm \
		--hidden-import=bssm.config \
		--hidden-import=bssm.ui

# 테스트 실행
test:
	. venv/bin/activate && python -m pytest tests/ -v

# 정리
clean:
	rm -rf build/
	rm -rf dist/
	rm -rf *.egg-info/
	rm -rf venv/
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete

# 실행 (개발용)
run:
	. venv/bin/activate && python src/main.py

# 도움말
help:
	@echo "사용 가능한 명령어:"
	@echo "  make dev     - 개발 환경 설정"
	@echo "  make install - 로컬 설치"
	@echo "  make build   - 실행파일 빌드"
	@echo "  make test    - 테스트 실행"
	@echo "  make clean   - 정리"
	@echo "  make run     - 개발 모드 실행"