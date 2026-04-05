#!/bin/bash

#===============================================
# Marathon Safety - APK Setup Helper
# 
# For users WITHOUT Flutter installed:
# Download pre-built APK → Save to ./app-release.apk → Run this script
#
# For developers WITH Flutter:
# Build APK → Run this script to install on device
#===============================================

set -e

echo "🏃 Marathon Safety - APK Connection Setup"
echo "=========================================="
echo ""

# Find APK file
echo "🔍 Looking for APK file..."
APK_PATH=""

# Check standard build location
if [ -f "frontend/build/app/outputs/flutter-apk/app-release.apk" ]; then
    APK_PATH="frontend/build/app/outputs/flutter-apk/app-release.apk"
    echo "✅ Found APK at: $APK_PATH"
# Check if user placed it in main directory
elif [ -f "app-release.apk" ]; then
    APK_PATH="app-release.apk"
    echo "✅ Found APK at: $APK_PATH"
# Check Downloads folder
elif [ -f "$HOME/Downloads/app-release.apk" ]; then
    APK_PATH="$HOME/Downloads/app-release.apk"
    echo "✅ Found APK at: $APK_PATH"
else
    echo ""
    echo "❌ APK file not found!"
    echo ""
    echo "📥 EASIEST: Download pre-built APK (NO FLUTTER NEEDED)"
    echo "   1. Visit: https://github.com/your-org/Marathon/releases"
    echo "   2. Download: app-release.apk"
    echo "   3. Save to: $(pwd)/app-release.apk"
    echo "   4. Run: ./setup-apk.sh"
    echo ""
    echo "🔨 ALTERNATIVE: Build APK yourself (requires Flutter)"
    echo "   cd frontend"
    echo "   flutter pub get"
    echo "   flutter build apk --release"
    echo ""
    exit 1
fi

echo ""

# Check if Docker is running
if ! docker ps >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Get local IP address
echo "📍 Finding your PC's local IP address..."
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    LOCAL_IP=$(hostname -I | awk '{print $1}')
elif [[ "$OSTYPE" == "darwin"* ]]; then
    LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
else
    echo "⚠️  Couldn't auto-detect IP. Please enter manually."
    read -p "Enter your PC's local IP (example: 192.168.1.100): " LOCAL_IP
fi

echo "✅ Your local IP: $LOCAL_IP"
echo ""

# Check if backend is running
echo "🔍 Checking if Docker services are running..."
if docker-compose ps 2>/dev/null | grep -q "kafka"; then
    echo "✅ Docker services are running"
else
    echo ""
    echo "⚠️  Docker services are not running."
    echo "   Start them with: ./scripts/start-backend.sh"
    echo ""
    read -p "Would you like me to start them now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd "$(dirname "$0")"
        ./scripts/start-backend.sh
    fi
fi

echo ""
echo "=========================================="
echo "✨ QUICKEST WAY TO RUN YOUR APP"
echo "=========================================="
echo ""

echo "🌐 🚀 RECOMMENDED: Browser Emulator (Easiest - No Setup!)"
echo "   Zero installation needed!"
echo ""
echo "   1️⃣  Go to: https://appetize.io"
echo "   2️⃣  Sign up (free account)"
echo "   3️⃣  Upload: frontend/build/app/outputs/flutter-apk/app-release.apk"
echo "   4️⃣  Select 'Android' and a device model"
echo "   5️⃣  Click 'Start' - app will run in your browser!"
echo "   6️⃣  Login with: admin / admin123"
echo ""
echo "   ✨ That's it! Your app is running and connecting to your backend."
echo ""

echo "=========================================="
echo "📱 Alternative: Android Emulator (Local)"
echo "=========================================="
echo ""
echo "   Requirements: Android SDK installed on your PC"
echo ""
echo "   $ emulator -avd <device_name> &"
echo "   $ adb wait-for-device"
echo "   $ adb install frontend/build/app/outputs/flutter-apk/app-release.apk"
echo "   $ adb shell am start -n com.example.marathon_safety/.MainActivity"
echo ""

echo "=========================================="
echo "📱 Alternative: Physical Android Device"
echo "=========================================="
echo ""
echo "   1. Make sure your phone is on the same WiFi as this PC"
echo "   2. Connect via USB"
echo ""
echo "   $ adb install frontend/build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "   3. Tap the app in your phone's app drawer"
echo "   4. App connects to: $LOCAL_IP:8080"
echo ""

echo "=========================================="
echo "📋 Credentials"
echo "=========================================="
echo "Username: admin"
echo "Password: admin123"
echo ""

echo "=========================================="
echo "📊 Expected Results"
echo "=========================================="
echo "✓ App launches successfully"
echo "✓ Sees list of 500 marathon runners"
echo "✓ Displays real-time vital signs (heart rate, breathing)"
echo "✓ Shows health status indicators"
echo "✓ Receives push notifications for alerts"
echo ""

echo "=========================================="
echo "🆘 Troubleshooting"
echo "=========================================="
echo ""
echo "❌ App can't connect?"
echo "   1. Verify backend is running: docker-compose ps"
echo "   2. Check firewall allows port 8080"
echo "   3. For emulator: adb shell ping 10.0.2.2"
echo "   4. For phone: Phone must be on same WiFi"
echo ""
echo "❌ Docker services not starting?"
echo "   Run: cd $(dirname "$0") && ./scripts/start-backend.sh"
echo ""

echo "✅ Setup complete! Start building with:"
echo "   cd $(dirname "$0")/frontend && flutter run"
echo ""
