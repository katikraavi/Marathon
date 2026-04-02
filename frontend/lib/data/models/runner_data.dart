import 'health_state.dart';
import 'report.dart';
import '../../config/constants.dart';

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
      temperature: (report.temperature * 10).toInt(),
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
