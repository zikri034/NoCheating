import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/widgets/neo_text_field.dart';
import '../../data/models/course_model.dart';

class CreateExamDialog extends StatefulWidget {
  final List<CourseModel> courses;
  final Future<bool> Function(Map<String, dynamic> data) onSubmit;

  const CreateExamDialog({
    super.key,
    required this.courses,
    required this.onSubmit,
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

  String? _selectedCourseId;
  DateTime _startAt = DateTime.now().add(const Duration(hours: 1));
  DateTime _endAt = DateTime.now().add(const Duration(hours: 3));
  bool _requireBiometric = false;
  bool _requireGeofence = false;
  bool _isPublished = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
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
                                const Text(
                                  'Waktu Mulai:',
                                  style: TextStyle(
                                    fontFamily: 'Hanken Grotesk',
                                    fontWeight: FontWeight.w700,
                                    color: NeoColors.ink,
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
                                const Text(
                                  'Waktu Selesai:',
                                  style: TextStyle(
                                    fontFamily: 'Hanken Grotesk',
                                    fontWeight: FontWeight.w700,
                                    color: NeoColors.ink,
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
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: NeoTextField(
                                label: 'Latitude',
                                controller: _latController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: NeoTextField(
                                label: 'Longitude',
                                controller: _lngController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        NeoTextField(
                          label: 'Radius Geofence (Meter)',
                          controller: _radiusController,
                          keyboardType: TextInputType.number,
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
