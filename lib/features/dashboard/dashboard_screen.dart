import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/space_theme.dart';
import '../../models/queue_state.dart';
import '../../services/repository/space_providers.dart';
import 'space_shell.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(allNodesProvider);
    final syncState = ref.watch(syncStateProvider);
    final queue = ref.watch(uploadQueueProvider);

    return SpaceShell(
      title: 'Dashboard',
      selectedIndex: 0,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () {
            ref.invalidate(allNodesProvider);
            ref.invalidate(syncStateProvider);
          },
        ),
      ],
      child: nodes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorPanel(message: error.toString()),
        data: (nodeList) {
          final fileCount = nodeList.where((node) => !node.isFolder).length;
          final folderCount = nodeList.where((node) => node.isFolder).length;
          final totalBytes = nodeList.fold<int>(
            0,
            (sum, node) => sum + node.sizeBytes,
          );

          final recentFiles = nodeList
              .where((node) => !node.isFolder)
              .sorted((a, b) => b.updatedAt.compareTo(a.updatedAt))
              .take(4)
              .toList();

          return ListView(
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _MetricCard(
                    icon: Icons.shield_rounded,
                    label: 'Vault Health',
                    value: 'Protected',
                    accent: SpaceColors.green,
                  ),
                  _MetricCard(
                    icon: Icons.folder_copy_rounded,
                    label: 'Folders',
                    value: '$folderCount',
                    accent: SpaceColors.cyan,
                  ),
                  _MetricCard(
                    icon: Icons.description_rounded,
                    label: 'Files',
                    value: '$fileCount',
                    accent: SpaceColors.violet,
                  ),
                  _MetricCard(
                    icon: Icons.storage_rounded,
                    label: 'Mapped Data',
                    value: _formatBytes(totalBytes),
                    accent: SpaceColors.amber,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 820;
                  final syncPanel = syncState.when(
                    loading: () => const _SyncPanel.loading(),
                    error: (error, stackTrace) =>
                        _ErrorPanel(message: error.toString()),
                    data: (state) => _SyncPanel(
                      exportedAt: state.exportedAt,
                      deviceId: state.deviceId,
                      nodeCount: state.nodes.length,
                    ),
                  );

                  if (!isWide) {
                    return Column(
                      children: [
                        _QueuePanel(queue: queue.asData?.value),
                        const SizedBox(height: 18),
                        syncPanel,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _QueuePanel(queue: queue.asData?.value),
                      ),
                      const SizedBox(width: 18),
                      Expanded(flex: 2, child: syncPanel),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              // Category Bento Cards
              Text(
                'Space Categories',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: SpaceColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _CategoryBentoCard(
                    title: 'Photos',
                    icon: Icons.photo_library_rounded,
                    color: SpaceColors.cyan,
                    count: nodeList
                        .where(
                          (n) => !n.isFolder && n.mimeType.startsWith('image/'),
                        )
                        .length,
                    onTap: () {
                      ref
                          .read(categoryFilterProvider.notifier)
                          .setCategory('photos');
                      context.go('/folder/root');
                    },
                  ),
                  _CategoryBentoCard(
                    title: 'Videos',
                    icon: Icons.video_collection_rounded,
                    color: SpaceColors.violet,
                    count: nodeList
                        .where(
                          (n) => !n.isFolder && n.mimeType.startsWith('video/'),
                        )
                        .length,
                    onTap: () {
                      ref
                          .read(categoryFilterProvider.notifier)
                          .setCategory('videos');
                      context.go('/folder/root');
                    },
                  ),
                  _CategoryBentoCard(
                    title: 'Documents',
                    icon: Icons.source_rounded,
                    color: SpaceColors.green,
                    count: nodeList
                        .where(
                          (n) =>
                              !n.isFolder &&
                              (n.mimeType.contains('pdf') ||
                                  n.mimeType.contains('text') ||
                                  n.mimeType.contains('json')),
                        )
                        .length,
                    onTap: () {
                      ref
                          .read(categoryFilterProvider.notifier)
                          .setCategory('documents');
                      context.go('/folder/root');
                    },
                  ),
                  _CategoryBentoCard(
                    title: 'Other Vault Files',
                    icon: Icons.folder_zip_rounded,
                    color: SpaceColors.amber,
                    count: nodeList
                        .where(
                          (n) =>
                              !n.isFolder &&
                              !n.mimeType.startsWith('image/') &&
                              !n.mimeType.startsWith('video/') &&
                              !n.mimeType.contains('pdf') &&
                              !n.mimeType.contains('text'),
                        )
                        .length,
                    onTap: () {
                      ref
                          .read(categoryFilterProvider.notifier)
                          .setCategory('others');
                      context.go('/folder/root');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 22),
              // Recent Files Section
              if (recentFiles.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      'Recent Vault Files',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: SpaceColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        ref
                            .read(categoryFilterProvider.notifier)
                            .setCategory('all');
                        context.go('/folder/root');
                      },
                      child: const Text('View all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentFiles.length,
                    separatorBuilder: (context, index) =>
                        const Divider(color: SpaceColors.border, height: 1),
                    itemBuilder: (context, index) {
                      final f = recentFiles[index];
                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: SpaceColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: SpaceColors.border),
                          ),
                          child: Icon(
                            f.mimeType.startsWith('image/')
                                ? Icons.image_rounded
                                : f.mimeType.startsWith('video/')
                                ? Icons.movie_rounded
                                : Icons.insert_drive_file_rounded,
                            color: SpaceColors.cyan,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          f.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${_formatBytes(f.sizeBytes)} • ${f.chunkMessageIds.length} chunk(s)',
                          style: const TextStyle(
                            color: SpaceColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: SpaceColors.muted,
                        ),
                        onTap: () {
                          context.go('/folder/root');
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent),
              const SizedBox(height: 12),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueuePanel extends StatelessWidget {
  const _QueuePanel({required this.queue});

  final QueueState? queue;

  @override
  Widget build(BuildContext context) {
    final progress = queue?.progressPercentage ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const _WeavingRing(size: 86),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weaving Engine',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    queue?.statusLabel ?? 'Vault queue is idle',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value: progress == 0 ? null : progress,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncPanel extends ConsumerWidget {
  const _SyncPanel({
    required this.exportedAt,
    required this.deviceId,
    required this.nodeCount,
  });

  const _SyncPanel.loading()
    : exportedAt = null,
      deviceId = null,
      nodeCount = null;

  final DateTime? exportedAt;
  final String? deviceId;
  final int? nodeCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatted = exportedAt == null
        ? 'Preparing...'
        : DateFormat('MMM d, h:mm a').format(exportedAt!.toLocal());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.push_pin_rounded, color: SpaceColors.cyan),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pinned Sync State',
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DetailRow(label: 'Exported', value: formatted),
            _DetailRow(label: 'Nodes', value: '${nodeCount ?? 0}'),
            _DetailRow(
              label: 'Device',
              value: deviceId == null ? 'Pending' : deviceId!.substring(0, 8),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Synchronizing with MTProto private channel...',
                      ),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  await ref
                      .read(spaceRepositoryProvider)
                      .pullRemoteVaultState();
                  await ref
                      .read(spaceRepositoryProvider)
                      .syncLocalStateToVault();
                  ref.invalidate(syncStateProvider);
                  ref.invalidate(allNodesProvider);
                  ref.invalidate(directoryNodesProvider);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Ecosystem synchronized successfully.'),
                      backgroundColor: Color(0xFF0D3B2E),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: const Text('Sync With Cloud Vault'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBentoCard extends StatelessWidget {
  const _CategoryBentoCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.count,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 175,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count item${count == 1 ? "" : "s"}',
                  style: const TextStyle(
                    color: SpaceColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeavingRing extends StatefulWidget {
  const _WeavingRing({required this.size});

  final double size;

  @override
  State<_WeavingRing> createState() => _WeavingRingState();
}

class _WeavingRingState extends State<_WeavingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _RingPainter(progress: _controller.value),
            child: const Center(
              child: Icon(Icons.hub_rounded, color: SpaceColors.cyan),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 5;
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = SpaceColors.violet.withValues(alpha: 0.24);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6
      ..color = SpaceColors.cyan;

    canvas.drawCircle(center, radius, basePaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * 6.283,
      2.4,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.error_rounded, color: SpaceColors.danger),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
