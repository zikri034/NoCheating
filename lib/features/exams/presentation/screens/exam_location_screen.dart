import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/services/geofence_service.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_card.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/widgets/neo_tag.dart';
import '../../data/models/exam_model.dart';

class ExamLocationScreen extends StatefulWidget {
  final ExamModel exam;

  const ExamLocationScreen({super.key, required this.exam});

  @override
  State<ExamLocationScreen> createState() => _ExamLocationScreenState();
}

class _ExamLocationScreenState extends State<ExamLocationScreen> {
  final GeofenceService _geofenceService = GeofenceService();
  final MapController _mapController = MapController();

  Position? _currentPosition;
  double? _distanceMeters;
  bool _isInside = false;
  bool _isMocked = false;
  bool _isLoading = true;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _checkLocation();
  }

  Future<void> _checkLocation() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Mengecek koordinat GPS...';
    });

    final venueLat = widget.exam.venueLat;
    final venueLng = widget.exam.venueLng;
    final radius = widget.exam.venueRadiusM?.toDouble() ?? 100.0;

    if (venueLat == null || venueLng == null) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Lokasi ujian tidak ditentukan oleh pengampu.';
      });
      return;
    }

    final hasPermission = await _geofenceService.checkAndRequestPermission();
    if (!hasPermission) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Izin lokasi ditolak atau GPS tidak aktif.';
      });
      return;
    }

    final status = await _geofenceService.checkGeofence(
      venueLat: venueLat,
      venueLng: venueLng,
      radiusMeters: radius,
    );

    if (status != null) {
      setState(() {
        _currentPosition = status.currentPosition;
        _distanceMeters = status.distanceMeters;
        _isInside = status.isInside;
        _isMocked = status.isMocked;
        _isLoading = false;
        _statusMessage = null;
      });

      if (_currentPosition != null) {
        _mapController.move(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          16.0,
        );
      }
    } else {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Gagal memperoleh posisi GPS saat ini.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final venueLat = widget.exam.venueLat ?? -6.175392;
    final venueLng = widget.exam.venueLng ?? 106.827153;
    final venueRadius = widget.exam.venueRadiusM?.toDouble() ?? 100.0;

    return Scaffold(
      backgroundColor: NeoColors.bg,
      appBar: AppBar(
        title: const Text(
          'LOKASI & GEOFENCE',
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: NeoColors.ink,
          ),
        ),
        backgroundColor: NeoColors.primary,
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: NeoColors.ink, width: 3),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: NeoColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // FlutterMap OpenStreetMap view
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(venueLat, venueLng),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.thereisnocheating',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: LatLng(venueLat, venueLng),
                    radius: venueRadius,
                    useRadiusInMeter: true,
                    color: NeoColors.primary.withValues(alpha: 0.25),
                    borderColor: NeoColors.ink,
                    borderStrokeWidth: 3.0,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Venue Marker
                  Marker(
                    point: LatLng(venueLat, venueLng),
                    width: 48,
                    height: 48,
                    child: const Icon(
                      Icons.location_on,
                      color: NeoColors.danger,
                      size: 44,
                    ),
                  ),
                  // Current Position Marker
                  if (_currentPosition != null)
                    Marker(
                      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.my_location,
                        color: NeoColors.info,
                        size: 34,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Bottom Neo-Brutalist Info Card
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: NeoCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.exam.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (!_isLoading && _distanceMeters != null)
                        NeoTag(
                          label: _isInside ? 'DALAM RADIUS' : 'DI LUAR RADIUS',
                          variant: _isInside ? NeoTagVariant.success : NeoTagVariant.danger,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: NeoColors.ink, thickness: 2),
                  const SizedBox(height: 8),

                  if (_isLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: NeoColors.ink),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _statusMessage ?? 'Memuat lokasi...',
                            style: const TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else if (_statusMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _statusMessage!,
                        style: const TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          color: NeoColors.danger,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Jarak ke Lokasi Ujian:',
                          style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 13),
                        ),
                        Text(
                          '${_distanceMeters!.round()} meter',
                          style: const TextStyle(
                            fontFamily: 'Space Mono',
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: NeoColors.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Radius Maksimal:',
                          style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 13),
                        ),
                        Text(
                          '${venueRadius.round()} meter',
                          style: const TextStyle(
                            fontFamily: 'Space Mono',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (_isMocked) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: NeoColors.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: NeoColors.danger, width: 2),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning, color: NeoColors.danger, size: 18),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'PERINGATAN: Lokasi palsu/mocked terdeteksi!',
                                style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  color: NeoColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: NeoButton(
                          text: 'REFRESH GPS',
                          variant: NeoButtonVariant.primary,
                          onPressed: _checkLocation,
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: NeoColors.surface,
                          side: const BorderSide(color: NeoColors.ink, width: 2.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.settings, color: NeoColors.ink),
                        tooltip: 'Pengaturan Lokasi',
                        onPressed: () => _geofenceService.openSettings(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
