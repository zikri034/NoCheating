import 'package:flutter_test/flutter_test.dart';
import 'package:thereisnocheating/features/auth/domain/models/user.dart';
import 'package:thereisnocheating/core/network/dio_client.dart';

void main() {
  group('User Model Tests', () {
    test('fromJson and toJson handles full profile data correctly', () {
      final json = {
        'id': 'uuid-1234',
        'name': 'Budi Santoso',
        'email': 'budi@safeexam.ac.id',
        'role': 'student',
        'nim': '12345678',
        'avatar_path': '/uploads/avatars/avatar-123.jpg',
        'created_at': '2026-10-15T12:00:00.000Z',
      };

      final user = User.fromJson(json);

      expect(user.id, 'uuid-1234');
      expect(user.name, 'Budi Santoso');
      expect(user.email, 'budi@safeexam.ac.id');
      expect(user.role, 'student');
      expect(user.nim, '12345678');
      expect(user.avatarPath, '/uploads/avatars/avatar-123.jpg');
      expect(user.createdAt, isNotNull);

      final convertedJson = user.toJson();
      expect(convertedJson['id'], 'uuid-1234');
      expect(convertedJson['avatar_path'], '/uploads/avatars/avatar-123.jpg');
    });

    test('copyWith updates fields immutably', () {
      final user = User(
        id: '1',
        name: 'Initial Name',
        email: 'test@exam.com',
        role: 'student',
      );

      final updated = user.copyWith(name: 'Updated Name');
      expect(updated.name, 'Updated Name');
      expect(updated.id, '1');
      expect(user.name, 'Initial Name');
    });
  });

  group('DioClient resolveUrl Tests', () {
    test('resolves relative avatar path against server host', () {
      final url = DioClient.resolveUrl('/uploads/avatars/pic.jpg');
      expect(url.endsWith('/uploads/avatars/pic.jpg'), isTrue);
      expect(url.contains('/api/uploads'), isFalse);
    });

    test('preserves absolute URLs', () {
      const fullUrl = 'https://example.com/avatar.png';
      expect(DioClient.resolveUrl(fullUrl), fullUrl);
    });
  });
}
