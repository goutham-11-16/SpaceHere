import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:telegram_client/scheme/scheme.dart';
import 'package:telegram_client/telegram_client.dart';

import '../../core/config/telegram_config.dart';
import '../../core/exceptions/space_exception.dart';
import 'telegram_service.dart';

class TdLibTelegramDriver implements TelegramDriver {
  TdLibTelegramDriver({
    this.apiId = TelegramConfig.apiId,
    this.apiHash = TelegramConfig.apiHash,
  });

  final int apiId;
  final String apiHash;

  Tdlib? _tdlib;
  int _clientId = 0;
  bool _isInitialized = false;
  String? _authState;
  int? _vaultChatId;
  final Completer<void> _readyCompleter = Completer<void>();

  String? get authState => _authState;
  bool get isReady => _authState == 'authorizationStateReady';

  @override
  Future<void> initialize() async {
    if (_isInitialized && _tdlib != null) {
      return;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final tdlibDir = Directory(path.join(docsDir.path, 'spacehere_tdlib'));
    final dbDir = Directory(path.join(tdlibDir.path, 'db'));
    final filesDir = Directory(path.join(tdlibDir.path, 'files'));

    if (!dbDir.existsSync()) {
      await dbDir.create(recursive: true);
    }
    if (!filesDir.existsSync()) {
      await filesDir.create(recursive: true);
    }

    _tdlib = Tdlib(
      pathTdl: TgUtils.pathTdlib(),
      clientOption: TelegramClientLibraryTdlibOptionParameter.create(
        api_id: apiId,
        api_hash: apiHash,
        database_directory: dbDir.path,
        files_directory: filesDir.path,
        use_test_dc: false,
      ),
    );

    await _tdlib!.ensureInitialized();
    _clientId = _tdlib!.td_create_client_id();
    await _tdlib!.createclient(clientId: _clientId);

    _tdlib!.on(_tdlib!.event_update, (
      UpdateTelegramClientTdlib updateTd,
    ) async {
      final update = updateTd.update;
      if (update['@type'] == 'updateAuthorizationState') {
        final authStateMap = update['authorization_state'];
        if (authStateMap is Map) {
          _authState = authStateMap['@type'] as String?;
          if (_authState == 'authorizationStateReady' &&
              !_readyCompleter.isCompleted) {
            _readyCompleter.complete();
          }
        }
      }
    });

    _isInitialized = true;
  }

  @override
  Future<bool> sendPhoneOtp(String phoneNumber) async {
    await initialize();

    String formatted = phoneNumber.trim().replaceAll(' ', '');
    if (!formatted.startsWith('+')) {
      if (formatted.length == 10) {
        formatted = '+91$formatted'; // default India prefix if 10 digits
      } else {
        formatted = '+$formatted';
      }
    }

    final res = await _tdlib!.invoke(
      'setAuthenticationPhoneNumber',
      parameters: {'phone_number': formatted},
      clientId: _clientId,
    );

    _handleTdError(res);
    return true;
  }

  @override
  Future<bool> verifyPhoneOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    await initialize();

    final res = await _tdlib!.invoke(
      'checkAuthenticationCode',
      parameters: {'code': otp.trim()},
      clientId: _clientId,
    );

    if (res['@type'] == 'error') {
      final msg = res['message'] as String? ?? 'Invalid OTP code';
      throw SpaceException(SpaceErrorKind.unknown, msg);
    }

    return true;
  }

  @override
  Future<String> ensureVaultChannel() async {
    await initialize();

    if (_vaultChatId != null) {
      return _vaultChatId.toString();
    }

    // Check existing chats for the vault channel
    final chatsRes = await _tdlib!.invoke(
      'getChats',
      parameters: {'limit': 100},
      clientId: _clientId,
    );

    if (chatsRes['@type'] == 'chats' && chatsRes['chat_ids'] is List) {
      final chatIds = (chatsRes['chat_ids'] as List).cast<int>();
      for (final cid in chatIds) {
        final chat = await _tdlib!.invoke(
          'getChat',
          parameters: {'chat_id': cid},
          clientId: _clientId,
        );
        if (chat['title'] == TelegramConfig.vaultChannelTitle) {
          _vaultChatId = cid;
          return cid.toString();
        }
      }
    }

    // Create private supergroup channel for SpaceHere
    final createRes = await _tdlib!.invoke(
      'createNewSupergroupChat',
      parameters: {
        'title': TelegramConfig.vaultChannelTitle,
        'is_channel': true,
        'description': TelegramConfig.vaultChannelDescription,
      },
      clientId: _clientId,
    );

    _handleTdError(createRes);
    final newChatId = createRes['id'] as int;
    _vaultChatId = newChatId;
    return newChatId.toString();
  }

