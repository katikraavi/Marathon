# 🚀 Marathon Safety APK - User Setup Guide

Complete guide to run Marathon Safety app on any Android device without needing Flutter installed.

---

## 📋 Prerequisites

- **Docker** (for backend services)
- **Android Phone** OR **Android Emulator** (Bluestacks, NoxPlayer, Android Studio, LDPlayer)
- **APK File**: `app-release.apk` (provided)
- **Same WiFi Network** (for phone) or **Same Computer** (for emulator)

---

## ⚡ Quick Start (5 minutes)

### Step 1: Start Backend Services

```bash
# Navigate to Marathon directory
cd Marathon

# Start all backend services (Zookeeper, Kafka, Data Generator)
docker-compose up -d

# Verify services are running
docker-compose ps
```

**Expected output:**
```
NAME                    STATUS       PORTS
marathon-zookeeper-1    Up           0.0.0.0:22181->2181/tcp
marathon-kafka-1        Up           0.0.0.0:29092->29092/tcp
marathon-data-generator-1 Up         0.0.0.0:8080->8080/tcp
```

⏱️ **Wait 30-45 seconds** for Kafka to fully initialize.

### Step 2: Get Your PC/Server IP Address

**On Linux/WSL:**
```bash
hostname -I
# Example output: 172.31.195.26
```

**On Windows:**
```cmd
ipconfig
# Look for IPv4 Address (usually 192.168.x.x or 10.x.x.x)
```

**On Mac:**
```bash
ifconfig | grep inet
# Look for inet 192.168.x.x (not 127.0.0.1)
```

📝 **Save this IP** - you'll need it for the next step.

### Step 3: Install APK

#### Option A: Real Android Phone
1. Transfer `app-release.apk` to your phone
2. On phone: Settings → Security → Enable "Unknown sources"
3. Tap APK file to install
4. ✅ Done!

#### Option B: Android Emulator (Bluestacks/NoxPlayer)
```bash
# On Windows Command Prompt or Linux terminal
adb install app-release.apk
```

#### Option C: Android Studio Emulator
```bash
# Android Studio will handle ADB automatically
adb install app-release.apk
```

#### Option D: LDPlayer
1. Drag-drop `app-release.apk` into LDPlayer window
2. Wait for installation
3. ✅ Done!

### Step 4: Configure Network Connection

**Important:** The APK needs to know your PC's IP address to connect to the backend.

#### For Real Android Phone (Same WiFi):
1. In app, if stuck on loading, check:
   - Phone is on **same WiFi** as your PC
   - PC IP is correct in app configuration

#### For Windows Emulator (LDPlayer/NoxPlayer):
The emulator might need the **Windows IP** (not WSL IP).

**Get Windows IP:**
```cmd
ipconfig
```
Look for: `IPv4 Address . . . . . . . . . : 192.168.x.x`

The app uses this configuration:
- **Android/iOS**: `ws://172.31.195.26:8080` (update this to your IP)
- **Desktop/Linux**: `ws://localhost:8080`

### Step 5: Open App & Verify

1. Launch Marathon Safety app
2. Login with: `admin` / `admin123`
3. Wait for runners to load (should show 500 runners with vital signs)
4. ✅ **Success!** Real-time data should appear

---

## 🔧 Troubleshooting

### "Waiting for connection..." (never loads)

**Possible causes:**

1. **Backend not running**
   ```bash
   docker-compose ps
   # All services should show "Up"
   ```

2. **Wrong IP address**
   - Verify you're using the correct PC/server IP
   - Test: Try `ping YOUR_IP` from phone/emulator
   - If ping fails → WiFi issue on phone or emulator network config

3. **Firewall blocking port 8080**
   ```bash
   # Linux: Allow port 8080
   sudo ufw allow 8080
   
   # Check if port is listening
   ss -tuln | grep 8080
   ```

4. **Different WiFi band (2.4GHz vs 5GHz)**
   - Check router settings
   - Ensure phone and PC on same band
   - Or disable Client Isolation in mesh router

### "Cannot reach 172.31.195.26"

The IP in the APK doesn't match your network setup:

```bash
# Check current backend IP
hostname -I

# Update APK by rebuilding with correct IP
# Contact developer for updated APK with your IP
```

### Backend shows "Loading runners... (0/500)"

