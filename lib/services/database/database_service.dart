import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/space_node.dart';
import '../../models/sync_state.dart';
import '../device/device_service.dart';

enum SortField { name, dateModified, size, type }

enum SortOrder { ascending, descending }

class FolderStats {
  const FolderStats({
    required this.folderUuid,
    required this.totalFiles,
    required this.totalFolders,
    required this.totalBytes,
    required this.mimeBreakdown,
  });

  final String? folderUuid;
  final int totalFiles;
  final int totalFolders;
  final int totalBytes;
  final Map<String, int> mimeBreakdown;
}

class VaultStats {
  const VaultStats({
    required this.totalFiles,
    required this.totalFolders,
    required this.totalBytes,
    required this.trashBytes,
    required this.trashCount,
    required this.favoritesCount,
    required this.mimeBreakdown,
  });

  final int totalFiles;
  final int totalFolders;
  final int totalBytes;
  final int trashBytes;
  final int trashCount;
  final int favoritesCount;
  final Map<String, int> mimeBreakdown;
}

abstract class LocalDatabaseService {
  Future<void> initialize();
  Future<List<SpaceNode>> listChildren(
    String? parentUuid, {
    SortField sortBy = SortField.name,
    SortOrder sortOrder = SortOrder.ascending,
  });
  Future<List<SpaceNode>> listAllNodes();
  Future<List<SpaceNode>> searchNodes(
    String query, {
    SortField sortBy = SortField.name,
    SortOrder sortOrder = SortOrder.ascending,
  });
  Future<List<SpaceNode>> filterByMime(String mimeCategory);
  Future<List<SpaceNode>> filterByMimeCategory(
    String category, {
    SortField sortBy = SortField.name,
    SortOrder sortOrder = SortOrder.ascending,
  });
  Future<SpaceNode?> findNode(String uuid);
  Future<List<SpaceNode>> getBreadcrumbs(String? leafUuid);
  Future<SpaceNode> createFolder(String name, String? parentUuid);
  Future<void> renameNode(String uuid, String newName);
  Future<void> moveNode(String uuid, String? newParentUuid);
  Future<void> moveBatch(List<String> uuids, String? newParentUuid);
  Future<SpaceNode> duplicateNode(String uuid, {String? targetParentUuid});
  Future<List<SpaceNode>> copyBatch(
    List<String> uuids,
    String? targetParentUuid,
  );
  Future<void> toggleFavorite(String uuid);
  Future<List<SpaceNode>> listFavorites({
    SortField sortBy = SortField.name,
    SortOrder sortOrder = SortOrder.ascending,
  });
  Future<void> addTag(String uuid, String tag);
  Future<void> removeTag(String uuid, String tag);
  Future<List<SpaceNode>> filterByDevice(
    String deviceName, {
    SortField sortBy = SortField.name,
    SortOrder sortOrder = SortOrder.ascending,
  });
  Future<List<String>> listRegisteredDevices();
  Future<FolderStats> getFolderStats(String? folderUuid);
  Future<VaultStats> getVaultStats();
  Future<void> upsertNode(SpaceNode node);
  Future<void> softDelete(String uuid);
  Future<void> softDeleteBatch(List<String> uuids);
  Future<List<SpaceNode>> listTrashNodes();
  Future<void> restoreNode(String uuid);
  Future<void> purgeNode(String uuid);
  Future<void> emptyTrash();
  Future<String> resolveUniqueName(String baseName, String? parentUuid);
  Future<SyncState> exportSyncState();
  Future<void> importSyncState(SyncState state);
  Future<void> clearAll();
}