  @override
  Future<int> uploadEncryptedChunk({
    required Uint8List chunkBytes,
    required int chunkIndex,
  }) async {
    final chatId = _vaultChatId ?? int.parse(await ensureVaultChannel());

    final tempDir = await getTemporaryDirectory();
    final chunksDir = Directory(path.join(tempDir.path, 'spacehere_chunks'));
    if (!chunksDir.existsSync()) {
      await chunksDir.create(recursive: true);
    }

    final tempFile = File(
      path.join(
        chunksDir.path,
        'chunk_${DateTime.now().microsecondsSinceEpoch}_$chunkIndex.enc',
      ),
    );
    await tempFile.writeAsBytes(chunkBytes, flush: true);

    final res = await _tdlib!.invoke(
      'sendMessage',
      parameters: {
        'chat_id': chatId,
        'input_message_content': {
          '@type': 'inputMessageDocument',
          'document': {'@type': 'inputFileLocal', 'path': tempFile.path},
          'caption': {
            '@type': 'formattedText',
            'text': 'SpaceHERE_CHUNK_$chunkIndex',
          },
        },
      },
      clientId: _clientId,
    );

    _handleTdError(res);
    final msgId = res['id'] as int;

    // Retain file temporarily for TDLib to stream over MTProto, then clean up
    Future.delayed(const Duration(minutes: 5), () {
      if (tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }
    });

    return msgId;
  }

  @override
  Future<Uint8List> downloadEncryptedChunk({required int messageId}) async {
    final chatId = _vaultChatId ?? int.parse(await ensureVaultChannel());

    final msg = await _tdlib!.invoke(
      'getMessage',
      parameters: {'chat_id': chatId, 'message_id': messageId},
      clientId: _clientId,
    );

    _handleTdError(msg);

    final content = msg['content'];
    if (content == null || content['@type'] != 'messageDocument') {
      throw SpaceException(
        SpaceErrorKind.unknown,
        'Chunk message #$messageId does not contain a document.',
      );
    }

    final fileId = content['document']['document']['id'] as int;

    // Download the file
    var dl = await _tdlib!.invoke(
      'downloadFile',
      parameters: {
        'file_id': fileId,
        'priority': 32,
        'synchronous': true,
      },
      clientId: _clientId,
    );

    _handleTdError(dl);

    // Poll until download finishes if not immediate
    var isCompleted = dl['local']?['is_downloading_completed'] == true;
    var filePath = dl['local']?['path'] as String?;
    var retries = 0;

    while (!isCompleted && retries < 20) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final fileStatus = await _tdlib!.invoke(
        'getFile',
        parameters: {'file_id': fileId},
        clientId: _clientId,
      );
      isCompleted = fileStatus['local']?['is_downloading_completed'] == true;
      filePath = fileStatus['local']?['path'] as String?;
      retries++;
    }

    if (filePath == null || !File(filePath).existsSync()) {
      throw SpaceException(
        SpaceErrorKind.unknown,
        'Failed to download chunk #$messageId from TDLib.',
      );
    }

