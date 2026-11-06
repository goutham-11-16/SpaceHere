import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class VaultKeyMaterial {
  const VaultKeyMaterial({
    required this.secretKey,
    required this.keyBase64,
    required this.saltBase64,
  });

  final SecretKey secretKey;
  final String keyBase64;
  final String saltBase64;
}

class EncryptedPayload {
  const EncryptedPayload({
    required this.cipherText,
    required this.ivBase64,
    required this.authTagBase64,
  });

  final Uint8List cipherText;
  final String ivBase64;
  final String authTagBase64;
}

class AesEncryptionService {
  static const kdfIterations = 100000;
  static const saltLengthBytes = 16;
  static const ivLengthBytes = 12;

  final AesGcm _aesGcm = AesGcm.with256bits();
  final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: kdfIterations,
    bits: 256,
  );

  Future<VaultKeyMaterial> deriveMasterKey(
    String passphrase, {
    List<int>? saltBytes,
  }) async {
    final salt = Uint8List.fromList(
      saltBytes ?? _secureRandomBytes(saltLengthBytes),
    );
    final secretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    final keyBytes = await secretKey.extractBytes();

    return VaultKeyMaterial(
      secretKey: secretKey,
      keyBase64: base64Encode(keyBytes),
      saltBase64: base64Encode(salt),
    );
  }

  SecretKey keyFromBase64(String keyBase64) {
    return SecretKey(base64Decode(keyBase64));
  }

  Future<EncryptedPayload> encryptFileBytes(
    List<int> clearBytes,
    SecretKey secretKey,
  ) async {
    final iv = _secureRandomBytes(ivLengthBytes);
    final keyBytes = await secretKey.extractBytes();
    final clearUint8 = clearBytes is Uint8List
        ? clearBytes
        : Uint8List.fromList(clearBytes);

    if (clearUint8.length > 1024 * 1024) {
      return Isolate.run(() async {
        final aesGcm = AesGcm.with256bits();
        final box = await aesGcm.encrypt(
          clearUint8,
          secretKey: SecretKey(keyBytes),
          nonce: iv,
        );
        return EncryptedPayload(
          cipherText: Uint8List.fromList(box.cipherText),
          ivBase64: base64Encode(iv),
          authTagBase64: base64Encode(box.mac.bytes),
        );
      });
    }

    final box = await _aesGcm.encrypt(
      clearUint8,
      secretKey: secretKey,
      nonce: iv,
    );

    return EncryptedPayload(
      cipherText: Uint8List.fromList(box.cipherText),
      ivBase64: base64Encode(iv),
      authTagBase64: base64Encode(box.mac.bytes),
    );
  }

  Future<Uint8List> decryptFileBytes({
    required List<int> cipherText,
    required String ivBase64,
    required String authTagBase64,
    required SecretKey secretKey,
  }) async {
    final keyBytes = await secretKey.extractBytes();
    final cipherUint8 = cipherText is Uint8List
        ? cipherText
        : Uint8List.fromList(cipherText);

    if (cipherUint8.length > 1024 * 1024) {
      final nonceBytes = base64Decode(ivBase64);
      final tagBytes = base64Decode(authTagBase64);
      return Isolate.run(() async {
        final aesGcm = AesGcm.with256bits();
        final box = SecretBox(
          cipherUint8,
          nonce: nonceBytes,
          mac: Mac(tagBytes),
        );
        final clearBytes = await aesGcm.decrypt(
          box,
          secretKey: SecretKey(keyBytes),
        );
        return Uint8List.fromList(clearBytes);
      });
    }

    final box = SecretBox(
      cipherUint8,
      nonce: base64Decode(ivBase64),
      mac: Mac(base64Decode(authTagBase64)),
    );
    final clearBytes = await _aesGcm.decrypt(box, secretKey: secretKey);
    return Uint8List.fromList(clearBytes);
  }

  Uint8List _secureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
