import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Check if the device has biometric hardware and if it's enrolled
  Future<bool> canAuthenticate() async {
    try {
      final bool canCheckBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  /// Get the list of available biometrics (Face, Fingerprint, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Get human-readable biometric label according to PRD F02:
  /// 'Face ID' (iOS face) atau 'Sidik Jari' (fingerprint/lainnya)
  Future<String> getBiometricLabel() async {
    try {
      final biometrics = await getAvailableBiometrics();
      if (biometrics.contains(BiometricType.face)) {
        return 'Face ID';
      }
    } catch (_) {}
    return 'Sidik Jari';
  }

  /// Perform biometric authentication
  Future<bool> authenticate({String? localizedReason}) async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason ?? 'Silakan verifikasi identitas Anda untuk melanjutkan',
        biometricOnly: true,
      );
      return didAuthenticate;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
