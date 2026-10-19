import 'package:flutter_test/flutter_test.dart';
import 'package:thereisnocheating/core/utils/device_utils.dart';

void main() {
  group('DeviceUtils Tests', () {
    test('generateUuid generates a valid RFC 4122 UUID v4', () {
      final uuid = DeviceUtils.generateUuid();
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(uuidRegex.hasMatch(uuid), isTrue, reason: '$uuid is not a valid v4 UUID');
    });

    test('generateDeviceSecret produces 64-character hex string (256-bit)', () {
      final secret = DeviceUtils.generateDeviceSecret();
      expect(secret.length, equals(64));
      final hexRegex = RegExp(r'^[0-9a-f]{64}$');
      expect(hexRegex.hasMatch(secret), isTrue);
    });

    test('getPlatformName returns android or ios', () {
      final platform = DeviceUtils.getPlatformName();
      expect(platform == 'android' || platform == 'ios', isTrue);
    });
  });
}
