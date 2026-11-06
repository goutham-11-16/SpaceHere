import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:spacehere/models/space_node.dart';
import 'package:spacehere/models/sync_state.dart';
import 'package:spacehere/services/crypto/aes_encryption_service.dart';

void main() {
  test('sync state preserves the VFS contract', () {
    final now = DateTime.utc(2026, 6, 15);
    final node = SpaceNode(
      uuid: 'node-1',
      name: 'demo.pdf',
      parentUuid: null,
      mimeType: 'application/pdf',
      isFolder: false,
      sizeBytes: 42,
      chunkMessageIds: const [1001, 1002],
      ivBase64: 'iv',
      authTagBase64: 'tag',
      createdAt: now,
      updatedAt: now,
    );
    final state = SyncState(
      schemaVersion: 1,
      exportedAt: now,
      deviceId: 'device-1',
      channelId: 'spacehere-private-vault',
      nodes: [node],
    );

    final decoded = SyncState.fromJson(
      jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
    );

    expect(decoded.nodes.single.chunkMessageIds, [1001, 1002]);
    expect(decoded.nodes.single.ivBase64, 'iv');
    expect(decoded.nodes.single.authTagBase64, 'tag');
  });

  test('AES-GCM pipeline encrypts and decrypts bytes', () async {
    final service = AesEncryptionService();
    final key = await service.deriveMasterKey('spacehere-demo-pin');
    final encrypted = await service.encryptFileBytes([
      1,
      2,
      3,
      4,
    ], key.secretKey);
    final clear = await service.decryptFileBytes(
      cipherText: encrypted.cipherText,
      ivBase64: encrypted.ivBase64,
      authTagBase64: encrypted.authTagBase64,
      secretKey: key.secretKey,
    );

    expect(clear, [1, 2, 3, 4]);
  });
}
