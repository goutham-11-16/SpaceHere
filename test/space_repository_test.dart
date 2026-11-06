import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacehere/core/exceptions/space_exception.dart';
import 'package:spacehere/models/queue_state.dart';
import 'package:spacehere/models/space_node.dart';
import 'package:spacehere/models/sync_state.dart';
import 'package:spacehere/services/crypto/aes_encryption_service.dart';
import 'package:spacehere/services/database/database_service.dart';
import 'package:spacehere/services/network/telegram_service.dart';
import 'package:spacehere/services/repository/space_repository.dart';

class InMemorySecureStorage implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #write) {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String?;
      if (value == null) {
        _data.remove(key);
      } else {
        _data[key] = value;
      }
      return Future<void>.value();
    }
    if (invocation.memberName == #read) {
      final key = invocation.namedArguments[#key] as String;
      return Future<String?>.value(_data[key]);
    }
    if (invocation.memberName == #delete) {
      final key = invocation.namedArguments[#key] as String;
      _data.remove(key);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  late DatabaseService databaseService;
  late TelegramService telegramService;
  late SimulatedTelegramDriver telegramDriver;
  late AesEncryptionService encryptionService;
  late InMemorySecureStorage secureStorage;
  late SpaceRepository repository;

  setUp(() async {
    databaseService = DatabaseService.instance;
    await databaseService.initialize();

    telegramDriver = SimulatedTelegramDriver();
    telegramService = TelegramService.instance;
    telegramService.setDriver(telegramDriver);

    encryptionService = AesEncryptionService();
    secureStorage = InMemorySecureStorage();

    repository = SpaceRepository(
      databaseService: databaseService,
      telegramService: telegramService,
      encryptionService: encryptionService,
      secureStorage: secureStorage,
    );
  });

  test(
    'Vault initialization stores email, phone, derived master key and salt',
    () async {
      await repository.initializeVault(
        email: 'test@spacehere.com',
        telegramPhone: '+1234567890',
        vaultPin: 'super-secret-pin-123',
      );

      final session = await repository.readSession();
      expect(session.email, 'test@spacehere.com');
      expect(session.phone, '+1234567890');
      expect(session.hasVault, isTrue);
    },
  );

  test(
    'Uploading a file encrypts bytes and posts chunk to Telegram Service',
    () async {
      await repository.initializeVault(
        email: 'test@spacehere.com',
        telegramPhone: '+1234567890',
        vaultPin: 'super-secret-pin-123',
      );

      final queueStates = <QueueState>[];
      final file = SelectedFilePayload(
        name: 'document.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 100,
        bytes: Uint8List.fromList(List.generate(100, (i) => i % 256)),
      );

      await repository.uploadFiles(
        files: [file],
        parentUuid: null,
        onQueueState: (state) => queueStates.add(state),
      );

      expect(queueStates, isNotEmpty);
      final allNodes = await repository.listAllNodes();
      final uploaded = allNodes.firstWhere((n) => n.name == 'document.pdf');
      expect(uploaded.chunkMessageIds, isNotEmpty);
      expect(uploaded.ivBase64, isNotNull);
      expect(uploaded.authTagBase64, isNotNull);
    },
  );

  test('Upload loop handles FLOOD_WAIT error gracefully and resumes', () async {
    await repository.initializeVault(
      email: 'test@spacehere.com',
      telegramPhone: '+1234567890',
      vaultPin: 'super-secret-pin-123',
    );

    telegramDriver.injectNextError(
      const SpaceException(
        SpaceErrorKind.floodWait,
        'FloodWait trigger test',
        waitSeconds: 1,
      ),
    );

    final queueStates = <QueueState>[];
    final file = SelectedFilePayload(
      name: 'resilient_upload.txt',
      mimeType: 'text/plain',
      sizeBytes: 50,
      bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
    );

    await repository.uploadFiles(
      files: [file],
      parentUuid: null,
      onQueueState: (state) => queueStates.add(state),
    );

    expect(queueStates.any((s) => s.isPaused), isTrue);
    final allNodes = await repository.listAllNodes();
    expect(allNodes.any((n) => n.name == 'resilient_upload.txt'), isTrue);
  });

  test(
    'Uploading then downloading a file reassembles chunks and decrypts identical original bytes',
    () async {
      await repository.initializeVault(
        email: 'test@spacehere.com',
        telegramPhone: '+1234567890',
        vaultPin: 'super-secret-pin-123',
      );

      final originalBytes = Uint8List.fromList([
        10,
        20,
        30,
        40,
        50,
        60,
        70,
        80,
      ]);
      final file = SelectedFilePayload(
        name: 'secure_passwords.txt',
        mimeType: 'text/plain',
        sizeBytes: originalBytes.length,
        bytes: originalBytes,
      );

      await repository.uploadFiles(
        files: [file],
        parentUuid: null,
        onQueueState: (_) {},
      );

      final allNodes = await repository.listAllNodes();
      final uploadedNode = allNodes.firstWhere(
        (n) => n.name == 'secure_passwords.txt',
      );

      final progressUpdates = <String>[];
      final decryptedBytes = await repository.downloadAndDecryptFile(
        node: uploadedNode,
        onProgress: (prog, status) => progressUpdates.add(status),
      );

      expect(decryptedBytes, originalBytes);
      expect(progressUpdates, isNotEmpty);
    },
  );

  test('Renaming and moving a node updates VFS metadata correctly', () async {
    await repository.initializeVault(
      email: 'test@spacehere.com',
      telegramPhone: '+1234567890',
      vaultPin: 'super-secret-pin-123',
    );

    final folderA = await repository.createFolder('SourceFolder', null);
    final folderB = await repository.createFolder('DestFolder', null);

    await repository.renameNode(folderA.uuid, 'RenamedFolder');
    var all = await repository.listAllNodes();
    expect(all.any((n) => n.name == 'RenamedFolder'), isTrue);

    await repository.moveNode(folderA.uuid, folderB.uuid);
    final childrenOfB = await repository.listChildren(folderB.uuid);
    expect(childrenOfB.single.name, 'RenamedFolder');
  });

  test(
    'pullRemoteVaultState updates local state from pinned channel',
    () async {
      await repository.initializeVault(
        email: 'test@spacehere.com',
        telegramPhone: '+1234567890',
        vaultPin: 'super-secret-pin-123',
      );

      final remoteNode = SpaceNode(
        name: 'remote_file.pdf',
        parentUuid: null,
        mimeType: 'application/pdf',
        isFolder: false,
        sizeBytes: 1024,
        chunkMessageIds: const [999],
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final mockRemoteSync = SyncState(
        schemaVersion: 1,
        exportedAt: DateTime.now().toUtc(),
        deviceId: 'remote-device',
        channelId: 'spacehere-private-vault',
        nodes: [remoteNode],
      );

      await telegramService.pinSyncState(mockRemoteSync.toJson());

      final pulled = await repository.pullRemoteVaultState();
      expect(pulled, isTrue);

      final all = await repository.listAllNodes();
      expect(all.any((n) => n.name == 'remote_file.pdf'), isTrue);
    },
  );

  test(
    'reinitializeVault recreates channel and updates pinned state',
    () async {
      await repository.initializeVault(
        email: 'test@spacehere.com',
        telegramPhone: '+1234567890',
        vaultPin: 'super-secret-pin-123',
      );

      await repository.reinitializeVault();
      final pinned = await telegramService.fetchPinnedSyncState();
      expect(pinned, isNotNull);
      expect(pinned!['channelId'], 'spacehere-private-vault');
    },
  );
}
