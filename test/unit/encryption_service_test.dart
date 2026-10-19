import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:thereisnocheating/core/services/local_encryption_service.dart';

class MockSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    dynamic aOptions,
    dynamic iOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    dynamic aOptions,
    dynamic iOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    dynamic aOptions,
    dynamic iOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
  }) async {
    _data.remove(key);
  }
}

void main() {
  group('LocalEncryptionService AES-GCM Tests (PRD F04 & Section 10)', () {
    late LocalEncryptionService service;
    late MockSecureStorage mockStorage;

    setUp(() {
      mockStorage = MockSecureStorage();
      service = LocalEncryptionService(storage: mockStorage);
    });

    test('encrypt and decrypt roundtrip restores original plain text', () async {
      const originalText = 'Ini adalah draf jawaban essay ujian yang sangat rahasia.';
      final encryptedJson = await service.encrypt(originalText);

      expect(encryptedJson.contains('nonce'), true);
      expect(encryptedJson.contains('cipherText'), true);
      expect(encryptedJson.contains(originalText), false); // must NOT leak clear text

      final decrypted = await service.decrypt(encryptedJson);
      expect(decrypted, originalText);
    });

    test('decrypt with invalid payload throws error', () async {
      final invalidPayload = '{"nonce":"AAAA","cipherText":"BBBB","mac":"CCCC"}';
      expect(() => service.decrypt(invalidPayload), throwsA(anything));
    });
  });
}
