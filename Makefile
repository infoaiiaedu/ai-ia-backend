.PHONY: help deploy status logs backup restore cleanup monitor test

DEPLOY_PATH ?= /home/ubuntu/ai-ia-backend
SSH_USER ?= ubuntu
SSH_HOST ?= your-server-ip

help:
	@echo "🚀 AI-IA Deployment Commands"
	@echo ""
	@echo "  make deploy         - Deploy to production"
	@echo "  make status         - Check deployment status"
	@echo "  make logs           - View all service logs"
	@echo "  make backup         - Create manual backup"
	@echo "  make restore        - Restore from backup"
	@echo "  make cleanup        - Clean up old resources"
	@echo "  make monitor        - Open monitoring dashboard"
	@echo "  make test           - Run tests locally"
	@echo ""

deploy:
	@echo "🚀 Deploying to production..."
	@git push origin main
	@echo "✓ Pushed to main branch. GitHub Actions will handle deployment."

status:
	@echo "📊 Checking deployment status..."
	@ssh -i ~/.ssh/deploy_key $(SSH_USER)@$(SSH_HOST) "cd $(DEPLOY_PATH) && docker-compose ps"

logs:
	@echo "📋 Fetching logs from all services..."
	@ssh -i ~/.ssh/deploy_key $(SSH_USER)@$(SSH_HOST) "cd $(DEPLOY_PATH) && docker-compose logs --tail=100 -f"

logs-django:
	@ssh -i ~/.ssh/deploy_key $(SSH_USER)@$(SSH_HOST) "cd $(DEPLOY_PATH) && docker-compose logs --tail=100 -f django"

logs-postgres:
	@ssh -i ~/.ssh/deploy_key $(SSH_USER)@$(SSH_HOST) "cd $(DEPLOY_PATH) && docker-compose logs --tail=100 -f postgres"

logs-nginx:
	@ssh -i ~/.ssh/deploy_key $(SSH_USER)@$(SSH_HOST) "cd $(DEPLOY_PATH) && docker-compose logs --tail=100 -f nginx"

backup:
	@echo "💾 Creating manual backup..."
	@ssh -i ~/.ssh/deploy_key $(SSH_USER)@$(SSH_HOST) "cd $(DEPLOY_PATH) && sudo bash scripts/backup.sh"

restore:
	@echo "⚠️  Restoring from backup..."
	@ssh -i ~/.ssh/deploy_key $(SSH_USER)@$(SSH_HOST) "cd $(DEPLOY_PATH) && sudo bash scripts/restore.sh"

cleanup:
	@echo "🧹 Cleaning up resources..."
	@ssh -i ~/.ssh/deploy_key $(SSH_USER)@$(SSH_HOST) "sudo bash $(DEPLOY_PATH)/scripts/cleanup.sh"

monitor:
	@echo "📊 Opening monitoring dashboard..."
	@open https://devstatus.eduaiia.com || xdg-open https://devstatus.eduaiia.com

test:
	@echo "🧪 Running tests locally..."
	@cd code && python manage.py test

test-coverage:
	@echo "🧪 Running tests with coverage..."
	@cd code && pytest --cov=apps --cov-report=html

shell:
	@echo "🐚 Opening remote shell..."
	@ssh -i ~/.ssh/deploy_key $(SSH_USER)@$(SSH_HOST)

restart:
	@echo "🔄 Restarting all services..."
	@ssh -i ~/.ssh/deploy_key $(SSH_USER)@$(SSH_HOST) "cd $(DEPLOY_PATH) && docker-compose restart"

stop:
	@echo "🛑 Stopping all services..."
	@ssh -i ~/.ssh/deploy_key $(SSH_USER)@$(SSH_HOST) "cd $(DEPLOY_PATH) && docker-compose down"

start:
	@echo "▶️  Starting all services..."
	@ssh -i ~/.ssh/deploy_key $(SSH_USER)@$(SSH_HOST) "cd $(DEPLOY_PATH) && docker-compose up -d"
