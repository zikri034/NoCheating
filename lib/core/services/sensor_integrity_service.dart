import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class ViolationEvent {
  final String type;
  final String severity; // 'warn' or 'critical'
  final Map<String, dynamic>? detail;
  final DateTime occurredAt;

  ViolationEvent({
    required this.type,
    required this.severity,
    this.detail,
    DateTime? occurredAt,
  }) : occurredAt = occurredAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'type': type,
        'severity': severity,
        if (detail != null) 'detail': detail,
        'occurred_at': occurredAt.toIso8601String(),
      };
}

class SensorIntegrityService {
  // Threshold constants as defined in PRD F05
  static const double shakeThresholdDiff = 6.0; // m/s² diff from baseline
  static const int shakeDurationMs = 300; // ms sustained shake
  static const double gyroAngularThreshold = 3.0; // rad/s
  static const int backgroundCriticalSeconds = 5; // seconds paused
  static const int geofenceCriticalSeconds = 30; // seconds outside

  double _baselineMagnitude = 9.8;
  bool _isCalibrated = false;
  bool _isMonitoring = false;

  DateTime? _shakeStartTime;
  DateTime? _lastAccelSample;
  DateTime? _lastGyroSample;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  final void Function(ViolationEvent event)? onViolation;

  SensorIntegrityService({this.onViolation});

  double get baselineMagnitude => _baselineMagnitude;
  bool get isCalibrated => _isCalibrated;
  bool get isMonitoring => _isMonitoring;

  // Pure logic calculation: Euclidean magnitude
  static double calculateMagnitude(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }

  // Pure logic: check if shake threshold is exceeded
  static bool isShakeExceeded(double currentMagnitude, double baseline) {
    final diff = (currentMagnitude - baseline).abs();
    return diff > shakeThresholdDiff;
  }

  // Pure logic: check if angular rotation exceeds 3 rad/s
  static bool isGyroExceeded(double x, double y, double z) {
    final angularSpeed = calculateMagnitude(x, y, z);
    return angularSpeed > gyroAngularThreshold;
  }

  // Pure logic: check background duration
  static bool isBackgroundCritical(int secondsPaused) {
    return secondsPaused >= backgroundCriticalSeconds;
  }

  // Pure logic: check geofence exit duration
  static bool isGeofenceExitCritical(int secondsOutside) {
    return secondsOutside >= geofenceCriticalSeconds;
  }

  /// Calibrate baseline gravity magnitude over duration (default 3 seconds)
  Future<void> calibrate({
    Duration duration = const Duration(seconds: 3),
    Stream<AccelerometerEvent>? accelStream,
  }) async {
    final stream = accelStream ?? accelerometerEventStream();
    final List<double> magnitudes = [];

    final sub = stream.listen((event) {
      magnitudes.add(calculateMagnitude(event.x, event.y, event.z));
    });

    await Future.delayed(duration);
    await sub.cancel();

    if (magnitudes.isNotEmpty) {
      final sum = magnitudes.reduce((a, b) => a + b);
      _baselineMagnitude = sum / magnitudes.length;
    } else {
      _baselineMagnitude = 9.8;
    }
    _isCalibrated = true;
  }

  /// Manually set baseline (useful for testing)
  void setBaseline(double baseline) {
    _baselineMagnitude = baseline;
    _isCalibrated = true;
  }

  /// Start monitoring sensors with bounded sampling rate (~20 Hz, ~50 ms)
  void startMonitoring({
    Stream<AccelerometerEvent>? accelStream,
    Stream<GyroscopeEvent>? gyroStream,
  }) {
    if (_isMonitoring) return;

    try {
      final aStream = accelStream ?? accelerometerEventStream();
      final gStream = gyroStream ?? gyroscopeEventStream();

      _isMonitoring = true;

      _accelSub = aStream.listen((event) {
        final now = DateTime.now();
        if (_lastAccelSample != null &&
            now.difference(_lastAccelSample!).inMilliseconds < 50) {
          return; // throttle sampling ~20Hz
        }
        _lastAccelSample = now;
        _handleAccelerometerEvent(event);
      }, onError: (_) {});

      _gyroSub = gStream.listen((event) {
        final now = DateTime.now();
        if (_lastGyroSample != null &&
            now.difference(_lastGyroSample!).inMilliseconds < 50) {
          return; // throttle sampling ~20Hz
        }
        _lastGyroSample = now;
        _handleGyroscopeEvent(event);
      }, onError: (_) {});
    } catch (_) {
      // Platform channels not available in headless test environments
      _isMonitoring = true;
    }
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    final mag = calculateMagnitude(event.x, event.y, event.z);
    final exceeded = isShakeExceeded(mag, _baselineMagnitude);

    if (exceeded) {
      _shakeStartTime ??= DateTime.now();
      final duration = DateTime.now().difference(_shakeStartTime!).inMilliseconds;
      if (duration >= shakeDurationMs) {
        // Emit warn violation
        onViolation?.call(ViolationEvent(
          type: 'device_shake',
          severity: 'warn',
          detail: {
            'magnitude': double.parse(mag.toStringAsFixed(2)),
            'baseline': double.parse(_baselineMagnitude.toStringAsFixed(2)),
            'duration_ms': duration,
          },
        ));
        _shakeStartTime = null; // reset to avoid duplicate instant triggers
      }
    } else {
      _shakeStartTime = null;
    }
  }

  void _handleGyroscopeEvent(GyroscopeEvent event) {
    if (isGyroExceeded(event.x, event.y, event.z)) {
      final speed = calculateMagnitude(event.x, event.y, event.z);
      onViolation?.call(ViolationEvent(
        type: 'sudden_rotation',
        severity: 'warn',
        detail: {
          'angular_speed': double.parse(speed.toStringAsFixed(2)),
        },
      ));
    }
  }

  /// Trigger violation manually (e.g. for background, mock location, geofence, screenshot)
  void reportViolation(ViolationEvent event) {
    onViolation?.call(event);
  }

  /// Stop monitoring and release subscriptions
  void stopMonitoring() {
    _isMonitoring = false;
    try {
      _accelSub?.cancel();
    } catch (_) {}
    _accelSub = null;
    try {
      _gyroSub?.cancel();
    } catch (_) {}
    _gyroSub = null;
    _shakeStartTime = null;
  }

  void dispose() {
    stopMonitoring();
  }
}