**Check backend health:**
```bash
# View backend logs
docker logs marathon-data-generator-1 | tail -20

# Check Kafka is running
docker logs marathon-kafka-1 | tail -20

# Test WebSocket directly
curl -v ws://localhost:8080/time_based_reports
```

---

## 🏗️ Architecture

```
┌─ Your PC/Server ────────────────┐
│  ┌─ Docker Network ───────────┐ │
│  │ - Zookeeper (2181)        │ │
│  │ - Kafka (9092)            │ │
│  │ - Data Generator (8080)   │ │
│  └───────────────────────────┘ │
│  Port 8080 exposed to network  │
└────────────────────────────────┘
            ▲
            │ WiFi
            │
  ┌─────────▼──────────┐
  │ Android Phone/    │
  │ Emulator          │
  │ Port: 8080        │
  │ ws://YOUR_IP:8080 │
  └───────────────────┘
```

---

## 📱 Supported Platforms

| Platform | Method | Ease | Speed |
|----------|--------|------|-------|
| **Real Android Phone** | WiFi | ⭐⭐⭐⭐⭐ | Very Fast |
| **Bluestacks** | USB/Network | ⭐⭐⭐⭐ | Fast |
| **NoxPlayer** | USB/Network | ⭐⭐⭐⭐ | Fast |
| **LDPlayer** | USB/Network | ⭐⭐⭐⭐ | Fast |
| **Android Studio** | adb | ⭐⭐⭐ | Fast |
| **iPhone** | Not supported | ❌ | N/A |

---

## 🔐 Security

- **Default Credentials**: `admin` / `admin123`
- **Network**: Assumes private/trusted network
- **Data**: Simulated runner data (no real PII)
- **WebSocket**: Unencrypted (ws://, not wss://) - suitable for local networks only

---

## ❓ FAQ

**Q: Do I need Flutter installed?**
A: No! Flutter is only needed to **build** the APK. The APK runs on any Android device.

**Q: Can I use this on iOS?**
A: Not with this APK. iOS requires separate native development. Contact the development team.

**Q: How long does the backend take to initialize?**
A: ~45 seconds for Kafka to stabilize and start generating data.

**Q: Can I run this without Docker?**
A: No, the backend services (Zookeeper, Kafka, Data Generator) require Docker. They could be installed separately, but Docker is the recommended approach.

**Q: Can multiple phones/emulators connect simultaneously?**
A: Yes! The backend can handle multiple WebSocket connections.

**Q: What if my WiFi is slow?**
A: The app loads 500 runners gradually. Initial load takes 30-60 seconds depending on network speed.

**Q: Why do I see "Loading runners (0/500)"?**
A: The app waits until at least 80% of runners (400/500) are loaded before showing the list. This ensures a good user experience.

---

## 📞 Support

If issues persist:

1. **Check logs:**
   ```bash
   docker logs marathon-data-generator-1
   ```

2. **Restart everything:**
   ```bash
   docker-compose down
   docker-compose up -d
   # Wait 45 seconds
   ```

3. **Verify connectivity:**
   ```bash
   # From phone/emulator terminal or network tool
   ping YOUR_PC_IP
   curl http://YOUR_PC_IP:8080
   ```

4. **Ask for help with:**
   - Your PC IP address
   - Output from `docker-compose ps`
   - Backend logs

---

## 🎯 What You Should See

### Successful App Launch:
- ✅ Login screen with admin/admin123
- ✅ "Loading runner data..." (0-500)
- ✅ Progress bar filling up
- ✅ List of 500 runners with health status
- ✅ Red/yellow/green health indicators
- ✅ Distance sorting options
- ✅ Search/filtering capabilities

### Successful Backend:
```
docker-compose ps
NAME                      STATUS    PORTS
marathon-zookeeper-1      Up        0.0.0.0:22181->2181/tcp
marathon-kafka-1          Up        0.0.0.0:29092->29092/tcp
marathon-data-generator-1 Up        0.0.0.0:8080->8080/tcp
```

---

## 🚀 Next Steps

1. **Install APK** on your device
2. **Start backend** with `docker-compose up -d`
3. **Open app** and login
4. **Enjoy** monitoring 500 runners in real-time!

For developers wanting to modify the app, see [DEVELOPMENT_SETUP.md](./DEVELOPMENT_SETUP.md).

---

**Version**: 1.0  
**Last Updated**: April 5, 2026  
**APK Size**: ~50 MB  
**Requirements**: Docker 20+, Android 6.0+
