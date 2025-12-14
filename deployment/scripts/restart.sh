#!/bin/bash
# Restart script for AI-IA Backend
# This script stops, updates, and restarts the backend services

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.subdomain.yml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR/../docker"
CONFIG_FILE="$SCRIPT_DIR/../../config/project.toml"

echo -e "${GREEN}=== AI-IA Backend Restart Script ===${NC}\n"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}ERROR: Configuration file not found at $CONFIG_FILE${NC}"
    echo -e "${YELLOW}Please create config/project.toml from the example${NC}"
    exit 1
fi

# Change to docker directory
cd "$DOCKER_DIR"

echo -e "${YELLOW}Step 1: Stopping current containers...${NC}"
docker compose -f "$COMPOSE_FILE" down

echo -e "\n${YELLOW}Step 2: Pulling latest images...${NC}"
docker compose -f "$COMPOSE_FILE" pull

echo -e "\n${YELLOW}Step 3: Starting services...${NC}"
docker compose -f "$COMPOSE_FILE" up -d

echo -e "\n${YELLOW}Step 4: Waiting for services to be healthy...${NC}"
sleep 10

# Check container status
echo -e "\n${GREEN}Container Status:${NC}"
docker ps --filter "name=django" --format "table {{.Names}}\t{{.Status}}"

echo -e "\n${YELLOW}Step 5: Checking logs for errors...${NC}"
docker compose -f "$COMPOSE_FILE" logs --tail=20 app

echo -e "\n${GREEN}=== Restart Complete ===${NC}"
echo -e "\n${GREEN}Access your application at:${NC}"
echo -e "  - Admin Panel: ${YELLOW}http://localhost:8080/admin/${NC}"
echo -e "  - API: ${YELLOW}http://localhost:8080/api/${NC}"
echo -e "  - API Docs: ${YELLOW}http://localhost:8080/api/docs/${NC}"
echo -e "\n${GREEN}To view logs:${NC}"
echo -e "  docker compose -f deployment/docker/$COMPOSE_FILE logs -f"
