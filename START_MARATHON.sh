#!/bin/bash
set -e

echo "Starting Marathon System..."
echo ""

# Start backend services
echo "1. Starting Docker services..."
cd /home/katikraavi/Marathon
docker-compose up -d
sleep 5

# Start data generator
echo "2. Starting data producer (500 runners)..."
docker-compose exec -d data-generator ./producer 500

sleep 2

# Start WebSocket client
echo "3. Starting WebSocket client..."
docker-compose exec -d data-generator ./client

sleep 3

# Start Flutter app
echo "4. Building Flutter app (if needed)..."
cd /home/katikraavi/Marathon/frontend
if [ ! -f ./build/linux/x64/release/bundle/marathon_safety ]; then
    echo "   Building release binary..."
    flutter build linux --release -v
fi

echo "Starting Flutter app..."
timeout 600 ./build/linux/x64/release/bundle/marathon_safety 2>&1 &
APP_PID=$!

echo ""
echo "✅ Marathon is RUNNING! (PID: $APP_PID)"
echo "   - 500 runners with varied vital signs"
echo "   - Backend: http://localhost:8080"
echo "   - WebSocket: ws://localhost:8080/time_based_reports"
echo "   - Frontend: Running (Press Ctrl+C to stop)"

