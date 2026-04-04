import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../data/repositories/runner_repository.dart';
import '../../presentation/providers/runner_detail_provider.dart';
import '../../data/models/health_state.dart';
import '../../data/models/runner_data.dart';

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

class _RunnerDetailScreenState extends State<RunnerDetailScreen> {
  late RunnerDetailProvider _detailProvider;

  @override
  void initState() {
    super.initState();
    _detailProvider = RunnerDetailProvider(
      repository: widget.repository,
      deviceId: widget.deviceId,
    );
  }

  @override
  void dispose() {
    _detailProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RunnerDetailProvider>.value(
      value: _detailProvider,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Runner #${widget.deviceId}',
            style: const TextStyle(fontSize: 16),
          ),
          centerTitle: true,
          toolbarHeight: 40,
        ),
        body: _DetailBody(
          detailProvider: _detailProvider,
          deviceId: widget.deviceId,
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
            final lastReport = runner.reports.isNotEmpty ? runner.reports.last : null;
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
                          GridView.count(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 0,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 0.55,
                            children: health.vitalDetails.map((detail) {
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

                              return Padding(
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
                                          Icon(getIcon(detail.name), size: 10, color: statusColor),
                                          const SizedBox(width: 1),
                                          Expanded(
                                            child: Text(
                                              detail.name,
                                              style: const TextStyle(
                                                fontSize: 8,
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
                                            'Value',
                                            style: TextStyle(
                                              fontSize: 5,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: detail.value,
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                    color: statusColor,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: ' ${detail.unit}',
                                                  style: TextStyle(
                                                    fontSize: 5,
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
                                            'Normal',
                                            style: TextStyle(
                                              fontSize: 5,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          Text(
                                            detail.normalRange,
                                            style: const TextStyle(
                                              fontSize: 5,
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
                                          horizontal: 2,
                                          vertical: 0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                        child: Text(
                                          detail.status.toString().split('.').last.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 1),
                          if (runner.lastUpdateTime != null)
                            Text(
                              'Updated: ${DateFormat('HH:mm:ss').format(runner.lastUpdateTime!)} • ${health.reason}',
                              style: TextStyle(
                                fontSize: 10,
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
                                    Icon(Icons.check_circle, size: 12, color: Colors.green),
                                    SizedBox(width: 2),
                                    Expanded(
                                      child: Text(
                                        'All vitals within normal ranges',
                                        style: TextStyle(
                                          fontSize: 8,
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
                          'Changes',
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
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
                                dense: true,
                                leading: Icon(
                                  _getEventIcon(event.type),
                                  color: Colors.blue,
                                ),
                                title: Text(event.type),
                                subtitle: Text(event.value),
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

  IconData _getEventIcon(String vitalType) {
    switch (vitalType) {
      case 'BP':
        return Icons.favorite;
      case 'Blood Oxygen':
        return Icons.air;
      case 'Temperature':
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
}


class _VitalTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color? color;

  const _VitalTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: (color ?? Colors.blue).withOpacity(0.08),
        border: Border.all(
          color: (color ?? Colors.blue).withOpacity(0.2),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: color ?? Colors.blue,
          ),
          const SizedBox(width: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color ?? Colors.blue,
                        ),
                      ),
                      TextSpan(
                        text: ' $unit',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalChart extends StatelessWidget {
  final List<ChartDataPoint> data;
  final int normalMin;
  final int normalMax;
  final int warningMin;
  final int warningMax;

  const _VitalChart({
    required this.data,
    required this.normalMin,
    required this.normalMax,
    required this.warningMin,
    required this.warningMax,
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
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(3),
      ),
      padding: const EdgeInsets.all(4),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: data.last.x,
          minY: minY,
          maxY: maxY,
          lineTouchData: LineTouchData(enabled: true),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 5,
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: data.length > 50 ? (data.last.x / 5) : null,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
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
              HorizontalLine(
                y: normalMin.toDouble(),
                color: Colors.green.withOpacity(0.3),
                strokeWidth: 1,
                dashArray: [5, 5],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  labelResolver: (_) => 'Normal Min',
                  style: const TextStyle(fontSize: 9),
                ),
              ),
              HorizontalLine(
                y: normalMax.toDouble(),
                color: Colors.green.withOpacity(0.3),
                strokeWidth: 1,
                dashArray: [5, 5],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.bottomRight,
                  labelResolver: (_) => 'Normal Max',
                  style: const TextStyle(fontSize: 9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