class DatabaseService implements LocalDatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  final Map<String, SpaceNode> _nodes = {};
  final String _deviceId = const Uuid().v4();
  final StreamController<void> _changes = StreamController<void>.broadcast();
  bool _initialized = false;

  Stream<void> get changes => _changes.stream;

  @override
  Future<void> initialize() async {
    if (_initialized && _nodes.isNotEmpty) {
      return;
    }

    final loaded = await _loadFromDisk();
    if (loaded && _nodes.isNotEmpty) {
      _initialized = true;
      return;
    }

    final now = DateTime.now().toUtc();
    final photos = SpaceNode(
      name: 'Photos',
      parentUuid: null,
      mimeType: 'inode/directory',
      isFolder: true,
      sizeBytes: 0,
      chunkMessageIds: const [],
      createdAt: now,
      updatedAt: now,
    );
    final documents = SpaceNode(
      name: 'Documents',
      parentUuid: null,
      mimeType: 'inode/directory',
      isFolder: true,
      sizeBytes: 0,
      chunkMessageIds: const [],
      createdAt: now,
      updatedAt: now,
    );
    final videos = SpaceNode(
      name: 'Videos',
      parentUuid: null,
      mimeType: 'inode/directory',
      isFolder: true,
      sizeBytes: 0,
      chunkMessageIds: const [],
      createdAt: now,
      updatedAt: now,
    );
    final syncContract = SpaceNode(
      name: 'sync_state.contract.json',
      parentUuid: documents.uuid,
      mimeType: 'application/json',
      isFolder: false,
      sizeBytes: 2480,
      chunkMessageIds: const [1042],
      ivBase64: 'demo-iv-placeholder',
      authTagBase64: 'demo-tag-placeholder',
      createdAt: now,
      updatedAt: now,
    );

    for (final node in [photos, documents, videos, syncContract]) {
      _nodes[node.uuid] = node;
    }
    _initialized = true;
    await _persistToDisk();
  }

  @override
  Future<SpaceNode?> findNode(String uuid) async {
    return _nodes[uuid];
  }

  @override
  Future<List<SpaceNode>> getBreadcrumbs(String? leafUuid) async {
    if (leafUuid == null || leafUuid.isEmpty) {
      return const [];
    }

    final trail = <SpaceNode>[];
    String? currentUuid = leafUuid;

    while (currentUuid != null) {
      final node = _nodes[currentUuid];
      if (node == null || node.isDeleted) {
        break;
      }
      trail.insert(0, node);
      currentUuid = node.parentUuid;
    }

    return trail;
  }

  @override
  Future<List<SpaceNode>> listChildren(
    String? parentUuid, {
    SortField sortBy = SortField.name,
    SortOrder sortOrder = SortOrder.ascending,
  }) async {
    final nodes = _nodes.values
        .where((node) => node.parentUuid == parentUuid && !node.isDeleted)
        .toList();

    return _sortNodes(nodes, sortBy, sortOrder);
  }

  @override
  Future<List<SpaceNode>> listAllNodes() async {
    return _nodes.values
        .where((node) => !node.isDeleted)
        .sortedBy((node) => node.name.toLowerCase())
        .toList();
  }

  @override
  Future<List<SpaceNode>> searchNodes(
    String query, {
    SortField sortBy = SortField.name,
    SortOrder sortOrder = SortOrder.ascending,
  }) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      return listAllNodes();
    }
    final matches = _nodes.values
        .where(
          (node) =>
              !node.isDeleted && node.name.toLowerCase().contains(cleanQuery),
        )
        .toList();

    return _sortNodes(matches, sortBy, sortOrder);
  }

  @override
  Future<List<SpaceNode>> filterByMime(String mimeCategory) async {
    final category = mimeCategory.trim().toLowerCase();
    return _nodes.values
        .where(
          (node) =>
              !node.isDeleted &&
              !node.isFolder &&
              node.mimeType.toLowerCase().contains(category),
        )
        .sortedBy((node) => node.name.toLowerCase())
        .toList();
  }

  @override
  Future<List<SpaceNode>> filterByMimeCategory(
    String category, {
    SortField sortBy = SortField.name,
    SortOrder sortOrder = SortOrder.ascending,
  }) async {
    final cat = category.trim().toLowerCase();
    if (cat.isEmpty || cat == 'all') {
      final list = _nodes.values
          .where((n) => !n.isDeleted && !n.isFolder)
          .toList();
      return _sortNodes(list, sortBy, sortOrder);
    }

    final filtered = _nodes.values.where((node) {
      if (node.isDeleted || node.isFolder) return false;
      final m = node.mimeType.toLowerCase();
      final n = node.name.toLowerCase();

      switch (cat) {
        case 'photos':
        case 'images':
          return m.startsWith('image/') ||
              n.endsWith('.png') ||
              n.endsWith('.jpg') ||
              n.endsWith('.jpeg') ||
              n.endsWith('.webp') ||
              n.endsWith('.gif');
        case 'videos':
          return m.startsWith('video/') ||
              n.endsWith('.mp4') ||
              n.endsWith('.mkv') ||
              n.endsWith('.mov') ||
              n.endsWith('.avi');
        case 'documents':
          return m.contains('pdf') ||
              m.contains('text') ||
              m.contains('json') ||
              m.contains('document') ||
              m.contains('sheet') ||
              n.endsWith('.pdf') ||
              n.endsWith('.txt') ||
              n.endsWith('.doc') ||
              n.endsWith('.docx') ||
              n.endsWith('.xls') ||
              n.endsWith('.xlsx') ||
              n.endsWith('.json');
        case 'archives':
          return m.contains('zip') ||
              m.contains('tar') ||
              m.contains('rar') ||
              m.contains('7z') ||
              n.endsWith('.zip') ||
              n.endsWith('.tar') ||
              n.endsWith('.gz') ||
              n.endsWith('.7z');
        case 'others':
          final isImg = m.startsWith('image/');
          final isVid = m.startsWith('video/');
          final isDoc =
              m.contains('pdf') || m.contains('text') || m.contains('json');
          final isArch = m.contains('zip') || m.contains('tar');
          return !isImg && !isVid && !isDoc && !isArch;
        default:
          return m.contains(cat);
      }
    }).toList();

    return _sortNodes(filtered, sortBy, sortOrder);
  }

  @override
  Future<SpaceNode> createFolder(String name, String? parentUuid) async {
    final uniqueName = await resolveUniqueName(name.trim(), parentUuid);
    final now = DateTime.now().toUtc();
    final folder = SpaceNode(
      name: uniqueName,
      parentUuid: parentUuid,
      mimeType: 'inode/directory',
      isFolder: true,
      sizeBytes: 0,
      chunkMessageIds: const [],
      originDevice: DeviceService.instance.currentDeviceName,
      originPlatform: DeviceService.instance.currentPlatform,
      createdAt: now,
      updatedAt: now,
    );
    _nodes[folder.uuid] = folder;
    _changes.add(null);
    await _persistToDisk();
    return folder;
  }

  @override
  Future<void> renameNode(String uuid, String newName) async {
    final node = _nodes[uuid];
    if (node == null) return;
    _nodes[uuid] = node.copyWith(
      name: newName.trim(),
      updatedAt: DateTime.now().toUtc(),
    );
    _changes.add(null);
    await _persistToDisk();
  }

  @override
  Future<void> moveNode(String uuid, String? newParentUuid) async {
    final node = _nodes[uuid];
    if (node == null) return;
    if (node.isFolder && newParentUuid != null) {
      if (_isDescendantOf(newParentUuid, uuid)) return;
    }
    _nodes[uuid] = node.copyWith(
      parentUuid: newParentUuid,
      updatedAt: DateTime.now().toUtc(),
    );
    _changes.add(null);
    await _persistToDisk();
  }

  @override
  Future<void> moveBatch(List<String> uuids, String? newParentUuid) async {
    final now = DateTime.now().toUtc();
    for (final uuid in uuids) {
      final node = _nodes[uuid];
      if (node == null) continue;
      if (node.isFolder && newParentUuid != null) {
        if (_isDescendantOf(newParentUuid, uuid)) continue;
      }
      _nodes[uuid] = node.copyWith(parentUuid: newParentUuid, updatedAt: now);
    }
    _changes.add(null);
    await _persistToDisk();
  }

  @override
  Future<SpaceNode> duplicateNode(
    String uuid, {
    String? targetParentUuid,
  }) async {
    final original = _nodes[uuid];
    if (original == null) {
      throw ArgumentError('Node with uuid $uuid not found');
    }

    final parent = targetParentUuid ?? original.parentUuid;
    final now = DateTime.now().toUtc();
    final uniqueName = await resolveUniqueName(
      '${original.name} (Copy)',
      parent,
    );

    final clone = SpaceNode(
      name: uniqueName,
      parentUuid: parent,
      mimeType: original.mimeType,
      isFolder: original.isFolder,
      sizeBytes: original.sizeBytes,
      chunkMessageIds: List<int>.from(original.chunkMessageIds),
      ivBase64: original.ivBase64,
      authTagBase64: original.authTagBase64,
      isFavorite: original.isFavorite,
      tags: List<String>.from(original.tags),
      originDevice: DeviceService.instance.currentDeviceName,
      originPlatform: DeviceService.instance.currentPlatform,
      createdAt: now,
      updatedAt: now,
    );
    _nodes[clone.uuid] = clone;

    if (original.isFolder) {
      await _duplicateChildrenRecursively(original.uuid, clone.uuid);
    }

    _changes.add(null);
    await _persistToDisk();
    return clone;
  }

  Future<void> _duplicateChildrenRecursively(
    String oldParentUuid,
    String newParentUuid,
  ) async {
    final children = _nodes.values
        .where((n) => n.parentUuid == oldParentUuid && !n.isDeleted)
        .toList();
    final now = DateTime.now().toUtc();
    for (final child in children) {
      final childClone = SpaceNode(
        name: child.name,
        parentUuid: newParentUuid,
        mimeType: child.mimeType,
        isFolder: child.isFolder,
        sizeBytes: child.sizeBytes,
        chunkMessageIds: List<int>.from(child.chunkMessageIds),
        ivBase64: child.ivBase64,
        authTagBase64: child.authTagBase64,
        isFavorite: child.isFavorite,
        tags: List<String>.from(child.tags),
        originDevice: DeviceService.instance.currentDeviceName,
        originPlatform: DeviceService.instance.currentPlatform,
        createdAt: now,
        updatedAt: now,
      );
      _nodes[childClone.uuid] = childClone;
      if (child.isFolder) {
        await _duplicateChildrenRecursively(child.uuid, childClone.uuid);
      }
    }
  }

  @override
  Future<List<SpaceNode>> copyBatch(
    List<String> uuids,
    String? targetParentUuid,
  ) async {
    final copied = <SpaceNode>[];
    for (final uuid in uuids) {
      if (_nodes.containsKey(uuid)) {
        copied.add(
          await duplicateNode(uuid, targetParentUuid: targetParentUuid),
        );
      }
    }
    return copied;
  }

  @override
  Future<void> toggleFavorite(String uuid) async {
    final node = _nodes[uuid];
    if (node == null) return;
    _nodes[uuid] = node.copyWith(
      isFavorite: !node.isFavorite,
      updatedAt: DateTime.now().toUtc(),
    );
    _changes.add(null);
    await _persistToDisk();
  }

  @override
  Future<List<SpaceNode>> listFavorites({
    SortField sortBy = SortField.name,
    SortOrder sortOrder = SortOrder.ascending,
  }) async {
    final favs = _nodes.values
        .where((n) => !n.isDeleted && n.isFavorite)
        .toList();
    return _sortNodes(favs, sortBy, sortOrder);
  }

  @override
  Future<void> addTag(String uuid, String tag) async {
    final node = _nodes[uuid];
    if (node == null) return;
    final trimmed = tag.trim();
    if (trimmed.isEmpty || node.tags.contains(trimmed)) return;
    _nodes[uuid] = node.copyWith(
      tags: [...node.tags, trimmed],
      updatedAt: DateTime.now().toUtc(),
    );
    _changes.add(null);
    await _persistToDisk();
  }

  @override
  Future<void> removeTag(String uuid, String tag) async {
    final node = _nodes[uuid];
    if (node == null) return;
    final trimmed = tag.trim();
    if (!node.tags.contains(trimmed)) return;
    _nodes[uuid] = node.copyWith(
      tags: node.tags.where((t) => t != trimmed).toList(),
      updatedAt: DateTime.now().toUtc(),
    );
    _changes.add(null);
    await _persistToDisk();
  }

  @override
  Future<List<SpaceNode>> filterByDevice(
    String deviceName, {
    SortField sortBy = SortField.name,
    SortOrder sortOrder = SortOrder.ascending,
  }) async {
    final filtered = _nodes.values
        .where(
          (n) =>
              !n.isDeleted &&
              n.originDevice.toLowerCase() == deviceName.toLowerCase(),
        )
        .toList();
    return _sortNodes(filtered, sortBy, sortOrder);
  }

  @override
  Future<List<String>> listRegisteredDevices() async {
    final devices = <String>{};
    for (final node in _nodes.values) {
      if (node.originDevice.isNotEmpty &&
          node.originDevice != 'Local Workspace') {
        devices.add(node.originDevice);
      }
    }
    devices.add(DeviceService.instance.currentDeviceName);
    return devices.toList();
  }

  @override
  Future<FolderStats> getFolderStats(String? folderUuid) async {
    int totalFiles = 0;
    int totalFolders = 0;
    int totalBytes = 0;
    final Map<String, int> mimeBreakdown = {};

    void collectRecursively(String? parentId) {
      final children = _nodes.values.where(
        (n) => n.parentUuid == parentId && !n.isDeleted,
      );
      for (final child in children) {
        if (child.isFolder) {
          totalFolders++;
          collectRecursively(child.uuid);
        } else {
          totalFiles++;
          totalBytes += child.sizeBytes;
          final category = _resolveCategory(child.mimeType);
          mimeBreakdown[category] =
              (mimeBreakdown[category] ?? 0) + child.sizeBytes;
        }
      }
    }

    collectRecursively(folderUuid);

    return FolderStats(
      folderUuid: folderUuid,
      totalFiles: totalFiles,
      totalFolders: totalFolders,
      totalBytes: totalBytes,
      mimeBreakdown: mimeBreakdown,
    );
  }

  @override
  Future<VaultStats> getVaultStats() async {
    int totalFiles = 0;
    int totalFolders = 0;
    int totalBytes = 0;
    int trashBytes = 0;
    int trashCount = 0;
    int favoritesCount = 0;
    final Map<String, int> mimeBreakdown = {};

    for (final node in _nodes.values) {
      if (node.isDeleted) {
        trashCount++;
        trashBytes += node.sizeBytes;
        continue;
      }
      if (node.isFavorite) {
        favoritesCount++;
      }
      if (node.isFolder) {
        totalFolders++;
      } else {
        totalFiles++;
        totalBytes += node.sizeBytes;
        final category = _resolveCategory(node.mimeType);
        mimeBreakdown[category] =
            (mimeBreakdown[category] ?? 0) + node.sizeBytes;
      }
    }

    return VaultStats(
      totalFiles: totalFiles,
      totalFolders: totalFolders,
      totalBytes: totalBytes,
      trashBytes: trashBytes,
      trashCount: trashCount,
      favoritesCount: favoritesCount,
      mimeBreakdown: mimeBreakdown,
    );
  }

  String _resolveCategory(String mime) {
    final lower = mime.toLowerCase();
    if (lower.startsWith('image/')) {
      return 'Images';
    }
    if (lower.startsWith('video/') || lower.startsWith('audio/')) {
      return 'Media';
    }
    if (lower.contains('pdf') ||
        lower.contains('text') ||
        lower.contains('doc') ||
        lower.contains('sheet') ||
        lower.contains('presentation') ||
        lower.contains('json')) {
      return 'Documents';
    }
    return 'Other';
  }

  @override
  Future<void> upsertNode(SpaceNode node) async {
    _nodes[node.uuid] = node;
    _changes.add(null);
    await _persistToDisk();
  }

  @override
  Future<void> softDelete(String uuid) async {
    final node = _nodes[uuid];
    if (node == null) return;
    final now = DateTime.now().toUtc();
    _nodes[uuid] = node.copyWith(isDeleted: true, updatedAt: now);
    if (node.isFolder) {
      _softDeleteChildrenRecursively(uuid, now);
    }
    _changes.add(null);
    await _persistToDisk();
  }

  @override
  Future<void> softDeleteBatch(List<String> uuids) async {
    final now = DateTime.now().toUtc();
    for (final uuid in uuids) {
      final node = _nodes[uuid];
      if (node == null) continue;
      _nodes[uuid] = node.copyWith(isDeleted: true, updatedAt: now);
      if (node.isFolder) {
        _softDeleteChildrenRecursively(uuid, now);
      }
    }
    _changes.add(null);
    await _persistToDisk();
  }

  void _softDeleteChildrenRecursively(String parentUuid, DateTime timestamp) {
    for (final child in _nodes.values.where(
      (n) => n.parentUuid == parentUuid,
    )) {
      _nodes[child.uuid] = child.copyWith(
        isDeleted: true,
        updatedAt: timestamp,
      );
      if (child.isFolder) {
        _softDeleteChildrenRecursively(child.uuid, timestamp);
      }
    }
  }

  @override
  Future<List<SpaceNode>> listTrashNodes() async {
    return _nodes.values
        .where((node) => node.isDeleted)
        .sorted((a, b) => b.updatedAt.compareTo(a.updatedAt))
        .toList();
  }

  @override
  Future<void> restoreNode(String uuid) async {
    final node = _nodes[uuid];
    if (node == null) return;

    String? parentUuid = node.parentUuid;
    if (parentUuid != null) {
      final parent = _nodes[parentUuid];
      if (parent == null || parent.isDeleted) {
        parentUuid = null; // Move to root if parent folder was deleted/removed
      }
    }

    final now = DateTime.now().toUtc();
    _nodes[uuid] = node.copyWith(
      isDeleted: false,
      parentUuid: parentUuid,
      updatedAt: now,
    );
    _changes.add(null);
    await _persistToDisk();
  }

  @override
  Future<void> purgeNode(String uuid) async {
    final node = _nodes[uuid];
    if (node == null) return;
    if (node.isFolder) {
      _purgeChildrenRecursively(uuid);
    }
    _nodes.remove(uuid);
    _changes.add(null);
    await _persistToDisk();
  }

  void _purgeChildrenRecursively(String parentUuid) {
    final childUuids = _nodes.values
        .where((n) => n.parentUuid == parentUuid)
        .map((n) => n.uuid)
        .toList();
    for (final childUuid in childUuids) {
      _purgeChildrenRecursively(childUuid);
      _nodes.remove(childUuid);
    }
  }

  @override
  Future<void> emptyTrash() async {
    final deletedUuids = _nodes.values
        .where((n) => n.isDeleted)
        .map((n) => n.uuid)
        .toList();
    for (final id in deletedUuids) {
      _nodes.remove(id);
    }
    _changes.add(null);
    await _persistToDisk();
  }

  @override
  Future<String> resolveUniqueName(String baseName, String? parentUuid) async {
    final existingNames = _nodes.values
        .where((n) => n.parentUuid == parentUuid && !n.isDeleted)
        .map((n) => n.name.toLowerCase())
        .toSet();

    if (!existingNames.contains(baseName.toLowerCase())) {
      return baseName;
    }

    final lastDot = baseName.lastIndexOf('.');
    final nameWithoutExt = lastDot > 0
        ? baseName.substring(0, lastDot)
        : baseName;
    final ext = lastDot > 0 ? baseName.substring(lastDot) : '';

    var counter = 1;
    while (true) {
      final candidate = '$nameWithoutExt ($counter)$ext';
      if (!existingNames.contains(candidate.toLowerCase())) {
        return candidate;
      }
      counter++;
    }
  }

  bool _isDescendantOf(String targetUuid, String potentialAncestorUuid) {
    String? current = targetUuid;
    while (current != null) {
      if (current == potentialAncestorUuid) return true;
      current = _nodes[current]?.parentUuid;
    }
    return false;
  }

  List<SpaceNode> _sortNodes(
    List<SpaceNode> nodes,
    SortField sortBy,
    SortOrder sortOrder,
  ) {
    final isAsc = sortOrder == SortOrder.ascending;
    return nodes.sorted((a, b) {
      // Folders always appear first
      if (a.isFolder != b.isFolder) {
        return a.isFolder ? -1 : 1;
      }

      int comparison;
      switch (sortBy) {
        case SortField.name:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case SortField.dateModified:
          comparison = a.updatedAt.compareTo(b.updatedAt);
        case SortField.size:
          comparison = a.sizeBytes.compareTo(b.sizeBytes);
        case SortField.type:
          comparison = a.mimeType.compareTo(b.mimeType);
      }

      return isAsc ? comparison : -comparison;
    });
  }

  @override
  Future<SyncState> exportSyncState() async {
    return SyncState(
      schemaVersion: 1,
      exportedAt: DateTime.now().toUtc(),
      deviceId: _deviceId,
      channelId: 'spacehere-private-vault',
      nodes: _nodes.values.sortedBy((node) => node.uuid).toList(),
    );
  }

  @override
  Future<void> importSyncState(SyncState state) async {
    for (final incoming in state.nodes) {
      final local = _nodes[incoming.uuid];
      if (local == null || incoming.updatedAt.isAfter(local.updatedAt)) {
        _nodes[incoming.uuid] = incoming;
      }
    }
    _changes.add(null);
    await _persistToDisk();
  }

  @override
  Future<void> clearAll() async {
    _nodes.clear();
    _changes.add(null);
    await _persistToDisk();
  }

  Future<File?> _getLocalFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/spacehere_vfs.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistToDisk() async {
    try {
      final file = await _getLocalFile();
      if (file == null) return;
      final map = _nodes.map((k, v) => MapEntry(k, v.toJson()));
      await file.writeAsString(jsonEncode(map));
    } catch (_) {
      // Fallback silently if unsupported on test/web
    }
  }

  Future<bool> _loadFromDisk() async {
    try {
      final file = await _getLocalFile();
      if (file == null || !await file.exists()) return false;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return false;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _nodes.clear();
      for (final entry in map.entries) {
        _nodes[entry.key] = SpaceNode.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
      return _nodes.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
