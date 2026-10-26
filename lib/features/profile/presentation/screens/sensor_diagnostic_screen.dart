import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../../core/services/biometric_service.dart';
import '../../../../core/services/geofence_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/screen_protector_service.dart';
import '../../../../core/services/sensor_integrity_service.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/widgets/neo_card.dart';
import '../../../../core/widgets/neo_snackbar.dart';
import '../../../../core/widgets/neo_tag.dart';

class SensorDiagnosticScreen extends StatefulWidget {
  const SensorDiagnosticScreen({super.key});

  @override
  State<SensorDiagnosticScreen> createState() => _SensorDiagnosticScreenState();
}

class _SensorDiagnosticScreenState extends State<SensorDiagnosticScreen>
    with WidgetsBindingObserver {
  // --- Sensor Services ---
  final BiometricService _biometricService = BiometricService();
  final GeofenceService _geofenceService = GeofenceService();
  final ImagePicker _imagePicker = ImagePicker();

  // --- Accelerometer State ---
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _accelX = 0.0;
  double _accelY = 0.0;
  double _accelZ = 0.0;
  double _accelMagnitude = 9.8;
  double _baselineGravity = 9.8;
  bool _isShakeAlert = false;
  int _shakeCount = 0;
  Timer? _shakeResetTimer;

  // --- Gyroscope State ---
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  double _gyroX = 0.0;
  double _gyroY = 0.0;
  double _gyroZ = 0.0;
  double _angularSpeed = 0.0;
  bool _isRotationAlert = false;
  int _rotationCount = 0;
  Timer? _rotationResetTimer;

  // --- GPS & Geofence State ---
  Position? _currentPosition;
  bool _isLoadingGps = false;
  String? _gpsError;
  double _targetLat = -6.89148; // ITB Ganesha default
  double _targetLng = 107.61066;
  String _targetName = 'Institut Teknologi Bandung (Ganesha)';
  double _testRadiusMeters = 150.0;
  double? _calculatedDistance;
  bool? _isInsideGeofence;

  // --- Biometric State ---
  bool _checkingBiometric = true;
  bool _canAuthBiometric = false;
  String _biometricType = 'Memeriksa...';
  String? _lastBiometricResult;

  // --- Screen Protector State ---
  bool _isScreenProtected = false;

  // --- App Lifecycle / Background State ---
  DateTime? _pausedAt;
  final List<String> _lifecycleLogs = [];

  // --- Camera Test State ---
  String? _capturedImagePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSensors();
    _checkBiometrics();
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _shakeResetTimer?.cancel();
    _rotationResetTimer?.cancel();
    // Revert screen protector when leaving diagnostic page if it was enabled
    if (_isScreenProtected) {
      ScreenProtector.preventScreenshotOff();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _pausedAt != null) {
      final pausedSeconds = DateTime.now().difference(_pausedAt!).inSeconds;
      _pausedAt = null;
      final isCritical = SensorIntegrityService.isBackgroundCritical(pausedSeconds);
      final logEntry = 'Resumed: di latar belakang $pausedSeconds detik '
          '${isCritical ? '⚠️ [KRITIS >= 5s: UJIAN GAGAL]' : 'ℹ️ [AMAN < 5s]'}';
      setState(() {
        _lifecycleLogs.insert(0, logEntry);
        if (_lifecycleLogs.length > 5) _lifecycleLogs.removeLast();
      });
    }
  }

  void _initSensors() {
    // Accelerometer stream
    try {
      _accelSub = accelerometerEventStream().listen((event) {
        final mag = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        final diff = (mag - _baselineGravity).abs();
        final isShake = diff > SensorIntegrityService.shakeThresholdDiff;

        setState(() {
          _accelX = event.x;
          _accelY = event.y;
          _accelZ = event.z;
          _accelMagnitude = mag;

          if (isShake && !_isShakeAlert) {
            _isShakeAlert = true;
            _shakeCount++;
            _shakeResetTimer?.cancel();
            _shakeResetTimer = Timer(const Duration(milliseconds: 600), () {
              if (mounted) setState(() => _isShakeAlert = false);
            });
          }
        });
      }, onError: (_) {});
    } catch (_) {}

    // Gyroscope stream
    try {
      _gyroSub = gyroscopeEventStream().listen((event) {
        final speed = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        final isFastRot = speed > SensorIntegrityService.gyroAngularThreshold;

        setState(() {
          _gyroX = event.x;
          _gyroY = event.y;
          _gyroZ = event.z;
          _angularSpeed = speed;

          if (isFastRot && !_isRotationAlert) {
            _isRotationAlert = true;
            _rotationCount++;
            _rotationResetTimer?.cancel();
            _rotationResetTimer = Timer(const Duration(milliseconds: 600), () {
              if (mounted) setState(() => _isRotationAlert = false);
            });
          }
        });
      }, onError: (_) {});
    } catch (_) {}
  }

  void _calibrateGravityBaseline() {
    setState(() {
      _baselineGravity = _accelMagnitude;
    });
    NeoSnackbar.showSuccess(
      context,
      title: 'BASELINE DIKALIBRASI',
      message: 'Nilai gravitasi dasar diatur ke ${_baselineGravity.toStringAsFixed(2)} m/s².',
    );
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isLoadingGps = true;
      _gpsError = null;
    });

    try {
      final pos = await _geofenceService.getCurrentPosition();
      if (!mounted) return;
      if (pos == null) {
        setState(() {
          _isLoadingGps = false;
          _gpsError = 'Izin lokasi tidak diberikan atau GPS tidak aktif.';
        });
        return;
      }

      final dist = GeofenceService.calculateDistanceMeters(
        pos.latitude,
        pos.longitude,
        _targetLat,
        _targetLng,
      );

      setState(() {
        _currentPosition = pos;
        _isLoadingGps = false;
        _calculatedDistance = dist;
        _isInsideGeofence = dist <= _testRadiusMeters;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingGps = false;
        _gpsError = e.toString();
      });
    }
  }

  Future<void> _checkBiometrics() async {
    setState(() => _checkingBiometric = true);
    final canAuth = await _biometricService.canAuthenticate();
    final label = await _biometricService.getBiometricLabel();
    if (!mounted) return;
    setState(() {
      _checkingBiometric = false;
      _canAuthBiometric = canAuth;
      _biometricType = label;
    });
  }

  Future<void> _testBiometricAuth() async {
    final success = await _biometricService.authenticate(
      localizedReason: 'Uji Diagnostik SafeExam: Letakkan jari atau hadapkan wajah',
    );
    if (!mounted) return;
    setState(() {
      _lastBiometricResult = success ? 'BERHASIL TERVERIFIKASI ✅' : 'GAGAL / DIBATALKAN ❌';
    });
    if (success) {
      NeoSnackbar.showSuccess(
        context,
        title: 'VERIFIKASI SUKSES',
        message: 'Sensor biometrik $_biometricType membaca identitas dengan benar.',
      );
    } else {
      NeoSnackbar.showError(
        context,
        title: 'VERIFIKASI DITOLAK',
        message: 'Biometrik tidak cocok atau dialog dibatalkan pengguna.',
      );
    }
  }

  Future<void> _toggleScreenProtector(bool enable) async {
    setState(() => _isScreenProtected = enable);
    if (enable) {
      await ScreenProtector.preventScreenshotOn();
      if (mounted) {
        NeoSnackbar.showWarning(
          context,
          title: 'FLAG_SECURE AKTIF',
          message: 'Tangkapan layar (screenshot/recording) sekarang diblokir oleh sistem HP!',
        );
      }
    } else {
      await ScreenProtector.preventScreenshotOff();
      if (mounted) {
        NeoSnackbar.showInfo(
          context,
          title: 'FLAG_SECURE NONAKTIF',
          message: 'Proteksi layar dimatikan.',
        );
      }
    }
  }

  Future<void> _testCamera() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 600,
        maxHeight: 600,
      );
      if (picked != null && mounted) {
        setState(() => _capturedImagePath = picked.path);
        NeoSnackbar.showSuccess(
          context,
          title: 'KAMERA BERFUNGSI',
          message: 'Foto berhasil diambil: ${picked.name}',
        );
      }
    } catch (e) {
      if (mounted) {
        NeoSnackbar.showError(
          context,
          title: 'KAMERA GAGAL',
          message: 'Terjadi kendala saat mengakses kamera: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeoColors.bg,
      appBar: AppBar(
        title: const Text(
          'LAB DIAGNOSTIK SENSOR',
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: NeoColors.ink,
          ),
        ),
        backgroundColor: NeoColors.primary,
        foregroundColor: NeoColors.ink,
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: NeoColors.ink, width: 3),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: NeoColors.ink),
            tooltip: 'Segarkan GPS & Biometrik',
            onPressed: () {
              _fetchCurrentLocation();
              _checkBiometrics();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner Info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: NeoColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: NeoColors.ink, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: NeoColors.ink,
                    offset: Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NeoColors.tertiary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: NeoColors.ink, width: 2),
                    ),
                    child: const Icon(Icons.sensors, color: NeoColors.ink, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PEMANTAUAN SENSOR REAL-TIME',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: NeoColors.ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Uji dan amati respons sensor pengawasan ujian secara langsung.',
                          style: TextStyle(
                            fontFamily: 'Hanken Grotesk',
                            fontSize: 12,
                            color: NeoColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 1. AKSELEROMETER (GUNCANGAN / SHAKE)
            _buildAccelerometerCard(),
            const SizedBox(height: 16),

            // 2. GIROSKOP (ROTASI CEPAT / GYROSCOPE)
            _buildGyroscopeCard(),
            const SizedBox(height: 16),

            // 3. GPS & GEOFENCE CALCULATOR
            _buildGpsGeofenceCard(),
            const SizedBox(height: 16),

            // 4. BIOMETRIK (SIDIK JARI / FACE ID)
            _buildBiometricCard(),
            const SizedBox(height: 16),

            // 5. PROTEKSI LAYAR (ANTI-SCREENSHOT)
            _buildScreenProtectorCard(),
            const SizedBox(height: 16),

            // 6. DETEKSI LATAR BELAKANG (LIFECYCLE)
            _buildLifecycleCard(),
            const SizedBox(height: 16),

            // 7. UJI KAMERA & MEDIA
            _buildCameraCard(),
            const SizedBox(height: 16),

            // 8. UJI NOTIFIKASI & ALARM
            _buildNotificationAlarmCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- 1. ACCELEROMETER CARD ---
  Widget _buildAccelerometerCard() {
    final diff = (_accelMagnitude - _baselineGravity).abs();

    return NeoCard(
      header: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.vibration, size: 20, color: NeoColors.ink),
              SizedBox(width: 8),
              Text(
                '1. AKSELEROMETER (GUNCANGAN)',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: NeoColors.ink,
                ),
              ),
            ],
          ),
          NeoTag(
            label: '$_shakeCount GUNCANGAN',
            variant: _shakeCount > 0 ? NeoTagVariant.danger : NeoTagVariant.muted,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Shake Alert Banner
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: _isShakeAlert ? NeoColors.danger : NeoColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: NeoColors.ink, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isShakeAlert ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  color: _isShakeAlert ? Colors.white : NeoColors.success,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isShakeAlert ? 'GUNCANGAN TERDETEKSI! (SHAKE ALERT)' : 'Kondisi Tenang / Normal',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: _isShakeAlert ? Colors.white : NeoColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Axis metrics
          Row(
            children: [
              Expanded(child: _buildMetricTile('X', _accelX.toStringAsFixed(2), 'm/s²')),
              const SizedBox(width: 6),
              Expanded(child: _buildMetricTile('Y', _accelY.toStringAsFixed(2), 'm/s²')),
              const SizedBox(width: 6),
              Expanded(child: _buildMetricTile('Z', _accelZ.toStringAsFixed(2), 'm/s²')),
            ],
          ),
          const SizedBox(height: 10),

          // Magnitude & Baseline
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: NeoColors.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NeoColors.ink, width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Magnitude:', style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 13, fontWeight: FontWeight.bold)),
                    Text('${_accelMagnitude.toStringAsFixed(2)} m/s²', style: const TextStyle(fontFamily: 'Space Mono', fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Baseline Gravitasi:', style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 13)),
                    Text('${_baselineGravity.toStringAsFixed(2)} m/s²', style: const TextStyle(fontFamily: 'Space Mono', fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Deviasi (Threshold > 6.0):', style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 13)),
                    Text(
                      '${diff.toStringAsFixed(2)} m/s²',
                      style: TextStyle(
                        fontFamily: 'Space Mono',
                        fontWeight: FontWeight.w900,
                        color: diff > 6.0 ? NeoColors.danger : NeoColors.ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Action
          Row(
            children: [
              Expanded(
                child: NeoButton(
                  text: 'KALIBRASI BASELINE',
                  icon: const Icon(Icons.tune, size: 16),
                  backgroundColor: NeoColors.secondary,
                  fontSize: 12,
                  onPressed: _calibrateGravityBaseline,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: NeoColors.ink, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  backgroundColor: NeoColors.surface,
                ),
                onPressed: () => setState(() => _shakeCount = 0),
                child: const Text('RESET', style: TextStyle(fontFamily: 'Space Grotesk', fontWeight: FontWeight.bold, color: NeoColors.ink)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 2. GYROSCOPE CARD ---
  Widget _buildGyroscopeCard() {
    return NeoCard(
      header: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.screen_rotation, size: 20, color: NeoColors.ink),
              SizedBox(width: 8),
              Text(
                '2. GIROSKOP (ROTASI SUDUT)',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: NeoColors.ink,
                ),
              ),
            ],
          ),
          NeoTag(
            label: '$_rotationCount ROTASI',
            variant: _rotationCount > 0 ? NeoTagVariant.danger : NeoTagVariant.muted,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rotation Alert Banner
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: _isRotationAlert ? NeoColors.danger : NeoColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: NeoColors.ink, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isRotationAlert ? Icons.rotate_right : Icons.check_circle_outline,
                  color: _isRotationAlert ? Colors.white : NeoColors.success,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isRotationAlert ? 'ROTASI TAJAM TERDETEKSI! (> 3.0 rad/s)' : 'Rotasi Sudut Normal',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: _isRotationAlert ? Colors.white : NeoColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Axis metrics
          Row(
            children: [
              Expanded(child: _buildMetricTile('Rot X', _gyroX.toStringAsFixed(2), 'rad/s')),
              const SizedBox(width: 6),
              Expanded(child: _buildMetricTile('Rot Y', _gyroY.toStringAsFixed(2), 'rad/s')),
              const SizedBox(width: 6),
              Expanded(child: _buildMetricTile('Rot Z', _gyroZ.toStringAsFixed(2), 'rad/s')),
            ],
          ),
          const SizedBox(height: 10),

          // Total Angular Speed
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: NeoColors.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NeoColors.ink, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Kecepatan Sudut (Threshold > 3.0):', style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 13, fontWeight: FontWeight.bold)),
                Text(
                  '${_angularSpeed.toStringAsFixed(2)} rad/s',
                  style: TextStyle(
                    fontFamily: 'Space Mono',
                    fontWeight: FontWeight.w900,
                    color: _angularSpeed > 3.0 ? NeoColors.danger : NeoColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: NeoColors.ink, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                backgroundColor: NeoColors.surface,
              ),
              onPressed: () => setState(() => _rotationCount = 0),
              child: const Text('RESET COUNTER', style: TextStyle(fontFamily: 'Space Grotesk', fontWeight: FontWeight.bold, color: NeoColors.ink)),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. GPS & GEOFENCE CARD ---
  Widget _buildGpsGeofenceCard() {
    return NeoCard(
      header: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, size: 20, color: NeoColors.ink),
              SizedBox(width: 8),
              Text(
                '3. GPS & GEOFENCE DISTANCE',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: NeoColors.ink,
                ),
              ),
            ],
          ),
          if (_currentPosition != null)
            NeoTag(
              label: _currentPosition!.isMocked ? 'FAKE GPS!' : 'ASLI (REAL)',
              variant: _currentPosition!.isMocked ? NeoTagVariant.danger : NeoTagVariant.success,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isLoadingGps)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(color: NeoColors.ink)),
            )
          else if (_gpsError != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NeoColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NeoColors.danger, width: 1.5),
              ),
              child: Text(_gpsError!, style: const TextStyle(color: NeoColors.danger, fontWeight: FontWeight.bold)),
            )
          else if (_currentPosition != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NeoColors.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NeoColors.ink, width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Latitude:', style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 13)),
                      Text(_currentPosition!.latitude.toStringAsFixed(6), style: const TextStyle(fontFamily: 'Space Mono', fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Longitude:', style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 13)),
                      Text(_currentPosition!.longitude.toStringAsFixed(6), style: const TextStyle(fontFamily: 'Space Mono', fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Akurasi GPS:', style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 13)),
                      Text('±${_currentPosition!.accuracy.toStringAsFixed(1)} meter', style: const TextStyle(fontFamily: 'Space Mono', fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Mock / Fake GPS:', style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 13)),
                      Text(
                        _currentPosition!.isMocked ? 'TERDETEKSI FAKE!' : 'Tidak (Aman)',
                        style: TextStyle(
                          fontFamily: 'Space Mono',
                          fontWeight: FontWeight.bold,
                          color: _currentPosition!.isMocked ? NeoColors.danger : NeoColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Geofence Evaluation vs Target
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isInsideGeofence == true ? NeoColors.success.withValues(alpha: 0.15) : NeoColors.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isInsideGeofence == true ? NeoColors.success : NeoColors.danger,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Uji Jarak ke Titik Target:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _isInsideGeofence == true ? NeoColors.success : NeoColors.danger,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _isInsideGeofence == true ? 'DI DALAM RADIUS' : 'DI LUAR RADIUS',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Target: $_targetName', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Jarak: ${((_calculatedDistance ?? 0) > 1000 ? "${((_calculatedDistance ?? 0) / 1000).toStringAsFixed(2)} km" : "${(_calculatedDistance ?? 0).toStringAsFixed(1)} m")}'),
                      Text('Radius Uji: ${_testRadiusMeters.toInt()} m'),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Preset Target Campus Buttons
          const Text('Uji Titik Kampus Contoh:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildPresetChip('ITB', -6.89148, 107.61066, 'ITB Ganesha'),
              _buildPresetChip('UI Depok', -6.36531, 106.83152, 'UI Depok'),
              _buildPresetChip('UGM', -7.77092, 110.37772, 'UGM Jogja'),
              _buildPresetChip('Monas', -6.175392, 106.827153, 'Monas Jakarta'),
              _buildPresetChip('Posisi Saya (Radius 50m)', _currentPosition?.latitude ?? -6.175, _currentPosition?.longitude ?? 106.827, 'Titik Saya Sendiri', radius: 50),
            ],
          ),
          const SizedBox(height: 10),
          NeoButton(
            text: 'BACA ULANG GPS SEKARANG',
            icon: const Icon(Icons.my_location, size: 16),
            backgroundColor: NeoColors.primary,
            fontSize: 12,
            onPressed: _fetchCurrentLocation,
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, double lat, double lng, String name, {double radius = 150}) {
    final isSelected = (_targetLat - lat).abs() < 0.0001 && (_targetLng - lng).abs() < 0.0001;
    return GestureDetector(
      onTap: () {
        setState(() {
          _targetLat = lat;
          _targetLng = lng;
          _targetName = name;
          _testRadiusMeters = radius;
          if (_currentPosition != null) {
            final dist = GeofenceService.calculateDistanceMeters(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              lat,
              lng,
            );
            _calculatedDistance = dist;
            _isInsideGeofence = dist <= radius;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? NeoColors.primary : NeoColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: NeoColors.ink, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : NeoColors.ink,
          ),
        ),
      ),
    );
  }

  // --- 4. BIOMETRIC CARD ---
  Widget _buildBiometricCard() {
    return NeoCard(
      header: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.fingerprint, size: 20, color: NeoColors.ink),
              SizedBox(width: 8),
              Text(
                '4. SENSOR BIOMETRIK',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: NeoColors.ink,
                ),
              ),
            ],
          ),
          NeoTag(
            label: _checkingBiometric
                ? 'MEMERIKSA...'
                : (_canAuthBiometric ? 'DIDUKUNG' : 'TIDAK TERSEDIA'),
            variant: _checkingBiometric
                ? NeoTagVariant.muted
                : (_canAuthBiometric ? NeoTagVariant.success : NeoTagVariant.danger),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tipe Sensor: $_biometricType',
            style: const TextStyle(fontFamily: 'Space Grotesk', fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            _canAuthBiometric
                ? 'Perangkat Anda memiliki sensor biometrik aktif yang siap digunakan untuk verifikasi kehadiran ujian.'
                : 'Sensor biometrik tidak ditemukan atau belum didaftarkan di pengaturan keamanan perangkat.',
            style: const TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 12),
          ),
          if (_lastBiometricResult != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NeoColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: NeoColors.ink, width: 1.5),
              ),
              child: Text(
                'Hasil Uji Terakhir: $_lastBiometricResult',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 12),
          NeoButton(
            text: 'UJI DIALOG BIOMETRIK SEKARANG',
            icon: const Icon(Icons.fingerprint, size: 16),
            backgroundColor: NeoColors.secondary,
            fontSize: 12,
            onPressed: _canAuthBiometric ? _testBiometricAuth : null,
          ),
        ],
      ),
    );
  }

  // --- 5. SCREEN PROTECTOR CARD ---
  Widget _buildScreenProtectorCard() {
    return NeoCard(
      header: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.screenshot_outlined, size: 20, color: NeoColors.ink),
              SizedBox(width: 8),
              Text(
                '5. PROTEKSI LAYAR & SCREENSHOT',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: NeoColors.ink,
                ),
              ),
            ],
          ),
          NeoTag(
            label: _isScreenProtected ? 'AKTIF (FLAG_SECURE)' : 'NONAKTIF',
            variant: _isScreenProtected ? NeoTagVariant.success : NeoTagVariant.muted,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Saat proteksi aktif (FLAG_SECURE), sistem Android akan memblokir screenshot dan perekaman layar (tampilan menjadi hitam atau muncul notifikasi diblokir kebijakan keamanan).',
            style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 12),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Aktifkan Anti-Screenshot Sekarang', style: TextStyle(fontFamily: 'Space Grotesk', fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(_isScreenProtected ? 'Silakan coba tekan tombol Power + Vol Down di HP' : 'Proteksi layar mati', style: const TextStyle(fontSize: 11)),
            value: _isScreenProtected,
            activeTrackColor: NeoColors.primary,
            onChanged: _toggleScreenProtector,
          ),
        ],
      ),
    );
  }

  // --- 6. APP LIFECYCLE CARD ---
  Widget _buildLifecycleCard() {
    return NeoCard(
      header: const Row(
        children: [
          Icon(Icons.hourglass_bottom, size: 20, color: NeoColors.ink),
          SizedBox(width: 8),
          Text(
            '6. DETEKSI APLIKASI DI BACKGROUND',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: NeoColors.ink,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cara Uji: Tekan tombol Home atau buka aplikasi lain, tunggu beberapa detik, lalu kembali ke aplikasi SafeExam ini.',
            style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 12),
          ),
          const SizedBox(height: 6),
          const Text(
            '• Ambang Batas Aman: < 5 detik (hanya log biasa)\n• Ambang Batas Kritis: >= 5 detik (pelanggaran kritis auto-terminate di ujian)',
            style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (_lifecycleLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NeoColors.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: NeoColors.ink, width: 1.5),
              ),
              child: const Text('Belum ada log minimize. Coba minimize aplikasi ini sebentar.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            )
          else
            Column(
              children: _lifecycleLogs.map((log) {
                final isCritical = log.contains('KRITIS');
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCritical ? NeoColors.danger.withValues(alpha: 0.15) : NeoColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isCritical ? NeoColors.danger : NeoColors.ink, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(isCritical ? Icons.cancel : Icons.info, size: 16, color: isCritical ? NeoColors.danger : NeoColors.ink),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'Space Mono',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCritical ? NeoColors.danger : NeoColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // --- 7. CAMERA CARD ---
  Widget _buildCameraCard() {
    return NeoCard(
      header: const Row(
        children: [
          Icon(Icons.camera_alt, size: 20, color: NeoColors.ink),
          SizedBox(width: 8),
          Text(
            '7. UJI KAMERA & VERIFIKASI WAJAH',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: NeoColors.ink,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Kamera digunakan untuk verifikasi foto wajah sebelum mulai ujian serta foto profil akun.',
            style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 12),
          ),
          if (_capturedImagePath != null) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: NeoColors.ink, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(File(_capturedImagePath!), fit: BoxFit.cover),
              ),
            ),
          ],
          const SizedBox(height: 12),
          NeoButton(
            text: 'BUKA KAMERA UJI COBA',
            icon: const Icon(Icons.photo_camera, size: 16),
            backgroundColor: NeoColors.tertiary,
            fontSize: 12,
            onPressed: _testCamera,
          ),
        ],
      ),
    );
  }

  // --- 8. NOTIFICATION & ALARM CARD ---
  Widget _buildNotificationAlarmCard() {
    return NeoCard(
      header: const Row(
        children: [
          Icon(Icons.alarm, size: 20, color: NeoColors.ink),
          SizedBox(width: 8),
          Text(
            '8. NOTIFIKASI & ALARM PENGINGAT',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: NeoColors.ink,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Uji sistem notifikasi lokal dan penjadwalan alarm tepat waktu untuk pengingat jadwal ujian.',
            style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: NeoButton(
                  text: 'NOTIFIKASI INSTAN',
                  icon: const Icon(Icons.notifications_active, size: 16),
                  backgroundColor: NeoColors.primary,
                  fontSize: 11,
                  onPressed: () async {
                    await NotificationService.instance.showTestNotification();
                    if (!mounted) return;
                    NeoSnackbar.showSuccess(
                      context,
                      title: 'NOTIFIKASI TERKIRIM',
                      message: 'Periksa status bar HP Anda.',
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NeoButton(
                  text: 'ALARM 5 DETIK',
                  icon: const Icon(Icons.alarm, size: 16),
                  backgroundColor: NeoColors.secondary,
                  fontSize: 11,
                  onPressed: () async {
                    await NotificationService.instance.scheduleQuickTestNotification(delaySeconds: 5);
                    if (!mounted) return;
                    NeoSnackbar.showInfo(
                      context,
                      title: 'ALARM DIJADWALKAN',
                      message: 'Alarm akan berdering dalam 5 detik.',
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: NeoColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: NeoColors.ink, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontFamily: 'Space Grotesk', fontWeight: FontWeight.w900, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontFamily: 'Space Mono', fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(
            unit,
            style: TextStyle(fontSize: 10, color: NeoColors.ink.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}
