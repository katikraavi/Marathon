import 'package:flutter/foundation.dart';
import '../models/report.dart';
import '../models/health_state.dart';
import '../utils/constants.dart';

class RunnerData {
  final int deviceId;
  final List<Report> reports; // Sorted by timestamp, newest last
  double get distance => reports.isNotEmpty ? reports.last.distanceCovered : 0;
  DateTime? get lastUpdateTime => reports.isNotEmpty ? reports.last.timestamp : null;

  HealthStatus get healthStatus {
    if (reports.isEmpty) {
      return HealthStatus(state: HealthState.normal, reason: 'No data');
    }

    final heartbeat = getAverageHeartbeat();
    final breath = getAverageBreath();
    final report = reports.last;

    return HealthStatus.calculate(
      heartbeat: heartbeat,
      breath: breath,
      systolicBp: report.systolicBp,
      diastolicBp: report.diastolicBp,
      bloodOxygen: report.bloodOxygen,
      temperature: report.temperature,
    );
  }

  RunnerData({required this.deviceId}) : reports = [];

  // Get rolling 5-second average heartbeat (last 5 reports)
  int getAverageHeartbeat() {
    if (reports.isEmpty) return 0;
    
    final recentCount = reports.length >= 5 ? 5 : reports.length;
    final sum = reports.sublist(reports.length - recentCount).fold<int>(
      0,
      (sum, report) => sum + report.heartbeat,
    );
    return (sum / recentCount).round();
  }

  // Get rolling 5-second average breath rate
  int getAverageBreath() {
    if (reports.isEmpty) return 0;
    
    final recentCount = reports.length >= 5 ? 5 : reports.length;
    final sum = reports.sublist(reports.length - recentCount).fold<int>(
      0,
      (sum, report) => sum + report.breath,
    );
    return (sum / recentCount).round();
  }

  void addReport(Report report) {
    // Remove old reports outside the time window
    final cutoffTime = DateTime.now().subtract(
      Duration(seconds: AppConstants.reportWindowSeconds),
    );
    
    reports.removeWhere((r) => r.timestamp.isBefore(cutoffTime));

    // Add new report (maintain sort order)
    reports.add(report);
    
    // Keep only max reports
    if (reports.length > AppConstants.maxReportsPerDevice) {
      reports.removeAt(0);
    }
  }

  List<Report> getReportsInWindow(Duration window) {
    final cutoffTime = DateTime.now().subtract(window);
    return reports.where((r) => r.timestamp.isAfter(cutoffTime)).toList();
  }
}

class RunnerRepository extends ChangeNotifier {
  final Map<int, RunnerData> _runners = {};
  final Map<int, HealthStatus> _previousHealthStatus = {};

  Map<int, RunnerData> get runners => _runners;
  
  List<int> get allRunnerIds => _runners.keys.toList();
  
  List<RunnerData> getAllRunners() => _runners.values.toList();

  List<RunnerData> getRunnersSorted({
    required String sortBy,
    required bool ascending,
  }) {
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
      return list.reversed.toList();
    }

    return list;
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
    final runner = _runners.putIfAbsent(
      report.deviceId,
      () => RunnerData(deviceId: report.deviceId),
    );

    final previousStatus = _previousHealthStatus[report.deviceId];
    runner.addReport(report);
    final newStatus = runner.healthStatus;

    // Track health state changes for notifications (test req #12)
    if (previousStatus == null ||
        previousStatus.state != newStatus.state) {
      _previousHealthStatus[report.deviceId] = newStatus;
    }

    notifyListeners();
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
    notifyListeners();
  }

  int get runnerCount => _runners.length;

  // Statistics
  Map<HealthState, int> getHealthStateDistribution() {
    final distribution = {
      HealthState.normal: 0,
      HealthState.warning: 0,
      HealthState.emergency: 0,
    };

    for (final runner in _runners.values) {
      distribution[runner.healthStatus.state] =
          (distribution[runner.healthStatus.state] ?? 0) + 1;
    }

    return distribution;
  }
}
