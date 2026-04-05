import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../data/repositories/runner_repository.dart';
import '../../data/models/report.dart';
import '../../data/models/runner_data.dart';
import '../../data/models/health_state.dart';
import '../../data/sources/websocket_source.dart';

class RunnerDetailProvider extends ChangeNotifier {
  // Track which runners are currently active (updating)
  static final Set<int> _activeRunners = {};
  // Notifier to trigger rebuilds when active runners change
  static final ValueNotifier<int> _activeRunnersNotifier = ValueNotifier<int>(0);
  
  final RunnerRepository repository;
  final int deviceId;
  final WebSocketService webSocketService;
  Timer? _refreshTimer;
  bool _isVisible = false;
  bool _isConnected = false;
  bool _disposed = false;
  int _updateCount = 0;
  StreamSubscription? _connectionStatusSubscription;

  RunnerDetailProvider({
    required this.repository,
    required this.deviceId,
    required this.webSocketService,
  }) {
    print('[Provider] Created for Runner #$deviceId');
    // Listen to repository for all updates
    repository.addListener(_onRepositoryChanged);
    
    // Listen to WebSocket connection status changes
    _connectionStatusSubscription = webSocketService.connectionStatus.listen((isConnected) {
      if (_disposed) return;
      
      print('[Connection] Status change: isConnected=$isConnected, _isVisible=$_isVisible, hadTimer=${_refreshTimer != null}');
      _isConnected = isConnected;
      
      // When connection is lost, stop the update timer immediately
      if (!isConnected) {
        _refreshTimer?.cancel();
        _refreshTimer = null;
        final wasActive = _activeRunners.contains(deviceId);
        _activeRunners.remove(deviceId);
        if (wasActive) {
          print('[Update] DISCONNECTED Runner #$deviceId (now ${_activeRunners.length} updating)');
        }
        _activeRunnersNotifier.value = _activeRunners.length; // Set to actual count
      } 
      // When connection is restored and we're visible, restart the timer
      else if (isConnected && _isVisible) {
        _activeRunners.add(deviceId);
        _startTimerIfNeeded();
        print('[Update] RECONNECTED Runner #$deviceId (now ${_activeRunners.length} updating)');
        _activeRunnersNotifier.value = _activeRunners.length; // Set to actual count
      }
      
      notifyListeners();
    });
  }

  int get updateCount => _updateCount;
  // Paused if either not visible (off-screen) OR not connected (backend down)
  bool get isPaused => !(_isVisible && _isConnected);

  // Static method to check if a runner is currently active (updating)
  static bool isRunnerActive(int deviceId) {
    return _activeRunners.contains(deviceId);
  }

  // Static getter for the notifier to listen to changes
  static ValueNotifier<int> get activeRunnersNotifier => _activeRunnersNotifier;
  
  // Static getter to get count of active runners
  static int get activeRunnersCount => _activeRunners.length;
  
  // Static getter to get the currently active runner ID (if only one)
  static int? get activeRunnerId => _activeRunners.length == 1 ? _activeRunners.first : null;

  void _onRepositoryChanged() {
    // Only increment counter if BOTH visible AND connected AND new data actually arrived
    if (_isVisible && _isConnected) {
      _updateCount++;
      notifyListeners();
    }
    // If not visible or not connected, don't increment even if data arrives
    // (data won't come through anyway if disconnected)
  }

