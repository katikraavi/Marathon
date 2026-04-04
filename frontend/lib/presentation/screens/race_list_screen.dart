import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/health_state.dart';
import '../../data/repositories/runner_repository.dart';
import '../../data/models/runner_data.dart';
import '../../presentation/providers/runners_provider.dart';
import '../../data/sources/websocket_source.dart';
import '../../services/notification_service.dart';
import 'runner_detail_screen.dart';

class RaceListScreen extends StatefulWidget {
  const RaceListScreen({Key? key}) : super(key: key);

  @override
  State<RaceListScreen> createState() => _RaceListScreenState();
}

class _RaceListScreenState extends State<RaceListScreen> {
  late WebSocketService _webSocketService;
  late RunnerRepository _repository;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    try {
      // Get the global services that were already initialized and started loading
      _repository = context.read<RunnerRepository>();
      _webSocketService = context.read<WebSocketService>();
    } catch (e) {
      print('[ERROR] Failed to read global services: $e');
      // Fallback: create new services if global ones aren't available
      _repository = RunnerRepository();
      _webSocketService = WebSocketService();
      
      // Connect WebSocket if we created new service
      _webSocketService.connect();
    }

    // Setup listeners after services are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupListeners();
    });
  }

  void _setupListeners() {
    try {
      // Update connection status from WebSocket
      _webSocketService.connectionStatus.listen((isConnected) {
        if (mounted) {
          setState(() => _isConnected = isConnected);
        }
      });

      // Listen to reports and handle notifications
      _webSocketService.reportStream.listen((report) {
        // Check for health state changes and show notifications
        if (_repository.hasHealthStateChanged(report.deviceId)) {
          final runner = _repository.getRunner(report.deviceId);
          if (runner != null) {
            final healthStatus = runner.healthStatus;
            final notificationService = NotificationService();

            if (healthStatus.state == HealthState.emergency) {
              notificationService.showEmergencyAlert(
                runnerId: report.deviceId,
                reason: 'Emergency: Runner ${report.deviceId} is ill. ${healthStatus.reason}',
              );
            } else if (healthStatus.state == HealthState.warning) {
              notificationService.showWarningAlert(
                runnerId: report.deviceId,
                reason: 'Warning: Runner ${report.deviceId} is at risk. ${healthStatus.reason}',
              );
            }
          }
        }
      });
    } catch (e) {
      print('[ERROR] Failed to setup listeners: $e');
    }
  }

  @override
  void dispose() {
    // Don't dispose global services - they should keep running
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RunnersProvider(repository: _repository),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Marathon Safety Monitoring'),
          centerTitle: true,
          elevation: 2,
          actions: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Row(
                  children: [
                    if (!_isConnected)
                      Tooltip(
                        message: 'Connecting to data stream...',
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orange.shade400,
                          ),
                        ),
                      )
                    else
                      Tooltip(
                        message: 'Connected',
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // OPTIMIZATION: Separate Consumer for control bar (stats + filters)
            // This rebuilds independently from runner list
            _ControlBar(),
            
            // OPTIMIZATION: Separate Consumer for runner list
            // Only this widget rebuilds when runner data changes
            _RunnerListSection(repository: _repository),
          ],
        ),
      ),
    );
  }
}

