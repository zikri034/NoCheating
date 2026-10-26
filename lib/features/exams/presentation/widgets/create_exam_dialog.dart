import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/services/geofence_service.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/widgets/neo_snackbar.dart';
import '../../../../core/widgets/neo_text_field.dart';
import '../../data/models/course_model.dart';
import 'exam_location_picker_dialog.dart';

class CreateExamDialog extends StatefulWidget {
  final List<CourseModel> courses;
  final Future<bool> Function(Map<String, dynamic> data) onSubmit;
  final List<String>? initialSelectedQuestionIds;

  const CreateExamDialog({
    super.key,
    required this.courses,
    required this.onSubmit,
    this.initialSelectedQuestionIds,
  });

  @override
  State<CreateExamDialog> createState() => _CreateExamDialogState();
}

class _CreateExamDialogState extends State<CreateExamDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  final _feeController = TextEditingController();
  final _latController = TextEditingController(text: '-6.175392');
  final _lngController = TextEditingController(text: '106.827153');
  final _radiusController = TextEditingController(text: '150');

  String _locationName = 'Monas (Jakarta Pusat)';
  bool _showManualCoords = false;

  late List<String> _selectedQuestionIds;

  String? _selectedCourseId;
  DateTime _startAt = DateTime.now().add(const Duration(hours: 1));
  DateTime _endAt = DateTime.now().add(const Duration(hours: 3));
  bool _requireBiometric = false;
  bool _requireGeofence = false;
  bool _isPublished = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _openLocationPicker() async {
    final currentLat = double.tryParse(_latController.text) ?? -6.175392;
    final currentLng = double.tryParse(_lngController.text) ?? 106.827153;
    final currentRadius = int.tryParse(_radiusController.text) ?? 150;

    final result = await showDialog<ExamLocationPickerResult>(
      context: context,
      builder: (ctx) => ExamLocationPickerDialog(
        initialLat: currentLat,
        initialLng: currentLng,
        initialRadius: currentRadius,
        initialLocationName: _locationName,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latController.text = result.latitude.toStringAsFixed(6);
        _lngController.text = result.longitude.toStringAsFixed(6);
        _radiusController.text = result.radiusMeters.toString();
        _locationName = result.locationName;
      });
    }
  }

  Future<void> _useCurrentGps() async {
    final geo = GeofenceService();
    final hasPerm = await geo.checkAndRequestPermission();
    if (!hasPerm) {
      if (mounted) {
        NeoSnackbar.showError(
          context,
          title: 'IZIN LOKASI DITOLAK',
          message: 'Aktifkan GPS dan izinkan akses lokasi untuk membaca posisi saat ini.',
        );
      }
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _latController.text = pos.latitude.toStringAsFixed(6);
        _lngController.text = pos.longitude.toStringAsFixed(6);
        _locationName = 'Posisi GPS Saya Saat Ini';
      });
      NeoSnackbar.showSuccess(
        context,
        title: 'POSISI TERCATAT',
        message: 'Koordinat diperbarui ke lokasi GPS Anda saat ini.',
      );
    } catch (_) {
      if (mounted) {
        NeoSnackbar.showError(
          context,
          title: 'GAGAL MEMBACA GPS',
          message: 'Gagal mengambil koordinat posisi perangkat.',
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedQuestionIds = List.from(widget.initialSelectedQuestionIds ?? []);
    if (widget.courses.isNotEmpty) {
      _selectedCourseId = widget.courses.first.id;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _durationController.dispose();
    _feeController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initialDate = isStart ? _startAt : _endAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null || !mounted) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        _startAt = selected;
        if (_endAt.isBefore(_startAt)) {
          _endAt = _startAt.add(const Duration(hours: 2));
        }
      } else {
        _endAt = selected;
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih mata kuliah terlebih dahulu')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final duration = int.tryParse(_durationController.text) ?? 60;
    final fee = _feeController.text.isNotEmpty ? int.tryParse(_feeController.text) : null;

    final payload = {
      'course_id': _selectedCourseId,
      'title': _titleController.text.trim(),
      'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      'start_at': _startAt.toUtc().toIso8601String(),
      'end_at': _endAt.toUtc().toIso8601String(),
      'duration_min': duration,
      'fee_idr': fee,
      'require_biometric': _requireBiometric,
      'require_geofence': _requireGeofence,
      'venue_lat': _requireGeofence ? double.tryParse(_latController.text) ?? -6.175392 : null,
      'venue_lng': _requireGeofence ? double.tryParse(_lngController.text) ?? 106.827153 : null,
      'venue_radius_m': _requireGeofence ? int.tryParse(_radiusController.text) ?? 150 : null,
      'status': _isPublished ? 'published' : 'draft',
      if (_selectedQuestionIds.isNotEmpty) 'question_ids': _selectedQuestionIds,
    };

    final success = await widget.onSubmit(payload);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _errorMessage = 'Gagal menyimpan ujian. Pastikan format tanggal dan mata kuliah valid.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
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
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: NeoColors.secondary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                border: Border(bottom: BorderSide(color: NeoColors.ink, width: 3)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'BUAT UJIAN BARU',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
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
                        shape: BoxShape.circle,
                        border: Border.all(color: NeoColors.ink, width: 2),
                      ),
                      child: const Icon(Icons.close, size: 16, color: NeoColors.ink),
                    ),
                  ),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: NeoColors.danger.withValues(alpha: 0.15),
                            border: Border.all(color: NeoColors.danger, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: NeoColors.danger, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: NeoColors.danger,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (_selectedQuestionIds.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: NeoColors.tertiary,
                            border: Border.all(color: NeoColors.ink, width: 2.5),
                            borderRadius: BorderRadius.circular(8),
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
                              const Icon(Icons.check_circle, color: NeoColors.ink, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${_selectedQuestionIds.length} butir soal dari Bank Soal akan otomatis dimasukkan ke dalam ujian ini.',
                                  style: const TextStyle(
                                    fontFamily: 'Hanken Grotesk',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: NeoColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Course Dropdown
                      const Text(
                        'MATA KULIAH',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: NeoColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: NeoColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: NeoColors.ink, width: 2),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedCourseId,
                            items: widget.courses.map((c) {
                              return DropdownMenuItem<String>(
                                value: c.id,
                                child: Text(
                                  '${c.code} - ${c.name}',
                                  style: const TextStyle(
                                    fontFamily: 'Hanken Grotesk',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: NeoColors.ink,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedCourseId = val),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Title
                      const Text(
                        'JUDUL UJIAN',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: NeoColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      NeoTextField(
                        controller: _titleController,
                        hintText: 'Contoh: Ujian Tengah Semester Ganjil',
                      ),
                      const SizedBox(height: 14),

                      // Description
                      const Text(
                        'DESKRIPSI (OPSIONAL)',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: NeoColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      NeoTextField(
                        controller: _descController,
                        hintText: 'Petunjuk pengerjaan dan materi',
                      ),
                      const SizedBox(height: 14),

                      // Duration & Fee Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DURASI (MENIT)',
                                  style: TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: NeoColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                NeoTextField(
                                  controller: _durationController,
                                  hintText: '60',
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'BIAYA IDR (OPSIONAL)',
                                  style: TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: NeoColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                NeoTextField(
                                  controller: _feeController,
                                  hintText: '0',
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Date Time Selection
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: NeoColors.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: NeoColors.ink, width: 2),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Flexible(
                                  child: Text(
                                    'Waktu Mulai:',
                                    style: TextStyle(
                                      fontFamily: 'Hanken Grotesk',
                                      fontWeight: FontWeight.w700,
                                      color: NeoColors.ink,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _pickDateTime(isStart: true),
                                  icon: const Icon(Icons.edit_calendar, size: 16, color: NeoColors.ink),
                                  label: Text(
                                    DateFormat('dd/MM HH:mm').format(_startAt),
                                    style: const TextStyle(
                                      fontFamily: 'Space Mono',
                                      fontWeight: FontWeight.w700,
                                      color: NeoColors.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: NeoColors.ink, thickness: 1),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Flexible(
                                  child: Text(
                                    'Waktu Selesai:',
                                    style: TextStyle(
                                      fontFamily: 'Hanken Grotesk',
                                      fontWeight: FontWeight.w700,
                                      color: NeoColors.ink,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _pickDateTime(isStart: false),
                                  icon: const Icon(Icons.edit_calendar, size: 16, color: NeoColors.ink),
                                  label: Text(
                                    DateFormat('dd/MM HH:mm').format(_endAt),
                                    style: const TextStyle(
                                      fontFamily: 'Space Mono',
                                      fontWeight: FontWeight.w700,
                                      color: NeoColors.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Switches
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Wajibkan Autentikasi Biometrik',
                          style: TextStyle(
                            fontFamily: 'Hanken Grotesk',
                            fontWeight: FontWeight.w700,
                            color: NeoColors.ink,
                          ),
                        ),
                        value: _requireBiometric,
                        activeTrackColor: NeoColors.primary,
                        onChanged: (val) => setState(() => _requireBiometric = val),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Wajibkan Lokasi / Geofence',
                          style: TextStyle(
                            fontFamily: 'Hanken Grotesk',
                            fontWeight: FontWeight.w700,
                            color: NeoColors.ink,
                          ),
                        ),
                        value: _requireGeofence,
                        activeTrackColor: NeoColors.primary,
                        onChanged: (val) => setState(() => _requireGeofence = val),
                      ),
                      if (_requireGeofence) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title & Radius chip
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: NeoColors.primary,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: NeoColors.ink, width: 2),
                                    ),
                                    child: const Icon(Icons.location_on, size: 20, color: Colors.white),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _locationName.isEmpty ? 'Lokasi Ujian' : _locationName,
                                          style: const TextStyle(
                                            fontFamily: 'Space Grotesk',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: NeoColors.ink,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Lat: ${_latController.text} | Lng: ${_lngController.text}',
                                          style: TextStyle(
                                            fontFamily: 'Hanken Grotesk',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: NeoColors.ink.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: NeoColors.secondary,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: NeoColors.ink, width: 1.5),
                                    ),
                                    child: Text(
                                      '${_radiusController.text} M',
                                      style: const TextStyle(
                                        fontFamily: 'Space Grotesk',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: NeoColors.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Interactive Mini-Map Preview
                              Builder(
                                builder: (context) {
                                  final lat = double.tryParse(_latController.text) ?? -6.175392;
                                  final lng = double.tryParse(_lngController.text) ?? 106.827153;
                                  final radius = double.tryParse(_radiusController.text) ?? 150.0;
                                  final center = LatLng(lat, lng);

                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      children: [
                                        Container(
                                          height: 140,
                                          decoration: BoxDecoration(
                                            border: Border.all(color: NeoColors.ink, width: 2),
                                          ),
                                          child: FlutterMap(
                                            options: MapOptions(
                                              initialCenter: center,
                                              initialZoom: 15.5,
                                              interactionOptions: const InteractionOptions(
                                                flags: InteractiveFlag.none,
                                              ),
                                              onTap: (tapPosition, point) => _openLocationPicker(),
                                            ),
                                            children: [
                                              TileLayer(
                                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                userAgentPackageName: 'com.example.thereisnocheating',
                                              ),
                                              CircleLayer(
                                                circles: [
                                                  CircleMarker(
                                                    point: center,
                                                    radius: radius,
                                                    useRadiusInMeter: true,
                                                    color: NeoColors.primary.withValues(alpha: 0.25),
                                                    borderColor: NeoColors.primary,
                                                    borderStrokeWidth: 2,
                                                  ),
                                                ],
                                              ),
                                              MarkerLayer(
                                                markers: [
                                                  Marker(
                                                    point: center,
                                                    width: 32,
                                                    height: 32,
                                                    child: const Icon(
                                                      Icons.location_on,
                                                      color: NeoColors.danger,
                                                      size: 32,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: _openLocationPicker,
                                              child: Container(
                                                alignment: Alignment.bottomRight,
                                                padding: const EdgeInsets.all(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: NeoColors.ink.withValues(alpha: 0.8),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.touch_app, size: 12, color: Colors.white),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'Sentuh untuk ubah peta',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),

                              // Map Actions Buttons
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: NeoButton(
                                      text: 'PILIH TITIK DI PETA',
                                      icon: const Icon(Icons.map, size: 16),
                                      backgroundColor: NeoColors.primary,
                                      fontSize: 12,
                                      onPressed: _openLocationPicker,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: NeoButton(
                                      text: 'GPS SAYA',
                                      icon: const Icon(Icons.my_location, size: 16),
                                      backgroundColor: NeoColors.secondary,
                                      fontSize: 12,
                                      onPressed: _useCurrentGps,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Accordion toggle for manual coordinates
                              InkWell(
                                onTap: () => setState(() => _showManualCoords = !_showManualCoords),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _showManualCoords ? 'Sembunyikan Koordinat Manual' : 'Ubah Koordinat & Radius Manual',
                                        style: const TextStyle(
                                          fontFamily: 'Hanken Grotesk',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: NeoColors.ink,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                      Icon(
                                        _showManualCoords ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                        size: 16,
                                        color: NeoColors.ink,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_showManualCoords) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: NeoTextField(
                                        label: 'Latitude',
                                        controller: _latController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: NeoTextField(
                                        label: 'Longitude',
                                        controller: _lngController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                NeoTextField(
                                  label: 'Radius Geofence (Meter)',
                                  controller: _radiusController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Langsung Publikasikan (Published)',
                          style: TextStyle(
                            fontFamily: 'Hanken Grotesk',
                            fontWeight: FontWeight.w700,
                            color: NeoColors.ink,
                          ),
                        ),
                        value: _isPublished,
                        activeTrackColor: NeoColors.success,
                        onChanged: (val) => setState(() => _isPublished = val),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Submit
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: NeoColors.bg,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
                border: Border(top: BorderSide(color: NeoColors.ink, width: 3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: NeoButton(
                      text: _isSubmitting ? 'MENYIMPAN...' : 'SIMPAN UJIAN',
                      variant: NeoButtonVariant.primary,
                      onPressed: _isSubmitting ? null : _handleSubmit,
                    ),
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
