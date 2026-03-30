# Marathon Safety - System Integration Guide

Complete walkthrough for testing the full Marathon Safety system from backend to Flutter app.

---

## 📊 System Architecture

```
Backend Infrastructure
├── Zookeeper (Coordination)         ← Kafka broker leadership
├── Kafka (Persistence)              ← Stores vital reports  
└── Data Generator (gRPC on :8080)   ← Streams simulated runner data
                      ↓
                  Protobuf
                 (binary msgs)
                      ↓
Flutter App (WebSocket Consumer)
├── Dual-Format Parser (JSON/Protobuf)
├── Domain Models (Report, HealthState)
├── Real-Time Charts (10-min windows)
└── Emergency Alerts (notifications)
```

---

## 🧪 Integration Testing Checklist

### Phase 1: Backend Startup (5 minutes)

**Step 1: Start Docker Services**
```bash
cd /home/katikraavi/Marathon
./start-backend.sh
```

Expected output:
```
✓ Checking Docker...
✓ Starting services...
✓ All services running:

NAME                COMMAND             STATUS
zookeeper           /etc/confluent/...  Up (healthy)
kafka               /etc/confluent/...  Up (healthy)
data-generator      /bin/sh             Up (healthy)

Connection Endpoints:
- gRPC: ws://localhost:8080
- Android Emulator: ws://10.0.2.2:8080
- Physical Device: ws://{YOUR_IP}:8080
```

**Step 2: Verify Services**
```bash
docker-compose ps
```

All three services should show `Up (healthy)`.

**Step 3: Check Data Generator Logs**
```bash
docker-compose logs -f data-generator
```

Look for messages like:
```
INFO: Data Generator Started
INFO: Listening on port 8080
INFO: Sending TimeBasedReport for device 1
```

Press `Ctrl+C` to exit logs (services keep running).

---

### Phase 2: Flutter App Startup (10 minutes)

**Step 1: Launch Flutter App**

In a new terminal:
```bash
cd marathon_safety
flutter run
```

Choose target:
- **Android Emulator**: Press `a`
- **iOS Simulator**: Press `i`
- **Physical Device** (USB connected): Press your device number

Expected output:
```
✓ Flutter app started
✓ Welcome to Marathon Safety
✓ Login screen visible
```

**Step 2: Login to App**

User credentials:
- **Username**: `admin`
- **Password**: `admin123`

After login, you should see:
- ✅ Race list with ~500 active runners
- ✅ Real-time vital stats (heartbeat, oxygen, temperature, etc.)
- ✅ Health status chips (✓ Normal, ⚠️ Warning, 🚨 Emergency)

---

### Phase 3: Data Flow Verification (15 minutes)

#### Test Case 1: Real-Time Updates

**Objective:** Verify data refreshes every 1 second

1. Open **Race List Screen**
2. Observe runner heartbeat values
3. **Every 1 second**, heartbeat should increment slightly
   - ✅ Updates via TimeBasedReport (Protobuf)
   - ✅ Calculated as rolling 5-sec average

**Verification:**
```bash
# Terminal 1: Watch backend logs
docker-compose logs -f data-generator | grep TimeBasedReport

# Should see continuous updates like:
# Sending TimeBasedReport for device 1, heartbeat: 412 bpm
# Sending TimeBasedReport for device 2, heartbeat: 405 bpm
```

---

#### Test Case 2: Health Status Detection

**Objective:** Verify warning/emergency alerts trigger correctly

1. In Race List, find runners with different health states:
   - ✅ Green chip = Normal
   - ⚠️ Orange chip = Warning (1+ vital outside threshold)
   - 🚨 Red chip = Emergency (2+ vitals outside threshold)

2. Tap on a runner to open **Runner Detail Screen**
   - Should see 2 real-time charts:
     - **Heartbeat Chart** (last 10 min, rolling window)
     - **Oxygen Level Chart** (last 10 min, rolling window)
   - Should see **Event Log** below charts

**Health Thresholds (defined in app):**

| Vital | Warning | Emergency |
|-------|---------|-----------|
| Heartbeat | >150 or <50 bpm | >180 or <40 bpm |
| Oxygen | <85% | <70% |
| Temperature | >39°C or <35°C | >40°C or <34°C |
| BP Systolic | >160 or <90 mmHg | >180 or <80 mmHg |

---

#### Test Case 3: WebSocket Dual Format Support

**Objective:** Verify app handles both JSON and Protobuf messages

**Backend sends both formats automatically:**
- **TimeBasedReport** (Protobuf): Every 1 second
- **EventBasedReport** (Protobuf): When vital changes

**Verification in App:**
1. Charts update in real-time → **Parsing Protobuf ✓**
2. Event log shows new vitals → **Parsing EventBased ✓**
3. No parsing errors in console → **Auto-detection working ✓**

**Debug: Check Flutter Console**
```
[VERBOSE] WebSocket incoming: TimeBasedReport (232 bytes)
[VERBOSE] Parsed heartbeat: 412 bpm
[VERBOSE] Updated health state: Normal
```

---

#### Test Case 4: Filtering & Sorting

**On Race List Screen:**

**Test Sort Order:**
1. Tap "Sort by: Distance" → Runners sorted by distance (ascending)
2. Tap again → Sorted descending
3. Tap "Sort by: Heartbeat" → Runners sorted by BPM

**Test Health Filter:**
1. Tap "Filter: All" → Shows all runners
2. Tap "Filter: Normal" → Shows only ✅ green chips
3. Tap "Filter: Warning" → Shows only ⚠️ orange chips
4. Tap "Filter: Emergency" → Shows only 🚨 red chips

