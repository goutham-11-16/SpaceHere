import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/exceptions/exception_parser.dart';
import '../../core/exceptions/space_exception.dart';
import '../../core/logging/logger_service.dart';
import '../../models/queue_state.dart';
import '../../models/space_node.dart';
import '../../models/sync_state.dart';
import '../crypto/aes_encryption_service.dart';
import '../database/database_service.dart';
import '../device/device_service.dart';
import '../network/telegram_service.dart';

class SelectedFilePayload {
  const SelectedFilePayload({
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final int sizeBytes;
  final Uint8List bytes;
}

class SpaceRepository {
  SpaceRepository({
    required LocalDatabaseService databaseService,
    required TelegramService telegramService,
    required AesEncryptionService encryptionService,
    required FlutterSecureStorage secureStorage,
    SpaceExceptionParser exceptionParser = const SpaceExceptionParser(),
  }) : _databaseService = databaseService,
       _telegramService = telegramService,
       _encryptionService = encryptionService,
       _secureStorage = secureStorage,
       _exceptionParser = exceptionParser;

  static const instantUploadThresholdBytes = 20 * 1024 * 1024;
  static const chunkSizeBytes = 50 * 1024 * 1024;
  static const _emailKey = 'spacehere.email';
  static const _phoneKey = 'spacehere.telegram_phone';
  static const _saltKey = 'spacehere.vault_salt';
  static const _masterKey = 'spacehere.master_key';

  final LocalDatabaseService _databaseService;
  final TelegramService _telegramService;
  final AesEncryptionService _encryptionService;
  final FlutterSecureStorage _secureStorage;
  final SpaceExceptionParser _exceptionParser;

  Future<void> initializeVault({
    required String email,
    required String telegramPhone,
    required String vaultPin,
  }) async {
    final keyMaterial = await _encryptionService.deriveMasterKey(vaultPin);

    // Persist local vault credentials FIRST so local session is authenticated
    await _secureStorage.write(key: _emailKey, value: email.trim());
    await _secureStorage.write(key: _phoneKey, value: telegramPhone.trim());
    await _secureStorage.write(key: _saltKey, value: keyMaterial.saltBase64);
    await _secureStorage.write(key: _masterKey, value: keyMaterial.keyBase64);

    try {
      final channelId = await _telegramService.ensureVaultChannel();
      final syncState = await _databaseService.exportSyncState();
      await _telegramService.pinSyncState({
        ...syncState.toJson(),
        'channelId': channelId,
      });
    } catch (_) {
      // Cloud sync will continue in background without failing local vault login
    }
  }

  Future<({String? email, String? phone, bool hasVault})> readSession() async {
    final email = await _secureStorage.read(key: _emailKey);
    final phone = await _secureStorage.read(key: _phoneKey);
    final masterKey = await _secureStorage.read(key: _masterKey);
    return (email: email, phone: phone, hasVault: masterKey != null);
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: _emailKey);
    await _secureStorage.delete(key: _phoneKey);
    await _secureStorage.delete(key: _saltKey);
    await _secureStorage.delete(key: _masterKey);
  }

  Future<List<SpaceNode>> listChildren(
    String? parentUuid, {
    SortField sortBy = SortField.name,
    SortOrder sortOrder = SortOrder.ascending,
  }) {
    return _databaseService.listChildren(
      parentUuid,
      sortBy: sortBy,
      sortOrder: sortOrder,
    );
  }

  Future<List<SpaceNode>> listAllNodes() {
    return _databaseService.listAllNodes();
  }

  Future<List<SpaceNode>> searchNodes(
    String query, {
    SortField sortBy = SortField.name,
    SortOrder sortOrder = SortOrder.ascending,
  }) {
    return _databaseService.searchNodes(
      query,
      sortBy: sortBy,
      sortOrder: sortOrder,
    );
  }

  Future<List<SpaceNode>> getBreadcrumbs(String? leafUuid) {
    return _databaseService.getBreadcrumbs(leafUuid);
  }

  Future<List<SpaceNode>> filterByMimeCategory(
    String category, {
    SortField sortBy = SortField.name,
    SortOrder sortOrder = SortOrder.ascending,
  }) {
    return _databaseService.filterByMimeCategory(
      category,
      sortBy: sortBy,
      sortOrder: sortOrder,
    );
  }

  Future<SpaceNode> createFolder(String name, String? parentUuid) async {
    final folder = await _databaseService.createFolder(name, parentUuid);
    await syncLocalStateToVault();
    return folder;
  }

  Future<void> renameNode(String uuid, String newName) async {
    await _databaseService.renameNode(uuid, newName);
    await syncLocalStateToVault();
  }

  Future<void> moveNode(String uuid, String? newParentUuid) async {
    await _databaseService.moveNode(uuid, newParentUuid);
    await syncLocalStateToVault();
  }

  Future<void> moveBatch(List<String> uuids, String? newParentUuid) async {
    await _databaseService.moveBatch(uuids, newParentUuid);
    await syncLocalStateToVault();
  }

  Future<void> softDelete(String uuid) async {
    await _databaseService.softDelete(uuid);
    await syncLocalStateToVault();
  }

  Future<void> softDeleteBatch(List<String> uuids) async {
    await _databaseService.softDeleteBatch(uuids);
    await syncLocalStateToVault();
  }

  Future<List<SpaceNode>> listTrashNodes() {
    return _databaseService.listTrashNodes();
  }

  Future<void> restoreNode(String uuid) async {
    await _databaseService.restoreNode(uuid);
    await syncLocalStateToVault();
  }

  Future<void> purgeNode(String uuid) async {
    await _databaseService.purgeNode(uuid);
    await syncLocalStateToVault();
  }

  Future<void> emptyTrash() async {
    await _databaseService.emptyTrash();
    await syncLocalStateToVault();
  }

  Future<SpaceNode> duplicateNode(
    String uuid, {
    String? targetParentUuid,
  }) async {
    final copy = await _databaseService.duplicateNode(
      uuid,
      targetParentUuid: targetParentUuid,
    );
    await syncLocalStateToVault();
    return copy;
  }

  Future<List<SpaceNode>> copyBatch(
    List<String> uuids,
    String? targetParentUuid,
  ) async {
    final copies = await _databaseService.copyBatch(uuids, targetParentUuid);
    await syncLocalStateToVault();
    return copies;
  }

  Future<void> toggleFavorite(String uuid) async {
    await _databaseService.toggleFavorite(uuid);
    await syncLocalStateToVault();
  }

  Future<List<SpaceNode>> listFavorites({
    SortField sortBy = SortField.name,
    SortOrder sortOrder = SortOrder.ascending,
  }) {
    return _databaseService.listFavorites(sortBy: sortBy, sortOrder: sortOrder);
  }

  Future<void> addTag(String uuid, String tag) async {
    await _databaseService.addTag(uuid, tag);
    await syncLocalStateToVault();
  }

  Future<void> removeTag(String uuid, String tag) async {
    await _databaseService.removeTag(uuid, tag);
    await syncLocalStateToVault();
  }

  Future<FolderStats> getFolderStats(String? folderUuid) {
    return _databaseService.getFolderStats(folderUuid);
  }

  Future<VaultStats> getVaultStats() {
    return _databaseService.getVaultStats();
  }

  Future<List<SpaceNode>> filterByDevice(
    String deviceName, {
    SortField sortBy = SortField.name,
    SortOrder sortOrder = SortOrder.ascending,
  }) {
    return _databaseService.filterByDevice(
      deviceName,
      sortBy: sortBy,
      sortOrder: sortOrder,
    );
  }

  Future<List<String>> listRegisteredDevices() {
    return _databaseService.listRegisteredDevices();
  }

  Future<SyncState> exportSyncState() {
    return _databaseService.exportSyncState();
  }

  Future<void> syncLocalStateToVault() async {
    final state = await _databaseService.exportSyncState();
    await _telegramService.pinSyncState(state.toJson());
  }

  Future<bool> pullRemoteVaultState() async {
    final remoteStateMap = await _telegramService.fetchPinnedSyncState();
    if (remoteStateMap == null) {
      return false;
    }

    final remoteState = SyncState.fromJson(remoteStateMap);
    await _databaseService.importSyncState(remoteState);
    return true;
  }

  Future<void> reinitializeVault() async {
    final channelId = await _telegramService.ensureVaultChannel();
    final syncState = await _databaseService.exportSyncState();
    await _telegramService.pinSyncState({
      ...syncState.toJson(),
      'channelId': channelId,
    });
  }

  Future<Uint8List> downloadAndDecryptFile({
    required SpaceNode node,
    void Function(double progress, String status)? onProgress,
  }) async {
    if (node.isFolder) {
      throw const SpaceException(
        SpaceErrorKind.unknown,
        'Cannot download a folder directly.',
      );
    }

    if (node.ivBase64 == null || node.authTagBase64 == null) {
      throw const SpaceException(
        SpaceErrorKind.unknown,
        'Missing cryptographic nonce/tag for file decryption.',
      );
    }

    final keyBase64 = await _secureStorage.read(key: _masterKey);
    if (keyBase64 == null) {
      throw const SpaceException(
        SpaceErrorKind.authKeyUnregistered,
        'No local vault key exists.',
      );
    }

    final secretKey = _encryptionService.keyFromBase64(keyBase64);

    onProgress?.call(0.1, 'Locating remote vault chunks...');

    final chunkBytesList = <Uint8List>[];
    final totalChunks = node.chunkMessageIds.length;

    if (totalChunks == 0) {
      return Uint8List(0);
    }

    for (var i = 0; i < totalChunks; i++) {
      final messageId = node.chunkMessageIds[i];
      onProgress?.call(
        0.1 + ((i / totalChunks) * 0.7),
        'Retrieving chunk ${i + 1}/$totalChunks from vault...',
      );

      var downloaded = false;
      Uint8List? chunk;
      while (!downloaded) {
        try {
          chunk = await _telegramService.downloadEncryptedChunk(
            messageId: messageId,
          );
          downloaded = true;
        } catch (error) {
          final parsed = _exceptionParser.parse(error);
          if (parsed.kind == SpaceErrorKind.floodWait) {
            final waitSeconds = (parsed.waitSeconds ?? 0) + 2;
            onProgress?.call(
              0.1 + ((i / totalChunks) * 0.7),
              'FloodWait: pacing connection for $waitSeconds seconds...',
            );
            await Future<void>.delayed(Duration(seconds: waitSeconds));
          } else if (parsed.kind == SpaceErrorKind.networkDropped) {
            onProgress?.call(
              0.1 + ((i / totalChunks) * 0.7),
              'Waiting for network signal...',
            );
            await _telegramService.waitForConnectivityReturn();
          } else {
            throw parsed;
          }
        }
      }
      if (chunk != null) {
        chunkBytesList.add(chunk);
      }
    }

    onProgress?.call(0.85, 'Reassembling encrypted blocks...');
    final totalLength = chunkBytesList.fold<int>(0, (sum, c) => sum + c.length);
    final concatenated = Uint8List(totalLength);
    var offset = 0;
    for (final c in chunkBytesList) {
      concatenated.setRange(offset, offset + c.length, c);
      offset += c.length;
    }

    onProgress?.call(0.92, 'Decrypting AES-256 GCM payload...');
    final decrypted = await _encryptionService.decryptFileBytes(
      cipherText: concatenated,
      ivBase64: node.ivBase64!,
      authTagBase64: node.authTagBase64!,
      secretKey: secretKey,
    );

    onProgress?.call(1.0, 'File decrypted successfully');
    return decrypted;
  }

  Future<void> uploadFiles({
    required List<SelectedFilePayload> files,
    required String? parentUuid,
    required void Function(QueueState state) onQueueState,
  }) async {
    if (files.isEmpty) {
      onQueueState(const QueueState.idle());
      return;
    }

    final keyBase64 = await _secureStorage.read(key: _masterKey);
    if (keyBase64 == null) {
      throw const SpaceException(
        SpaceErrorKind.authKeyUnregistered,
        'No local vault key exists.',
      );
    }

    final secretKey = _encryptionService.keyFromBase64(keyBase64);

    for (var fileIndex = 0; fileIndex < files.length; fileIndex++) {
      final file = files[fileIndex];
      final mbSize = (file.sizeBytes / (1024 * 1024)).toStringAsFixed(1);
      onQueueState(
        QueueState(
          isUploading: true,
          currentFile: file.name,
          statusLabel: 'Encrypting AES-256 vault payload ($mbSize MB)...',
          progressPercentage: 0.05,
          completedFiles: fileIndex,
          totalFiles: files.length,
          isPaused: false,
        ),
      );

      final encrypted = await _encryptionService.encryptFileBytes(
        file.bytes,
        secretKey,
      );

      final chunkIds = <int>[];
      final chunks = _chunkBytes(encrypted.cipherText, chunkSizeBytes);

      for (var chunkIndex = 0; chunkIndex < chunks.length; chunkIndex++) {
        final chunk = chunks[chunkIndex];
        final uploadProgress = chunks.isEmpty
            ? 1.0
            : chunkIndex / chunks.length;

        final chunkLabel = chunks.length > 1
            ? 'Uploading chunk ${chunkIndex + 1}/${chunks.length} ($mbSize MB)...'
            : 'Streaming encrypted data to Telegram...';

        onQueueState(
          QueueState(
            isUploading: true,
            currentFile: file.name,
            statusLabel: chunkLabel,
            progressPercentage: 0.15 + (uploadProgress * 0.80),
            completedFiles: fileIndex,
            totalFiles: files.length,
            isPaused: false,
          ),
        );

        var uploaded = false;
        while (!uploaded) {
          try {
            final messageId = await _telegramService.uploadEncryptedChunk(
              chunkBytes: chunk,
              chunkIndex: chunkIndex,
            );
            chunkIds.add(messageId);
            uploaded = true;
          } catch (error) {
            final parsed = _exceptionParser.parse(error);
            await _handleUploadException(
              parsed,
              file,
              fileIndex,
              files.length,
              onQueueState,
            );
          }
        }

        // Fast cooperative yield to keep Flutter UI event loop smooth
        if (chunkIndex < chunks.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      }

      final uniqueName = await _databaseService.resolveUniqueName(
        file.name,
        parentUuid,
      );
      final now = DateTime.now().toUtc();
      await _databaseService.upsertNode(
        SpaceNode(
          name: uniqueName,
          parentUuid: parentUuid,
          mimeType: file.mimeType,
          isFolder: false,
          sizeBytes: file.sizeBytes,
          chunkMessageIds: chunkIds,
          ivBase64: encrypted.ivBase64,
          authTagBase64: encrypted.authTagBase64,
          originDevice: DeviceService.instance.currentDeviceName,
          originPlatform: DeviceService.instance.currentPlatform,
          createdAt: now,
          updatedAt: now,
        ),
      );

      try {
        await syncLocalStateToVault();
      } catch (err) {
        LoggerService.instance.warning(
          'SpaceRepository',
          'Background vault sync deferred: $err',
        );
      }

      onQueueState(
        QueueState(
          isUploading: fileIndex < files.length - 1,
          currentFile: file.name,
          statusLabel: 'Sync state pinned to private vault',
          progressPercentage: 1,
          completedFiles: fileIndex + 1,
          totalFiles: files.length,
          isPaused: false,
        ),
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 450));
    onQueueState(const QueueState.idle());
  }

  Future<void> _handleUploadException(
    SpaceException exception,
    SelectedFilePayload file,
    int completedFiles,
    int totalFiles,
    void Function(QueueState state) onQueueState,
  ) async {
    switch (exception.kind) {
      case SpaceErrorKind.floodWait:
        final waitSeconds = (exception.waitSeconds ?? 0) + 2;
        onQueueState(
          QueueState(
            isUploading: true,
            currentFile: file.name,
            statusLabel: exception.message,
            progressPercentage: 0.5,
            completedFiles: completedFiles,
            totalFiles: totalFiles,
            isPaused: true,
          ),
        );
        await Future<void>.delayed(Duration(seconds: waitSeconds));
      case SpaceErrorKind.networkDropped:
        onQueueState(
          QueueState(
            isUploading: true,
            currentFile: file.name,
            statusLabel: exception.message,
            progressPercentage: 0.5,
            completedFiles: completedFiles,
            totalFiles: totalFiles,
            isPaused: true,
          ),
        );
        await _telegramService.waitForConnectivityReturn();
      case SpaceErrorKind.channelDeleted:
      case SpaceErrorKind.authKeyUnregistered:
      case SpaceErrorKind.unknown:
        throw exception;
    }
  }

  List<Uint8List> _chunkBytes(Uint8List bytes, int size) {
    if (bytes.isEmpty) {
      return [Uint8List(0)];
    }

    final chunks = <Uint8List>[];
    for (var offset = 0; offset < bytes.length; offset += size) {
      final end = min(offset + size, bytes.length);
      chunks.add(Uint8List.sublistView(bytes, offset, end));
    }
    return chunks;
  }
}
