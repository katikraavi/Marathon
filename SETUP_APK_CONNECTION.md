# Marathon Safety - Running Without Flutter

Complete guide for running the app without installing Flutter.

---

## 🚀 Three-Step Quickstart

```bash
# 1. Download APK from GitHub Releases
# 2. Save to: ~/Marathon/app-release.apk
# 3. Run:
./setup-apk.sh
```

The script will:
- ✅ Find your APK
- ✅ Start Docker backend
- ✅ Detect your network setup
- ✅ Show you exactly how to proceed

---

## 📦 Getting the APK

The APK is **NOT in git** (binary files shouldn't be version controlled).

### Download Pre-Built APK (Recommended)

```bash
# 1. Visit: https://github.com/your-org/Marathon/releases
# 2. Download: app-release.apk
# 3. Save it:
cp ~/Downloads/app-release.apk ~/Marathon/app-release.apk
```

### Build APK Yourself (Optional - Requires Flutter)

```bash
cd frontend
flutter pub get
flutter build apk --release

# APK will be at:
# frontend/build/app/outputs/flutter-apk/app-release.apk
```

---

## 🎬 Running the App

After running `./setup-apk.sh`, you'll see three options. Choose one:

---

## 🌐 Option 1: BROWSER EMULATOR (Fastest - Recommended!)

**Zero installation needed - runs in your browser!**

### Steps:

1. **Visit**: https://appetize.io
2. **Sign up** (free account)
3. **Upload APK**: `frontend/build/app/outputs/flutter-apk/app-release.apk`
4. **Select**: Android device model
5. **Click**: "Start"
6. **App runs in browser!** Automatically connects to your backend
7. **Login**: `admin` / `admin123`

### Why This Is Best:

✅ No software to install  
✅ No emulator setup needed  
✅ Works immediately - click & go  
✅ Runs on any computer (Windows/Mac/Linux)  
✅ Perfect for testing and demos  

---

## 📱 Option 2: Local Android Emulator

**For developers with Android SDK installed.**

### Requirements:

- Android SDK installed
- Virtual device created in Android Studio

### Steps:

```bash
# 1. Start the emulator
emulator -avd <device_name> &

# 2. Wait for it to boot
adb wait-for-device

# 3. Install APK
adb install frontend/build/app/outputs/flutter-apk/app-release.apk

# 4. Launch app
adb shell am start -n com.example.marathon_safety/.MainActivity
```

The emulator connects to your PC backend via `10.0.2.2:8080` (automatically configured).

---

## 📱 Option 3: Physical Android Phone

**For testing on a real device.**

### Requirements:

- Android phone
- USB cable or WiFi connection
- Phone on same network as PC

### Steps:

```bash
# 1. Enable USB Debugging on phone:
#    Settings → Developer Options → USB Debugging

# 2. Connect phone via USB
adb devices  # Should list your phone

# 3. Install APK
adb install frontend/build/app/outputs/flutter-apk/app-release.apk

# 4. Launch from phone app drawer
```

The phone connects to your PC backend via ngrok tunnel (automatically configured).

---

## ✅ What You See When Running

1. **Marathon Safety app launches** ✅
2. **Login screen** - Enter: `admin` / `admin123`
3. **Live runner list** - Shows 500 marathon participants
4. **Real-time data**:
   - Heart rate (updates every second)
   - Breathing rate
   - Distance covered
   - Health status (Normal/Warning/Emergency)
5. **Push notifications** - Alerts for critical health events
6. **Click runner** - See 10-minute chart history

---

## 🔧 How Connection Works

### Browser Emulator & Phone:
```
Your PC (Docker Backend)
  ↓
ngrok tunnel (auto-configured)
  ↓
APK app (connects automatically)
```

**Already configured - nothing to change!**

### Local Emulator:
```
Your PC (Docker Backend) ← 10.0.2.2:8080 ← Android Emulator
```

**Already configured - nothing to change!**

---

## 🆘 Troubleshooting

### "App won't start"

```bash
# 1. Verify backend is running
docker-compose ps
# Should show: zookeeper, kafka, data-generator all running

# 2. Check Docker status
docker ps
```

### "App connects but no data"

```bash
# For browser emulator: ngrok tunnel might be down
# For local emulator: Check port 8080 is accessible
adb shell ping 10.0.2.2:8080
```

### "APK file not found"

Place APK at one of these locations:
- `~/Marathon/app-release.apk` (main dir)
- `~/Marathon/frontend/build/app/outputs/flutter-apk/app-release.apk`
- `~/Downloads/app-release.apk`

---

## 📋 One-Command Setup

Everything can be done with one command:

```bash
cd ~/Marathon
./setup-apk.sh
```

This will:
1. Find your APK
2. Start Docker (if not running)
3. Show your local network IP
4. Print detailed instructions for all options

---

## ✨ Key Points

- ✅ **No Flutter needed** - Use pre-built APK
- ✅ **One command setup** - `./setup-apk.sh` does everything
- ✅ **Auto-connecting** - App finds your backend automatically
- ✅ **Instant testing** - Browser emulator is fastest
- ✅ **Multiple options** - Choose what works best for you

---

## 📞 Need Help?

1. Backend not starting?
   ```bash
   ./scripts/start-backend.sh
   ```

2. APK not found?
   - Download from releases or build locally
   - Place in `~/Marathon/app-release.apk`

3. Emulator issues?
   - Browser emulator is the easiest alternative
   - Go to https://appetize.io and skip the setup
