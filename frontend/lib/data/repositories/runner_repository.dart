import 'package:flutter/foundation.dart';
import '../models/report.dart';
import '../models/health_state.dart';
import '../models/runner_data.dart';

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
