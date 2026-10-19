import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/models/auth_session.dart';

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  AuthRepository(this._dio, this._storage);

  // --- Auth Methods ---

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? nim,
    String? inviteCode,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      'nim': nim,
      'inviteCode': inviteCode,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _dio.post('/auth/login', data: {
      'identifier': identifier,
      'password': password,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await _dio.get('/me');
    return response.data;
  }

  Future<Map<String, dynamic>> updateProfile({required String name}) async {
    final response = await _dio.patch('/me', data: {'name': name});
    return response.data;
  }

  Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post('/me/avatar', data: formData);
    return response.data;
  }

  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final response = await _dio.post('/me/password', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
    // Changing password revokes all biometric devices per PRD F02 & F13
    await clearDeviceSecret();
    return response.data;
  }

  Future<List<Map<String, dynamic>>> getBiometricDevices() async {
    final response = await _dio.get('/me/devices');
    final List list = response.data['devices'] ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> refreshSession() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) throw Exception('No refresh token found');

    final response = await _dio.post('/auth/refresh', data: {
      'refreshToken': refreshToken,
    });
    return response.data;
  }

  Future<void> logout() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken != null) {
      try {
        await _dio.post('/auth/logout', data: {
          'refreshToken': refreshToken,
        });
      } catch (_) {
        // Log out locally even if server call fails
      }
    }
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<void> revokeBiometrics(String deviceId) async {
    try {
      await _dio.delete('/auth/biometric/$deviceId');
    } catch (_) {
      // Continue to remove locally even if offline/revocation error
    }
    await clearDeviceSecret();
  }

  Future<void> clearDeviceSecret() async {
    await _storage.delete(key: 'device_id');
    await _storage.delete(key: 'device_secret');
  }

  // --- Biometric Methods ---

  Future<void> enrollBiometrics({
    required String deviceId,
    required String deviceName,
    required String platform,
    required String deviceSecret,
  }) async {
    await _dio.post('/auth/biometric/enroll', data: {
      'device_id': deviceId,
      'device_name': deviceName,
      'platform': platform,
      'device_secret': deviceSecret,
    });
  }

  Future<Map<String, dynamic>> loginWithBiometrics({
    required String deviceId,
    required String deviceSecret,
  }) async {
    final response = await _dio.post('/auth/biometric/login', data: {
      'device_id': deviceId,
      'device_secret': deviceSecret,
    });
    return response.data;
  }

  // --- Storage Helpers ---

  Future<void> saveSession(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<AuthSession?> getSession() async {
    final access = await _storage.read(key: 'access_token');
    final refresh = await _storage.read(key: 'refresh_token');
    if (access == null || refresh == null) return null;
    return AuthSession(accessToken: access, refreshToken: refresh);
  }

  Future<void> saveDeviceSecret(String deviceId, String secret) async {
    await _storage.write(key: 'device_id', value: deviceId);
    await _storage.write(key: 'device_secret', value: secret);
  }

  Future<String?> getDeviceId() async => await _storage.read(key: 'device_id');
  Future<String?> getDeviceSecret() async => await _storage.read(key: 'device_secret');
}
