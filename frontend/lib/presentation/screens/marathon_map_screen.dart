import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/health_state.dart';
import '../../data/models/runner_data.dart';
import '../../data/repositories/runner_repository.dart';
import '../../presentation/providers/runners_provider.dart';
import 'runner_detail_screen.dart';

class MarathonMapScreen extends StatefulWidget {
  const MarathonMapScreen({Key? key}) : super(key: key);

  @override
  State<MarathonMapScreen> createState() => _MarathonMapScreenState();
}

class _MarathonMapScreenState extends State<MarathonMapScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  int? _selectedRunnerId;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getHealthColor(HealthState healthState) {
    switch (healthState) {
      case HealthState.normal:
        return Colors.green;
      case HealthState.warning:
        return Colors.orange;
      case HealthState.emergency:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<RunnerRepository>();
    
    return Consumer<RunnersProvider>(
      builder: (context, runnersProvider, child) {
        // Get all runners (not filtered)
        final runners = repository.getRunnersSorted(sortBy: 'distance', ascending: false);
        final normalCount = runners.where((r) => r.healthStatus.state == HealthState.normal).length;
        final warningCount = runners.where((r) => r.healthStatus.state == HealthState.warning).length;
        final emergencyCount = runners.where((r) => r.healthStatus.state == HealthState.emergency).length;

        return Column(
          children: [
            // Stats Bar
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard('Total', runners.length.toString(), Colors.blue),
                  _buildStatCard('Normal', normalCount.toString(), Colors.green),
                  _buildStatCard('Warning', warningCount.toString(), Colors.orange),
                  _buildStatCard('Emergency', emergencyCount.toString(), Colors.red),
                ],
              ),
            ),
            // Marathon Course Map
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Marathon Course Map',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!, width: 2),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[50],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: CustomPaint(
                          size: const Size(350, 150),
                          painter: MarathonCourseMapPainter(
                            runners: runners,
                            getHealthColor: _getHealthColor,
                            selectedRunnerId: _selectedRunnerId,
                            animationValue: _animationController.value,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Legend
                    _buildLegend(),
                    const SizedBox(height: 24),
                    // Runners by Health Status
                    _buildHealthStatusSections(context, runners, repository),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
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
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Legend',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem('Normal', Colors.green),
              _buildLegendItem('Warning', Colors.orange),
              _buildLegendItem('Emergency', Colors.red),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• Each dot = 1 runner  • Size = distance progress  • Pulsing = real-time updates',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildHealthStatusSections(BuildContext context, List<RunnerData> runners, RunnerRepository repository) {
    return Column(
      children: [
        _buildHealthStatusSection(
          context,
          'Emergency Runners',
          runners.where((r) => r.healthStatus.state == HealthState.emergency).toList(),
          Colors.red,
          repository,
        ),
        const SizedBox(height: 16),
        _buildHealthStatusSection(
          context,
          'Warning Runners',
          runners.where((r) => r.healthStatus.state == HealthState.warning).toList(),
          Colors.orange,
          repository,
        ),
        const SizedBox(height: 16),
        _buildHealthStatusSection(
          context,
          'Normal Runners',
          runners.where((r) => r.healthStatus.state == HealthState.normal).toList(),
          Colors.green,
          repository,
        ),
      ],
    );
  }

  Widget _buildHealthStatusSection(
    BuildContext context,
    String title,
    List<RunnerData> runnersInStatus,
    Color color,
    RunnerRepository repository,
  ) {
    if (runnersInStatus.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$title (0)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        title: Text(
          '$title (${runnersInStatus.length})',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: runnersInStatus.length,
              itemBuilder: (context, index) {
                final runner = runnersInStatus[index];
                return GestureDetector(
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
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: color,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Runner #${runner.deviceId}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${runner.distance.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MarathonCourseMapPainter extends CustomPainter {
  final List<RunnerData> runners;
  final Color Function(HealthState) getHealthColor;
  final int? selectedRunnerId;
  final double animationValue;

  MarathonCourseMapPainter({
    required this.runners,
    required this.getHealthColor,
    required this.selectedRunnerId,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const marathonDistance = 42.0;
    const padding = 40.0;
    final courseY = size.height / 2;
    
    // Draw course background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(8),
      ),
      Paint()..color = Colors.white,
    );

    // Draw main course line (horizontal)
    final courseStartX = padding;
    final courseEndX = size.width - padding;
    
    canvas.drawLine(
      Offset(courseStartX, courseY),
      Offset(courseEndX, courseY),
      Paint()
        ..color = Colors.grey[400]!
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke,
    );

    // Draw start and finish markers
    canvas.drawCircle(Offset(courseStartX, courseY), 8, Paint()..color = Colors.green);
    canvas.drawCircle(Offset(courseEndX, courseY), 8, Paint()..color = Colors.red);
    
    // Draw distance labels
    _drawDistanceLabels(canvas, size, courseStartX, courseEndX, courseY, marathonDistance);

    // Draw runners
    _drawRunners(canvas, size, courseStartX, courseEndX, courseY, marathonDistance);
  }

  void _drawDistanceLabels(Canvas canvas, Size size, double startX, double endX, double courseY, double marathonDistance) {
    final labels = ['0km', '10km', '20km', '30km', '42km'];
    final positions = [0.0, 10.0, 20.0, 30.0, 42.0];
    
    for (int i = 0; i < labels.length; i++) {
      final x = startX + (endX - startX) * (positions[i] / marathonDistance);
      
      // Draw marker line
      canvas.drawLine(
        Offset(x, courseY - 12),
        Offset(x, courseY + 12),
        Paint()
          ..color = Colors.blue[300]!
          ..strokeWidth = 2,
      );
      
      // Draw label
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, courseY - 25),
      );
    }
  }

  void _drawRunners(Canvas canvas, Size size, double startX, double endX, double courseY, double marathonDistance) {
    const padding = 40.0;
    
    for (final runner in runners) {
      // Calculate position on the course
      final progress = (runner.distance / marathonDistance).clamp(0.0, 1.0);
      final x = startX + (endX - startX) * progress;
      
      // Vary y position for each runner to avoid overlapping (vertical offset)
      final hash = runner.deviceId.hashCode;
      final yOffset = ((hash % 4) - 1.5) * 18; // Spread runners vertically around the line
      final y = courseY + yOffset;
      
      // Get runner color
      final color = getHealthColor(runner.healthStatus.state);
      
      // Draw runner dot with pulse effect for emergencies
      if (runner.healthStatus.state == HealthState.emergency) {
        // Draw pulsing outer ring
        final pulseSize = 6 + (animationValue * 3);
        canvas.drawCircle(
          Offset(x, y),
          pulseSize,
          Paint()
            ..color = color.withOpacity(0.4)
            ..style = PaintingStyle.fill,
        );
      }
      
      // Draw main runner dot
      canvas.drawCircle(
        Offset(x, y),
        5,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      
      // Draw border
      canvas.drawCircle(
        Offset(x, y),
        5,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
      
      // Draw runner ID label on hover (just show a small indicator)
      if (selectedRunnerId == runner.deviceId) {
        canvas.drawCircle(
          Offset(x, y),
          8,
          Paint()
            ..color = Colors.transparent
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke
            ..color = Colors.yellow,
        );
        
        // Show runner ID
        final textPainter = TextPainter(
          text: TextSpan(
            text: '#${runner.deviceId}',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, y - 20),
        );
      }
    }
  }

  @override
  bool shouldRepaint(MarathonCourseMapPainter oldDelegate) {
    return oldDelegate.runners.length != runners.length ||
        oldDelegate.selectedRunnerId != selectedRunnerId ||
        oldDelegate.animationValue != animationValue;
  }
}
