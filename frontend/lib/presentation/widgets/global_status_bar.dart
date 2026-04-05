import 'package:flutter/material.dart';
import '../providers/runner_detail_provider.dart';

/// Global status bar showing which runners are updating vs paused across all screens.
/// Demonstrates Requirement #21 (visibility-based updates) and #22 (error recovery).
class GlobalStatusBar extends StatelessWidget {
  /// The runner being viewed (null when on runner list).
  /// Used to show which runner is LIVE.
  final int? activeRunnerId;

  /// Total number of runners in the system.
  final int totalRunners;

  const GlobalStatusBar({
    required this.activeRunnerId,
    required this.totalRunners,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: RunnerDetailProvider.activeRunnersNotifier,
      builder: (context, _, __) {
        return Container(
          color: Colors.blue.shade900,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Active runner info
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (activeRunnerId != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '🟢 Runner #$activeRunnerId (Updating)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                overflow: TextOverflow.ellipsis,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ],
                      )
                    else
                      const Row(
                        children: [
                          Icon(
                            Icons.pause_circle,
                            size: 16,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '⏸️ All runners paused (viewing list)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    // Counter removed - check terminal for reliable tracking
                  ],
                ),
              ),
              // Right: Status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: activeRunnerId != null ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  activeRunnerId != null ? 'LIVE' : 'PAUSED',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
