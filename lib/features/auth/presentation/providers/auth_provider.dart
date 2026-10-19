import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../domain/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/utils/device_utils.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository;
  final BiometricService _biometricService = BiometricService();

  User? _currentUser;
  bool _isLoading = false;
  bool _isGatePassed = false;
  bool _isBiometricEnabled = false;

  AuthProvider(this._authRepository) {
    initBiometricState();
  }

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isGatePassed => _isGatePassed;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isAuthenticated => _currentUser != null;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> _saveSession(String accessToken, String refreshToken) async {
    await _authRepository.saveSession(accessToken, refreshToken);
  }

  Future<void> _setUnauthenticated() async {
    _currentUser = null;
    _isGatePassed = false;
    // Note: Do not clear _isBiometricEnabled here so Mode B biometric login button is available on Login screen!
    await initBiometricState();
    notifyListeners();
  }

  Future<void> initBiometricState() async {
    try {
      final secret = await _authRepository.getDeviceSecret();
      final deviceId = await _authRepository.getDeviceId();
      _isBiometricEnabled = (secret != null && secret.isNotEmpty && deviceId != null && deviceId.isNotEmpty);
    } catch (_) {
      _isBiometricEnabled = false;
    }
    notifyListeners();
  }

  Future<void> login(String identifier, String password) async {
    _setLoading(true);
    try {
      final data = await _authRepository.login(
        identifier: identifier,
        password: password,
      );

      final user = User.fromJson(data['user']);
      _currentUser = user;

      await _saveSession(
        data['accessToken'],
        data['refreshToken'],
      );
      await initBiometricState();
    } catch (e) {
      if (e is DioException) {
        final errorMessage = e.response?.data?['error']?['message'] ?? e.message;
        throw errorMessage;
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? nim,
    String? inviteCode,
  }) async {
    _setLoading(true);
    try {
      final data = await _authRepository.register(
        name: name,
        email: email,
        password: password,
        role: role,
        nim: nim ?? '',
        inviteCode: inviteCode ?? '',
      );

      final user = User.fromJson(data['user']);
      _currentUser = user;

      await _saveSession(
        data['accessToken'],
        data['refreshToken'],
      );
      await initBiometricState();
    } catch (e) {
      if (e is DioException) {
        final errorMessage = e.response?.data?['error']?['message'] ?? e.message;
        throw errorMessage;
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      await _authRepository.logout();
      await _setUnauthenticated();
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> checkAuthStatus() async {
    _setLoading(true);
    try {
      await initBiometricState();
      final session = await _authRepository.getSession();
      if (session != null) {
        final userData = await _authRepository.getCurrentUser();
        _currentUser = User.fromJson(userData['user']);
      }
    } catch (e) {
      _currentUser = null;
      await _authRepository.logout();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> checkBiometricSupport() async {
    return await _biometricService.canAuthenticate();
  }

  Future<void> loginWithBiometrics() async {
    _setLoading(true);
    try {
      final deviceId = await _authRepository.getDeviceId();
      final deviceSecret = await _authRepository.getDeviceSecret();

      if (deviceId == null || deviceSecret == null) {
        throw 'Biometrik belum didaftarkan pada perangkat ini. Silakan login dengan password terlebih dahulu.';
      }

      final result = await _biometricService.authenticate(
        localizedReason: 'Masuk ke SafeExam dengan biometrik',
      );
      if (!result) {
        throw 'Verifikasi biometrik dibatalkan.';
      }

      final data = await _authRepository.loginWithBiometrics(
        deviceId: deviceId,
        deviceSecret: deviceSecret,
      );

      final user = User.fromJson(data['user']);
      _currentUser = user;

      await _saveSession(
        data['accessToken'],
        data['refreshToken'],
      );

      await _markGatePassed();
    } catch (e) {
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final errorCode = e.response?.data?['error']?['code'];
        // Sesuai PRD F02: Jika secret tidak cocok atau perangkat dicabut (401), hapus secret lokal
        if (statusCode == 401 || errorCode == 'DEVICE_NOT_FOUND' || errorCode == 'INVALID_SECRET') {
          await _authRepository.clearDeviceSecret();
          _isBiometricEnabled = false;
          notifyListeners();
        }
        final errorMessage = e.response?.data?['error']?['message'] ?? e.message;
        throw errorMessage;
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> enrollBiometrics() async {
    _setLoading(true);
    try {
      final supported = await _biometricService.canAuthenticate();
      if (!supported) {
        throw 'Perangkat tidak mendukung biometrik atau belum ada sidik jari / Face ID yang terdaftar pada pengaturan sistem.';
      }

      final verified = await _biometricService.authenticate(
        localizedReason: 'Konfirmasi biometrik untuk menghubungkan akun SafeExam ke perangkat ini',
      );
      if (!verified) {
        throw 'Verifikasi biometrik dibatalkan.';
      }

      final deviceId = DeviceUtils.generateUuid();
      final deviceSecret = DeviceUtils.generateDeviceSecret();
      final platform = DeviceUtils.getPlatformName();
      final deviceName = DeviceUtils.getDeviceName();

      await _authRepository.enrollBiometrics(
        deviceId: deviceId,
        deviceName: deviceName,
        platform: platform,
        deviceSecret: deviceSecret,
      );

      await _authRepository.saveDeviceSecret(deviceId, deviceSecret);
      _isBiometricEnabled = true;
      notifyListeners();
    } catch (e) {
      if (e is DioException) {
        final errorMessage = e.response?.data?['error']?['message'] ?? e.message;
        throw errorMessage;
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> disableBiometrics() async {
    _setLoading(true);
    try {
      final deviceId = await _authRepository.getDeviceId();
      if (deviceId != null) {
        await _authRepository.revokeBiometrics(deviceId);
      } else {
        await _authRepository.clearDeviceSecret();
      }
      _isBiometricEnabled = false;
      notifyListeners();
    } catch (e) {
      if (e is DioException) {
        final errorMessage = e.response?.data?['error']?['message'] ?? e.message;
        throw errorMessage;
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> unlockGate() async {
    try {
      final verified = await _biometricService.authenticate(
        localizedReason: 'Konfirmasi biometrik untuk mengakses SafeExam',
      );
      if (verified) {
        _isGatePassed = true;
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateProfile(String name) async {
    _setLoading(true);
    try {
      final res = await _authRepository.updateProfile(name: name);
      if (res['user'] != null) {
        _currentUser = User.fromJson(res['user']);
        notifyListeners();
      }
    } catch (e) {
      if (e is DioException) {
        final errorMessage = e.response?.data?['error']?['message'] ?? e.message;
        throw errorMessage;
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> uploadAvatar(String filePath) async {
    _setLoading(true);
    try {
      final res = await _authRepository.uploadAvatar(filePath);
      if (res['user'] != null) {
        _currentUser = User.fromJson(res['user']);
        notifyListeners();
      }
    } catch (e) {
      if (e is DioException) {
        final errorMessage = e.response?.data?['error']?['message'] ?? e.message;
        throw errorMessage;
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    try {
      await _authRepository.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      _isBiometricEnabled = false;
      notifyListeners();
    } catch (e) {
      if (e is DioException) {
        final errorMessage = e.response?.data?['error']?['message'] ?? e.message;
        throw errorMessage;
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Map<String, dynamic>>> getBiometricDevices() async {
    try {
      return await _authRepository.getBiometricDevices();
    } catch (e) {
      if (e is DioException) {
        final errorMessage = e.response?.data?['error']?['message'] ?? e.message;
        throw errorMessage;
      }
      rethrow;
    }
  }

  Future<void> revokeBiometricDevice(String deviceId) async {
    _setLoading(true);
    try {
      await _authRepository.revokeBiometrics(deviceId);
      final currentDeviceId = await _authRepository.getDeviceId();
      if (currentDeviceId == deviceId) {
        await _authRepository.clearDeviceSecret();
        _isBiometricEnabled = false;
      }
      notifyListeners();
    } catch (e) {
      if (e is DioException) {
        final errorMessage = e.response?.data?['error']?['message'] ?? e.message;
        throw errorMessage;
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _markGatePassed() async {
    _isGatePassed = true;
    notifyListeners();
  }
}
