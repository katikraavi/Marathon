#!/bin/bash
# Marathon Safety - Backend Startup Script
# Starts Zookeeper + Kafka + Data Generator

set -e

echo "🚀 Marathon Safety Backend Startup"
echo "=================================="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose not found. Please install Docker Compose first."
    exit 1
fi

# Navigate to project root (one level up from scripts directory)
cd "$(dirname "$0")/.."

echo "📦 Starting services..."
echo ""

# Start services
docker-compose up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to be healthy..."
sleep 5

# Check service status
echo ""
echo "📊 Checking service status..."
docker-compose ps

echo ""
echo "✅ Backend started successfully!"
echo ""
echo "🌐 Available at:"
echo "   - gRPC Server: ws://localhost:8080"
echo "   - Android Emulator: ws://10.0.2.2:8080"
echo "   - Kafka: localhost:29092"
echo "   - Zookeeper: localhost:22181"
echo ""
echo "📋 Useful commands:"
echo "   - View logs:     docker-compose logs -f data-generator"
echo "   - Check health:  docker-compose ps"
echo "   - Stop services: docker-compose down"
echo "   - Reset data:    docker-compose down -v"
echo ""
