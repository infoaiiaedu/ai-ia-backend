@echo off
REM Windows Development Environment Batch Script
REM Usage: dev.bat [command]

setlocal enabledelayedexpansion

set "COMPOSE_FILE=docker-compose.local.yml"

if "%1"=="" (
    set "COMMAND=start"
) else (
    set "COMMAND=%1"
)

if /i "%COMMAND%"=="start" (
    cls
    echo.
    echo ============================================================
    echo   STARTING LOCAL DEVELOPMENT ENVIRONMENT
    echo ============================================================
    echo.
    docker-compose -f %COMPOSE_FILE% up -d
    if !errorlevel! equ 0 (
        echo.
        echo Development environment started successfully!
        echo.
        echo 📍 ENDPOINTS:
        echo    - Django:      http://localhost:8000
        echo    - Admin:       http://localhost:8000/admin
        echo    - Health:      http://localhost:8000/health/
        echo    - Nginx:       http://localhost
        echo.
        echo 📊 SERVICES:
        echo    - PostgreSQL:  localhost:5432 ^(aiia_dev/dev_password_123^)
        echo    - Redis:       localhost:6379
        echo.
        echo 📝 USEFUL COMMANDS:
        echo    - Logs:        dev.bat logs
        echo    - Status:      dev.bat status
        echo    - Stop:        dev.bat stop
        echo.
    ) else (
        echo ERROR: Failed to start development environment
        exit /b 1
    )
    goto :end
)

if /i "%COMMAND%"=="stop" (
    cls
    echo.
    echo ============================================================
    echo   STOPPING DEVELOPMENT ENVIRONMENT
    echo ============================================================
    echo.
    docker-compose -f %COMPOSE_FILE% down
    echo Development environment stopped.
    goto :end
)

if /i "%COMMAND%"=="down" (
    cls
    echo.
    echo ============================================================
    echo   STOPPING DEVELOPMENT ENVIRONMENT
    echo ============================================================
    echo.
    docker-compose -f %COMPOSE_FILE% down
    echo Development environment stopped.
    goto :end
)

if /i "%COMMAND%"=="logs" (
    cls
    echo.
    echo ============================================================
    echo   DJANGO DEVELOPMENT LOGS
    echo ============================================================
    echo.
    docker-compose -f %COMPOSE_FILE% logs -f django
    goto :end
)

if /i "%COMMAND%"=="status" (
    cls
    echo.
    echo ============================================================
    echo   CONTAINER STATUS
    echo ============================================================
    echo.
    docker-compose -f %COMPOSE_FILE% ps
    goto :end
)

if /i "%COMMAND%"=="shell" (
    cls
    echo.
    echo ============================================================
    echo   OPENING DJANGO SHELL
    echo ============================================================
    echo.
    docker-compose -f %COMPOSE_FILE% exec django python manage.py shell
    goto :end
)

if /i "%COMMAND%"=="bash" (
    cls
    echo.
    echo ============================================================
    echo   OPENING BASH SHELL
    echo ============================================================
    echo.
    docker-compose -f %COMPOSE_FILE% exec django /bin/bash
    goto :end
)

if /i "%COMMAND%"=="help" (
    cls
    echo.
    echo ============================================================
    echo   AI-IA Backend - Windows Dev Script
    echo ============================================================
    echo.
    echo USAGE: dev.bat [command]
    echo.
    echo COMMANDS:
    echo   start      Start the development environment ^(default^)
    echo   stop       Stop the development environment
    echo   down       Stop the development environment
    echo   logs       View Django container logs
    echo   status     Show container status
    echo   shell      Open Django Python shell
    echo   bash       Open bash shell
    echo   help       Show this help message
    echo.
    goto :end
)

echo Unknown command: %COMMAND%
echo Run "dev.bat help" for usage information
exit /b 1

:end
endlocal
