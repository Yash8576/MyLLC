#!/bin/bash
# Start the default BuzzCart local Docker services

echo "========================================"
echo "Starting BuzzCart Services"
echo "========================================"
echo ""

cd "$(dirname "$0")/.." || exit

echo "Stopping any existing containers..."
docker compose -f docker/docker-compose.yml down
echo ""

echo "Starting default services..."
docker compose -f docker/docker-compose.yml up -d redis backend frontend
echo ""

echo "Waiting for services to be healthy..."
sleep 5
echo ""

echo "Checking service status..."
docker compose -f docker/docker-compose.yml ps
echo ""

echo "========================================"
echo "Service URLs:"
echo "========================================"
echo "Redis:       localhost:6379"
echo "Backend:     localhost:8080"
echo "Frontend:    localhost:8081"
echo "========================================"
echo ""
echo "Optional chatbot profile:"
echo "docker compose -f docker/docker-compose.yml --profile chatbot up -d chatbot ollama ollama-init"
echo "Run 'docker compose -f docker/docker-compose.yml logs -f' to view logs"
echo ""
