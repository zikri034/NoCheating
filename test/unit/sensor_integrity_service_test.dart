import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:thereisnocheating/core/services/sensor_integrity_service.dart';

void main() {
  group('SensorIntegrityService (F05 Logic & Thresholds)', () {
    test('calculateMagnitude calculates 3D Euclidean vector length', () {
      expect(SensorIntegrityService.calculateMagnitude(3, 4, 0), closeTo(5.0, 0.001));
      expect(SensorIntegrityService.calculateMagnitude(0, 0, 9.8), closeTo(9.8, 0.001));
      expect(SensorIntegrityService.calculateMagnitude(1, 2, 2), closeTo(3.0, 0.001));
    });

    test('isShakeExceeded correctly evaluates difference against baseline (PRD > 6.0 m/s²)', () {
      const baseline = 9.8;

      // Small jitter -> not exceeded
      expect(SensorIntegrityService.isShakeExceeded(12.0, baseline), isFalse); // diff 2.2
      expect(SensorIntegrityService.isShakeExceeded(15.7, baseline), isFalse); // diff 5.9

      // Sudden shake -> exceeded
      expect(SensorIntegrityService.isShakeExceeded(16.0, baseline), isTrue); // diff 6.2 > 6.0
      expect(SensorIntegrityService.isShakeExceeded(2.0, baseline), isTrue); // diff 7.8 > 6.0
    });

    test('isGyroExceeded evaluates angular speed against threshold (PRD > 3.0 rad/s)', () {
      // Slow rotation -> not exceeded
      expect(SensorIntegrityService.isGyroExceeded(1.0, 1.0, 1.0), isFalse); // sqrt(3) ~ 1.73

      // Sudden fast rotation -> exceeded
      expect(SensorIntegrityService.isGyroExceeded(2.0, 2.5, 2.0), isTrue); // sqrt(4+6.25+4) = 3.77 > 3.0
    });

    test('isBackgroundCritical evaluates background duration (PRD >= 5s)', () {
      expect(SensorIntegrityService.isBackgroundCritical(2), isFalse);
      expect(SensorIntegrityService.isBackgroundCritical(4), isFalse);
      expect(SensorIntegrityService.isBackgroundCritical(5), isTrue);
      expect(SensorIntegrityService.isBackgroundCritical(10), isTrue);
    });

    test('isGeofenceExitCritical evaluates geofence out duration (PRD >= 30s)', () {
      expect(SensorIntegrityService.isGeofenceExitCritical(10), isFalse);
      expect(SensorIntegrityService.isGeofenceExitCritical(29), isFalse);
      expect(SensorIntegrityService.isGeofenceExitCritical(30), isTrue);
      expect(SensorIntegrityService.isGeofenceExitCritical(60), isTrue);
    });

    test('manual baseline setting and violation reporting', () {
      final violations = <ViolationEvent>[];
      final service = SensorIntegrityService(onViolation: (v) => violations.add(v));

      service.setBaseline(9.81);
      expect(service.isCalibrated, isTrue);
      expect(service.baselineMagnitude, closeTo(9.81, 0.001));

      service.reportViolation(ViolationEvent(
        type: 'device_shake',
        severity: 'warn',
        detail: {'magnitude': 17.5},
      ));

      expect(violations.length, 1);
      expect(violations.first.type, 'device_shake');
      expect(violations.first.severity, 'warn');
      expect(violations.first.detail?['magnitude'], 17.5);
    });

    test('monitoring stream emits sudden_rotation when gyro exceeds 3.0 rad/s', () async {
      final violations = <ViolationEvent>[];
      final service = SensorIntegrityService(onViolation: (v) => violations.add(v));

      final gyroController = StreamController<GyroscopeEvent>.broadcast();
      final accelController = StreamController<AccelerometerEvent>.broadcast();

      service.startMonitoring(
        accelStream: accelController.stream,
        gyroStream: gyroController.stream,
      );

      expect(service.isMonitoring, isTrue);

      // Emit fast rotation
      gyroController.add(GyroscopeEvent(2.5, 2.5, 2.5, DateTime.now()));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(violations.any((v) => v.type == 'sudden_rotation'), isTrue);

      service.stopMonitoring();
      expect(service.isMonitoring, isFalse);

      await gyroController.close();
      await accelController.close();
    });
  });
}
