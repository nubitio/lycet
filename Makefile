.DEFAULT_GOAL := help
.PHONY: help up down restart logs sh build

APP_PORT ?= 8000

help: ## Muestra esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

up: ## Levanta el servidor local (http://localhost:APP_PORT)
	APP_PORT=$(APP_PORT) docker compose up --build -d

down: ## Detiene los contenedores
	docker compose down

restart: down up ## Reinicia el servidor

logs: ## Muestra los logs del contenedor
	docker compose logs -f app

sh: ## Abre una shell en el contenedor
	docker compose exec app sh

build: ## Reconstruye la imagen Docker (target prod)
	docker build --target prod -t lycet .

seed-data: ## Copia certificado y logo de prueba a ./data (primera vez)
	@mkdir -p data
	cp tests/Resources/cert.pem data/cert.pem 2>/dev/null || true
	cp tests/Resources/logo.png data/logo.png 2>/dev/null || true
	@echo "Archivos de prueba copiados a ./data"
