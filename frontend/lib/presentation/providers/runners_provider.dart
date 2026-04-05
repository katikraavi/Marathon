import 'package:flutter/material.dart';
import '../../data/repositories/runner_repository.dart';
import '../../data/models/health_state.dart';
import '../../data/models/runner_data.dart';

class RunnersProvider extends ChangeNotifier {
  final RunnerRepository repository;
  String _sortBy = 'distance';
  bool _sortAscending = false;
  HealthState? _filterState;
  bool _isDisposed = false;
  late final VoidCallback _repositoryListener;

  RunnersProvider({required this.repository}) {
    // Listen to repository changes and propagate them
    // Save the listener so we can remove it in dispose
    _repositoryListener = () {
      if (!_isDisposed) {
        notifyListeners();
      }
    };
    repository.addListener(_repositoryListener);
  }

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
  
  // Show loading until we have at least 80% of runners (400/500)
  bool get isLoading => repository.runnerCount < 400;
  double get loadingProgress => repository.runnerCount / 500.0;

  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void setSortAscending(bool ascending) {
    _sortAscending = ascending;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void setFilterState(HealthState? state) {
    _filterState = state;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  RunnerData? getRunner(int deviceId) {
    return repository.getRunner(deviceId);
  }

  @override
  void dispose() {
    _isDisposed = true;
    repository.removeListener(_repositoryListener);
    super.dispose();
  }
}
