import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/space_theme.dart';
import '../../models/queue_state.dart';
import '../../services/device/device_service.dart';
import '../../services/repository/space_providers.dart';
import '../storage/queue_dock.dart';

class SpaceShell extends ConsumerWidget {
  const SpaceShell({
    super.key,
    required this.title,
    required this.selectedIndex,
    required this.child,
    this.actions = const [],
    this.floatingActionButton,
  });

  final String title;
  final int selectedIndex;
  final Widget child;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue =
        ref.watch(uploadQueueProvider).asData?.value ?? const QueueState.idle();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        final scaffold = Scaffold(
          drawer: isWide ? null : const _MobileDriveDrawer(),
          appBar: AppBar(title: Text(title), actions: actions),
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: isWide
              ? null
              : BottomNavigationBar(
                  currentIndex: selectedIndex,
                  onTap: (index) => _goToIndex(context, ref, index),
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard_rounded),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.cloud_queue_rounded),
                      label: 'Drive',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.tune_rounded),
                      label: 'Settings',
                    ),
                  ],
                ),
          body: Stack(
            children: [
              const Positioned.fill(child: _CosmicBackdrop()),
              Positioned.fill(
                child: SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            isWide ? 24 : 16,
                            8,
                            isWide ? 24 : 16,
                            queue.isUploading ? 96 : 16,
                          ),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (queue.isUploading || queue.completedFiles > 0)
                Positioned(
                  left: isWide ? 24 : 12,
                  right: isWide ? 24 : 12,
                  bottom: isWide ? 20 : 86,
                  child: QueueDock(queue: queue),
                ),
            ],
          ),
        );

        if (!isWide) {
          return scaffold;
        }

        return Scaffold(
          body: Row(
            children: [
              _DriveSidebar(
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) =>
                    _goToIndex(context, ref, index),
              ),
              Expanded(child: scaffold),
            ],
          ),
        );
      },
    );
  }

  void _goToIndex(BuildContext context, WidgetRef ref, int index) {
    switch (index) {
      case 0:
        ref.read(activeDeviceFilterProvider.notifier).setDevice(null);
        ref.read(categoryFilterProvider.notifier).setCategory('all');
        context.go('/dashboard');
      case 1:
        context.go('/folder/root');
      case 2:
        ref.read(activeDeviceFilterProvider.notifier).setDevice(null);
        context.go('/settings');
    }
  }
}

