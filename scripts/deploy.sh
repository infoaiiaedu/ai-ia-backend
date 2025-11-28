#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  AI-IA Backend Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites OK${NC}"

# Check config file
if [ ! -f "config/project.toml" ]; then
    echo -e "${YELLOW}Warning: config/project.toml not found, creating default...${NC}"
    mkdir -p config
    cat > config/project.toml << 'EOF'
[project]
SECRET_KEY = "django-insecure-temporary-key-change-in-production"
DEBUG = false
ALLOWED_HOSTS = ["localhost", "127.0.0.1", "*"]
CSRF_TRUSTED_ORIGINS = ["http://localhost"]
REDIS_URI = "redis://redis:6379/0"

[database]
ENGINE = "postgresql"
NAME = "ai_db"
USER = "postgres"
PASSWORD = "postgres"
HOST = "psql"
PORT = "5432"
EOF
    echo -e "${GREEN}✓ Default config created${NC}"
fi

# Stop existing containers
echo ""
echo -e "${YELLOW}Stopping existing containers...${NC}"
docker compose down --remove-orphans 2>/dev/null || true
echo -e "${GREEN}✓ Containers stopped${NC}"

# Build images
echo ""
echo -e "${YELLOW}Building Docker images...${NC}"
docker compose build --no-cache
echo -e "${GREEN}✓ Images built${NC}"

# Start services
echo ""
echo -e "${YELLOW}Starting services...${NC}"
docker compose up -d
echo -e "${GREEN}✓ Services started${NC}"

# Wait for services to be ready
echo ""
echo -e "${YELLOW}Waiting for services to be ready...${NC}"
sleep 10

# Check container status
echo ""
echo -e "${YELLOW}Checking container status...${NC}"
docker compose ps

# Final status
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Deployment completed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Services are running. Check logs with:"
echo "  docker compose logs -f"
echo ""
echo "Access the application at:"
echo "  http://localhost"
