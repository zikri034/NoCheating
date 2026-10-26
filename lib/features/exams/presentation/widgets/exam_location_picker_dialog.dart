import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/services/geofence_service.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/widgets/neo_snackbar.dart';

class ExamLocationPickerResult {
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final String locationName;

  ExamLocationPickerResult({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.locationName,
  });
}

class ExamLocationPickerDialog extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final int initialRadius;
  final String? initialLocationName;

  const ExamLocationPickerDialog({
    super.key,
    this.initialLat = -6.175392,
    this.initialLng = 106.827153,
    this.initialRadius = 150,
    this.initialLocationName,
  });

  static const List<Map<String, dynamic>> campusPresets = [
    {'short': 'ITB Ganesha', 'name': 'Institut Teknologi Bandung (Ganesha)', 'lat': -6.89148, 'lng': 107.61066},
    {'short': 'UI Depok', 'name': 'Universitas Indonesia (Depok)', 'lat': -6.36531, 'lng': 106.83152},
    {'short': 'UGM Jogja', 'name': 'Universitas Gadjah Mada (Yogyakarta)', 'lat': -7.77092, 'lng': 110.37772},
    {'short': 'Telkom Univ', 'name': 'Telkom University (Bandung)', 'lat': -6.97403, 'lng': 107.63035},
    {'short': 'ITS Surabaya', 'name': 'Institut Teknologi Sepuluh Nopember (Surabaya)', 'lat': -7.28236, 'lng': 112.79493},
    {'short': 'Unpad', 'name': 'Universitas Padjadjaran (Jatinangor)', 'lat': -6.92722, 'lng': 107.77381},
    {'short': 'Undip', 'name': 'Universitas Diponegoro (Semarang)', 'lat': -7.04944, 'lng': 110.43981},
    {'short': 'IPB Dramaga', 'name': 'IPB University (Bogor)', 'lat': -6.55986, 'lng': 106.72684},
    {'short': 'Monas Jkt', 'name': 'Monas (Jakarta Pusat)', 'lat': -6.175392, 'lng': 106.827153},
  ];

  @override
  State<ExamLocationPickerDialog> createState() => _ExamLocationPickerDialogState();
}