    return File(filePath).readAsBytes();
  }

  @override
  Future<void> pinSyncState(Map<String, dynamic> syncStateJson) async {
    final chatId = _vaultChatId ?? int.parse(await ensureVaultChannel());
    final jsonStr = jsonEncode(syncStateJson);

    final sendRes = await _tdlib!.invoke(
      'sendMessage',
      parameters: {
        'chat_id': chatId,
        'input_message_content': {
          '@type': 'inputMessageText',
          'text': {
            '@type': 'formattedText',
            'text': '[SPACEHERE_SYNC_STATE]: $jsonStr',
          },
        },
      },
      clientId: _clientId,
    );

    _handleTdError(sendRes);
    final msgId = sendRes['id'] as int;

    // Pinning accelerates peer lookup, but failure is non-fatal since message is in chat history
    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final pinRes = await _tdlib!.invoke(
        'pinChatMessage',
        parameters: {
          'chat_id': chatId,
          'message_id': msgId,
          'disable_notification': true,
          'only_for_self': false,
        },
        clientId: _clientId,
      );
      if (pinRes['@type'] == 'error') {
        await _tdlib!.invoke(
          'pinChatMessage',
          parameters: {
            'chat_id': chatId,
            'message_id': msgId,
            'disable_notification': true,
            'only_for_self': true,
          },
          clientId: _clientId,
        );
      }
    } catch (_) {
      // Pinning exception safely caught; message is logged in chat history
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchPinnedSyncState() async {
    final chatId = _vaultChatId ?? int.parse(await ensureVaultChannel());

    // 1. Try fetching directly from the chat pinned message
    try {
      final chat = await _tdlib!.invoke(
        'getChat',
        parameters: {'chat_id': chatId},
        clientId: _clientId,
      );
      final pinnedMsgId = chat['pinned_message_id'] as int? ?? 0;
      if (pinnedMsgId != 0) {
        final msg = await _tdlib!.invoke(
          'getMessage',
          parameters: {'chat_id': chatId, 'message_id': pinnedMsgId},
          clientId: _clientId,
        );
        final text = msg['content']?['text']?['text'] as String?;
        if (text != null && text.contains('[SPACEHERE_SYNC_STATE]: ')) {
          final rawJson = text
              .substring(text.indexOf('[SPACEHERE_SYNC_STATE]: ') + 24)
              .trim();
          return jsonDecode(rawJson) as Map<String, dynamic>;
        }
      }
    } catch (_) {}

    // 2. Fallback: Search recent chat history in the vault channel
    try {
      final history = await _tdlib!.invoke(
        'getChatHistory',
        parameters: {
          'chat_id': chatId,
          'from_message_id': 0,
          'offset': 0,
          'limit': 50,
          'only_local': false,
        },
        clientId: _clientId,
      );
      if (history['@type'] == 'messages' && history['messages'] is List) {
        final messages = history['messages'] as List;
        for (final msgObj in messages) {
          if (msgObj is Map) {
            final text = msgObj['content']?['text']?['text'] as String?;
            if (text != null && text.contains('[SPACEHERE_SYNC_STATE]: ')) {
              final rawJson = text
                  .substring(text.indexOf('[SPACEHERE_SYNC_STATE]: ') + 24)
                  .trim();
              return jsonDecode(rawJson) as Map<String, dynamic>;
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<void> waitForConnectivityReturn() async {
    final connectivity = Connectivity();
    final initial = await connectivity.checkConnectivity();
    if (!initial.contains(ConnectivityResult.none)) {
      return;
    }

    await for (final results in connectivity.onConnectivityChanged) {
      if (!results.contains(ConnectivityResult.none)) {
        break;
      }
    }
  }

  void _handleTdError(Map res) {
    if (res['@type'] == 'error') {
      final message = res['message'] as String? ?? 'TDLib error';
      final code = res['code'] as int? ?? 500;

      if (message.contains('FLOOD_WAIT_')) {
        final digits = RegExp(r'\d+').stringMatch(message) ?? '10';
        final seconds = int.tryParse(digits) ?? 10;
        throw SpaceException(
          SpaceErrorKind.floodWait,
          message,
          waitSeconds: seconds,
        );
      }

      if (message.contains('CHAT_ADMIN_REQUIRED') ||
          message.contains('CHAT_INVALID') ||
          message.contains('CHANNEL_INVALID')) {
        throw SpaceException(SpaceErrorKind.channelDeleted, message);
      }

      if (message.contains('AUTH_KEY_UNREGISTERED') ||
          message.contains('SESSION_REVOKED')) {
        throw SpaceException(SpaceErrorKind.authKeyUnregistered, message);
      }

      throw SpaceException(SpaceErrorKind.unknown, 'TDLib ($code): $message');
    }
  }
}
