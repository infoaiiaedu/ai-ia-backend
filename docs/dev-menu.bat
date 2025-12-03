@echo off
REM =====================================================
REM Windows Quick Start - AI-IA Backend
REM =====================================================
REM
REM This script provides quick access to development
REM commands on Windows without using Unix tools
REM
REM Usage: Simply run this file or use commands below
REM =====================================================

setlocal enabledelayedexpansion

title AI-IA Backend - Windows Development

:menu
cls
echo.
echo ============================================================
echo   AI-IA Backend - Windows Development Environment
echo ============================================================
echo.
echo Current Status:
docker-compose -f docker-compose.local.yml ps 2>nul | find "aiia_dev"
if errorlevel 1 (
    echo   Status: NOT RUNNING
) else (
    echo   Status: RUNNING
)
echo.
echo ============================================================
echo   AVAILABLE COMMANDS
echo ============================================================
echo.
echo 1. Start Environment        (docker-compose up -d)
echo 2. Stop Environment         (docker-compose down)
echo 3. View Logs               (docker-compose logs -f django)
echo 4. Show Status             (docker-compose ps)
echo 5. Django Migrations       (python manage.py migrate)
echo 6. Create Superuser        (python manage.py createsuperuser)
echo 7. Django Shell            (python manage.py shell)
echo 8. Open Bash               (bash shell in container)
echo 9. Access Points           (show URLs and info)
echo 0. Exit
echo.
echo ============================================================
echo.

set /p choice="Enter choice [0-9]: "

if "%choice%"=="1" goto start
if "%choice%"=="2" goto stop
if "%choice%"=="3" goto logs
if "%choice%"=="4" goto status
if "%choice%"=="5" goto migrate
if "%choice%"=="6" goto superuser
if "%choice%"=="7" goto shell
if "%choice%"=="8" goto bash
if "%choice%"=="9" goto info
if "%choice%"=="0" exit /b 0

echo Invalid choice. Please try again.
pause
goto menu

:start
echo.
echo Starting development environment...
docker-compose -f docker-compose.local.yml up -d
if !errorlevel! equ 0 (
    echo.
    echo ✓ Environment started successfully!
    echo.
    echo Access your application at:
    echo   • Django:      http://localhost:9000
    echo   • Admin:       http://localhost:9000/admin
    echo   • Nginx:       http://localhost:9080
    echo.
) else (
    echo.
    echo ✗ Failed to start environment
    echo.
)
pause
goto menu

:stop
echo.
echo Stopping development environment...
docker-compose -f docker-compose.local.yml down
echo.
echo ✓ Environment stopped
echo.
pause
goto menu

:logs
echo.
echo Showing Django logs (Press Ctrl+C to exit)...
echo.
docker-compose -f docker-compose.local.yml logs -f django
goto menu

:status
echo.
echo Container Status:
echo.
docker-compose -f docker-compose.local.yml ps
echo.
pause
goto menu

:migrate
echo.
echo Running Django migrations...
docker-compose -f docker-compose.local.yml exec django python manage.py migrate
echo.
pause
goto menu

:superuser
echo.
echo Create Django superuser...
docker-compose -f docker-compose.local.yml exec django python manage.py createsuperuser
echo.
pause
goto menu

:shell
echo.
echo Opening Django shell (type 'exit()' to quit)...
docker-compose -f docker-compose.local.yml exec django python manage.py shell
goto menu

:bash
echo.
echo Opening bash shell (type 'exit' to quit)...
docker-compose -f docker-compose.local.yml exec django /bin/bash
goto menu

:info
cls
echo.
echo ============================================================
echo   ACCESS POINTS & INFORMATION
echo ============================================================
echo.
echo WEB ENDPOINTS:
echo   • Application:  http://localhost:9000
echo   • Admin Panel:  http://localhost:9000/admin
echo   • Nginx Proxy:  http://localhost:9080
echo.
echo DATABASE & CACHE:
echo   • PostgreSQL:   localhost:5432
echo   •   Username:   aiia_dev
echo   •   Password:   dev_password_123
echo   •   Database:   aiia_dev
echo   • Redis:        localhost:6379
echo.
echo COMMON COMMANDS:
echo   • Start:        docker-compose -f docker-compose.local.yml up -d
echo   • Stop:         docker-compose -f docker-compose.local.yml down
echo   • Logs:         docker-compose -f docker-compose.local.yml logs -f django
echo   • Migrate:      docker-compose -f docker-compose.local.yml exec django python manage.py migrate
echo   • Superuser:    docker-compose -f docker-compose.local.yml exec django python manage.py createsuperuser
echo.
echo NEXT STEPS:
echo   1. Start the environment (option 1)
echo   2. Create a superuser (option 6)
echo   3. Visit http://localhost:9000/admin
echo   4. Log in with your credentials
echo.
echo DOCUMENTATION:
echo   • README.md              - Full setup guide
echo   • WINDOWS_QUICKSTART.md  - Windows-specific guide
echo   • DEPLOYMENT.md          - Production deployment
echo.
echo ============================================================
echo.
pause
goto menu

endlocal
