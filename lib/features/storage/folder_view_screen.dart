import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/space_theme.dart';
import '../../models/space_node.dart';
import '../../services/database/database_service.dart';
import '../../services/repository/space_providers.dart';
import '../dashboard/space_shell.dart';

class FolderViewScreen extends ConsumerStatefulWidget {
  const FolderViewScreen({super.key, required this.parentUuid});

  final String? parentUuid;

  @override
  ConsumerState<FolderViewScreen> createState() => _FolderViewScreenState();
}

class _FolderViewScreenState extends ConsumerState<FolderViewScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(_openDirectory);
  }

  @override
  void didUpdateWidget(covariant FolderViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parentUuid != widget.parentUuid) {
      Future.microtask(_openDirectory);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentParent = ref.watch(currentDirectoryProvider);
    final breadcrumbsAsync = ref.watch(
      folderBreadcrumbsProvider(currentParent),
    );
    final currentCategory = ref.watch(categoryFilterProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final selectedUuids = ref.watch(selectedNodesProvider);
    final sortField = ref.watch(sortFieldProvider);
    final sortOrder = ref.watch(sortOrderProvider);
    final viewMode = ref.watch(driveViewModeProvider);
    final activeDevice = ref.watch(activeDeviceFilterProvider);

    final isTrashMode = currentCategory == 'trash';
    final isFavoritesMode = currentCategory == 'favorites';

    // Determine nodes to display based on active device, category & search
    final AsyncValue<List<SpaceNode>> nodesAsync;
    if (activeDevice != null) {
      nodesAsync = ref.watch(deviceNodesProvider(activeDevice));
    } else if (isTrashMode) {
      nodesAsync = ref.watch(trashNodesProvider);
    } else if (isFavoritesMode) {
      nodesAsync = ref.watch(favoritesNodesProvider);
    } else if (searchQuery.trim().isNotEmpty) {
      nodesAsync = ref.watch(searchResultsProvider);
    } else if (currentCategory != 'all') {
      nodesAsync = ref.watch(categoryNodesProvider(currentCategory));
    } else {
      nodesAsync = ref.watch(directoryNodesProvider);
    }

    return SpaceShell(
      title: activeDevice != null
          ? 'Device: $activeDevice'
          : isTrashMode
          ? 'Trash & Recycle Bin'
          : isFavoritesMode
          ? 'Favorites & Starred'
          : currentParent == null
          ? 'Vault Files'
          : 'Folder',
      selectedIndex: 1,
      actions: [
        IconButton(
          tooltip: viewMode == DriveViewMode.grid
              ? 'Switch to List view'
              : 'Switch to Grid view',
          icon: Icon(
            viewMode == DriveViewMode.grid
                ? Icons.view_list_rounded
                : Icons.grid_view_rounded,
            color: SpaceColors.cyan,
          ),
          onPressed: () {
            ref.read(driveViewModeProvider.notifier).toggle();
          },
        ),
        if (isTrashMode) ...[
          IconButton(
            tooltip: 'Empty Trash',
            icon: const Icon(
              Icons.delete_forever_rounded,
              color: SpaceColors.danger,
            ),
            onPressed: () => _confirmEmptyTrash(),
          ),
        ] else ...[
          IconButton(
            tooltip: 'Vault Analytics',
            icon: const Icon(Icons.pie_chart_outline_rounded),
            onPressed: () => _showStorageAnalytics(context, ref, currentParent),
          ),
          IconButton(
            tooltip: 'New folder',
            icon: const Icon(Icons.create_new_folder_rounded),
            onPressed: () => _showCreateFolderDialog(currentParent),
          ),
        ],
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () {
            ref.invalidate(directoryNodesProvider);
            ref.invalidate(allNodesProvider);
            ref.invalidate(syncStateProvider);
            ref.invalidate(trashNodesProvider);
            ref.invalidate(favoritesNodesProvider);
            ref.invalidate(searchResultsProvider);
            ref.invalidate(vaultStatsProvider);
            ref.invalidate(registeredDevicesProvider);
            if (activeDevice != null) {
              ref.invalidate(deviceNodesProvider(activeDevice));
            }
            if (currentParent != null) {
              ref.invalidate(folderStatsProvider(currentParent));
            }
          },
        ),
      ],
      floatingActionButton: isTrashMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => ref
                  .read(uploadQueueProvider.notifier)
                  .pickAndUpload(currentParent),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Upload'),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: isTrashMode
                          ? 'Viewing deleted files in trash...'
                          : 'Search files across vault...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: SpaceColors.cyan,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(searchQueryProvider.notifier)
                                    .setQuery('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      ref.read(searchQueryProvider.notifier).setQuery(val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Sort Menu
                PopupMenuButton<SortField>(
                  tooltip: 'Sort by',
                  icon: const Icon(Icons.sort_rounded, color: SpaceColors.cyan),
                  initialValue: sortField,
                  color: SpaceColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: SpaceColors.border),
                  ),
                  onSelected: (field) {
                    ref.read(sortFieldProvider.notifier).setSortField(field);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: SortField.name,
                      child: Text('Name (Alphabetical)'),
                    ),
                    const PopupMenuItem(
                      value: SortField.dateModified,
                      child: Text('Date Modified'),
                    ),
                    const PopupMenuItem(
                      value: SortField.size,
                      child: Text('File Size'),
                    ),
                    const PopupMenuItem(
                      value: SortField.type,
                      child: Text('File Type'),
                    ),
                  ],
                ),
                // Sort Direction Toggle
                IconButton(
                  tooltip: sortOrder == SortOrder.ascending
                      ? 'Ascending (A-Z / Oldest first)'
                      : 'Descending (Z-A / Newest first)',
                  icon: Icon(
                    sortOrder == SortOrder.ascending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: SpaceColors.cyan,
                  ),
                  onPressed: () {
                    ref.read(sortOrderProvider.notifier).toggle();
                  },
                ),
              ],
            ),
          ),

          // Category Chips Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                _CategoryChip(
                  label: 'All Files',
                  icon: Icons.grid_view_rounded,
                  selected: currentCategory == 'all',
                  onSelected: () => ref
                      .read(categoryFilterProvider.notifier)
                      .setCategory('all'),
                ),
                const SizedBox(width: 8),
                _CategoryChip(
                  label: 'Favorites',
                  icon: Icons.star_rounded,
                  selected: currentCategory == 'favorites',
                  onSelected: () => ref
                      .read(categoryFilterProvider.notifier)
                      .setCategory('favorites'),
                ),
                const SizedBox(width: 8),
                _CategoryChip(
                  label: 'Photos',
                  icon: Icons.image_rounded,
                  selected: currentCategory == 'photos',
                  onSelected: () => ref
                      .read(categoryFilterProvider.notifier)
                      .setCategory('photos'),
                ),
                const SizedBox(width: 8),
                _CategoryChip(
                  label: 'Videos',
                  icon: Icons.movie_rounded,
                  selected: currentCategory == 'videos',
                  onSelected: () => ref
                      .read(categoryFilterProvider.notifier)
                      .setCategory('videos'),
                ),
                const SizedBox(width: 8),
                _CategoryChip(
                  label: 'Documents',
                  icon: Icons.description_rounded,
                  selected: currentCategory == 'documents',
                  onSelected: () => ref
                      .read(categoryFilterProvider.notifier)
                      .setCategory('documents'),
                ),
                const SizedBox(width: 8),
                _CategoryChip(
                  label: 'Archives',
                  icon: Icons.folder_zip_rounded,
                  selected: currentCategory == 'archives',
                  onSelected: () => ref
                      .read(categoryFilterProvider.notifier)
                      .setCategory('archives'),
                ),
                const SizedBox(width: 8),
                _CategoryChip(
                  label: 'Trash',
                  icon: Icons.delete_outline_rounded,
                  selected: currentCategory == 'trash',
                  onSelected: () => ref
                      .read(categoryFilterProvider.notifier)
                      .setCategory('trash'),
                ),
              ],
            ),
          ),

          // Google Drive Trash Banner
          if (isTrashMode)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: SpaceColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: SpaceColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: SpaceColors.danger,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Items in trash are automatically deleted after 30 days.',
                      style: TextStyle(
                        fontSize: 13,
                        color: SpaceColors.text,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmEmptyTrash(),
                    icon: const Icon(
                      Icons.delete_forever_rounded,
                      size: 16,
                      color: SpaceColors.danger,
                    ),
                    label: const Text(
                      'Empty Trash Now',
                      style: TextStyle(
                        color: SpaceColors.danger,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Active Device Filter Banner
          if (activeDevice != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: SpaceColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: SpaceColors.cyan.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.devices_rounded,
                    size: 18,
                    color: SpaceColors.cyan,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Filtering files uploaded from: $activeDevice',
                    style: const TextStyle(
                      fontSize: 13,
                      color: SpaceColors.cyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    tooltip: 'Clear device filter',
                    onPressed: () => ref
                        .read(activeDeviceFilterProvider.notifier)
                        .setDevice(null),
                  ),
                ],
              ),
            ),

          // Multi-Selection Action Banner
          if (selectedUuids.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: SpaceColors.cyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: SpaceColors.cyan.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '${selectedUuids.length} selected',
                    style: const TextStyle(
                      color: SpaceColors.cyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (!isTrashMode) ...[
                    TextButton.icon(
                      onPressed: () => _batchMove(selectedUuids),
                      icon: const Icon(Icons.drive_file_move_rounded, size: 18),
                      label: const Text('Move'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _batchDuplicate(selectedUuids),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: SpaceColors.danger,
                      ),
                      onPressed: () => _batchDelete(selectedUuids),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Delete'),
                    ),
                  ] else ...[
                    TextButton.icon(
                      onPressed: () => _batchRestore(selectedUuids),
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: const Text('Restore'),
                    ),
                  ],
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Clear selection',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () =>
                        ref.read(selectedNodesProvider.notifier).clear(),
                  ),
                ],
              ),
            ),

          // Interactive Breadcrumbs Bar
          if (currentParent != null && !isTrashMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: breadcrumbsAsync.when(
                loading: () => const SizedBox(height: 32),
                error: (error, stackTrace) => const SizedBox.shrink(),
                data: (trail) => _BreadcrumbBar(trail: trail),
              ),
            ),

          // Main Nodes Grid
          Expanded(
            child: nodesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  _ErrorPanel(message: error.toString()),
              data: (displayed) {
                if (displayed.isEmpty) {
                  return _EmptyFolder(isTrash: isTrashMode);
                }

                if (viewMode == DriveViewMode.table) {
                  return _DriveTableView(
                    nodes: displayed,
                    selectedUuids: selectedUuids,
                    isTrash: isTrashMode,
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final columns = width >= 1200
                        ? 5
                        : width >= 900
                        ? 4
                        : width >= 620
                        ? 3
                        : 2;

                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.05,
                      ),
                      itemCount: displayed.length,
                      itemBuilder: (context, index) {
                        final node = displayed[index];
                        final isSelected = selectedUuids.contains(node.uuid);
                        return _NodeTile(
                          node: node,
                          isSelected: isSelected,
                          isTrash: isTrashMode,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openDirectory() {
    if (!mounted) {
      return;
    }
    ref.read(currentDirectoryProvider.notifier).open(widget.parentUuid);
  }

  Future<void> _showCreateFolderDialog(String? parentUuid) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Folder name',
              prefixIcon: Icon(Icons.folder_rounded),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (name == null || name.trim().isEmpty) {
      return;
    }

    await ref.read(spaceRepositoryProvider).createFolder(name, parentUuid);
    _invalidateAll();
  }

  Future<void> _batchMove(Set<String> uuids) async {
    final allNodes = await ref.read(spaceRepositoryProvider).listAllNodes();
    final folders = allNodes
        .where((n) => n.isFolder && !uuids.contains(n.uuid))
        .toList();

    if (!mounted) return;

    final targetParent = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Move ${uuids.length} items to:'),
          content: SizedBox(
            width: 320,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.home_rounded,
                    color: SpaceColors.cyan,
                  ),
                  title: const Text('Vault Root'),
                  onTap: () => Navigator.of(context).pop('root'),
                ),
                const Divider(color: SpaceColors.border),
                for (final folder in folders)
                  ListTile(
                    leading: const Icon(
                      Icons.folder_rounded,
                      color: SpaceColors.cyan,
                    ),
                    title: Text(folder.name),
                    onTap: () => Navigator.of(context).pop(folder.uuid),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (targetParent == null) return;

    final newParentUuid = targetParent == 'root' ? null : targetParent;
    await ref
        .read(spaceRepositoryProvider)
        .moveBatch(uuids.toList(), newParentUuid);
    ref.read(selectedNodesProvider.notifier).clear();
    _invalidateAll();
  }

  Future<void> _batchDelete(Set<String> uuids) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete ${uuids.length} items?'),
          content: const Text('Selected items will be moved to the Trash.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: SpaceColors.danger,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Move to Trash'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(spaceRepositoryProvider).softDeleteBatch(uuids.toList());
      ref.read(selectedNodesProvider.notifier).clear();
      _invalidateAll();
    }
  }

  Future<void> _batchRestore(Set<String> uuids) async {
    for (final id in uuids) {
      await ref.read(spaceRepositoryProvider).restoreNode(id);
    }
    ref.read(selectedNodesProvider.notifier).clear();
    _invalidateAll();
  }

  Future<void> _confirmEmptyTrash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Empty Trash permanently?'),
          content: const Text(
            'This action cannot be undone. All soft-deleted items will be purged forever.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: SpaceColors.danger,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Empty Trash'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(spaceRepositoryProvider).emptyTrash();
      _invalidateAll();
    }
  }

  Future<void> _batchDuplicate(Set<String> uuids) async {
    final currentParent = ref.read(currentDirectoryProvider);
    await ref
        .read(spaceRepositoryProvider)
        .copyBatch(uuids.toList(), currentParent);
    ref.read(selectedNodesProvider.notifier).clear();
    _invalidateAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Duplicated ${uuids.length} item(s)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showStorageAnalytics(
    BuildContext context,
    WidgetRef ref,
    String? currentParent,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SpaceColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: SpaceColors.border),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final statsAsync = currentParent != null
                ? ref.watch(folderStatsProvider(currentParent))
                : ref.watch(vaultStatsProvider);

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: SpaceColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Icon(
                        Icons.pie_chart_rounded,
                        color: SpaceColors.cyan,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        currentParent == null
                            ? 'Vault Storage Analytics'
                            : 'Folder Statistics',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  statsAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Text('Error loading stats: $err'),
                    data: (stats) {
                      final totalFiles = stats is FolderStats
                          ? stats.totalFiles
                          : (stats as VaultStats).totalFiles;
                      final totalFolders = stats is FolderStats
                          ? stats.totalFolders
                          : (stats as VaultStats).totalFolders;
                      final totalBytes = stats is FolderStats
                          ? stats.totalBytes
                          : (stats as VaultStats).totalBytes;
                      final mimeBreakdown = stats is FolderStats
                          ? stats.mimeBreakdown
                          : (stats as VaultStats).mimeBreakdown;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DetailLine(
                            label: 'Total Files',
                            value: '$totalFiles',
                          ),
                          _DetailLine(
                            label: 'Total Folders',
                            value: '$totalFolders',
                          ),
                          _DetailLine(
                            label: 'Storage Occupied',
                            value: _formatBytes(totalBytes),
                          ),
                          if (stats is VaultStats) ...[
                            _DetailLine(
                              label: 'Favorite Items',
                              value: '${stats.favoritesCount}',
                            ),
                            _DetailLine(
                              label: 'Trash Items',
                              value:
                                  '${stats.trashCount} (${_formatBytes(stats.trashBytes)})',
                            ),
                          ],
                          const SizedBox(height: 16),
                          const Text(
                            'Category Breakdown',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: SpaceColors.text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final entry in mimeBreakdown.entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(
                                      color: SpaceColors.muted,
                                    ),
                                  ),
                                  Text(
                                    _formatBytes(entry.value),
                                    style: const TextStyle(
                                      color: SpaceColors.cyan,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (mimeBreakdown.isEmpty)
                            const Text(
                              'No files stored yet',
                              style: TextStyle(color: SpaceColors.muted),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _invalidateAll() {
    ref.invalidate(directoryNodesProvider);
    ref.invalidate(allNodesProvider);
    ref.invalidate(syncStateProvider);
    ref.invalidate(trashNodesProvider);
    ref.invalidate(favoritesNodesProvider);
    ref.invalidate(searchResultsProvider);
    ref.invalidate(vaultStatsProvider);
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? const Color(0xFF03131D) : SpaceColors.cyan,
      ),
      label: Text(label),
      selectedColor: SpaceColors.cyan,
      backgroundColor: SpaceColors.surface,
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF03131D) : SpaceColors.text,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? SpaceColors.cyan : SpaceColors.border,
        ),
      ),
    );
  }
}

class _BreadcrumbBar extends StatelessWidget {
  const _BreadcrumbBar({required this.trail});

  final List<SpaceNode> trail;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => context.go('/folder/root'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: SpaceColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SpaceColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.home_rounded, size: 16, color: SpaceColors.cyan),
                  SizedBox(width: 4),
                  Text('Vault Root', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
          for (var i = 0; i < trail.length; i++) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: SpaceColors.muted,
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => context.go('/folder/${trail[i].uuid}'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: i == trail.length - 1
                      ? SpaceColors.cyan.withValues(alpha: 0.14)
                      : SpaceColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: i == trail.length - 1
                        ? SpaceColors.cyan
                        : SpaceColors.border,
                  ),
                ),
                child: Text(
                  trail[i].name,
                  style: TextStyle(
                    color: i == trail.length - 1
                        ? SpaceColors.cyan
                        : SpaceColors.text,
                    fontWeight: i == trail.length - 1
                        ? FontWeight.w700
                        : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NodeTile extends ConsumerWidget {
  const _NodeTile({
    required this.node,
    required this.isSelected,
    this.isTrash = false,
  });

  final SpaceNode node;
  final bool isSelected;
  final bool isTrash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? SpaceColors.cyan : SpaceColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          final selected = ref.read(selectedNodesProvider);
          if (selected.isNotEmpty) {
            ref.read(selectedNodesProvider.notifier).toggle(node.uuid);
            return;
          }

          if (isTrash) {
            _showTrashDetailsSheet(context, ref, node);
          } else if (node.isFolder) {
            context.go('/folder/${node.uuid}');
          } else {
            _showFileDetailsSheet(context, ref, node);
          }
        },
        onLongPress: () {
          ref.read(selectedNodesProvider.notifier).toggle(node.uuid);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    node.isFolder
                        ? Icons.folder_rounded
                        : _iconForMime(node.mimeType),
                    color: isTrash
                        ? SpaceColors.muted
                        : node.isFolder
                        ? SpaceColors.cyan
                        : SpaceColors.violet,
                    size: 30,
                  ),
                  const Spacer(),
                  if (node.isFavorite)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.star_rounded,
                        color: SpaceColors.amber,
                        size: 18,
                      ),
                    ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: SpaceColors.cyan,
                      size: 20,
                    )
                  else
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: SpaceColors.muted,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: SpaceColors.border),
                      ),
                      color: SpaceColors.surface,
                      onSelected: (action) {
                        switch (action) {
                          case 'select':
                            ref
                                .read(selectedNodesProvider.notifier)
                                .toggle(node.uuid);
                          case 'favorite':
                            _toggleFavorite(context, ref, node);
                          case 'duplicate':
                            _duplicateNode(context, ref, node);
                          case 'restore':
                            _restoreNode(context, ref, node);
                          case 'purge':
                            _purgeNode(context, ref, node);
                          case 'details':
                            _showFileDetailsSheet(context, ref, node);
                          case 'download':
                            _downloadFile(context, ref, node);
                          case 'rename':
                            _showRenameDialog(context, ref, node);
                          case 'move':
                            _showMoveDialog(context, ref, node);
                          case 'delete':
                            _confirmDelete(context, ref, node);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'select',
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_box_outlined,
                                size: 18,
                                color: SpaceColors.cyan,
                              ),
                              SizedBox(width: 10),
                              Text('Select'),
                            ],
                          ),
                        ),
                        if (isTrash) ...[
                          const PopupMenuItem(
                            value: 'restore',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.restore_rounded,
                                  size: 18,
                                  color: SpaceColors.green,
                                ),
                                SizedBox(width: 10),
                                Text('Restore'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'purge',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_forever_rounded,
                                  size: 18,
                                  color: SpaceColors.danger,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Delete Forever',
                                  style: TextStyle(color: SpaceColors.danger),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          PopupMenuItem(
                            value: 'favorite',
                            child: Row(
                              children: [
                                Icon(
                                  node.isFavorite
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  size: 18,
                                  color: SpaceColors.amber,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  node.isFavorite
                                      ? 'Unstar'
                                      : 'Star (Favorite)',
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'duplicate',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 18,
                                  color: SpaceColors.cyan,
                                ),
                                SizedBox(width: 10),
                                Text('Make a Copy'),
                              ],
                            ),
                          ),
                          if (!node.isFolder) ...[
                            const PopupMenuItem(
                              value: 'details',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: SpaceColors.cyan,
                                  ),
                                  SizedBox(width: 10),
                                  Text('Details & Inspect'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'download',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.download_rounded,
                                    size: 18,
                                    color: SpaceColors.green,
                                  ),
                                  SizedBox(width: 10),
                                  Text('Download'),
                                ],
                              ),
                            ),
                          ],
                          const PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_rounded,
                                  size: 18,
                                  color: SpaceColors.amber,
                                ),
                                SizedBox(width: 10),
                                Text('Rename'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'move',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.drive_file_move_rounded,
                                  size: 18,
                                  color: SpaceColors.violet,
                                ),
                                SizedBox(width: 10),
                                Text('Move'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: SpaceColors.danger,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: SpaceColors.danger),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
              const Spacer(),
              Text(
                node.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  decoration: isTrash ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    node.isFolder ? 'Folder' : _formatBytes(node.sizeBytes),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: SpaceColors.surfaceLight,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: SpaceColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          node.originDevice.toLowerCase().contains('oneplus') ||
                                  node.originPlatform == 'android'
                              ? Icons.smartphone_rounded
                              : Icons.laptop_chromebook_rounded,
                          size: 10,
                          color: SpaceColors.cyan,
                        ),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 80),
                          child: Text(
                            node.originDevice,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: SpaceColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!node.isFolder && node.chunkMessageIds.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: SpaceColors.violet.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${node.chunkMessageIds.length}c',
                        style: const TextStyle(
                          fontSize: 10,
                          color: SpaceColors.violet,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFileDetailsSheet(
    BuildContext context,
    WidgetRef ref,
    SpaceNode file,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SpaceColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: SpaceColors.border),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Consumer(
              builder: (context, ref, _) {
                final dlState = ref.watch(fileDownloadProvider);
                final isCurrentFileDownloading =
                    dlState.isDownloading && dlState.fileUuid == file.uuid;

                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: SpaceColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Icon(
                            _iconForMime(file.mimeType),
                            color: SpaceColors.cyan,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              file.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _DetailLine(label: 'MIME Type', value: file.mimeType),
                      _DetailLine(
                        label: 'File Size',
                        value: _formatBytes(file.sizeBytes),
                      ),
                      _DetailLine(
                        label: 'Encrypted Chunks',
                        value:
                            '${file.chunkMessageIds.length} (IDs: ${file.chunkMessageIds.join(", ")})',
                      ),
                      _DetailLine(
                        label: 'AES-256 Nonce (IV)',
                        value: file.ivBase64 ?? 'None',
                      ),
                      _DetailLine(
                        label: 'GCM Auth Tag',
                        value: file.authTagBase64 ?? 'None',
                      ),
                      _DetailLine(
                        label: 'Last Modified',
                        value: file.updatedAt.toLocal().toString().substring(
                          0,
                          19,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (isCurrentFileDownloading) ...[
                        LinearProgressIndicator(value: dlState.progress),
                        const SizedBox(height: 8),
                        Text(
                          dlState.statusLabel,
                          style: const TextStyle(
                            color: SpaceColors.cyan,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (dlState.decryptedBytes != null &&
                          dlState.fileUuid == file.uuid) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: SpaceColors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: SpaceColors.green),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: SpaceColors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Decrypted successfully (${dlState.decryptedBytes!.length} bytes)',
                                style: const TextStyle(
                                  color: SpaceColors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (file.mimeType.startsWith('text/') ||
                            file.mimeType == 'application/json')
                          Container(
                            height: 140,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: SpaceColors.canvas,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: SpaceColors.border),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                utf8.decode(
                                  dlState.decryptedBytes!,
                                  allowMalformed: true,
                                ),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: isCurrentFileDownloading
                              ? null
                              : () => ref
                                    .read(fileDownloadProvider.notifier)
                                    .downloadAndDecrypt(file),
                          icon: const Icon(Icons.download_rounded),
                          label: Text(
                            isCurrentFileDownloading
                                ? 'Decrypting...'
                                : 'Download & Decrypt from Vault',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showTrashDetailsSheet(
    BuildContext context,
    WidgetRef ref,
    SpaceNode file,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SpaceColors.surface,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(file.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text('This file is currently in the Trash.'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SpaceColors.danger,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _purgeNode(context, ref, file);
                      },
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: const Text('Delete Forever'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _restoreNode(context, ref, file);
                      },
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Restore'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _restoreNode(
    BuildContext context,
    WidgetRef ref,
    SpaceNode node,
  ) async {
    await ref.read(spaceRepositoryProvider).restoreNode(node.uuid);
    _invalidateAll(ref);
  }

  Future<void> _purgeNode(
    BuildContext context,
    WidgetRef ref,
    SpaceNode node,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${node.name} forever?'),
        content: const Text(
          'This will permanently erase the item from your VFS map.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SpaceColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(spaceRepositoryProvider).purgeNode(node.uuid);
      _invalidateAll(ref);
    }
  }

  Future<void> _downloadFile(
    BuildContext context,
    WidgetRef ref,
    SpaceNode node,
  ) async {
    _showFileDetailsSheet(context, ref, node);
    await ref.read(fileDownloadProvider.notifier).downloadAndDecrypt(node);
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    SpaceNode node,
  ) async {
    final controller = TextEditingController(text: node.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename item'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'New name',
              prefixIcon: Icon(Icons.edit_rounded),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (newName == null ||
        newName.trim().isEmpty ||
        newName.trim() == node.name) {
      return;
    }

    await ref.read(spaceRepositoryProvider).renameNode(node.uuid, newName);
    _invalidateAll(ref);
  }

  Future<void> _showMoveDialog(
    BuildContext context,
    WidgetRef ref,
    SpaceNode node,
  ) async {
    final allNodes = await ref.read(spaceRepositoryProvider).listAllNodes();
    final folders = allNodes
        .where((n) => n.isFolder && n.uuid != node.uuid)
        .toList();

    if (!context.mounted) return;

    final targetParent = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Move to folder'),
          content: SizedBox(
            width: 320,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.home_rounded,
                    color: SpaceColors.cyan,
                  ),
                  title: const Text('Vault Root'),
                  onTap: () => Navigator.of(context).pop('root'),
                ),
                const Divider(color: SpaceColors.border),
                for (final folder in folders)
                  ListTile(
                    leading: const Icon(
                      Icons.folder_rounded,
                      color: SpaceColors.cyan,
                    ),
                    title: Text(folder.name),
                    onTap: () => Navigator.of(context).pop(folder.uuid),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (targetParent == null) return;

    final newParentUuid = targetParent == 'root' ? null : targetParent;
    await ref.read(spaceRepositoryProvider).moveNode(node.uuid, newParentUuid);
    _invalidateAll(ref);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SpaceNode node,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete ${node.name}?'),
          content: Text(
            'This will move the ${node.isFolder ? "folder and its contents" : "file"} to the Trash.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: SpaceColors.danger,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Move to Trash'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(spaceRepositoryProvider).softDelete(node.uuid);
      _invalidateAll(ref);
    }
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    SpaceNode node,
  ) async {
    await ref.read(spaceRepositoryProvider).toggleFavorite(node.uuid);
    _invalidateAll(ref);
  }

  Future<void> _duplicateNode(
    BuildContext context,
    WidgetRef ref,
    SpaceNode node,
  ) async {
    final currentParent = ref.read(currentDirectoryProvider);
    await ref
        .read(spaceRepositoryProvider)
        .duplicateNode(node.uuid, targetParentUuid: currentParent);
    _invalidateAll(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created copy of "${node.name}"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _invalidateAll(WidgetRef ref) {
    ref.invalidate(directoryNodesProvider);
    ref.invalidate(allNodesProvider);
    ref.invalidate(syncStateProvider);
    ref.invalidate(trashNodesProvider);
    ref.invalidate(favoritesNodesProvider);
    ref.invalidate(searchResultsProvider);
    ref.invalidate(vaultStatsProvider);
  }

  IconData _iconForMime(String mimeType) {
    if (mimeType.startsWith('image/')) {
      return Icons.image_rounded;
    }
    if (mimeType.startsWith('video/')) {
      return Icons.movie_rounded;
    }
    if (mimeType == 'application/pdf') {
      return Icons.picture_as_pdf_rounded;
    }
    if (mimeType == 'application/json') {
      return Icons.data_object_rounded;
    }
    if (mimeType == 'application/zip' || mimeType.contains('zip')) {
      return Icons.folder_zip_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(color: SpaceColors.muted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: SpaceColors.text,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFolder extends StatelessWidget {
  const _EmptyFolder({this.isTrash = false});

  final bool isTrash;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isTrash
                      ? Icons.delete_sweep_rounded
                      : Icons.folder_open_rounded,
                  color: SpaceColors.cyan,
                  size: 48,
                ),
                const SizedBox(height: 14),
                Text(
                  isTrash ? 'Trash is Empty' : 'No items here',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  isTrash
                      ? 'Deleted files and folders will appear here.'
                      : 'Upload files or create folders to organize your space.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

String _formatDate(DateTime dt) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

class _DriveTableView extends ConsumerWidget {
  const _DriveTableView({
    required this.nodes,
    required this.selectedUuids,
    required this.isTrash,
  });

  final List<SpaceNode> nodes;
  final Set<String> selectedUuids;
  final bool isTrash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSelected =
        nodes.isNotEmpty && selectedUuids.length == nodes.length;

    return Container(
      decoration: BoxDecoration(
        color: SpaceColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SpaceColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            // Table Header (Google Drive / shadcn styled)
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: SpaceColors.surfaceLight.withValues(alpha: 0.6),
                border: const Border(
                  bottom: BorderSide(color: SpaceColors.border),
                ),
              ),
              child: Row(
                children: [
                  // Select all checkbox
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      value: allSelected
                          ? true
                          : (selectedUuids.isNotEmpty ? null : false),
                      tristate: true,
                      onChanged: (val) {
                        if (val == true) {
                          ref
                              .read(selectedNodesProvider.notifier)
                              .selectAll(nodes.map((n) => n.uuid));
                        } else {
                          ref.read(selectedNodesProvider.notifier).clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Name header
                  const Expanded(
                    flex: 4,
                    child: Text(
                      'NAME',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: SpaceColors.muted,
                      ),
                    ),
                  ),
                  // Device Origin header
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'DEVICE ORIGIN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: SpaceColors.muted,
                      ),
                    ),
                  ),
                  // Modified date
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'LAST MODIFIED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: SpaceColors.muted,
                      ),
                    ),
                  ),
                  // Size
                  const SizedBox(
                    width: 80,
                    child: Text(
                      'SIZE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: SpaceColors.muted,
                      ),
                    ),
                  ),
                  // Security
                  const SizedBox(
                    width: 100,
                    child: Text(
                      'SECURITY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: SpaceColors.muted,
                      ),
                    ),
                  ),
                  // Actions header
                  const SizedBox(
                    width: 48,
                    child: Center(
                      child: Text('', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
            // Table Rows
            Expanded(
              child: ListView.separated(
                itemCount: nodes.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: SpaceColors.border),
                itemBuilder: (context, index) {
                  final node = nodes[index];
                  final isSelected = selectedUuids.contains(node.uuid);
                  return _DriveTableRow(
                    node: node,
                    isSelected: isSelected,
                    isTrash: isTrash,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriveTableRow extends ConsumerWidget {
  const _DriveTableRow({
    required this.node,
    required this.isSelected,
    required this.isTrash,
  });

  final SpaceNode node;
  final bool isSelected;
  final bool isTrash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAndroid =
        node.originDevice.toLowerCase().contains('oneplus') ||
        node.originPlatform == 'android';
    final isLinux =
        node.originDevice.toLowerCase().contains('ubuntu') ||
        node.originPlatform == 'linux';

    return InkWell(
      onTap: () {
        final selected = ref.read(selectedNodesProvider);
        if (selected.isNotEmpty) {
          ref.read(selectedNodesProvider.notifier).toggle(node.uuid);
          return;
        }

        if (node.isFolder) {
          context.go('/folder/${node.uuid}');
        } else {
          // Open details
          _openDetails(context, ref);
        }
      },
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: isSelected
            ? SpaceColors.cyan.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Row(
          children: [
            // Row Checkbox
            SizedBox(
              width: 40,
              child: Checkbox(
                value: isSelected,
                onChanged: (_) {
                  ref.read(selectedNodesProvider.notifier).toggle(node.uuid);
                },
              ),
            ),
            const SizedBox(width: 8),
            // Name with Mime Icon
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: node.isFolder
                          ? SpaceColors.cyan.withValues(alpha: 0.15)
                          : SpaceColors.violet.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      node.isFolder
                          ? Icons.folder_rounded
                          : _iconForMime(node.mimeType),
                      size: 18,
                      color: node.isFolder
                          ? SpaceColors.cyan
                          : SpaceColors.violet,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isTrash
                                ? SpaceColors.muted
                                : SpaceColors.text,
                            decoration: isTrash
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        Text(
                          node.isFolder
                              ? 'Folder'
                              : (node.chunkMessageIds.isNotEmpty
                                    ? '${node.chunkMessageIds.length} chunks • MTProto'
                                    : node.mimeType),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: SpaceColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Origin Device Badge
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isAndroid
                        ? SpaceColors.green.withValues(alpha: 0.12)
                        : (isLinux
                              ? SpaceColors.amber.withValues(alpha: 0.12)
                              : SpaceColors.cyan.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isAndroid
                          ? SpaceColors.green.withValues(alpha: 0.3)
                          : (isLinux
                                ? SpaceColors.amber.withValues(alpha: 0.3)
                                : SpaceColors.cyan.withValues(alpha: 0.3)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAndroid
                            ? Icons.smartphone_rounded
                            : (isLinux
                                  ? Icons.laptop_chromebook_rounded
                                  : Icons.computer_rounded),
                        size: 13,
                        color: isAndroid
                            ? SpaceColors.green
                            : (isLinux ? SpaceColors.amber : SpaceColors.cyan),
                      ),
                      const SizedBox(width: 5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Text(
                          node.originDevice,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isAndroid
                                ? SpaceColors.green
                                : (isLinux
                                      ? SpaceColors.amber
                                      : SpaceColors.cyan),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Last Modified
            Expanded(
              flex: 2,
              child: Text(
                _formatDate(node.updatedAt),
                style: const TextStyle(fontSize: 12, color: SpaceColors.muted),
              ),
            ),
            // Size
            SizedBox(
              width: 80,
              child: Text(
                node.isFolder ? '—' : _formatBytes(node.sizeBytes),
                style: const TextStyle(fontSize: 12, color: SpaceColors.text),
              ),
            ),
            // Security (Zero-Knowledge AES-256-GCM Badge)
            SizedBox(
              width: 100,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: SpaceColors.cyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 10,
                        color: SpaceColors.cyan,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'AES-256',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: SpaceColors.cyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Actions Popup
            SizedBox(
              width: 48,
              child: PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: SpaceColors.muted,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: SpaceColors.border),
                ),
                color: SpaceColors.surface,
                onSelected: (action) async {
                  final repo = ref.read(spaceRepositoryProvider);
                  switch (action) {
                    case 'star':
                      await repo.toggleFavorite(node.uuid);
                      _invalidate(ref);
                    case 'copy':
                      final parent = ref.read(currentDirectoryProvider);
                      await repo.duplicateNode(
                        node.uuid,
                        targetParentUuid: parent,
                      );
                      _invalidate(ref);
                    case 'delete':
                      if (isTrash) {
                        await repo.purgeNode(node.uuid);
                      } else {
                        await repo.softDelete(node.uuid);
                      }
                      _invalidate(ref);
                    case 'restore':
                      await repo.restoreNode(node.uuid);
                      _invalidate(ref);
                    case 'download':
                      if (!node.isFolder) {
                        await ref
                            .read(fileDownloadProvider.notifier)
                            .downloadAndDecrypt(node);
                      }
                  }
                },
                itemBuilder: (context) => [
                  if (!isTrash) ...[
                    PopupMenuItem(
                      value: 'star',
                      child: Row(
                        children: [
                          Icon(
                            node.isFavorite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 16,
                            color: SpaceColors.amber,
                          ),
                          const SizedBox(width: 8),
                          Text(node.isFavorite ? 'Unstar' : 'Star'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'copy',
                      child: Row(
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: SpaceColors.cyan,
                          ),
                          const SizedBox(width: 8),
                          Text('Duplicate'),
                        ],
                      ),
                    ),
                    if (!node.isFolder)
                      PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(
                              Icons.download_rounded,
                              size: 16,
                              color: SpaceColors.green,
                            ),
                            const SizedBox(width: 8),
                            Text('Download'),
                          ],
                        ),
                      ),
                  ] else ...[
                    PopupMenuItem(
                      value: 'restore',
                      child: Row(
                        children: [
                          Icon(
                            Icons.restore_rounded,
                            size: 16,
                            color: SpaceColors.green,
                          ),
                          const SizedBox(width: 8),
                          Text('Restore'),
                        ],
                      ),
                    ),
                  ],
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          isTrash
                              ? Icons.delete_forever_rounded
                              : Icons.delete_outline_rounded,
                          size: 16,
                          color: SpaceColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isTrash ? 'Delete forever' : 'Move to Trash',
                          style: const TextStyle(color: SpaceColors.danger),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SpaceColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: SpaceColors.border),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(node.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _DetailLine(label: 'Origin Device', value: node.originDevice),
              _DetailLine(label: 'Platform', value: node.originPlatform),
              _DetailLine(label: 'MIME Type', value: node.mimeType),
              _DetailLine(label: 'Size', value: _formatBytes(node.sizeBytes)),
              _DetailLine(
                label: 'Encryption',
                value: 'Zero-Knowledge AES-256-GCM',
              ),
              _DetailLine(
                label: 'Encrypted Chunks',
                value: '${node.chunkMessageIds.length} MTProto chunks',
              ),
              _DetailLine(
                label: 'Last Modified',
                value: _formatDate(node.updatedAt),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref
                        .read(fileDownloadProvider.notifier)
                        .downloadAndDecrypt(node);
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download & Decrypt'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _invalidate(WidgetRef ref) {
    ref.invalidate(directoryNodesProvider);
    ref.invalidate(allNodesProvider);
    ref.invalidate(trashNodesProvider);
    ref.invalidate(favoritesNodesProvider);
    ref.invalidate(vaultStatsProvider);
    ref.invalidate(registeredDevicesProvider);
  }
}

IconData _iconForMime(String mimeType) {
  if (mimeType.startsWith('image/')) {
    return Icons.image_rounded;
  }
  if (mimeType.startsWith('video/')) {
    return Icons.movie_rounded;
  }
  if (mimeType == 'application/pdf') {
    return Icons.picture_as_pdf_rounded;
  }
  if (mimeType == 'application/json') {
    return Icons.data_object_rounded;
  }
  if (mimeType == 'application/zip' || mimeType.contains('zip')) {
    return Icons.folder_zip_rounded;
  }
  return Icons.insert_drive_file_rounded;
}
