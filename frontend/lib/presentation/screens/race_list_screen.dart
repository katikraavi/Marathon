import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../data/models/health_state.dart';
import '../../data/repositories/runner_repository.dart';
import '../../data/models/runner_data.dart';
import '../../presentation/providers/runners_provider.dart';
import '../../presentation/providers/runner_detail_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../data/sources/websocket_source.dart';
import '../../services/notification_service.dart';
import '../../presentation/widgets/global_status_bar.dart';
import '../../presentation/widgets/connection_status_banner.dart';
import '../../main.dart' show scaffoldMessengerKey;
import 'runner_detail_screen.dart';
import 'marathon_map_screen.dart';

class RaceListScreen extends StatefulWidget {
  const RaceListScreen({Key? key}) : super(key: key);

  @override
  State<RaceListScreen> createState() => _RaceListScreenState();
}

class _RaceListScreenState extends State<RaceListScreen> with WidgetsBindingObserver {
  late WebSocketService _webSocketService;
  late RunnerRepository _repository;
  bool _isConnected = false;
  DateTime _lastDataUpdate = DateTime.now();
  Timer? _dataUpdateCheckTimer;
  
  // Track previous health states locally to detect changes
  final Map<int, HealthState> _previousStates = {};

  @override
  void initState() {
    super.initState();
    // Listen to app lifecycle changes for visibility-based updates
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  void _initializeServices() {
    try {
      // Get the global services that were already initialized and started loading
      _repository = context.read<RunnerRepository>();
      _webSocketService = context.read<WebSocketService>();
    } catch (e) {
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

  void _showAlert(int deviceId, String reason, HealthState state) {
    try {
      final isEmergency = state == HealthState.emergency;
      final scaffoldMessenger = scaffoldMessengerKey.currentState;
      
      if (scaffoldMessenger != null) {
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              '${isEmergency ? '🚨 EMERGENCY' : '⚠️ WARNING'}: Runner #$deviceId - $reason',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            backgroundColor: isEmergency ? Colors.red : Colors.orange,
            duration: Duration(seconds: isEmergency ? 6 : 5),
            dismissDirection: DismissDirection.horizontal,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        // Silently skip if MessengerState not available
      }
    } catch (e) {
      // Silently handle any errors showing alerts
    }
  }

  void _setupListeners() {
    try {
      // Listen to actual data updates (more reliable than connection status)
      _webSocketService.reportStream.listen((report) {
        _lastDataUpdate = DateTime.now();
        if (!_isConnected) {
          // Data received, so we must be connected
          if (mounted) {
            setState(() => _isConnected = true);
          }
        }

        // Check for health state changes by comparing with our local tracking
        final runner = _repository.getRunner(report.deviceId);
        
        if (runner != null) {
          final currentState = runner.healthStatus.state;
          final previousState = _previousStates[report.deviceId];
          final hasChanged = previousState != null && previousState != currentState;
          
          // First time seeing this device or state changed
          if (previousState == null) {
            _previousStates[report.deviceId] = currentState;
          } else if (hasChanged) {
            
            final healthStatus = runner.healthStatus;
            final notificationService = NotificationService();

            try {
              if (currentState == HealthState.emergency) {
                notificationService.showEmergencyAlert(
                  runnerId: report.deviceId,
                  reason: 'Emergency: Runner ${report.deviceId} is ill. ${healthStatus.reason}',
                );
                // Show in-app alert for web and visibility
                _showAlert(report.deviceId, healthStatus.reason, HealthState.emergency);
              } else if (currentState == HealthState.warning) {
                notificationService.showWarningAlert(
                  runnerId: report.deviceId,
                  reason: 'Warning: Runner ${report.deviceId} is at risk. ${healthStatus.reason}',
                );
                // Show in-app alert for web and visibility
                _showAlert(report.deviceId, healthStatus.reason, HealthState.warning);
              }
            } catch (e) {
              // Still show in-app alert even if notification service fails
              _showAlert(report.deviceId, healthStatus.reason, currentState);
            }
            
            // Update tracked state after processing
            _previousStates[report.deviceId] = currentState;
          }
        }
      });

      // Also listen to connection status as backup
      _webSocketService.connectionStatus.listen((isConnected) {
        if (mounted) {
          setState(() => _isConnected = isConnected);
        }
      });

      // Check for data staleness every 5 seconds
      _dataUpdateCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        
        final timeSinceUpdate = DateTime.now().difference(_lastDataUpdate);
        // Consider offline if no data for 20 seconds AND WebSocket says disconnected
        final shouldBeOffline = timeSinceUpdate > const Duration(seconds: 20) && !_webSocketService.isConnected;
        
        if (shouldBeOffline != _isConnected) {
          setState(() => _isConnected = !shouldBeOffline);
        }
      });
    } catch (e) {
      // Silently handle listener setup errors
    }
  }

  @override
  void dispose() {
    // Cancel data update check timer
    _dataUpdateCheckTimer?.cancel();
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    // Don't dispose global services - they should keep running
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause expensive operations when app goes to background
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      print('[LIFECYCLE] ⏸️ Race list: App backgrounded - reducing update frequency');
      // Repository will reduce update frequency when not visible
    }
    // Resume normal operations when app returns to foreground
    else if (state == AppLifecycleState.resumed) {
      print('[LIFECYCLE] ▶️ Race list: App resumed - resuming full update frequency');
      setState(() {}); // Refresh list when app comes back to foreground
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RunnersProvider(repository: _repository),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Marathon Safety Monitoring'),
            centerTitle: true,
            elevation: 2,
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.list), text: 'Runners List'),
                Tab(icon: Icon(Icons.map), text: 'Course Map'),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: () {
                  context.read<AuthProvider>().logout();
                },
              ),
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
              // Connection Status Banner
              ConnectionStatusBanner(
                isConnected: _isConnected,
                onReconnected: () {
                  try {
                    final scaffoldMessenger = scaffoldMessengerKey.currentState;
                    if (scaffoldMessenger != null) {
                      scaffoldMessenger.clearSnackBars();
                    }
                  } catch (e) {
                    // Silent error
                  }
                },
              ),
              
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: Runners List
                    Column(
                      children: [
                        // Global Status Bar - shows update status for all runners
                        Consumer<RunnersProvider>(
                          builder: (context, provider, _) {
                            return GlobalStatusBar(
                              activeRunnerId: null, // null when viewing list
                              totalRunners: provider.totalRunners,
                            );
                          },
                        ),
                        
                        // OPTIMIZATION: Separate Consumer for control bar (stats + filters)
                        // This rebuilds independently from runner list
                        _ControlBar(),
                        
                        // OPTIMIZATION: Separate Consumer for runner list
                        // Only this widget rebuilds when runner data changes
                        _RunnerListSection(repository: _repository),
                      ],
                    ),
                    
                    // Tab 2: Marathon Map
                    const MarathonMapScreen(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// OPTIMIZATION: Extracted control bar with stats and filters
/// Rebuilds only when provider state changes, separate from list
class _ControlBar extends StatefulWidget {
  const _ControlBar({Key? key}) : super(key: key);

  @override
  State<_ControlBar> createState() => _ControlBarState();
}

class _ControlBarState extends State<_ControlBar> {
  bool _showFilters = true;

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatCard(
                    label: 'Total Runners',
                    value: runnersProvider.totalRunners.toString(),
                    color: Colors.blue,
                    onTap: () {
                      setState(() => _showFilters = !_showFilters);
                      runnersProvider.setFilterState(null);
                    },
                  ),
                  _StatCard(
                    label: 'Normal',
                    value: runnersProvider.normalCount.toString(),
                    color: Colors.green,
                    onTap: () {
                      setState(() => _showFilters = false);
                      runnersProvider.setFilterState(HealthState.normal);
                    },
                  ),
                  _StatCard(
                    label: 'Warning',
                    value: runnersProvider.warningCount.toString(),
                    color: Colors.orange,
                    onTap: () {
                      setState(() => _showFilters = false);
                      runnersProvider.setFilterState(HealthState.warning);
                    },
                  ),
                  _StatCard(
                    label: 'Emergency',
                    value: runnersProvider.emergencyCount.toString(),
                    color: Colors.red,
                    onTap: () {
                      setState(() => _showFilters = false);
                      runnersProvider.setFilterState(HealthState.emergency);
                    },
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

              // Show filters only if _showFilters is true
              if (_showFilters) ...[
                const SizedBox(height: 12),
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
                      onSelected: (_) {
                        setState(() => _showFilters = true);
                        runnersProvider.setFilterState(null);
                      },
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
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Waiting for connection...',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
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
    return ValueListenableBuilder<int>(
      valueListenable: RunnerDetailProvider.activeRunnersNotifier,
      builder: (context, _, __) {
        // Rebuild when active runners change
        final isActive = RunnerDetailProvider.isRunnerActive(runner.deviceId);
        final statusText = isActive ? '🟢 UPDATING' : '⏸️ PAUSED';
        final statusColor = isActive ? Colors.green : Colors.grey;
        
        // Get warning indicators
        final warningIndicators = _getWarningIndicators(runner.healthStatus.vitalDetails);
        
        return ListTile(
          title: Row(
            children: [
              Expanded(
                child: Text('Device ${runner.deviceId}'),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  border: Border.all(color: statusColor, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Distance: ${runner.distance.toStringAsFixed(2)}m',
              ),
              const SizedBox(height: 6),
              // Show warning indicators if any
              if (warningIndicators.isNotEmpty)
                Row(
                  children: [
                    Text(
                      'Alerts: ',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        children: warningIndicators,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'All vitals normal',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.green[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          trailing: Icon(
            _getHealthIcon(runner.healthStatus.state),
            color: _getHealthColor(runner.healthStatus.state),
            size: 28,
          ),
          onTap: onTap,
        );
      },
    );
  }

  /// Get visual indicators for each vital that's in warning/emergency state
  List<Widget> _getWarningIndicators(List<VitalDetail> vitals) {
    final indicators = <Widget>[];
    
    for (final vital in vitals) {
      if (vital.status == HealthState.emergency) {
        indicators.add(_buildVitalIndicator(vital.name, Colors.red, true));
      } else if (vital.status == HealthState.warning) {
        indicators.add(_buildVitalIndicator(vital.name, Colors.orange, false));
      }
    }
    
    return indicators;
  }

  /// Build a small badge showing which vital is problematic
  Widget _buildVitalIndicator(String vitalName, Color color, bool isEmergency) {
    final icon = _getVitalIcon(vitalName);
    
    return Tooltip(
      message: vitalName,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 2),
            Text(
              isEmergency ? '!' : '⚠',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get Material icon for each vital
  IconData _getVitalIcon(String vitalName) {
    switch (vitalName.toLowerCase()) {
      case 'heartbeat':
        return Icons.favorite;
      case 'breath rate':
        return Icons.air;
      case 'systolic bp':
        return Icons.trending_up;
      case 'diastolic bp':
        return Icons.trending_down;
      case 'blood oxygen':
        return Icons.opacity;
      case 'temperature':
        return Icons.thermostat;
      default:
        return Icons.info;
    }
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
  final VoidCallback? onTap;

  const _StatCard({
    Key? key,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final card = Container(
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
    );

    return Expanded(
      child: onTap != null
          ? GestureDetector(onTap: onTap, child: card)
          : card,
    );
  }
}
