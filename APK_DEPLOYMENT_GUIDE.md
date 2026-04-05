# Marathon Safety - APK Deployment Guide

This guide explains how to run the Marathon Safety APK without needing a full Flutter setup.

## Prerequisites

**⚠️ IMPORTANT: Backend must be running FIRST**

```bash
cd /home/katikraavi/Marathon

# Option A: Automated setup (recommended)
./setup-apk.sh

# Option B: Manual setup
./scripts/start-backend.sh
# OR
docker-compose up -d
```

**Connection:**
- ✅ **Android Emulator**: Automatically connects via `10.0.2.2:8080` (Android's host alias)
- ✅ **Physical Device**: Connects via ngrok tunnel (included in APK)
- ✅ **Browser Emulator**: Connects via ngrok tunnel (included in APK)

---

## Option 1: Android Emulator (Lightweight - Recommended)

### Setup (One-time)
1. **Install Android Studio**: https://developer.android.com/studio
2. **Create a Virtual Device**:
   - Open Android Studio → Virtual Device Manager
   - Create a new device (Pixel 5 or similar)
   - Choose API level 28 or higher

### Run the APK
```bash
# Start the emulator
emulator -avd <device_name> &

# Wait for emulator to fully boot (2-3 minutes)
adb wait-for-device

# Install APK
adb install /home/katikraavi/Marathon/frontend/build/app/outputs/flutter-apk/app-release.apk

# Launch app
adb shell am start -n com.example.marathon_safety/com.example.marathon_safety.MainActivity
```

**Expected Result:**
- App launches
- Connects to ngrok tunnel: `wss://5785-88-196-199-75.ngrok-free.app`
- Shows participant list with real-time data
- Push notifications appear when health alerts occur

---

## Option 2: Physical Android Device

### Setup
1. **Enable Developer Mode**:
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times
   - Go back to Settings → Developer Options
   - Enable "USB Debugging"

2. **Connect via USB**:
   ```bash
   adb devices  # Should list your device
   ```

### Run the APK
```bash
# Install APK
adb install /home/katikraavi/Marathon/frontend/build/app/outputs/flutter-apk/app-release.apk

# App will appear in your app drawer - tap to launch
```

**Expected Result:**
- App launches on your device
- Receives real-time updates from Docker backend via ngrok tunnel

---

## Option 3: Browser-Based Emulator (Web Services)

Browser-based emulators allow testing without installing apps locally.

### Option 3a: Appetize.io (Free tier available)
1. **Sign up**: https://appetize.io/signup
2. **Premium APK upload**:
   - Upload: `/home/katikraavi/Marathon/frontend/build/app/outputs/flutter-apk/app-release.apk`
   - Select OS: Android
   - Device: Select a model (e.g., Pixel 5)
   - Click "Start"

3. **In the emulated app**:
   - Login with: `admin` / `admin123`
   - App automatically connects via ngrok tunnel

### Option 3b: BrowserStack App Live
1. **Sign up**: https://www.browserstack.com/app-live
2. **Upload APK same way**
3. **Test in browser** - app will connect to your backend

### Option 3c: Firebase Test Lab (Google Cloud)
1. **Upload APK** to Firebase Console
2. **Run tests** across multiple devices in the cloud

---

## Troubleshooting Connection Issues

### If the app shows "Connection Error":

**Check ngrok tunnel is running:**
```bash
curl -s http://localhost:4040/api/tunnels | grep public_url
```

**Expected output:**
```
"public_url":"https://5785-88-196-199-75.ngrok-free.app"
```

**If tunnel is down, restart:**
```bash
pkill -f "ngrok http" || true
sleep 1
ngrok http 8080 --log=stdout 2>&1 &
sleep 3
curl -s http://localhost:4040/api/tunnels | grep public_url
```

**Check Docker backend:**
```bash
docker-compose ps
# Should show: zookeeper, kafka, data-generator running
```

**Check connection manually:**
```bash
curl -i wss://5785-88-196-199-75.ngrok-free.app/time_based_reports
# Should show WebSocket connection info
```

---

## APK File Location

- **Path**: `/home/katikraavi/Marathon/frontend/build/app/outputs/flutter-apk/app-release.apk`
- **Size**: ~50-60 MB
- **Requires**: Android 7.0+ (API 24+)

---

## Credentials for Testing

- **Username**: `admin`
- **Password**: `admin123`

---

## Test Coverage

This setup allows testing:
✅ Real-time data synchronization from Docker backend  
✅ Multiple platforms without Flutter installation  
✅ Push notifications  
✅ Health state indicators  
✅ Charts and data visualization  
✅ Performance on different emulator types  

---

## Notes

- The APK automatically uses the ngrok tunnel (already configured)
- No additional configuration needed in the app
- Works internationally (ngrok provides global access)
- Tunnel stays active as long as ngrok process runs
- All three methods access the same local Docker backend

