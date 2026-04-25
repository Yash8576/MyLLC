@echo off
REM Stop all BuzzCart local Docker services

echo ========================================
echo Stopping BuzzCart Services
echo ========================================
echo.

cd /d "%~dp0\.."

echo Stopping all containers...
docker compose -f docker/docker-compose.yml down
echo.

echo All services stopped successfully!
echo.
echo To remove volumes as well, run:
echo docker compose -f docker/docker-compose.yml down -v
echo.
pause
