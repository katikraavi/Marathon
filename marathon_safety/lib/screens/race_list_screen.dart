import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/health_state.dart';
import '../repositories/runner_repository.dart';
import '../providers/runners_provider.dart';
import '../services/websocket_service.dart';
import '../services/notification_service.dart';
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
    _setupServices();
  }

  void _setupServices() {
    _repository = RunnerRepository();
    _webSocketService = WebSocketService();

    // Connect to WebSocket
    _webSocketService.connect();

    // Listen to reports
    _webSocketService.reportStream.listen((report) {
      _repository.addReport(report);

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

    // Listen to connection status
    _webSocketService.connectionStatus.listen((isConnected) {
      setState(() => _isConnected = isConnected);
    });
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    _repository.dispose();
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
        body: Consumer<RunnersProvider>(
          builder: (context, runnersProvider, child) {
            final runners = runnersProvider.filteredAndSortedRunners;

            return Column(
              children: [
                // Control bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats row
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
                ),

                // Runner list
                Expanded(
                  child: runners.isEmpty
                      ? Center(
                    child: Text(
                      'Waiting for runner data...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                      : ListView.builder(
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
                                repository: _repository,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _RunnerListTile extends StatelessWidget {
  final RunnerData runner;
  final VoidCallback onTap;

  const _RunnerListTile({
    required this.runner,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final health = runner.healthStatus;
    final healthColor = _getHealthColor(health.state);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: healthColor.withOpacity(0.2),
          ),
          child: Center(
            child: Icon(
              _getHealthIcon(health.state),
              color: healthColor,
              size: 28,
            ),
          ),
        ),
        title: Text(
          'Device #${runner.deviceId}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distance: ${runner.distance.toStringAsFixed(2)} km'),
            Text(
              health.reason,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: healthColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Chip(
          label: Text(
            health.state.toString().split('.').last.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: healthColor,
        ),
        isThreeLine: true,
      ),
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
