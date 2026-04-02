import 'package:flutter/material.dart';
import '../../data/repositories/runner_repository.dart';
import '../../data/models/health_state.dart';
import '../../data/models/runner_data.dart';

class RunnersProvider extends ChangeNotifier {
  final RunnerRepository repository;
  String _sortBy = 'distance';
  bool _sortAscending = false;
  HealthState? _filterState;

  RunnersProvider({required this.repository});

  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  HealthState? get filterState => _filterState;

  List<RunnerData> get filteredAndSortedRunners {
    var runners = repository.getRunnersSorted(
      sortBy: _sortBy,
      ascending: _sortAscending,
    );

    if (_filterState != null) {
      runners = runners
          .where((r) => r.healthStatus.state == _filterState)
          .toList();
    }

    return runners;
  }

  int get totalRunners => repository.runnerCount;
  int get normalCount => repository.getHealthStateDistribution()[HealthState.normal] ?? 0;
  int get warningCount => repository.getHealthStateDistribution()[HealthState.warning] ?? 0;
  int get emergencyCount => repository.getHealthStateDistribution()[HealthState.emergency] ?? 0;

  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  void setSortAscending(bool ascending) {
    _sortAscending = ascending;
    notifyListeners();
  }

  void setFilterState(HealthState? state) {
    _filterState = state;
    notifyListeners();
  }

  RunnerData? getRunner(int deviceId) {
    return repository.getRunner(deviceId);
  }
}
