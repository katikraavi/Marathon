import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../repositories/runner_repository.dart';
import '../providers/runner_detail_provider.dart';
import '../models/health_state.dart';

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
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RunnerDetailProvider(
        repository: widget.repository,
        deviceId: widget.deviceId,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Runner #${widget.deviceId} - Health Details'),
          centerTitle: true,
        ),
        body: Consumer<RunnerDetailProvider>(
          builder: (context, detailProvider, child) {
            final runner = detailProvider.runner;
            final health = runner.healthStatus;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current vitals summary
                  _VitalsSummaryCard(
                    runner: runner,
                    health: health,
                  ),

                  const Divider(),

                  // Charts section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vital Signs (Last 10 Minutes)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),

                        // Heartbeat chart
                        Text(
                          'Heartbeat (BPM)',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        _VitalChart(
                          data: detailProvider.heartbeatChartData,
                          normalMin: 60,
                          normalMax: 150,
                          warningMin: 40,
                          warningMax: 170,
                        ),
                        const SizedBox(height: 24),

                        // Breath rate chart
                        Text(
                          'Breath Rate (Breaths/min)',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
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

                  const Divider(),

                  // Event log
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vital Changes Log',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
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
                                contentPadding: EdgeInsets.zero,
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

                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
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
}

class _VitalsSummaryCard extends StatelessWidget {
  final RunnerData runner;
  final HealthStatus health;

  const _VitalsSummaryCard({
    required this.runner,
    required this.health,
  });

  @override
  Widget build(BuildContext context) {
    final lastReport = runner.reports.isNotEmpty ? runner.reports.last : null;
    final healthColor = _getHealthColor(health.state);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: healthColor, width: 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Device #${runner.deviceId}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: healthColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    health.state.toString().split('.').last.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Current vitals grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _VitalTile(
                  label: 'Heartbeat',
                  value: '${runner.getAverageHeartbeat()}',
                  unit: 'BPM',
                  icon: Icons.favorite,
                ),
                _VitalTile(
                  label: 'Breath Rate',
                  value: '${runner.getAverageBreath()}',
                  unit: '/min',
                  icon: Icons.air,
                ),
                if (lastReport != null) ...[
                  _VitalTile(
                    label: 'Distance',
                    value: '${runner.distance.toStringAsFixed(2)}',
                    unit: 'km',
                    icon: Icons.location_on,
                  ),
                  _VitalTile(
                    label: 'Blood Oxygen',
                    value: '${lastReport.bloodOxygen}',
                    unit: '%',
                    icon: Icons.air,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Timestamp and status
            if (runner.lastUpdateTime != null)
              Text(
                'Last update: ${DateFormat('HH:mm:ss').format(runner.lastUpdateTime!)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),

            const SizedBox(height: 8),
            Text(
              'Status: ${health.reason}',
              style: TextStyle(
                color: healthColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
}

class _VitalTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;

  const _VitalTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: Colors.blue),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                TextSpan(
                  text: ' $unit',
                  style: Theme.of(context).textTheme.labelSmall,
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
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('Waiting for data...'),
        ),
      );
    }

    final maxY = (data.map((d) => d.y).reduce((a, b) => a > b ? a : b) * 1.1) as double;
    final minY = ((data.map((d) => d.y).reduce((a, b) => a < b ? a : b) * 0.9).clamp(0, double.infinity)) as double;

    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
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
