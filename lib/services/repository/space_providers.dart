import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/logging/logger_service.dart';

import '../../models/queue_state.dart';
import '../../models/space_node.dart';
import '../../models/sync_state.dart';
import '../crypto/aes_encryption_service.dart';
import '../database/database_service.dart';
import '../network/telegram_service.dart';
import 'space_repository.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final databaseServiceProvider = Provider<LocalDatabaseService>((ref) {
  return DatabaseService.instance;
});

final telegramServiceProvider = Provider<TelegramService>((ref) {
  return TelegramService.instance;
});

final encryptionServiceProvider = Provider<AesEncryptionService>((ref) {
  return AesEncryptionService();
});

final spaceRepositoryProvider = Provider<SpaceRepository>((ref) {
  return SpaceRepository(
    databaseService: ref.watch(databaseServiceProvider),
    telegramService: ref.watch(telegramServiceProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

final currentDirectoryProvider =
    NotifierProvider<CurrentDirectoryController, String?>(
      CurrentDirectoryController.new,
    );

class CurrentDirectoryController extends Notifier<String?> {
  @override
  String? build() => null;

  void open(String? uuid) {
    state = uuid;
  }

  void setDirectory(String? uuid) {
    state = uuid;
  }
}

final sortFieldProvider = NotifierProvider<SortFieldNotifier, SortField>(
  SortFieldNotifier.new,
);

class SortFieldNotifier extends Notifier<SortField> {
  @override
  SortField build() => SortField.name;

  void setSortField(SortField field) {
    state = field;
  }
}

final sortOrderProvider = NotifierProvider<SortOrderNotifier, SortOrder>(
  SortOrderNotifier.new,
);

class SortOrderNotifier extends Notifier<SortOrder> {
  @override
  SortOrder build() => SortOrder.ascending;

  void toggle() {
    state = state == SortOrder.ascending
        ? SortOrder.descending
        : SortOrder.ascending;
  }

  void setOrder(SortOrder order) {
    state = order;
  }
}

enum DriveViewMode { grid, table }

final driveViewModeProvider =
    NotifierProvider<DriveViewModeNotifier, DriveViewMode>(
      DriveViewModeNotifier.new,
    );

class DriveViewModeNotifier extends Notifier<DriveViewMode> {
  @override
  DriveViewMode build() => DriveViewMode.grid;

  void setMode(DriveViewMode mode) {
    state = mode;
  }

  void toggle() {
    state = state == DriveViewMode.grid
        ? DriveViewMode.table
        : DriveViewMode.grid;
  }
}

final activeDeviceFilterProvider =
    NotifierProvider<ActiveDeviceFilterNotifier, String?>(
      ActiveDeviceFilterNotifier.new,
    );

class ActiveDeviceFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setDevice(String? device) {
    state = device;
  }
}

final selectedNodesProvider =
    NotifierProvider<SelectedNodesNotifier, Set<String>>(
      SelectedNodesNotifier.new,
    );

class SelectedNodesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void toggle(String uuid) {
    final next = Set<String>.from(state);
    if (next.contains(uuid)) {
      next.remove(uuid);
    } else {
      next.add(uuid);
    }
    state = next;
  }

  void selectAll(Iterable<String> uuids) {
    state = Set<String>.from(uuids);
  }

  void clear() {
    state = <String>{};
  }
}

final directoryNodesProvider = FutureProvider<List<SpaceNode>>((ref) async {
  final parentUuid = ref.watch(currentDirectoryProvider);
  final sortBy = ref.watch(sortFieldProvider);
  final sortOrder = ref.watch(sortOrderProvider);
  final repository = ref.watch(spaceRepositoryProvider);
  return repository.listChildren(
    parentUuid,
    sortBy: sortBy,
    sortOrder: sortOrder,
  );
});

final allNodesProvider = FutureProvider<List<SpaceNode>>((ref) async {
  final repository = ref.watch(spaceRepositoryProvider);
  return repository.listAllNodes();
});

final trashNodesProvider = FutureProvider<List<SpaceNode>>((ref) async {
  final repository = ref.watch(spaceRepositoryProvider);
  return repository.listTrashNodes();
});

final favoritesNodesProvider = FutureProvider<List<SpaceNode>>((ref) async {
  final sortBy = ref.watch(sortFieldProvider);
  final sortOrder = ref.watch(sortOrderProvider);
  final repository = ref.watch(spaceRepositoryProvider);
  return repository.listFavorites(sortBy: sortBy, sortOrder: sortOrder);
});

final folderStatsProvider = FutureProvider.family<FolderStats, String?>((
  ref,
  folderUuid,
) async {
  final repository = ref.watch(spaceRepositoryProvider);
  return repository.getFolderStats(folderUuid);
});

final vaultStatsProvider = FutureProvider<VaultStats>((ref) async {
  final repository = ref.watch(spaceRepositoryProvider);
  return repository.getVaultStats();
});

final registeredDevicesProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(spaceRepositoryProvider);
  return repository.listRegisteredDevices();
});

final deviceNodesProvider = FutureProvider.family<List<SpaceNode>, String>((
  ref,
  deviceName,
) async {
  final sortBy = ref.watch(sortFieldProvider);
  final sortOrder = ref.watch(sortOrderProvider);
  final repository = ref.watch(spaceRepositoryProvider);
  return repository.filterByDevice(
    deviceName,
    sortBy: sortBy,
    sortOrder: sortOrder,
  );
});

