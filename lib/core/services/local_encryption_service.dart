import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalEncryptionService {
  static const String _keyStorageKey = 'local_exam_enc_key';
  final FlutterSecureStorage _storage;
  final AesGcm _algorithm = AesGcm.with256bits();

  LocalEncryptionService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<SecretKey> _getOrCreateKey() async {
    final existingHex = await _storage.read(key: _keyStorageKey);
    if (existingHex != null && existingHex.length == 64) {
      final keyBytes = _hexToBytes(existingHex);
      return SecretKey(keyBytes);
    }

    final newSecretKey = await _algorithm.newSecretKey();
    final keyBytes = await newSecretKey.extractBytes();
    final hexString = keyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _keyStorageKey, value: hexString);
    return newSecretKey;
  }

  Future<String> encrypt(String plainText) async {
    final secretKey = await _getOrCreateKey();
    final clearBytes = utf8.encode(plainText);

    final secretBox = await _algorithm.encrypt(
      clearBytes,
      secretKey: secretKey,
    );

    // Encode nonce + ciphertext + mac into single JSON string
    final payload = {
      'nonce': base64Encode(secretBox.nonce),
      'cipherText': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };
    return jsonEncode(payload);
  }

  Future<String> decrypt(String encryptedJson) async {
    final secretKey = await _getOrCreateKey();
    final map = jsonDecode(encryptedJson) as Map<String, dynamic>;

    final nonce = base64Decode(map['nonce'] as String);
    final cipherText = base64Decode(map['cipherText'] as String);
    final macBytes = base64Decode(map['mac'] as String);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final clearBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    return utf8.decode(clearBytes);
  }

  static List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}
