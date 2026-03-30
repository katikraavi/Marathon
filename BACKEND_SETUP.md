# Marathon Safety - Backend Setup Guide

Complete guide for setting up and running the Marathon Safety backend data generator.

---

## ✨ One-Command Startup

**For Linux/macOS:**
```bash
cd /home/katikraavi/Marathon
./start-backend.sh
```

**For Windows (PowerShell):**
```powershell
cd C:\path\to\Marathon
docker-compose up -d
```

---

## 📋 Prerequisites

- **Docker**: [Install Docker](https://docs.docker.com/get-docker/)
- **Docker Compose**: [Install Docker Compose](https://docs.docker.com/compose/install/)
- **Ports available**: 8080, 22181, 29092 (not in use)

### Check Prerequisites

```bash
docker --version
docker-compose --version
```

---

## 🏗️ Architecture Overview

The Marathon Safety backend consists of 3 interconnected services:

```
Data Generator (gRPC Server on :8080)
        ↓
    Kafka Broker (Message persistence)
        ↓
    Zookeeper (Coordination)
```

### Service Responsibilities

| Service | Role | Responsibility |
|---------|------|-----------------|
| **Zookeeper** | Coordinator | Manages Kafka broker coordination and leader election |
| **Kafka** | Message Broker | Persists vital reports, ensures no data loss |
| **Data Generator** | gRPC Server | Generates simulated runner data, streams to Flutter app |

---

## 🚀 Quick Start (Step-by-Step)

### Step 1: Start Backend

```bash
cd /home/katikraavi/Marathon
docker-compose up -d
```

Expected output:
```
Creating zookeeper ... done
Creating kafka ... done
Creating data-generator ... done
```

### Step 2: Verify Services

```bash
docker-compose ps
```

Expected output:
```
NAME                COMMAND             STATUS
zookeeper           /etc/confluent/...  Up (healthy)
kafka               /etc/confluent/...  Up (healthy)
data-generator      /bin/sh             Up (healthy)
```

### Step 3: Check Data Generator Logs

```bash
docker-compose logs -f data-generator
```

You should see logs indicating data is being generated:
```
INFO: Starting Marathon Data Generator
INFO: Listening on port 8080
INFO: Producer started, sending reports...
```

### Step 4: Run Flutter App

In a new terminal:
```bash
cd marathon_safety
flutter run
```

The app will connect to `ws://10.0.2.2:8080` (Android) or `ws://localhost:8080` (iOS/Desktop).

### Step 5: Stop Backend

```bash
cd /home/katikraavi/Marathon
./stop-backend.sh
# or: docker-compose down
```

---

## 🔧 Manual Service Control

### Start All Services

```bash
docker-compose up -d
```

### Start Specific Service

```bash
# Just Zookeeper
docker-compose up -d zookeeper

# Just Kafka (requires Zookeeper running)
docker-compose up -d kafka

# Just Data Generator
docker-compose up -d data-generator
```

### Stop Services

```bash
# Stop all services (preserves data)
docker-compose stop

# Stop and remove containers (preserves volumes)
docker-compose down

# Stop and remove everything (deletes data)
docker-compose down -v
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f data-generator

# Last 50 lines
docker-compose logs --tail=50 data-generator
```

### Check Service Health

```bash
# Show status
docker-compose ps

# Inspect specific service
docker-compose exec data-generator /bin/sh

# Test gRPC health
grpcurl -plaintext localhost:8080 list
```

---

## 📊 Backend Services Explained

### 1️⃣ Zookeeper (Port 22181)

**Purpose:** Coordinates Kafka brokers and ensures high availability.

**Health Check:**
```bash
# Check if Zookeeper is responding
echo ruok | nc localhost 2181
# Should respond: "imok"
```

**Manual Management:**
```bash
docker-compose logs zookeeper
docker-compose restart zookeeper
```

---

### 2️⃣ Kafka (Port 29092)

**Purpose:** Persists vital reports and ensures no data is lost.

**Health Check:**
```bash
# List Kafka topics
kafka-topics --bootstrap-server localhost:29092 --list
```

**Manual Management:**
```bash
docker-compose logs kafka
docker-compose restart kafka
```

---

### 3️⃣ Data Generator (Port 8080)

**Purpose:** Simulates 500+ marathon runners' wearable devices and streams data via gRPC.

**Available Commands Inside Container:**

```bash
# Access container shell
docker-compose exec data-generator /bin/sh

# Inside container:
./producer    # Start sending test data
./client      # View incoming data in real-time
```

**Health Check:**
```bash
# Check gRPC service availability
grpcurl -plaintext localhost:8080 list
```

**View Logs:**
```bash
docker-compose logs -f data-generator
```

---

## 🔌 Connecting Flutter App

### Android Emulator
```
ws://10.0.2.2:8080
```
(Special gateway address for reaching host machine from Android emulator)

### iOS Simulator
```
ws://localhost:8080
```

### Physical Device (on same network)
```
ws://{YOUR_COMPUTER_IP}:8080
```

Example:
```bash
# Find your machine's IP
hostname -I  # Linux
ipconfig     # Windows
ifconfig     # macOS

# Use that IP in app constants
ws://192.168.1.100:8080
```

---

## ⚠️ Troubleshooting

### Problem: Services won't start

**Solution:**
```bash
# Clean up and restart
docker-compose down -v
docker-compose up -d
```

### Problem: Port already in use

**Solution:**
```bash
# Find what's using port 8080
lsof -i :8080  # macOS/Linux
netstat -ano | findstr :8080  # Windows

# Kill process or use different port in docker-compose.yml
```

### Problem: Can't connect from Flutter app

**Check:**
1. Backend is running: `docker-compose ps`
2. Using correct URL for your platform (see Connecting Flutter App section)
3. Both on same network for physical devices
4. Check firewall isn't blocking port 8080

**Debug:**
```bash
# Test gRPC endpoint
grpcurl -plaintext localhost:8080 list

# Check logs
docker-compose logs data-generator
```

### Problem: Data generator crashes

**Solution:**
```bash
# View detailed logs
docker-compose logs --tail=100 data-generator

# Restart service
docker-compose restart data-generator

# Force rebuild image
docker-compose down
docker pull ghcr.io/futurecoders-org/marathon-data-generator:latest
docker-compose up -d
```

---

## 📈 Performance Monitoring

### Monitor Services

```bash
# Real-time resource usage
docker stats

# Watch specific service
docker stats data-generator
```

### Check Data Flow

```bash
# View data generator output
docker-compose exec data-generator ./client

# Count messages in Kafka
docker-compose exec kafka kafka-consumer-groups \
  --bootstrap-server kafka:9092 \
  --list
```

---

## 🔒 Security Notes

- Backend runs on localhost by default (not exposed to internet)
- For production, add authentication and SSL
- Kafka is not authenticated by default (suitable for dev/test only)
- Data persists in Docker volumes (survives container restart)

---

## 📦 Volume Management

### View Volumes

```bash
docker volume ls | grep marathon
```

### Backup Data

```bash
# Export data to tar
docker run --rm -v marathon_safe_kafka:/data \
  -v $(pwd):/backup \
  ubuntu tar czf /backup/kafka_data.tar.gz /data
```

### Reset Data

```bash
# Remove all volumes (DELETES DATA)
docker-compose down -v

# Recreate with fresh service
docker-compose up -d
```

---

## 📚 Command Reference

| Command | Purpose |
|---------|---------|
| `./start-backend.sh` | Start all services (Linux/macOS) |
| `./stop-backend.sh` | Stop all services (Linux/macOS) |
| `docker-compose up -d` | Start all services |
| `docker-compose down` | Stop services (preserves data) |
| `docker-compose down -v` | Stop and remove all data |
| `docker-compose ps` | Show service status |
| `docker-compose logs -f` | View live logs |
| `docker-compose restart` | Restart all services |
| `docker-compose exec data-generator /bin/sh` | Access generator shell |

---

## 🎯 Next Steps

1. ✅ Start backend: `./start-backend.sh`
2. ✅ Verify running: `docker-compose ps`
3. ✅ Launch Flutter app: `cd marathon_safety && flutter run`
4. ✅ Login with: `admin` / `admin123`
5. ✅ View runners and vitals in real-time

For issues, check the troubleshooting section or view detailed logs with `docker-compose logs`.
