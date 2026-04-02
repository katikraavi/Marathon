#!/bin/bash
# Marathon Safety - Backend Shutdown Script
# Stops all backend services

set -e

echo "🛑 Shutting down Marathon Safety Backend"
echo "========================================"
echo ""

# Navigate to project root (one level up from scripts directory)
cd "$(dirname "$0")/.."

echo "Stopping services..."
docker-compose down

echo ""
echo "✅ Services stopped successfully!"
echo ""
echo "💡 To preserve data volumes, use: docker-compose down"
echo "   To remove all data, use:        docker-compose down -v"
echo ""
