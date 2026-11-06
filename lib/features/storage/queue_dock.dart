import 'package:flutter/material.dart';

import '../../core/theme/space_theme.dart';
import '../../models/queue_state.dart';

class QueueDock extends StatelessWidget {
  const QueueDock({super.key, required this.queue});

  final QueueState queue;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      color: Colors.transparent,
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xEE0D1728),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: SpaceColors.border),
        ),
        child: Row(
          children: [
            Icon(
              queue.isPaused
                  ? Icons.pause_circle_rounded
                  : Icons.cloud_upload_rounded,
              color: queue.isPaused ? SpaceColors.amber : SpaceColors.cyan,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    queue.currentFile ?? 'Vault queue',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                    value: queue.progressPercentage == 0
                        ? null
                        : queue.progressPercentage.clamp(0, 1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${queue.completedFiles}/${queue.totalFiles}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