class _ExamLocationPickerDialogState extends State<ExamLocationPickerDialog> {
  late LatLng _selectedPoint;
  late double _selectedRadius;
  late String _locationName;

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
    headers: {'User-Agent': 'SafeExamApp/1.0 (SafeExam Geofence Picker)'},
  ));

  bool _isSearching = false;
  bool _isGettingGps = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _selectedPoint = LatLng(widget.initialLat, widget.initialLng);
    _selectedRadius = widget.initialRadius.toDouble();
    _locationName = widget.initialLocationName ?? 'Titik Lokasi Ujian';

    if (widget.initialLocationName == null || widget.initialLocationName!.isEmpty) {
      _reverseGeocode(_selectedPoint);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _dio.close();
    super.dispose();
  }

  void _onMapTap(LatLng point) {
    setState(() {
      _selectedPoint = point;
      _searchResults.clear();
    });
    _reverseGeocode(point);
  }

  Future<void> _reverseGeocode(LatLng point) async {
    try {
      final res = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': point.latitude,
          'lon': point.longitude,
          'format': 'json',
          'zoom': 18,
          'addressdetails': 1,
        },
      );
      if (!mounted) return;
      if (res.data is Map && res.data['display_name'] != null) {
        final displayName = res.data['display_name'].toString();
        // Ambil bagian awal dari alamat agar lebih ringkas
        final parts = displayName.split(',');
        final conciseName = parts.length > 3 ? parts.take(3).join(',').trim() : displayName;
        setState(() {
          _locationName = conciseName;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationName = 'Koordinat: ${_selectedPoint.latitude.toStringAsFixed(5)}, ${_selectedPoint.longitude.toStringAsFixed(5)}';
        });
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final res = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query.trim(),
          'format': 'json',
          'limit': 5,
          'countrycodes': 'id',
          'addressdetails': 1,
        },
      );

      if (!mounted) return;
      if (res.data is List) {
        final list = (res.data as List).cast<Map<String, dynamic>>();
        setState(() {
          _searchResults = list;
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
      }
    }
  }

  void _selectSearchResult(Map<String, dynamic> item) {
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');
    if (lat != null && lon != null) {
      final point = LatLng(lat, lon);
      final displayName = item['display_name']?.toString() ?? 'Lokasi Terpilih';
      final parts = displayName.split(',');
      final conciseName = parts.length > 3 ? parts.take(3).join(',').trim() : displayName;

      setState(() {
        _selectedPoint = point;
        _locationName = conciseName;
        _searchResults.clear();
        _searchController.text = conciseName;
      });

      _mapController.move(point, 16.0);
    }
  }

  void _selectPreset(Map<String, dynamic> preset) {
    final point = LatLng(preset['lat'] as double, preset['lng'] as double);
    setState(() {
      _selectedPoint = point;
      _locationName = preset['name'] as String;
      _searchResults.clear();
      _searchController.text = preset['short'] as String;
    });
    _mapController.move(point, 16.0);
  }

  Future<void> _useCurrentGps() async {
    setState(() => _isGettingGps = true);
    final geo = GeofenceService();
    final hasPermission = await geo.checkAndRequestPermission();
    if (!hasPermission) {
      if (mounted) {
        setState(() => _isGettingGps = false);
        NeoSnackbar.showError(
          context,
          title: 'IZIN LOKASI DITOLAK',
          message: 'Aktifkan GPS dan izinkan akses lokasi untuk mendeteksi posisi Anda.',
        );
      }
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _selectedPoint = point;
        _isGettingGps = false;
        _locationName = 'Posisi GPS Saya Saat Ini';
        _searchResults.clear();
      });
      _mapController.move(point, 17.0);
      _reverseGeocode(point);
      NeoSnackbar.showSuccess(
        context,
        title: 'POSISI DITEMUKAN',
        message: 'Pin lokasi ujian berhasil diarahkan ke koordinat GPS Anda.',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isGettingGps = false);
        NeoSnackbar.showError(
          context,
          title: 'GAGAL MEMBACA GPS',
          message: 'Gagal mengambil posisi perangkat. Periksa koneksi GPS Anda.',
        );
      }
    }
  }

  void _onConfirm() {
    final result = ExamLocationPickerResult(
      latitude: _selectedPoint.latitude,
      longitude: _selectedPoint.longitude,
      radiusMeters: _selectedRadius.round(),
      locationName: _locationName,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final radiusPresets = [50, 100, 150, 200, 300, 500, 1000];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        decoration: BoxDecoration(
          color: NeoColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NeoColors.ink, width: 3),
          boxShadow: const [
            BoxShadow(
              color: NeoColors.ink,
              offset: Offset(6, 6),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Dialog
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: NeoColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                border: Border(bottom: BorderSide(color: NeoColors.ink, width: 3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.map_outlined, color: NeoColors.ink, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'PILIH LOKASI & GEOFENCE',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: NeoColors.ink,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: NeoColors.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: NeoColors.ink, width: 2),
                      ),
                      child: const Icon(Icons.close, size: 16, color: NeoColors.ink),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar & Campus Quick Chips
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              decoration: const BoxDecoration(
                color: NeoColors.bg,
                border: Border(bottom: BorderSide(color: NeoColors.ink, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search Input
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: NeoColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: NeoColors.ink, width: 2),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        const Icon(Icons.search, size: 20, color: NeoColors.ink),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(
                              fontFamily: 'Hanken Grotesk',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: NeoColors.ink,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Cari kampus atau lokasi (mis: ITB, UI, UGM)...',
                              hintStyle: TextStyle(
                                fontFamily: 'Hanken Grotesk',
                                fontSize: 12,
                                color: Colors.black45,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged: (val) {
                              _debounceTimer?.cancel();
                              _debounceTimer = Timer(const Duration(milliseconds: 600), () {
                                _searchLocation(val);
                              });
                            },
                            onSubmitted: (val) => _searchLocation(val),
                          ),
                        ),
                        if (_isSearching)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: NeoColors.ink),
                            ),
                          )
                        else if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchResults = []);
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(Icons.clear, size: 18, color: NeoColors.ink),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Campus Quick Preset Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: NeoColors.tertiary,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: NeoColors.ink, width: 1.5),
                          ),
                          child: const Text(
                            'KAMPUS:',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.w800,
                              fontSize: 9,
                              color: NeoColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ...ExamLocationPickerDialog.campusPresets.map((c) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => _selectPreset(c),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: NeoColors.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: NeoColors.ink, width: 1.5),
                                ),
                                child: Text(
                                  c['short'] as String,
                                  style: const TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    color: NeoColors.ink,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Map Area (Stack with Search Results Dropdown Overlay & Floating Controls)
            Expanded(
              child: Stack(
                children: [
                  // Interactive Map
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedPoint,
                      initialZoom: 16.0,
                      onTap: (_, point) => _onMapTap(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.thereisnocheating',
                      ),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _selectedPoint,
                            radius: _selectedRadius,
                            useRadiusInMeter: true,
                            color: NeoColors.primary.withValues(alpha: 0.28),
                            borderColor: NeoColors.ink,
                            borderStrokeWidth: 3.0,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedPoint,
                            width: 52,
                            height: 52,
                            alignment: Alignment.topCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: NeoColors.surface,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: NeoColors.ink, width: 2),
                                    boxShadow: const [
                                      BoxShadow(color: NeoColors.ink, offset: Offset(2, 2), blurRadius: 0),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: NeoColors.danger,
                                    size: 26,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Map Tap Instruction Banner (Top Floating)
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: IgnorePointer(
                      ignoring: _searchResults.isNotEmpty,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: NeoColors.surface.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: NeoColors.ink, width: 1.5),
                          boxShadow: const [
                            BoxShadow(color: NeoColors.ink, offset: Offset(2, 2), blurRadius: 0),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.touch_app, size: 16, color: NeoColors.ink),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Ketuk di mana saja pada peta untuk menjatuhkan titik lokasi ujian.',
                                style: TextStyle(
                                  fontFamily: 'Hanken Grotesk',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: NeoColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Floating Map Action Buttons (Right Side)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // GPS Saya Button
                        GestureDetector(
                          onTap: _isGettingGps ? null : _useCurrentGps,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: NeoColors.secondary,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: NeoColors.ink, width: 2),
                              boxShadow: const [
                                BoxShadow(color: NeoColors.ink, offset: Offset(3, 3), blurRadius: 0),
                              ],
                            ),
                            child: _isGettingGps
                                ? const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: NeoColors.ink),
                                    ),
                                  )
                                : const Icon(Icons.my_location, color: NeoColors.ink, size: 22),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Zoom In Button
                        GestureDetector(
                          onTap: () {
                            final zoom = _mapController.camera.zoom;
                            _mapController.move(_selectedPoint, zoom + 1);
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: NeoColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: NeoColors.ink, width: 2),
                              boxShadow: const [
                                BoxShadow(color: NeoColors.ink, offset: Offset(2, 2), blurRadius: 0),
                              ],
                            ),
                            child: const Icon(Icons.add, color: NeoColors.ink, size: 20),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Zoom Out Button
                        GestureDetector(
                          onTap: () {
                            final zoom = _mapController.camera.zoom;
                            _mapController.move(_selectedPoint, zoom - 1);
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: NeoColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: NeoColors.ink, width: 2),
                              boxShadow: const [
                                BoxShadow(color: NeoColors.ink, offset: Offset(2, 2), blurRadius: 0),
                              ],
                            ),
                            child: const Icon(Icons.remove, color: NeoColors.ink, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search Results Dropdown Overlay
                  if (_searchResults.isNotEmpty)
                    Positioned(
                      top: 4,
                      left: 12,
                      right: 12,
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: NeoColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: NeoColors.ink, width: 2.5),
                          boxShadow: const [
                            BoxShadow(color: NeoColors.ink, offset: Offset(4, 4), blurRadius: 0),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _searchResults.length,
                          separatorBuilder: (context, index) => const Divider(color: NeoColors.ink, height: 1),
                          itemBuilder: (context, index) {
                            final item = _searchResults[index];
                            final title = item['display_name']?.toString() ?? '';
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.location_city, color: NeoColors.ink, size: 20),
                              title: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Hanken Grotesk',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: NeoColors.ink,
                                ),
                              ),
                              onTap: () => _selectSearchResult(item),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Geofence Radius & Location Details
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: NeoColors.bg,
                border: Border(top: BorderSide(color: NeoColors.ink, width: 3)),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Location Address & Coordinates Summary
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: NeoColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: NeoColors.ink, width: 2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pin_drop, color: NeoColors.danger, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _locationName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: NeoColors.ink,
                                ),
                              ),
                              Text(
                                '${_selectedPoint.latitude.toStringAsFixed(6)}, ${_selectedPoint.longitude.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontFamily: 'Space Mono',
                                  fontSize: 10,
                                  color: NeoColors.ink.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: NeoColors.primary,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: NeoColors.ink, width: 1.5),
                          ),
                          child: Text(
                            '${_selectedRadius.round()} M',
                            style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: NeoColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Radius Selector (Chips + Slider)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'RADIUS GEOFENCE:',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: NeoColors.ink,
                        ),
                      ),
                      Text(
                        'Lingkaran toleransi kehadiran mahasiswa',
                        style: TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: 10,
                          color: NeoColors.ink.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Quick Radius Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: radiusPresets.map((r) {
                        final isSelected = _selectedRadius.round() == r;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedRadius = r.toDouble());
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSelected ? NeoColors.secondary : NeoColors.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: NeoColors.ink, width: 1.5),
                                boxShadow: isSelected
                                    ? const [BoxShadow(color: NeoColors.ink, offset: Offset(2, 2), blurRadius: 0)]
                                    : null,
                              ),
                              child: Text(
                                '$r m',
                                style: const TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  color: NeoColors.ink,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Action Button
                  NeoButton(
                    text: 'GUNAKAN LOKASI & RADIUS INI',
                    backgroundColor: NeoColors.primary,
                    icon: const Icon(Icons.check_circle_outline, size: 18, color: NeoColors.ink),
                    onPressed: _onConfirm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