class _DriveSidebar extends ConsumerWidget {
  const _DriveSidebar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDevice = ref.watch(activeDeviceFilterProvider);
    final currentCategory = ref.watch(categoryFilterProvider);
    final registeredDevicesAsync = ref.watch(registeredDevicesProvider);
    final currentParent = ref.watch(currentDirectoryProvider);

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Color(0xFF091220),
        border: Border(right: BorderSide(color: SpaceColors.border)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drive Brand Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [SpaceColors.cyan, SpaceColors.violet],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: SpaceColors.cyan.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.cloud_done_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SpaceHERE',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                        ),
                        const Text(
                          'Decentralized Drive',
                          style: TextStyle(
                            fontSize: 11,
                            color: SpaceColors.cyan,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Google Drive "+ New" Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: PopupMenuButton<String>(
                tooltip: 'Add new file or folder',
                offset: const Offset(0, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: SpaceColors.border),
                ),
                color: SpaceColors.surface,
                onSelected: (action) {
                  if (action == 'upload') {
                    ref
                        .read(uploadQueueProvider.notifier)
                        .pickAndUpload(currentParent);
                  } else if (action == 'folder') {
                    _showNewFolderDialog(context, ref, currentParent);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'upload',
                    child: Row(
                      children: [
                        Icon(
                          Icons.upload_file_rounded,
                          color: SpaceColors.cyan,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text('Upload file'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'folder',
                    child: Row(
                      children: [
                        Icon(
                          Icons.create_new_folder_rounded,
                          color: SpaceColors.violet,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text('New folder'),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: SpaceColors.cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: SpaceColors.cyan.withValues(alpha: 0.4),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        color: SpaceColors.cyan,
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'New',
                        style: TextStyle(
                          color: SpaceColors.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
            const Divider(color: Color(0x1F2FE8FF), height: 1),
            const SizedBox(height: 8),

            // Core Drive Navigation
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _NavButton(
                    selected: selectedIndex == 0,
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard_rounded,
                    label: 'Home',
                    onPressed: () => onDestinationSelected(0),
                  ),
                  _NavButton(
                    selected:
                        selectedIndex == 1 &&
                        activeDevice == null &&
                        currentCategory == 'all',
                    icon: Icons.folder_open_rounded,
                    activeIcon: Icons.folder_rounded,
                    label: 'My Drive',
                    onPressed: () {
                      ref
                          .read(activeDeviceFilterProvider.notifier)
                          .setDevice(null);
                      ref
                          .read(currentDirectoryProvider.notifier)
                          .setDirectory(null);
                      ref
                          .read(categoryFilterProvider.notifier)
                          .setCategory('all');
                      onDestinationSelected(1);
                    },
                  ),
                  _NavButton(
                    selected:
                        selectedIndex == 1 && currentCategory == 'favorites',
                    icon: Icons.star_outline_rounded,
                    activeIcon: Icons.star_rounded,
                    label: 'Starred',
                    onPressed: () {
                      ref
                          .read(activeDeviceFilterProvider.notifier)
                          .setDevice(null);
                      ref
                          .read(currentDirectoryProvider.notifier)
                          .setDirectory(null);
                      ref
                          .read(categoryFilterProvider.notifier)
                          .setCategory('favorites');
                      onDestinationSelected(1);
                    },
                  ),
                  _NavButton(
                    selected: selectedIndex == 1 && currentCategory == 'trash',
                    icon: Icons.delete_outline_rounded,
                    activeIcon: Icons.delete_rounded,
                    label: 'Trash',
                    onPressed: () {
                      ref
                          .read(activeDeviceFilterProvider.notifier)
                          .setDevice(null);
                      ref
                          .read(currentDirectoryProvider.notifier)
                          .setDirectory(null);
                      ref
                          .read(categoryFilterProvider.notifier)
                          .setCategory('trash');
                      onDestinationSelected(1);
                    },
                  ),

                  const SizedBox(height: 14),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Text(
                      'COMPUTERS & DEVICES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: SpaceColors.muted,
                      ),
                    ),
                  ),

                  // Dynamic Registered Devices (Ubuntu, OnePlus, etc.)
                  registeredDevicesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (err, stack) => const SizedBox.shrink(),
                    data: (devices) {
                      return Column(
                        children: [
                          for (final dev in devices)
                            _NavButton(
                              selected:
                                  selectedIndex == 1 && activeDevice == dev,
                              icon: _deviceIcon(dev),
                              activeIcon: _deviceIcon(dev),
                              label: dev,
                              onPressed: () {
                                ref
                                    .read(activeDeviceFilterProvider.notifier)
                                    .setDevice(dev);
                                ref
                                    .read(categoryFilterProvider.notifier)
                                    .setCategory('all');
                                onDestinationSelected(1);
                              },
                            ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 14),
                  _NavButton(
                    selected: selectedIndex == 2,
                    icon: Icons.tune_rounded,
                    activeIcon: Icons.tune_rounded,
                    label: 'Settings',
                    onPressed: () => onDestinationSelected(2),
                  ),
                ],
              ),
            ),

            // Bottom Device & Storage Footer
            const Padding(padding: EdgeInsets.all(14), child: _VaultPulse()),
          ],
        ),
      ),
    );
  }

  IconData _deviceIcon(String dev) {
    final lower = dev.toLowerCase();
    if (lower.contains('ubuntu') || lower.contains('linux')) {
      return Icons.computer_rounded;
    }
    if (lower.contains('oneplus') ||
        lower.contains('phone') ||
        lower.contains('android')) {
      return Icons.phone_android_rounded;
    }
    if (lower.contains('mac') || lower.contains('ios')) {
      return Icons.laptop_mac_rounded;
    }
    if (lower.contains('windows')) {
      return Icons.desktop_windows_rounded;
    }
    return Icons.devices_rounded;
  }

  void _showNewFolderDialog(
    BuildContext context,
    WidgetRef ref,
    String? parentUuid,
  ) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Folder name',
            prefixIcon: Icon(Icons.folder_rounded, color: SpaceColors.cyan),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      await ref.read(spaceRepositoryProvider).createFolder(name, parentUuid);
      ref.invalidate(directoryNodesProvider);
      ref.invalidate(allNodesProvider);
    }
  }
}

class _MobileDriveDrawer extends ConsumerWidget {
  const _MobileDriveDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: const Color(0xFF091220),
      child: _DriveSidebar(
        selectedIndex: 1,
        onDestinationSelected: (index) {
          Navigator.of(context).pop();
          ref.read(activeDeviceFilterProvider.notifier).setDevice(null);
          switch (index) {
            case 0:
              context.go('/dashboard');
            case 1:
              ref.read(categoryFilterProvider.notifier).setCategory('all');
              context.go('/folder/root');
            case 2:
              context.go('/settings');
          }
        },
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.activeIcon,
  });

  final bool selected;
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected
                ? SpaceColors.cyan.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? SpaceColors.border : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? (activeIcon ?? icon) : icon,
                color: selected ? SpaceColors.cyan : SpaceColors.muted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? SpaceColors.text : SpaceColors.muted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaultPulse extends StatelessWidget {
  const _VaultPulse();

  @override
  Widget build(BuildContext context) {
    final device = DeviceService.instance.currentDevice;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SpaceColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: SpaceColors.green,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Zero-Knowledge Encrypted',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: SpaceColors.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Host: ${device.deviceName}',
            style: const TextStyle(
              color: SpaceColors.cyan,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Telegram MTProto Distributed Vault',
            style: TextStyle(color: SpaceColors.muted, fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

class _CosmicBackdrop extends StatelessWidget {
  const _CosmicBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CosmicBackdropPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _CosmicBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [SpaceColors.canvas, Color(0xFF101B2D), Color(0xFF151126)],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    final linePaint = Paint()
      ..color = SpaceColors.cyan.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (var i = 0; i < 8; i++) {
      final y = size.height * (i / 7);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 50), linePaint);
    }

    final starPaint = Paint()..color = SpaceColors.text.withValues(alpha: 0.14);
    for (var i = 0; i < 60; i++) {
      final x = (i * 73 % size.width.toInt()).toDouble();
      final y = (i * 41 % size.height.toInt()).toDouble();
      canvas.drawCircle(Offset(x, y), i % 5 == 0 ? 1.2 : 0.7, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
