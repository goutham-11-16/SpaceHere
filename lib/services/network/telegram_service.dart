import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../core/exceptions/space_exception.dart';

abstract class TelegramDriver {
  Future<void> initialize();
  Future<bool> sendPhoneOtp(String phoneNumber);
  Future<bool> verifyPhoneOtp({
    required String phoneNumber,
    required String otp,
  });
  Future<String> ensureVaultChannel();
  Future<int> uploadEncryptedChunk({
    required Uint8List chunkBytes,
    required int chunkIndex,
  });
  Future<Uint8List> downloadEncryptedChunk({required int messageId});
  Future<void> pinSyncState(Map<String, dynamic> syncStateJson);
  Future<Map<String, dynamic>?> fetchPinnedSyncState();
  Future<void> waitForConnectivityReturn();
}

class SimulatedTelegramDriver implements TelegramDriver {
  int _nextMessageId = 1043;
  String? _pinnedSyncState;
  Object? _nextErrorToThrow;
  final Map<int, Uint8List> _chunkStorage = {};

  void injectNextError(Object error) {
    _nextErrorToThrow = error;
  }

  void storeChunk(int messageId, Uint8List bytes) {
    _chunkStorage[messageId] = bytes;
  }

  @override
  Future<void> initialize() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<bool> sendPhoneOtp(String phoneNumber) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return phoneNumber.trim().isNotEmpty;
  }

  @override
  Future<bool> verifyPhoneOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return phoneNumber.trim().isNotEmpty && otp.trim().length >= 4;
  }

  @override
  Future<String> ensureVaultChannel() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return 'spacehere-private-vault';
  }

  @override
  Future<int> uploadEncryptedChunk({
    required Uint8List chunkBytes,
    required int chunkIndex,
  }) async {
    if (_nextErrorToThrow != null) {
      final err = _nextErrorToThrow!;
      _nextErrorToThrow = null;
      throw err;
    }

    if (chunkBytes.isEmpty) {
      throw const SpaceException(
        SpaceErrorKind.unknown,
        'Cannot upload an empty encrypted chunk.',
      );
    }

    await Future<void>.delayed(
      Duration(milliseconds: 50 + Random().nextInt(50)),
    );
    final messageId = _nextMessageId++;
    _chunkStorage[messageId] = Uint8List.fromList(chunkBytes);
    return messageId;
  }

  @override
  Future<Uint8List> downloadEncryptedChunk({required int messageId}) async {
    if (_nextErrorToThrow != null) {
      final err = _nextErrorToThrow!;
      _nextErrorToThrow = null;
      throw err;
    }

    final chunk = _chunkStorage[messageId];
    if (chunk == null) {
      throw SpaceException(
        SpaceErrorKind.unknown,
        'Chunk message #$messageId not found in vault channel.',
      );
    }

    await Future<void>.delayed(
      Duration(milliseconds: 30 + Random().nextInt(40)),
    );
    return chunk;
  }

  @override
  Future<void> pinSyncState(Map<String, dynamic> syncStateJson) async {
    _pinnedSyncState = jsonEncode(syncStateJson);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<Map<String, dynamic>?> fetchPinnedSyncState() async {
    final state = _pinnedSyncState;
    if (state == null) {
      return null;
    }
    return jsonDecode(state) as Map<String, dynamic>;
  }

  @override
  Future<void> waitForConnectivityReturn() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

class TelegramService {
  TelegramService._([TelegramDriver? driver])
    : _driver = driver ?? SimulatedTelegramDriver();

  static final TelegramService instance = TelegramService._();

  TelegramDriver _driver;

  void setDriver(TelegramDriver driver) {
    _driver = driver;
  }

  TelegramDriver get driver => _driver;

  Future<void> initialize() => _driver.initialize();

  Future<bool> sendPhoneOtp(String phoneNumber) =>
      _driver.sendPhoneOtp(phoneNumber);

  Future<bool> verifyPhoneOtp({
    required String phoneNumber,
    required String otp,
  }) => _driver.verifyPhoneOtp(phoneNumber: phoneNumber, otp: otp);

  Future<String> ensureVaultChannel() => _driver.ensureVaultChannel();

  Future<int> uploadEncryptedChunk({
    required Uint8List chunkBytes,
    required int chunkIndex,
  }) => _driver.uploadEncryptedChunk(
    chunkBytes: chunkBytes,
    chunkIndex: chunkIndex,
  );

  Future<Uint8List> downloadEncryptedChunk({required int messageId}) =>
      _driver.downloadEncryptedChunk(messageId: messageId);

  Future<void> pinSyncState(Map<String, dynamic> syncStateJson) =>
      _driver.pinSyncState(syncStateJson);

  Future<Map<String, dynamic>?> fetchPinnedSyncState() =>
      _driver.fetchPinnedSyncState();

  Future<void> waitForConnectivityReturn() =>
      _driver.waitForConnectivityReturn();
}
