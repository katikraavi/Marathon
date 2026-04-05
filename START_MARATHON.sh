#!/bin/bash
set -e

MARATHON_DIR="/home/katikraavi/Marathon"
FRONTEND_DIR="$MARATHON_DIR/frontend"
BUILD_DIR="$FRONTEND_DIR/build/linux/x64/release/bundle/marathon_safety"

echo "🏃 Starting Marathon System..."
echo ""

# Function to clean up on exit
cleanup() {
    echo ""
    echo "⏹️  Shutting down Marathon..."
    docker compose -f "$MARATHON_DIR/docker-compose.yml" down
    exit 0
}
trap cleanup SIGINT SIGTERM

# Check prerequisites
echo "📋 Checking prerequisites..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker."
    exit 1
fi

# Start all backend services with docker compose up (foreground mode in prod, detached for dev)
echo "🐳 Starting Docker services (Zookeeper, Kafka, Data Generator)..."
cd "$MARATHON_DIR"
docker compose up -d
echo "   Waiting for services to be ready..."
sleep 8

# Health check: verify services are running
echo "🏥 Verifying services..."
for service in zookeeper kafka data-generator; do
    if ! docker compose ps | grep -q "$service"; then
        echo "❌ Service '$service' failed to start"
        docker compose logs "$service"
        exit 1
    fi
done
echo "   ✓ All services are running"

# Build Flutter app if needed
echo ""
echo "🔨 Preparing Flutter app..."
cd "$FRONTEND_DIR"
if [ ! -f "$BUILD_DIR" ]; then
    echo "   📦 Building release binary (first run)..."
    flutter build linux --release -v
    echo "   ✓ Build complete"
else
    echo "   ✓ Binary already built"
fi

# Start Flutter app
echo ""
echo "🚀 Starting Flutter frontend..."
timeout 600 "$BUILD_DIR" 2>&1 &
APP_PID=$!

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Marathon System is RUNNING!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Backend: http://localhost:8080"
echo "🔌 WebSocket: ws://localhost:8080/time_based_reports"
echo "💨 Data Generator: Running (500 runners)"
echo "🎨 Frontend: Running (PID: $APP_PID)"
echo ""
echo "Press Ctrl+C to stop all services"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Wait for app to finish
wait $APP_PID 2>/dev/null || true