**Observation:** Filters should update UI instantly without network delay.

---

#### Test Case 5: Temperature Precision

**Objective:** Verify protobuf temperature conversion (tenths of degree)

1. Open Runner Detail for multiple runners
2. Observe temperatures displayed (e.g., 37.5°C, 36.8°C)
3. Values should have decimal precision

**Backend sends as tenths:**
- Protobuf: 375 = 37.5°C
- App converts: 375 / 10 = 37.5°C ✓

**Verification Script:**
```bash
# Check backend is sending correct temperature format
docker-compose exec data-generator ./client | grep temperature
# Should see: temperature: 375 (meaning 37.5°C)
```

---

### Phase 4: Stress Testing (10 minutes)

#### Test Case 1: Handle 500 Concurrent Runners

1. Keep Flutter app running
2. Verify smooth performance:
   - ✅ No lag in list scrolling
   - ✅ Charts render without stutter
   - ✅ Tap response < 200ms

**Monitor Resources:**
```bash
docker stats
```

Expected (on typical machine):
- Kafka: ~5% CPU, 300MB RAM
- Data Generator: ~8% CPU, 250MB RAM
- Flutter App: depends on device

---

#### Test Case 2: Network Interruption Recovery

1. While app is running, simulate network issues:
   ```bash
   # On Linux/macOS, block port 8080
   sudo iptables -A INPUT -p tcp --destination-port 8080 -j DROP
   ```

2. App should:
   - ✅ Disconnect gracefully
   - ✅ Attempt reconnect (max 5 attempts, 3-sec backoff)
   - ✅ Show "Reconnecting..." state

3. Restore connectivity:
   ```bash
   sudo iptables -D INPUT -p tcp --destination-port 8080 -j DROP
   ```

4. App should:
   - ✅ Reconnect successfully
   - ✅ Resume data stream
   - ✅ Update UI with latest data

---

### Phase 5: Admin Features Testing (5 minutes)

#### Test Case 1: Pagination

On Race List:
1. View first 10 runners (default)
2. Scroll list → Next batch loads
3. Verify smooth infinite scroll

#### Test Case 2: Chart Data Window

On Runner Detail:
1. Charts show last **10 minutes** of data
2. Data automatically cleans up older entries
3. Memory usage stays stable (not growing unbounded)

#### Test Case 3: Emergency Notification

*Note: Requires device with notification support*

1. Find a runner with emergency-level vitals
2. App should show notification:
   - 🚨 Title: "EMERGENCY ALERT"
   - Sound + vibration
   - Auto-expand Runner Detail

---

## 🔍 Debugging Guide

### Problem: Data not updating

**Check Backend:**
```bash
# 1. Verify Docker running
docker-compose ps

# 2. Check data generator logs
docker-compose logs data-generator

# 3. Test gRPC endpoint
grpcurl -plaintext localhost:8080 list
```

**Check App:**
```
Look in Flutter console for:
- WebSocket connected messages
- Parse errors
- Reconnection attempts
```

---

### Problem: Charts not rendering

**Cause & Solution:**

1. **No data received**
   - Check WebSocket logs
   - Verify backend is running
   
2. **Data parsing failed**
   - Check for protobuf decode errors
   - Verify reports.pb.dart generated correctly
   
3. **Chart library issue**
   - `flutter pub get`
   - Rebuild app: `flutter run --release`

---

### Problem: Performance lag

**Check:**
```bash
# Monitor system resources
docker stats

# Check network latency
ping -c 1 localhost  # Should be < 1ms

# Verify no memory leaks in app
flutter run --profile
```

---

## ✅ Full System Verification Checklist

- [ ] Backend starts with `./start-backend.sh`
- [ ] All 3 services show "healthy" in `docker-compose ps`
- [ ] Flutter app launches without errors
- [ ] User login works (admin/admin123)
- [ ] Race list displays ~500 runners
- [ ] Heartbeat values update every 1 second
- [ ] Health status colors are accurate
- [ ] Filters & sorting work
- [ ] Charts render data for selected runner
- [ ] Temperature shows with decimal precision
- [ ] Event log shows real-time updates
- [ ] Notifications appear for emergency/warnings
- [ ] App handles network interruption gracefully
- [ ] Performance remains smooth with 500 runners
- [ ] No errors in Flutter console

---

## 📈 Success Criteria

System is **fully functional** when:

✅ **Backend Layer**: All 3 Docker services healthy, data generator streaming 500+ runners
✅ **Network Layer**: WebSocket connected, protobuf/JSON auto-detected
✅ **Data Layer**: Real-time updates received (1-sec interval), parsed correctly
✅ **UI Layer**: Charts animated smoothly, alerts triggered appropriately
✅ **State Layer**: Filters, sorting, pagination all responsive
✅ **Error Handling**: Graceful reconnection, no crashes under stress

---

## 🎯 Final Deployment

When all tests pass, you're ready to:

1. **Build Release APK**
   ```bash
   cd marathon_safety
   flutter build apk --release
   # Outputs: build/app/outputs/apk/release/app-release.apk
   ```

2. **Deploy to Device**
   See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for multiple methods

3. **Monitor in Production**
   ```bash
   # View app logs from device
   adb logcat | grep marathon
   ```

---

## 📞 Support

For issues during integration testing:
1. Check logs: `docker-compose logs -f`
2. Review troubleshooting section above
3. Consult [BACKEND_SETUP.md](BACKEND_SETUP.md) for backend-specific help
4. Check [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) for architecture details

