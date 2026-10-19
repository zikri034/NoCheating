import 'dart:io';
import 'dart:math';

/// Utility class for generating cryptographically secure UUID and device secrets,
/// as well as identifying client platform according to PRD F02 specifications.
class DeviceUtils {
  static final Random _secureRandom = Random.secure();

  /// Generates a RFC 4122 compliant UUID v4 string.
  static String generateUuid() {
    final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant RFC 4122

    String toHex(List<int> b) => b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${toHex(bytes.sublist(0, 4))}-${toHex(bytes.sublist(4, 6))}-${toHex(bytes.sublist(6, 8))}-${toHex(bytes.sublist(8, 10))}-${toHex(bytes.sublist(10, 16))}';
  }

  /// Generates a 256-bit cryptographically secure random secret (64 hex characters).
  static String generateDeviceSecret() {
    final bytes = List<int>.generate(32, (_) => _secureRandom.nextInt(256));
    return bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Returns the current platform name expected by backend: 'android' or 'ios'.
  static String getPlatformName() {
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
    } catch (_) {
      // In web or tests
    }
    return 'android';
  }

  /// Friendly device name for display
  static String getDeviceName() {
    try {
      if (Platform.isAndroid) return 'Android Phone';
      if (Platform.isIOS) return 'Apple iPhone';
    } catch (_) {}
    return 'Mobile Device';
  }
}