final syncStateProvider = FutureProvider<SyncState>((ref) async {
  final repository = ref.watch(spaceRepositoryProvider);
  return repository.exportSyncState();
});

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }
}

final categoryFilterProvider = NotifierProvider<CategoryFilterNotifier, String>(
  CategoryFilterNotifier.new,
);

class CategoryFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setCategory(String category) {
    state = category;
  }
}

final folderBreadcrumbsProvider =
    FutureProvider.family<List<SpaceNode>, String?>((ref, leafUuid) async {
      final repo = ref.watch(spaceRepositoryProvider);
      return repo.getBreadcrumbs(leafUuid);
    });

final categoryNodesProvider = FutureProvider.family<List<SpaceNode>, String>((
  ref,
  category,
) async {
  final repo = ref.watch(spaceRepositoryProvider);
  final sortBy = ref.watch(sortFieldProvider);
  final sortOrder = ref.watch(sortOrderProvider);
  return repo.filterByMimeCategory(
    category,
    sortBy: sortBy,
    sortOrder: sortOrder,
  );
});

final searchResultsProvider = FutureProvider<List<SpaceNode>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final sortBy = ref.watch(sortFieldProvider);
  final sortOrder = ref.watch(sortOrderProvider);
  final repo = ref.watch(spaceRepositoryProvider);
  return repo.searchNodes(query, sortBy: sortBy, sortOrder: sortOrder);
});

class DownloadProgressState {
  const DownloadProgressState({
    required this.isDownloading,
    required this.fileUuid,
    required this.fileName,
    required this.progress,
    required this.statusLabel,
    this.decryptedBytes,
    this.error,
  });

  const DownloadProgressState.idle()
    : isDownloading = false,
      fileUuid = null,
      fileName = null,
      progress = 0,
      statusLabel = '',
      decryptedBytes = null,
      error = null;

  final bool isDownloading;
  final String? fileUuid;
  final String? fileName;
  final double progress;
  final String statusLabel;
  final Uint8List? decryptedBytes;
  final String? error;
}

final fileDownloadProvider =
    NotifierProvider<FileDownloadNotifier, DownloadProgressState>(
      FileDownloadNotifier.new,
    );

class FileDownloadNotifier extends Notifier<DownloadProgressState> {
  @override
  DownloadProgressState build() => const DownloadProgressState.idle();

  Future<Uint8List?> downloadAndDecrypt(SpaceNode node) async {
    state = DownloadProgressState(
      isDownloading: true,
      fileUuid: node.uuid,
      fileName: node.name,
      progress: 0.05,
      statusLabel: 'Starting download...',
    );

    try {
      final repo = ref.read(spaceRepositoryProvider);
      final bytes = await repo.downloadAndDecryptFile(
        node: node,
        onProgress: (progress, status) {
          state = DownloadProgressState(
            isDownloading: true,
            fileUuid: node.uuid,
            fileName: node.name,
            progress: progress,
            statusLabel: status,
          );
        },
      );

      state = DownloadProgressState(
        isDownloading: false,
        fileUuid: node.uuid,
        fileName: node.name,
        progress: 1.0,
        statusLabel: 'Completed',
        decryptedBytes: bytes,
      );

      return bytes;
    } catch (e) {
      state = DownloadProgressState(
        isDownloading: false,
        fileUuid: node.uuid,
        fileName: node.name,
        progress: 0,
        statusLabel: 'Failed',
        error: e.toString(),
      );
      return null;
    }
  }

  void reset() {
    state = const DownloadProgressState.idle();
  }
}

final uploadQueueProvider =
    AsyncNotifierProvider<UploadQueueNotifier, QueueState>(
      UploadQueueNotifier.new,
    );

class UploadQueueNotifier extends AsyncNotifier<QueueState> {
  @override
  Future<QueueState> build() async => const QueueState.idle();

  Future<void> pickAndUpload(String? parentUuid) async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final files = <SelectedFilePayload>[];
      for (final file in result.files) {
        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null) {
          final ioFile = File(file.path!);
          if (await ioFile.exists()) {
            bytes = await ioFile.readAsBytes();
          }
        }
        if (bytes == null) {
          LoggerService.instance.warning(
            'UploadQueue',
            'Could not read bytes for selected file: ${file.name}',
          );
          continue;
        }

        files.add(
          SelectedFilePayload(
            name: file.name,
            mimeType: _guessMimeType(file.name),
            sizeBytes: file.size > 0 ? file.size : bytes.length,
            bytes: bytes,
          ),
        );
      }

      if (files.isEmpty) return;

      final repository = ref.read(spaceRepositoryProvider);

      state = const AsyncData(QueueState.idle());
      await repository.uploadFiles(
        files: files,
        parentUuid: parentUuid,
        onQueueState: (queueState) {
          state = AsyncData(queueState);
        },
      );
    } catch (e, st) {
      LoggerService.instance.error(
        'UploadQueue',
        'Failed to complete pickAndUpload',
        error: e,
        stackTrace: st,
      );
      state = AsyncData(
        QueueState(
          isUploading: false,
          currentFile: null,
          statusLabel: 'Upload stopped: $e',
          progressPercentage: 0,
          completedFiles: 0,
          totalFiles: 0,
          isPaused: false,
        ),
      );
    } finally {
      ref.invalidate(directoryNodesProvider);
      ref.invalidate(allNodesProvider);
      ref.invalidate(syncStateProvider);
      ref.invalidate(searchResultsProvider);
      ref.invalidate(folderStatsProvider);
      ref.invalidate(vaultStatsProvider);
    }
  }

  String _guessMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
  }
}
