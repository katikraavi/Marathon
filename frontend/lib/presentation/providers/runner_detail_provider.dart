import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../data/repositories/runner_repository.dart';
import '../../data/models/report.dart';
import '../../data/models/runner_data.dart';

class RunnerDetailProvider extends ChangeNotifier {
  final RunnerRepository repository;
  final int deviceId;
  Timer? _refreshTimer;

  RunnerDetailProvider({
    required this.repository,
    required this.deviceId,
  }) {
    // Listen to repository for all updates
    repository.addListener(_onRepositoryChanged);
    
    // Periodic refresh: every 50ms to ensure UI is always current
    // This is critical for real-time updates since reports come in frequently
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      notifyListeners();
    });
  }

  void _onRepositoryChanged() {
    // Immediately notify when repository changes
    notifyListeners();
  }

  @override
  void dispose() {
    repository.removeListener(_onRepositoryChanged);
    _refreshTimer?.cancel();
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

  // Event log - recent vital changes
  List<VitalEvent> get vitalEvents {
    final events = <VitalEvent>[];
    final reports = runner.getReportsInWindow(const Duration(minutes: 10));

    for (int i = 0; i < reports.length; i++) {
      final report = reports[i];
      
      // Check for changes from previous report
      if (i > 0) {
        final prevReport = reports[i - 1];
        
        if (report.systolicBp != prevReport.systolicBp ||
            report.diastolicBp != prevReport.diastolicBp) {
          events.add(VitalEvent(
            type: 'BP',
            value: '${report.systolicBp}/${report.diastolicBp} mmHg',
            timestamp: report.timestamp,
          ));
        }

        if (report.bloodOxygen != prevReport.bloodOxygen) {
          events.add(VitalEvent(
            type: 'Blood Oxygen',
            value: '${report.bloodOxygen}%',
            timestamp: report.timestamp,
          ));
        }

        if (report.temperature != prevReport.temperature) {
          events.add(VitalEvent(
            type: 'Temperature',
            value: '${report.temperature / 10}°C',
            timestamp: report.timestamp,
          ));
        }
      }
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