  /// Start the refresh timer if not already running and conditions allow
  /// This timer is only for UI rebuilds, NOT for incrementing the counter
  void _startTimerIfNeeded() {
    if (_refreshTimer != null) return; // Already running
    if (!_isVisible || !_isConnected) return; // Conditions not met
    
    _updateCount = 0; // Reset counter when resuming
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      // Timer ONLY forces UI rebuild - does NOT increment counter
      // Counter is incremented ONLY when data actually arrives (in _onRepositoryChanged)
      if (_isVisible && _isConnected) {
        notifyListeners(); // Rebuild UI to show latest data
      }
    });
  }

  // Pause updates when widget is not visible (off-screen)
  void pauseUpdates() {
    print('[Pause] pauseUpdates called for Runner #$deviceId');
    if (_disposed) {
      print('[Pause]   Already disposed, skipping');
      return;
    }
    _isVisible = false;
    final wasActive = _activeRunners.contains(deviceId);
    print('[Pause]   Was active: $wasActive, Active runners: ${_activeRunners.length}');
    _activeRunners.remove(deviceId); // Remove from active set
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (wasActive) {
      print('[Update] PAUSED Runner #$deviceId (now ${_activeRunners.length} updating)');
    }
    // Update notifier to reflect actual count
    _activeRunnersNotifier.value = _activeRunners.length;
    notifyListeners();
  }

  // Resume updates when widget becomes visible (on-screen)
  void resumeUpdates() {
    print('[Resume] resumeUpdates called for Runner #$deviceId');
    if (_disposed) {
      print('[Resume]   Already disposed, skipping');
      return;
    }
    _isVisible = true;
    // Get actual connection status from WebSocketService, not just cached value
    final actuallyConnected = webSocketService.isConnected;
    print('[Resume]   Connected: $actuallyConnected (cached: $_isConnected), Active runners: ${_activeRunners.length}');
    // Add to active set if connected (use actual status)
    if (actuallyConnected) {
      _activeRunners.add(deviceId); // Add to active set
      _startTimerIfNeeded(); // Start timer with all checks
      print('[Update] ACTIVE Runner #$deviceId (now ${_activeRunners.length} updating)');
      // Update notifier to reflect actual count
      _activeRunnersNotifier.value = _activeRunners.length;
      notifyListeners();
    } else {
      print('[Resume]   Not connected, skipping timer start');
      notifyListeners(); // Update status display even if not connected
    }
  }

  @override
  void dispose() {
    print('[Dispose] Runner #$deviceId, was active: ${_activeRunners.contains(deviceId)}');
    _disposed = true;
    repository.removeListener(_onRepositoryChanged);
    _connectionStatusSubscription?.cancel();
    _refreshTimer?.cancel();
    _activeRunners.remove(deviceId);
    super.dispose();
  }

  // Always get the latest runner from the repository - never cache it
  // This ensures the UI always reflects the most current data
  RunnerData get runner {
    final repoRunner = repository.getRunner(deviceId);
    if (repoRunner != null) {
      return repoRunner;
    }
    // If runner doesn't exist yet, return empty runner (will get populated when first report arrives)
    return RunnerData(deviceId: deviceId);
  }

  // Current vitals
  int get currentHeartbeat => runner.getAverageHeartbeat();
  int get currentBreath => runner.getAverageBreath();
  double get currentDistance => runner.distance;
  DateTime? get lastUpdateTime => runner.lastUpdateTime;

  // Chart data (last 10 minutes)
  List<ChartDataPoint> get heartbeatChartData {
    return _generateChartData(
      reports: runner.getReportsInWindow(const Duration(minutes: 10)),
      getValue: (r) => r.heartbeat.toDouble(),
    );
  }

  List<ChartDataPoint> get breathChartData {
    return _generateChartData(
      reports: runner.getReportsInWindow(const Duration(minutes: 10)),
      getValue: (r) => r.breath.toDouble(),
    );
  }

  List<ChartDataPoint> _generateChartData({
    required List<Report> reports,
    required double Function(Report) getValue,
  }) {
    if (reports.isEmpty) return [];

    final startTime = reports.first.timestamp;
    return reports.map((report) {
      final secondsElapsed = report.timestamp.difference(startTime).inSeconds;
      return ChartDataPoint(
        x: secondsElapsed.toDouble(),
        y: getValue(report),
        timestamp: report.timestamp,
      );
    }).toList();
  }

  // Event log - track HEALTH STATUS changes only (normal → warning → emergency)
  List<VitalEvent> get vitalEvents {
    final events = <VitalEvent>[];
    final reports = runner.getReportsInWindow(const Duration(minutes: 10));

    if (reports.isEmpty) return events;

    // Track health status changes through the report history
    HealthStatus? prevHealth;

    for (final report in reports) {
      final currentHealth = HealthStatus.calculate(
        heartbeat: report.heartbeat,
        breath: report.breath,
        systolicBp: report.systolicBp,
        diastolicBp: report.diastolicBp,
        bloodOxygen: report.bloodOxygen,
        temperature: (report.temperature * 10).toInt(),
      );

      // Detect status transition
      if (prevHealth != null && prevHealth.state != currentHealth.state) {
        String statusIcon = '';
        String statusLabel = '';
        
        if (currentHealth.state == HealthState.emergency) {
          statusIcon = '🚨';
          statusLabel = 'EMERGENCY';
        } else if (currentHealth.state == HealthState.warning) {
          statusIcon = '⚠️';
          statusLabel = 'WARNING';
        } else {
          statusIcon = '✅';
          statusLabel = 'NORMAL';
        }

        // Build detailed reason from the vital issues
        String reason = currentHealth.reason.isNotEmpty 
            ? currentHealth.reason 
            : 'Check vitals';

        final event = VitalEvent(
          type: statusLabel,
          value: reason,
          timestamp: report.timestamp,
        );
        
        events.add(event);
      }

      prevHealth = currentHealth;
    }
    
    // Return most recent events first
    return events.reversed.toList();
  }
}

class ChartDataPoint {
  final double x;
  final double y;
  final DateTime timestamp;

  ChartDataPoint({
    required this.x,
    required this.y,
    required this.timestamp,
  });
}

class VitalEvent {
  final String type;
  final String value;
  final DateTime timestamp;

  VitalEvent({
    required this.type,
    required this.value,
    required this.timestamp,
  });

  String get formattedTime {
    return DateFormat('HH:mm:ss').format(timestamp);
  }
}
