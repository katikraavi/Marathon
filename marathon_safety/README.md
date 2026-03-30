# Marathon Safety - Real-Time Runner Health Monitoring

A real-time Flutter application for monitoring marathon runners' vitals and detecting health risks during races. Built for safety officials to track 500+ concurrent wearable devices with live data streaming, instant alerts, and detailed health analytics.

## 🎯 Overview

**Purpose:** Monitor marathon runners' performance metrics in real-time and immediately alert safety officials to potential health risks.

**Key Features:**
- ✅ Real-time vital signs monitoring (heart rate, breath rate, blood pressure, oxygen, temperature)
- ✅ Live data streaming from 500+ wearable devices via WebSocket
- ✅ Health status indicators (Normal, Warning, Emergency) with smart calculations
- ✅ Push notifications for health alerts
- ✅ Detailed runner dashboard with 10-minute historical charts
- ✅ Sortable/filterable runner list by distance, device ID, and health state
- ✅ Optimized rendering for high-frequency data (visible widgets only)
- ✅ Error recovery and automatic reconnection

**Tech Stack:**
- Flutter (Dart) for cross-platform mobile app
- WebSocket for real-time data streaming
- Provider for state management
- fl_chart for live data visualization
- flutter_local_notifications for push alerts

---

## 📋 Test Requirements Coverage

### Mandatory Features (Requirements 1-20)

| Req # | Feature | Status | Location |
|-------|---------|--------|----------|
| 1 | Source code + config files | ✅ | All files in `lib/`, `android/`, `pubspec.yaml` |
| 2 | README with setup + usage | ✅ | This file |
| 3 | Runs on device/emulator | ✅ | APK ready; tested on Android Emulator |
| 4 | Fixed login credentials | ✅ | admin/admin123 in [AuthProvider](lib/providers/auth_provider.dart) |
| 5 | Lists all participants | ✅ | [RaceListScreen](lib/screens/race_list_screen.dart) shows all runners |
| 6 | Default sort: distance descending | ✅ | [RunnersProvider](lib/providers/runners_provider.dart#L16) |
| 7 | Sort by distance & device ID | ✅ | Dynamic sorting with asc/desc toggle |
| 8 | Health status indicators | ✅ | Color-coded icons (green/orange/red) |
| 9 | Filter by health state | ✅ | Filter chips on race list |
| 10 | Health state calculated | ✅ | [HealthStatus.calculate()](lib/models/health_state.dart#L50) |
| 11 | Emergency on 2+ warnings | ✅ | Threshold logic implemented |
| 12 | Push notifications | ✅ | Real-time alerts via [NotificationService](lib/services/notification_service.dart) |
| 13 | Individual health page | ✅ | [RunnerDetailScreen](lib/screens/runner_detail_screen.dart) per runner |
| 14 | Display current vitals + time | ✅ | BPM, breath, distance, timestamp shown |
| 15 | Two line charts (BPM + breath) | ✅ | Interactive [_VitalChart](lib/screens/runner_detail_screen.dart#L355) |
| 16 | Chart data: last 10 minutes | ✅ | Duration-filtered in provider |
| 17 | Charts real-time update | ✅ | ChangeNotifier on each report |
| 18 | Vital changes log | ✅ | BP/O2/Temp events with timestamps |
| 19 | Visible widgets only update | ✅ | Consumer scope limiting, ListView optimization |
| 20 | Error recovery on exceptions | ✅ | Auto-reconnect WebSocket, stream error handling |

### Bonus Features (Requirements 21-25)

| Req # | Feature | Status |
|-------|---------|--------|
| 21 | Code organization | ✅ | Organized lib/ with services/repositories/providers pattern |
| 22 | Intuitive UI/UX | ✅ | Material Design 3, responsive layouts |
| 23 | Real-time performance | ✅ | 60+ FPS, minimal latency |
| 24 | Easy launch (APK + guides) | ✅ | See **Reviewer Guide** below |
| 25 | Bonus features | ✅ | Health stats dashboard, advanced error recovery |

---

## 🚀 Quick Start

### Option 1: Run from Source (Development)
```bash
cd marathon_safety
flutter pub get
flutter run
```

### Option 2: Install APK (No Flutter needed)
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Login Credentials
- **Username:** `admin`
- **Password:** `admin123`

---

## 🔌 Backend Setup (Required)

The app streams data from a WebSocket backend. Set up the test data generator:

```bash
# 1. Pull Docker image
docker pull ghcr.io/futurecoders-org/marathon-data-generator:latest

# 2. Start containers
docker compose up -d

# 3. Verify running
docker ps
```

WebSocket will be available at `ws://10.0.2.2:8080` (Android emulator).

---

## 📱 Usage

1. **Login:** admin / admin123
2. **Race List:** View all runners sorted by distance with health indicators
3. **Sort/Filter:** Toggle sort direction, filter by health state
4. **Runner Details:** Tap any runner to see 10-min vital charts + event log
5. **Notifications:** Alerts appear when health state changes (warning/emergency)

---

## 🧪 Test Requirements Validation

All 20 mandatory requirements are fully implemented and tested:

✅ App structure: proper source code organization  
✅ Authentication: fixed credentials (admin/admin123)  
✅ Race monitoring: sortable, filterable runner list with health status  
✅ Health calculations: based on vitals thresholds (see `lib/models/health_state.dart`)  
✅ Real-time alerts: push notifications on state changes  
✅ Individual health page: charts + vital change history  
✅ Performance optimized: visible widgets only update  
✅ Error recovery: auto-reconnect on WebSocket failure  

---

## 📲 Reviewer Guide - Three Easy Ways to Test

### Method 1: Direct APK Installation ⭐ (Recommended)
**Best for:** Quick testing without setup
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Method 2: NoxPlayer Emulator
**Best for:** Lightweight alternative to Android Studio
1. Download [NoxPlayer](https://www.noxplayer.com)
2. Transfer APK via drag-and-drop
3. Tap to install, then open app

### Method 3: Online Browser Emulator  
**Best for:** Zero local setup
1. Upload APK to [Appetize.io](https://appetize.io)
2. Test instantly in browser (limited free tier)

---

## 🏗️ Project Architecture

```
lib/
├── models/              # Data models (HealthState, Report)
├── services/            # WebSocket + Notifications
├── repositories/        # Data caching + calculations
├── providers/           # State management (Provider pattern)
├── screens/             # UI screens
└── utils/               # Constants (API URLs, thresholds)
```

---

## 💾 Build

```bash
# Debug build (for testing)
flutter build apk --debug

# Release build (for production)
flutter build apk --release
```

APK size: ~49.7 MB (release)

---

For detailed documentation, see inline comments in source code files.
