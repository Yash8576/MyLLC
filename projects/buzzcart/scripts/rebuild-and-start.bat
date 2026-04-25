@echo off
REM Rebuild and start the default BuzzCart local Docker services

echo ========================================
echo Rebuilding BuzzCart Services
echo ========================================
echo.

cd /d "%~dp0\.."

echo Stopping and removing existing containers...
docker compose -f docker/docker-compose.yml down
echo.

echo Building and starting default services...
docker compose -f docker/docker-compose.yml up -d --build redis backend frontend
echo.

echo Waiting for services to be healthy...
timeout /t 10 /nobreak >nul
echo.

echo Checking service status...
docker compose -f docker/docker-compose.yml ps
echo.

echo Checking backend logs for errors...
docker compose -f docker/docker-compose.yml logs --tail=20 backend
echo.

echo ========================================
echo Service URLs:
echo ========================================
echo Redis:       localhost:6379
echo Backend:     localhost:8080
echo Frontend:    localhost:8081
echo ========================================
echo.
echo Chatbot and Ollama stay opt-in. Use:
echo docker compose -f docker/docker-compose.yml --profile chatbot up -d chatbot ollama ollama-init
echo.
echo Rebuild complete!
echo.
pause
