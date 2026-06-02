APP_NAME    := flask-make-demo
PYTHON      := python3
PIP         := pip
DOCKER      := docker
IMAGE_TAG   := latest
GIT_SHA     := $(shell git rev-parse --short HEAD 2>/dev/null \
               || echo "no-git")

.PHONY: help install test lint build clean docker-build docker-run

help:
	@echo ""
	@echo "Tillgängliga targets:"
	@echo ""
	@echo "  make install       Installera dependencies"
	@echo "  make test          Kör pytest"
	@echo "  make lint          Kodkontroll"
	@echo "  make build         Verifiera allt"
	@echo "  make clean         Rensa tempfiler"
	@echo "  make docker-build  Bygg Docker-image"
	@echo "  make docker-run    Kör i container"
	@echo ""

install:
	$(PIP) install -r requirements.txt

test: install
	$(PYTHON) -m pytest tests/ -v

lint:
	$(PYTHON) -m py_compile app/main.py

build: test lint
	@echo ""
	@echo "Build klar - alla tester och kontroller passerade."

clean:
	rm -rf __pycache__ app/__pycache__ tests/__pycache__
	rm -rf .pytest_cache
	rm -rf *.egg-info dist build
	@echo "Rensat."

docker-build: test
	$(DOCKER) build -t $(APP_NAME):$(IMAGE_TAG) .
	$(DOCKER) build -t $(APP_NAME):$(GIT_SHA) .
	@echo ""
	@echo "Image byggd:"
	@echo "  $(APP_NAME):$(IMAGE_TAG)"
	@echo "  $(APP_NAME):$(GIT_SHA)"

docker-run:
	$(DOCKER) run -d --rm -p 3000:3000 $(APP_NAME):$(IMAGE_TAG)


