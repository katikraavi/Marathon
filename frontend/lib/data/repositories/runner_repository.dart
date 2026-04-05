import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/report.dart';
import '../models/health_state.dart';
import '../models/runner_data.dart';

class RunnerRepository extends ChangeNotifier {
  final Map<int, RunnerData> _runners = {};
  final Map<int, HealthStatus> _previousHealthStatus = {};
  
  // OPTIMIZATION: Batching - collect reports before notifying
  final List<Report> _pendingReports = [];
  Timer? _batchTimer;
  static const batchWindowMs = 50; // Collect for 50ms before updating UI (more responsive)
  
  // OPTIMIZATION: Caching - avoid repeated sorting and filtering
  late List<RunnerData> _cachedSortedList = [];
  late String _cachedSortBy = 'distance';
  late bool _cachedAscending = false;
  late Map<HealthState, int> _cachedHealthDistribution = {};
  late DateTime _lastCacheTime = DateTime.now();
  
  // Track disposal to prevent notifications after dispose
  bool _isDisposed = false;

  Map<int, RunnerData> get runners => _runners;
  
  List<int> get allRunnerIds => _runners.keys.toList();
  
  List<RunnerData> getAllRunners() => _runners.values.toList();

  List<RunnerData> getRunnersSorted({
    required String sortBy,
    required bool ascending,
  }) {
    // OPTIMIZATION: Return cached list if sort criteria haven't changed
    if (sortBy == _cachedSortBy && ascending == _cachedAscending && _cachedSortedList.isNotEmpty) {
      return _cachedSortedList;
    }
    
    final list = getAllRunners();
    
    switch (sortBy) {
      case 'distance':
        list.sort((a, b) => a.distance.compareTo(b.distance));
      case 'device_id':
        list.sort((a, b) => a.deviceId.compareTo(b.deviceId));
      default:
        list.sort((a, b) => a.distance.compareTo(b.distance));
    }

    if (!ascending) {
      _cachedSortedList = list.reversed.toList();
    } else {
      _cachedSortedList = list;
    }
    
    _cachedSortBy = sortBy;
    _cachedAscending = ascending;

    return _cachedSortedList;
  }

  List<RunnerData> getRunnersByHealthState(HealthState state) {
    return _runners.values
        .where((runner) => runner.healthStatus.state == state)
        .toList();
  }

  RunnerData? getRunner(int deviceId) {
    return _runners[deviceId];
  }

  void addReport(Report report) {
    // OPTIMIZATION: Batch reports instead of notifying immediately
    _pendingReports.add(report);
    
    // Start or reschedule batch timer
    if (_pendingReports.length == 1) {
      // First report in batch - start timer
      _batchTimer = Timer(const Duration(milliseconds: batchWindowMs), _processBatch);
    } else if (_pendingReports.length > 50) {
      // Too many pending - process immediately for responsiveness
      _batchTimer?.cancel();
      _processBatch();
    }
  }
  
  void _processBatch() {
    if (_pendingReports.isEmpty) return;
    
    // Process all pending reports
    for (final report in _pendingReports) {
      final runner = _runners.putIfAbsent(
        report.deviceId,
        () => RunnerData(deviceId: report.deviceId),
      );

      final previousStatus = _previousHealthStatus[report.deviceId];
      runner.addReport(report);
      final newStatus = runner.healthStatus;

      // Track health state changes for notifications
      if (previousStatus == null ||
          previousStatus.state != newStatus.state) {
        _previousHealthStatus[report.deviceId] = newStatus;
      }
    }
    
    _pendingReports.clear();
    _batchTimer?.cancel();
    
    // Invalidate caches and notify listeners once for entire batch
    _invalidateCaches();
    
    // Only notify if not disposed (prevents errors after dispose)
    if (!_isDisposed) {
      notifyListeners();
    }
  }
  
  void _invalidateCaches() {
    // Clear cached sorted list so it will be recalculated next time it's needed
    _cachedSortedList = [];
    _cachedSortBy = ''; // Reset sort key to force cache check to fail
    _cachedAscending = false; // Reset ascending flag
    // Health distribution will be recalculated when accessed via getHealthStateDistribution()
  }

  bool hasHealthStateChanged(int deviceId) {
    final previous = _previousHealthStatus[deviceId];
    final runner = _runners[deviceId];
    
    if (runner == null || previous == null) return false;
    
    return previous.state != runner.healthStatus.state;
  }

  HealthStatus? getPreviousHealthStatus(int deviceId) {
    return _previousHealthStatus[deviceId];
  }

  void clear() {
    _runners.clear();
    _previousHealthStatus.clear();
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  int get runnerCount => _runners.length;

  // Statistics - OPTIMIZATION: Cache distribution to avoid recalculating every frame
  Map<HealthState, int> getHealthStateDistribution() {
    // Return cached distribution if it was calculated recently
    if (_cachedHealthDistribution.isNotEmpty &&
        DateTime.now().difference(_lastCacheTime).inMilliseconds < 500) {
      return _cachedHealthDistribution;
    }
    
    final distribution = {
      HealthState.normal: 0,
      HealthState.warning: 0,
      HealthState.emergency: 0,
    };

    for (final runner in _runners.values) {
      distribution[runner.healthStatus.state] =
          (distribution[runner.healthStatus.state] ?? 0) + 1;
    }

    _cachedHealthDistribution = distribution;
    _lastCacheTime = DateTime.now();
    return distribution;
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _batchTimer?.cancel();
    super.dispose();
  }
}
