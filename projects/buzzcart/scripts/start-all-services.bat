@echo off
REM Start the default BuzzCart local Docker services

echo ========================================
echo Starting BuzzCart Services
echo ========================================
echo.

cd /d "%~dp0\.."

echo Stopping any existing containers...
docker compose -f docker/docker-compose.yml down
echo.

echo Starting default services...
docker compose -f docker/docker-compose.yml up -d redis backend frontend
echo.

echo Waiting for services to be healthy...
timeout /t 5 /nobreak >nul
echo.

echo Checking service status...
docker compose -f docker/docker-compose.yml ps
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
echo Run 'docker compose -f docker/docker-compose.yml logs -f' to view logs
echo.
pause
