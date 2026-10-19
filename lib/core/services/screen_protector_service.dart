import 'package:flutter/services.dart';

/// Service untuk mencegah tangkapan layar (screenshot/screen recording)
/// sesuai PRD F05: Android memakai FLAG_SECURE selama ujian.
class ScreenProtector {
  static const MethodChannel _channel =
      MethodChannel('com.example.thereisnocheating/screen_protector');

  /// Mengaktifkan FLAG_SECURE di Android dan proteksi layar di iOS
  static Future<void> preventScreenshotOn() async {
    try {
      await _channel.invokeMethod('preventScreenshotOn');
    } catch (_) {
      // Best-effort pada platform tanpa implementasi / headless test runner
    }
  }

  /// Menonaktifkan FLAG_SECURE
  static Future<void> preventScreenshotOff() async {
    try {
      await _channel.invokeMethod('preventScreenshotOff');
    } catch (_) {
      // Best-effort
    }
  }
}
