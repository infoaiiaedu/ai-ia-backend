.PHONY: help dev prod staging logs clean build test migrate lint format healthcheck backup monitor

# Color output
BOLD := \033[1m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

help: ## Show this help message
	@echo "$(BOLD)AI-IA Backend Development Commands$(RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'

# ===== LOCAL DEVELOPMENT =====

dev: ## Start local development environment with Docker Compose
	@echo "$(BOLD)Starting development environment...$(RESET)"
	docker-compose -f docker-compose.local.yml up -d
	@echo "$(GREEN)✓ Development environment started$(RESET)"
	@echo "Django: http://localhost:8000"
	@echo "Nginx: http://localhost"
	@echo "PostgreSQL: localhost:5432 (aiia_dev/dev_password_123)"
	@echo "Redis: localhost:6379"

dev-down: ## Stop development environment
	@echo "$(BOLD)Stopping development environment...$(RESET)"
	docker-compose -f docker-compose.local.yml down
	@echo "$(GREEN)✓ Development environment stopped$(RESET)"

dev-logs: ## View development logs
	docker-compose -f docker-compose.local.yml logs -f django

dev-shell: ## Open Django shell in development
	docker-compose -f docker-compose.local.yml exec django python manage.py shell

dev-bash: ## Open bash in Django container
	docker-compose -f docker-compose.local.yml exec django /bin/bash

# ===== PRODUCTION OPERATIONS =====

prod-deploy: ## Deploy to production (requires SSH access)
	@bash scripts/deploy.sh production

prod-logs: ## View production Django logs
	docker logs aiia_django_prod -f

prod-shell: ## Open Django shell in production
	docker-compose exec django_prod python manage.py shell

prod-bash: ## Open bash in production Django container
	docker-compose exec django_prod /bin/bash

# ===== STAGING OPERATIONS =====

staging-deploy: ## Deploy to staging (requires SSH access)
	@bash scripts/deploy.sh staging

staging-logs: ## View staging Django logs
	docker logs aiia_django_staging -f

staging-shell: ## Open Django shell in staging
	docker-compose exec django_staging python manage.py shell

# ===== DATABASE OPERATIONS =====

migrate: ## Run Django migrations (development)
	docker-compose -f docker-compose.local.yml exec django python manage.py migrate

makemigrations: ## Create Django migrations (development)
	docker-compose -f docker-compose.local.yml exec django python manage.py makemigrations

superuser: ## Create Django superuser (development)
	docker-compose -f docker-compose.local.yml exec django python manage.py createsuperuser

db-backup: ## Backup production database
	@bash scripts/backup.sh production

db-backup-staging: ## Backup staging database
	@bash scripts/backup.sh staging

db-restore: ## Restore database from latest backup (specify BACKUP_PATH)
	@if [ -z "$(BACKUP_PATH)" ]; then \
		echo "$(RED)Error: BACKUP_PATH not set$(RESET)"; \
		echo "Usage: make db-restore BACKUP_PATH=backups/db_prod_20240101_120000/database.dump"; \
		exit 1; \
	fi
	@echo "Restoring database from $(BACKUP_PATH)..."
	docker exec aiia_postgresql pg_restore -U aiia -d aiia_prod -F custom "$(BACKUP_PATH)" || true

# ===== TESTING & VALIDATION =====

test: ## Run Django tests (development)
	docker-compose -f docker-compose.local.yml exec django python manage.py test

test-fast: ## Run Django tests with failfast (development)
	docker-compose -f docker-compose.local.yml exec django python manage.py test --failfast

lint: ## Run code linting
	docker-compose -f docker-compose.local.yml exec django bash -c "pip install flake8 && flake8 --max-line-length=100 code"

format: ## Format code with black
	docker-compose -f docker-compose.local.yml exec django bash -c "pip install black && black code"

check: ## Run Django system checks
	docker-compose -f docker-compose.local.yml exec django python manage.py check

collectstatic: ## Collect static files (development)
	docker-compose -f docker-compose.local.yml exec django python manage.py collectstatic --noinput --clear

# ===== DOCKER OPERATIONS =====

build: ## Build all Docker images
	docker-compose build

build-dev: ## Build development image
	docker-compose -f docker-compose.local.yml build

build-prod: ## Build production image
	docker-compose build django_prod

build-staging: ## Build staging image
	docker-compose build django_staging

ps: ## Show running containers
	@docker-compose ps
	@echo ""
	@docker-compose -f docker-compose.local.yml ps || true

images: ## List Docker images
	docker images | grep -E "aiia|django_prod|django_staging" || echo "No images found"

prune: ## Remove unused Docker resources
	@echo "$(YELLOW)Pruning Docker system...$(RESET)"
	docker system prune -f
	docker volume prune -f

# ===== MONITORING & HEALTH =====

monitor: ## Run health monitoring
	@bash scripts/monitor.sh

healthcheck: ## Check application health
	@echo "$(BOLD)Checking services health...$(RESET)"
	@echo ""
	@echo "Production Django:"
	@curl -sf http://localhost:8000/health/ && echo "$(GREEN)✓ OK$(RESET)" || echo "$(RED)✗ FAILED$(RESET)"
	@echo ""
	@echo "Staging Django:"
	@curl -sf http://localhost:8001/health/ && echo "$(GREEN)✓ OK$(RESET)" || echo "$(RED)✗ FAILED$(RESET)"
	@echo ""
	@echo "Nginx:"
	@curl -sf http://localhost/health && echo "$(GREEN)✓ OK$(RESET)" || echo "$(RED)✗ FAILED$(RESET)"
	@echo ""
	@echo "PostgreSQL:"
	@docker exec aiia_postgresql pg_isready -U aiia -d aiia_prod > /dev/null && echo "$(GREEN)✓ OK$(RESET)" || echo "$(RED)✗ FAILED$(RESET)"
	@echo ""
	@echo "Redis:"
	@docker exec aiia_redis redis-cli ping > /dev/null && echo "$(GREEN)✓ OK$(RESET)" || echo "$(RED)✗ FAILED$(RESET)"

# ===== SETUP & CLEANUP =====

setup: ## Initial setup (copy env files and create volumes)
	@echo "$(BOLD)Running initial setup...$(RESET)"
	@if [ ! -f .env ]; then \
		cp config/prod.env.example .env; \
		echo "$(YELLOW)Created .env from template$(RESET)"; \
		echo "$(YELLOW)Remember to edit .env with your credentials!$(RESET)"; \
	fi
	@if [ ! -f config/dev.env ]; then \
		cp config/dev.env.example config/dev.env; \
		echo "$(GREEN)✓ Created config/dev.env$(RESET)"; \
	fi
	@mkdir -p logs backups storage_prod storage_staging
	@echo "$(GREEN)✓ Setup completed$(RESET)"

clean: ## Clean up containers and volumes (WARNING: removes data!)
	@echo "$(RED)WARNING: This will remove all containers and volumes!$(RESET)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v; \
		docker-compose -f docker-compose.local.yml down -v; \
		echo "$(GREEN)✓ Cleanup completed$(RESET)"; \
	else \
		echo "$(YELLOW)Cleanup cancelled$(RESET)"; \
	fi

logs: ## View all service logs
	docker-compose logs -f

# ===== DOCUMENTATION =====

docs: ## Open README documentation
	@if command -v xdg-open &> /dev/null; then xdg-open README.md; fi
	@if command -v open &> /dev/null; then open README.md; fi

info: ## Show deployment architecture info
	@echo "$(BOLD)AI-IA Backend Architecture$(RESET)"
	@echo ""
	@echo "$(BOLD)Services:$(RESET)"
	@echo "  PostgreSQL:     aiia_postgresql (port 5432, limited to 128MB shared_buffers)"
	@echo "  PgBouncer:      aiia_pgbouncer (connection pooling, max 50 connections)"
	@echo "  Redis:          aiia_redis (port 6379, limited to 50MB)"
	@echo "  Production:     aiia_django_prod (port 8000, 150MB limit)"
	@echo "  Staging:        aiia_django_staging (port 8001, 100MB limit)"
	@echo "  Nginx:          aiia_nginx (ports 80, 443, 50MB limit)"
	@echo ""
	@echo "$(BOLD)Domains:$(RESET)"
	@echo "  Production:     https://eduaiia.com"
	@echo "  Staging:        https://staging.eduaiia.com"
	@echo "  Monitoring:     https://devstatus.eduaiia.com"
	@echo ""
	@echo "$(BOLD)Resource Limits (Total ~520MB):$(RESET)"
	@echo "  PostgreSQL:     200MB / 150MB reserved"
	@echo "  PgBouncer:      30MB / 20MB reserved"
	@echo "  Redis:          50MB / 40MB reserved"
	@echo "  Django Prod:    150MB / 120MB reserved"
	@echo "  Django Staging: 100MB / 80MB reserved"
	@echo "  Nginx:          50MB / 40MB reserved"
	@echo ""
	@echo "$(BOLD)Deployment:$(RESET)"
	@echo "  Production:     git push origin main"
	@echo "  Staging:        git push origin staging"

.DEFAULT_GOAL := help
