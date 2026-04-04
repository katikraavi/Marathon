import 'dart:collection';
import 'health_state.dart';
import 'report.dart';
import '../../config/constants.dart';

class RunnerData {
  final int deviceId;
  final ListQueue<Report> reports; // Use efficient deque instead of List
  
  // Cache calculated values to avoid recalculation every frame
  late HealthStatus _cachedHealthStatus;
  late int _cachedAverageHeartbeat;
  late int _cachedAverageBreath;
  
  double get distance => reports.isNotEmpty ? reports.last.distanceCovered : 0;
  DateTime? get lastUpdateTime => reports.isNotEmpty ? reports.last.timestamp : null;

  HealthStatus get healthStatus => _cachedHealthStatus;

  RunnerData({required this.deviceId}) : reports = ListQueue() {
    _updateCache();
  }
  
  // Update cached values (call only when reports change)
  void _updateCache() {
    if (reports.isEmpty) {
      _cachedHealthStatus = HealthStatus(
        state: HealthState.normal,
        reason: 'No data',
        vitalDetails: [],
      );
      _cachedAverageHeartbeat = 0;
      _cachedAverageBreath = 0;
      return;
    }
    
    _cachedAverageHeartbeat = _calculateAverageHeartbeat();
    _cachedAverageBreath = _calculateAverageBreath();
    
    final report = reports.last;
    _cachedHealthStatus = HealthStatus.calculate(
      heartbeat: _cachedAverageHeartbeat,
      breath: _cachedAverageBreath,
      systolicBp: report.systolicBp,
      diastolicBp: report.diastolicBp,
      bloodOxygen: report.bloodOxygen,
      temperature: (report.temperature * 10).toInt(),
    );
  }

  // Get rolling 5-second average heartbeat (last 5 reports)
  int _calculateAverageHeartbeat() {
    if (reports.isEmpty) return 0;
    
    final recentCount = reports.length >= 5 ? 5 : reports.length;
    final recentReports = reports.toList().sublist(reports.length - recentCount);
    final sum = recentReports.fold<int>(
      0,
      (sum, report) => sum + report.heartbeat,
    );
    return (sum / recentCount).round();
  }

  // Get rolling 5-second average breath rate
  int _calculateAverageBreath() {
    if (reports.isEmpty) return 0;
    
    final recentCount = reports.length >= 5 ? 5 : reports.length;
    final recentReports = reports.toList().sublist(reports.length - recentCount);
    final sum = recentReports.fold<int>(
      0,
      (sum, report) => sum + report.breath,
    );
    return (sum / recentCount).round();
  }
  
  // Public accessor for cached values (use cached values instead of recalculating)
  int getAverageHeartbeat() => _cachedAverageHeartbeat;
  int getAverageBreath() => _cachedAverageBreath;

  void addReport(Report report) {
    // Add new report to end
    reports.add(report);
    
    // Efficiently remove old reports from front instead of using removeWhere()
    // O(1) removal instead of O(n) scan
    final cutoffTime = DateTime.now().subtract(
      Duration(seconds: AppConstants.reportWindowSeconds),
    );
    
    // Remove expired reports from front
    while (reports.isNotEmpty && reports.first.timestamp.isBefore(cutoffTime)) {
      reports.removeFirst();
    }
    
    // Keep max reports limit
    if (reports.length > AppConstants.maxReportsPerDevice) {
      reports.removeFirst();
    }
    
    // Update cached health status and averages (only computed once per report)
    _updateCache();
  }

  List<Report> getReportsInWindow(Duration window) {
    final cutoffTime = DateTime.now().subtract(window);
    return reports.where((r) => r.timestamp.isAfter(cutoffTime)).toList();
  }
}
