# Windows Development Environment Script for AI-IA Backend
# Usage: .\dev.ps1 [command]

param([string]$Command = "start")

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ComposeFile = "docker-compose.local.yml"

function Write-Header($Message) {
    Write-Host "`n════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Green
    Write-Host "════════════════════════════════════════════`n" -ForegroundColor Cyan
}

function Show-Help {
    Write-Host "`nAI-IA Backend - Windows Development Commands`n" -ForegroundColor Cyan
    Write-Host "USAGE: .\dev.ps1 [command]`n" -ForegroundColor Yellow
    Write-Host "COMMANDS:" -ForegroundColor Green
    Write-Host "  start      Start development environment (default)" -ForegroundColor White
    Write-Host "  stop       Stop development environment" -ForegroundColor White
    Write-Host "  logs       View Django logs (follow mode)" -ForegroundColor White
    Write-Host "  status     Show container status" -ForegroundColor White
    Write-Host "  shell      Open Django shell" -ForegroundColor White
    Write-Host "  bash       Open bash in container" -ForegroundColor White
    Write-Host "  help       Show this message`n" -ForegroundColor White
}

switch ($Command.ToLower()) {
    "start" {
        Write-Header "Starting development environment..."
        docker-compose -f $ComposeFile up -d
        Write-Host "`n✓ Environment started!`n" -ForegroundColor Green
        Write-Host "📍 Access points:" -ForegroundColor Cyan
        Write-Host "   • Django:      http://localhost:9000" -ForegroundColor White
        Write-Host "   • Admin:       http://localhost:9000/admin" -ForegroundColor White
        Write-Host "   • Nginx:       http://localhost:9080" -ForegroundColor White
        Write-Host "   • PostgreSQL:  localhost:5432" -ForegroundColor White
        Write-Host "   • Redis:       localhost:6379`n" -ForegroundColor White
    }
    "stop" {
        Write-Header "Stopping development environment..."
        docker-compose -f $ComposeFile down
        Write-Host "✓ Stopped`n" -ForegroundColor Green
    }
    "logs" {
        Write-Header "Django logs (Ctrl+C to exit)..."
        docker-compose -f $ComposeFile logs -f django
    }
    "status" {
        Write-Header "Container status"
        docker-compose -f $ComposeFile ps
        Write-Host ""
    }
    "shell" {
        Write-Header "Opening Django shell..."
        docker-compose -f $ComposeFile exec django python manage.py shell
    }
    "bash" {
        Write-Header "Opening bash..."
        docker-compose -f $ComposeFile exec django /bin/bash
    }
    "help" {
        Show-Help
    }
    default {
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Show-Help
    }
}