/// OPTIMIZATION: Extracted control bar with stats and filters
/// Rebuilds only when provider state changes, separate from list
class _ControlBar extends StatelessWidget {
  const _ControlBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<RunnersProvider>(
      builder: (context, runnersProvider, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats row - only rebuilds when health stats change
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatCard(
                    label: 'Total Runners',
                    value: runnersProvider.totalRunners.toString(),
                    color: Colors.blue,
                  ),
                  _StatCard(
                    label: 'Normal',
                    value: runnersProvider.normalCount.toString(),
                    color: Colors.green,
                  ),
                  _StatCard(
                    label: 'Warning',
                    value: runnersProvider.warningCount.toString(),
                    color: Colors.orange,
                  ),
                  _StatCard(
                    label: 'Emergency',
                    value: runnersProvider.emergencyCount.toString(),
                    color: Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Sorting controls
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      value: runnersProvider.sortBy,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'distance',
                          child: Text('Sort by Distance'),
                        ),
                        DropdownMenuItem(
                          value: 'device_id',
                          child: Text('Sort by Device ID'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          runnersProvider.setSortBy(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      runnersProvider.sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                    ),
                    onPressed: () {
                      runnersProvider
                          .setSortAscending(!runnersProvider.sortAscending);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Health state filters
              Text(
                'Filter by Health:',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: runnersProvider.filterState == null,
                    onSelected: (_) =>
                        runnersProvider.setFilterState(null),
                  ),
                  FilterChip(
                    label: const Text('Normal'),
                    selected:
                        runnersProvider.filterState == HealthState.normal,
                    onSelected: (_) => runnersProvider
                        .setFilterState(HealthState.normal),
                  ),
                  FilterChip(
                    label: const Text('Warning'),
                    selected:
                        runnersProvider.filterState == HealthState.warning,
                    onSelected: (_) => runnersProvider
                        .setFilterState(HealthState.warning),
                  ),
                  FilterChip(
                    label: const Text('Emergency'),
                    selected: runnersProvider.filterState ==
                        HealthState.emergency,
                    onSelected: (_) => runnersProvider
                        .setFilterState(HealthState.emergency),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// OPTIMIZATION: Extracted runner list section
/// Rebuilds only when runner data changes, independent from control bar
class _RunnerListSection extends StatelessWidget {
  final RunnerRepository repository;

  const _RunnerListSection({
    Key? key,
    required this.repository,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Consumer<RunnersProvider>(
        builder: (context, runnersProvider, child) {
          final runners = runnersProvider.filteredAndSortedRunners;
          final totalRunners = runnersProvider.totalRunners;
          final isLoading = runnersProvider.isLoading;
          final loadingProgress = runnersProvider.loadingProgress;

          // Show loading state with progress
          if (runners.isEmpty && totalRunners == 0) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading runner data... (0/500)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          // Show partial data loading with progress
          if (runners.isEmpty && totalRunners > 0) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading runner data... ($totalRunners/500)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Filtering: ${runnersProvider.filterState ?? 'All'} runners',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            );
          }

          // Display runners with loading overlay if still loading
          return Stack(
            children: [
              // Runners list
              ListView.builder(
                itemCount: runners.length,
                itemBuilder: (context, index) {
                  final runner = runners[index];
                  return _RunnerListTile(
                    runner: runner,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RunnerDetailScreen(
                            deviceId: runner.deviceId,
                            repository: repository,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              
              // Loading overlay while fetching data
              if (isLoading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                'Loading Runners',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$totalRunners / 500',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: loadingProgress,
                                  minHeight: 8,
                                  backgroundColor: Colors.grey.shade300,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.blue.shade400,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${(loadingProgress * 100).toStringAsFixed(0)}%',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RunnerListTile extends StatelessWidget {
  final RunnerData runner;
  final VoidCallback onTap;

  const _RunnerListTile({
    Key? key,
    required this.runner,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('Device ${runner.deviceId}'),
      subtitle: Text(
        'Distance: ${runner.distance.toStringAsFixed(2)}m',
      ),
      trailing: Icon(
        _getHealthIcon(runner.healthStatus.state),
        color: _getHealthColor(runner.healthStatus.state),
      ),
      onTap: onTap,
    );
  }

  Color _getHealthColor(HealthState state) {
    switch (state) {
      case HealthState.normal:
        return Colors.green;
      case HealthState.warning:
        return Colors.orange;
      case HealthState.emergency:
        return Colors.red;
    }
  }

  IconData _getHealthIcon(HealthState state) {
    switch (state) {
      case HealthState.normal:
        return Icons.favorite;
      case HealthState.warning:
        return Icons.warning;
      case HealthState.emergency:
        return Icons.emergency;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    Key? key,
    required this.label,
    required this.value,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
