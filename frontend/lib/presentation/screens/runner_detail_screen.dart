import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../data/repositories/runner_repository.dart';
import '../../presentation/providers/runner_detail_provider.dart';
import '../../data/models/health_state.dart';
import '../../data/sources/websocket_source.dart';
import '../../presentation/widgets/global_status_bar.dart';

class RunnerDetailScreen extends StatefulWidget {
  final int deviceId;
  final RunnerRepository repository;

  const RunnerDetailScreen({
    Key? key,
    required this.deviceId,
    required this.repository,
  }) : super(key: key);

  @override
  State<RunnerDetailScreen> createState() => _RunnerDetailScreenState();
}

class _RunnerDetailScreenState extends State<RunnerDetailScreen> with WidgetsBindingObserver {
  late RunnerDetailProvider _detailProvider;

  @override
  void initState() {
    super.initState();
    _detailProvider = RunnerDetailProvider(
      repository: widget.repository,
      deviceId: widget.deviceId,
      webSocketService: context.read<WebSocketService>(),
    );
    // Start updates when screen is created
    _detailProvider.resumeUpdates();
    // Listen to app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Pause updates when screen is destroyed
    _detailProvider.pauseUpdates();
    _detailProvider.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause updates when app goes to background
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _detailProvider.pauseUpdates();
    }
    // Resume updates when app returns to foreground
    else if (state == AppLifecycleState.resumed) {
      _detailProvider.resumeUpdates();
    }
    _lastLifecycleState = state;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RunnerDetailProvider>.value(
      value: _detailProvider,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Runner #${widget.deviceId}',
                style: const TextStyle(fontSize: 16),
              ),
              Consumer<RunnerDetailProvider>(
                builder: (context, provider, _) {
                  final status = provider.isPaused ? '⏸️ PAUSED' : '🟢 UPDATING';
                  final color = provider.isPaused ? Colors.grey : Colors.green;
                  return Text(
                    '$status · Updates: ${provider.updateCount}',
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ],
          ),
          centerTitle: true,
          toolbarHeight: 50,
        ),
        body: Column(
          children: [
            // Global Status Bar - shows which runner is updating
            GlobalStatusBar(
              activeRunnerId: widget.deviceId,
              totalRunners: context.read<RunnerRepository>().runnerCount,
            ),
            // Detail content
            Expanded(
              child: _DetailBody(
                detailProvider: _detailProvider,
                deviceId: widget.deviceId,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatefulWidget {
  final RunnerDetailProvider detailProvider;
  final int deviceId;

  const _DetailBody({
    required this.detailProvider,
    required this.deviceId,
  });

  @override
  State<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends State<_DetailBody> {
  late Stream<void> _refreshStream;

  @override
  void initState() {
    super.initState();
    // Create a stream that emits every 50ms to force rebuilds
    _refreshStream = Stream.periodic(const Duration(milliseconds: 50), (_) => null);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: _refreshStream,
      builder: (context, snapshot) {
        return Consumer<RunnerDetailProvider>(
          builder: (context, detailProvider, child) {
            final runner = detailProvider.runner;
            final health = runner.healthStatus;
            final healthColor = _getHealthColor(health.state);

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: healthColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(2),
                        border: Border(
                          left: BorderSide(color: healthColor, width: 3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Device #${runner.deviceId}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: healthColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  health.state.toString().split('.').last.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: health.vitalDetails.map((detail) {
                              final cellWidth = (MediaQuery.of(context).size.width - 42) / 6;
                              final statusColor = detail.status == HealthState.normal
                                  ? Colors.green
                                  : detail.status == HealthState.warning
                                      ? Colors.orange
                                      : Colors.red;

                              IconData getIcon(String name) {
                                switch (name) {
                                  case 'Heartbeat':
                                    return Icons.favorite;
                                  case 'Breath Rate':
                                    return Icons.air;
                                  case 'Systolic BP':
                                    return Icons.favorite_border;
                                  case 'Diastolic BP':
                                    return Icons.favorite_border;
                                  case 'Blood Oxygen':
                                    return Icons.air;
                                  case 'Temperature':
                                    return Icons.thermostat;
                                  default:
                                    return Icons.info;
                                }
                              }

                              return SizedBox(
                                width: cellWidth,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: Container(
                                    padding: const EdgeInsets.only(left: 2, right: 2, top: 1, bottom: 1),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        left: BorderSide(color: statusColor, width: 2),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                      // Icon and name
                                      Row(
                                        children: [
                                          Icon(getIcon(detail.name), size: 18, color: statusColor),
                                          const SizedBox(width: 1),
                                          Expanded(
                                            child: Text(
                                              detail.name,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Current value
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Current',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: detail.value,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: statusColor,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: ' ${detail.unit}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                      // Normal range
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            detail.normalRange,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                      // Status badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          detail.status.toString().split('.').last.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],                                    ),                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 24),
                          if (runner.lastUpdateTime != null)
                            Text(
                              'Updated: ${DateFormat('HH:mm:ss').format(runner.lastUpdateTime!)} • ${health.reason}',
                              style: TextStyle(
                                fontSize: 12,
                                color: healthColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (health.state == HealthState.normal)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(2),
                                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_circle, size: 14, color: Colors.green),
                                    SizedBox(width: 2),
                                    Expanded(
                                      child: Text(
                                        'All vitals within normal ranges',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vital Signs Charts',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Heartbeat',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _VitalChart(
                          data: detailProvider.heartbeatChartData,
                          normalMin: 60,
                          normalMax: 150,
                          warningMin: 40,
                          warningMax: 170,
                          unit: 'BPM',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Breath Rate',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _VitalChart(
                          data: detailProvider.breathChartData,
                          normalMin: 45,
                          normalMax: 60,
                          warningMin: 25,
                          warningMax: 85,
                          unit: 'Breaths/min',
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Changes (${detailProvider.vitalEvents.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (detailProvider.vitalEvents.isEmpty)
                          Text(
                            'No changes recorded',
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: detailProvider.vitalEvents.length,
                            itemBuilder: (context, index) {
                              final event = detailProvider.vitalEvents[index];
                              final statusColor = _getStatusColor(event.type);
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
                                dense: true,
                                leading: Icon(
                                  _getStatusIcon(event.type),
                                  color: statusColor,
                                  size: 20,
                                ),
                                title: Text(
                                  event.type,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                                subtitle: Text(
                                  event.value,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                trailing: Text(
                                  event.formattedTime,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
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

  Color _getStatusColor(String eventType) {
    if (eventType.contains('EMERGENCY')) {
      return Colors.red;
    } else if (eventType.contains('WARNING')) {
      return Colors.orange;
    } else if (eventType.contains('NORMAL')) {
      return Colors.green;
    }
    return Colors.blue;
  }

  IconData _getStatusIcon(String eventType) {
    if (eventType.contains('EMERGENCY')) {
      return Icons.warning_amber_rounded;
    } else if (eventType.contains('WARNING')) {
      return Icons.info_rounded;
    } else if (eventType.contains('NORMAL')) {
      return Icons.check_circle_rounded;
    }
    return Icons.info;
  }
}



class _VitalChart extends StatelessWidget {
  final List<ChartDataPoint> data;
  final int normalMin;
  final int normalMax;
  final int warningMin;
  final int warningMax;
  final String unit;

  const _VitalChart({
    required this.data,
    required this.normalMin,
    required this.normalMax,
    required this.warningMin,
    required this.warningMax,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Center(
          child: Text('Waiting for data...'),
        ),
      );
    }

    final maxY = (data.map((d) => d.y).reduce((a, b) => a > b ? a : b) * 1.1) as double;
    final minY = ((data.map((d) => d.y).reduce((a, b) => a < b ? a : b) * 0.9).clamp(0, double.infinity)) as double;

    return Container(
      height: 220,
      margin: const EdgeInsets.only(right: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(3),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 600, // 10 minutes in seconds
          minY: minY,
          maxY: maxY,
          lineTouchData: LineTouchData(enabled: true),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            verticalInterval: 120, // Vertical lines every 2 minutes
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              );
            },
            horizontalInterval: (maxY - minY) / 5,
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              axisNameWidget: const Text(
                'Time (min)',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
              ),
              axisNameSize: 18,
              sideTitles: SideTitles(
                showTitles: true,
                interval: 120, // Show tick every 2 minutes
                getTitlesWidget: (value, meta) {
                  final minutes = (value / 60).toInt();
                  return Text(
                    '$minutes min',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: Text(
                unit,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              axisNameSize: 18,
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: data.map((d) => FlSpot(d.x, d.y)).toList(),
              isCurved: true,
              color: Colors.blue,
              barWidth: 2,
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.1),
              ),
              dotData: const FlDotData(show: false),
            ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              // Normal range - Green (solid line)
              HorizontalLine(
                y: normalMin.toDouble(),
                color: Colors.green.withOpacity(0.8),
                strokeWidth: 3,
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  labelResolver: (_) => 'Normal',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green),
                ),
              ),
              HorizontalLine(
                y: normalMax.toDouble(),
                color: Colors.green.withOpacity(0.8),
                strokeWidth: 3,
                label: HorizontalLineLabel(
                  show: false,
                ),
              ),
              // Warning range - Orange (solid line)
              HorizontalLine(
                y: warningMin.toDouble(),
                color: Colors.orange.withOpacity(0.8),
                strokeWidth: 3,
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  labelResolver: (_) => 'Warning',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange),
                ),
              ),
              HorizontalLine(
                y: warningMax.toDouble(),
                color: Colors.orange.withOpacity(0.8),
                strokeWidth: 3,
                label: HorizontalLineLabel(
                  show: false,
                ),
              ),
              // Emergency - Red (solid line at warning boundaries)
              HorizontalLine(
                y: warningMin.toDouble(),
                color: Colors.red.withOpacity(0.6),
                strokeWidth: 2,
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.bottomRight,
                  labelResolver: (_) => 'Emergency',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.red),
                ),
              ),
              HorizontalLine(
                y: warningMax.toDouble(),
                color: Colors.red.withOpacity(0.6),
                strokeWidth: 2,
                label: HorizontalLineLabel(
                  show: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
