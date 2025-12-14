# Restart script for AI-IA Backend (PowerShell version)
# This script stops, updates, and restarts the backend services

param(
    [switch]$Dev,
    [switch]$NoPull
)

$ErrorActionPreference = "Stop"

# Configuration
$ComposeFile = if ($Dev) { "docker-compose.dev.yml" } else { "docker-compose.subdomain.yml" }
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DockerDir = Join-Path $ScriptDir "..\docker"
$ConfigFile = Join-Path $ScriptDir "..\..\config\project.toml"

Write-Host "=== AI-IA Backend Restart Script ===" -ForegroundColor Green
Write-Host ""

# Check if config file exists
if (-not (Test-Path $ConfigFile)) {
    Write-Host "ERROR: Configuration file not found at $ConfigFile" -ForegroundColor Red
    Write-Host "Please create config/project.toml from the example" -ForegroundColor Yellow
    exit 1
}

# Change to docker directory
Set-Location $DockerDir

Write-Host "Step 1: Stopping current containers..." -ForegroundColor Yellow
docker compose -f $ComposeFile down

if (-not $NoPull) {
    Write-Host "`nStep 2: Pulling latest images..." -ForegroundColor Yellow
    docker compose -f $ComposeFile pull
}

Write-Host "`nStep 3: Starting services..." -ForegroundColor Yellow
docker compose -f $ComposeFile up -d

Write-Host "`nStep 4: Waiting for services to be healthy..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Check container status
Write-Host "`nContainer Status:" -ForegroundColor Green
docker ps --filter "name=django" --format "table {{.Names}}\t{{.Status}}"

Write-Host "`nStep 5: Checking logs for errors..." -ForegroundColor Yellow
docker compose -f $ComposeFile logs --tail=20 app

Write-Host "`n=== Restart Complete ===" -ForegroundColor Green

if ($Dev) {
    Write-Host "`nAccess your application at:" -ForegroundColor Green
    Write-Host "  - All endpoints: " -NoNewline -ForegroundColor Green
    Write-Host "http://localhost:5000/" -ForegroundColor Yellow
} else {
    Write-Host "`nAccess your application at:" -ForegroundColor Green
    Write-Host "  - Admin Panel: " -NoNewline -ForegroundColor Green
    Write-Host "http://localhost:8080/admin/" -ForegroundColor Yellow
    Write-Host "  - API: " -NoNewline -ForegroundColor Green
    Write-Host "http://localhost:8080/api/" -ForegroundColor Yellow
    Write-Host "  - API Docs: " -NoNewline -ForegroundColor Green
    Write-Host "http://localhost:8080/api/docs/" -ForegroundColor Yellow
}

Write-Host "`nTo view logs:" -ForegroundColor Green
Write-Host "  docker compose -f deployment/docker/$ComposeFile logs -f"
