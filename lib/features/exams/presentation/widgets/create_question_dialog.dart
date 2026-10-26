import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/widgets/neo_snackbar.dart';
import '../../../../core/widgets/neo_text_field.dart';
import '../../data/models/course_model.dart';
import '../providers/exam_provider.dart';

class CreateQuestionDialog extends StatefulWidget {
  final List<CourseModel> courses;
  final String? initialCourseId;
  final Future<bool> Function(Map<String, dynamic> data) onSubmit;

  const CreateQuestionDialog({
    super.key,
    required this.courses,
    this.initialCourseId,
    required this.onSubmit,
  });

  @override
  State<CreateQuestionDialog> createState() => _CreateQuestionDialogState();
}

class _CreateQuestionDialogState extends State<CreateQuestionDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCourseId;
  String _selectedType = 'mcq';

  // New course controllers
  bool _isCreatingNewCourse = false;
  final _newCourseCodeController = TextEditingController();
  final _newCourseNameController = TextEditingController();

  final _bodyController = TextEditingController();
  final _scoreController = TextEditingController(text: '10');

  // MCQ controllers
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  int _correctOptionIndex = 0;

  // Essay controllers
  final _rubricController = TextEditingController();
  final _modelAnswerController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.courses.isEmpty) {
      _isCreatingNewCourse = true;
    } else if (widget.initialCourseId != null &&
        widget.courses.any((c) => c.id == widget.initialCourseId)) {
      _selectedCourseId = widget.initialCourseId;
    } else if (widget.courses.isNotEmpty) {
      _selectedCourseId = widget.courses.first.id;
    }
  }

  @override
  void dispose() {
    _newCourseCodeController.dispose();
    _newCourseNameController.dispose();
    _bodyController.dispose();
    _scoreController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    _rubricController.dispose();
    _modelAnswerController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isCreatingNewCourse) {
      final code = _newCourseCodeController.text.trim();
      final name = _newCourseNameController.text.trim();
      if (code.isEmpty || name.isEmpty) {
        NeoSnackbar.showError(
          context,
          title: 'DATA MATERI KURANG',
          message: 'Silakan isi Kode Materi dan Nama Materi baru.',
        );
        return;
      }

      setState(() => _isSubmitting = true);
      final examProv = context.read<ExamProvider>();
      final newCourse = await examProv.createCourse(code, name);
      if (!mounted) return;
      if (newCourse == null) {
        setState(() => _isSubmitting = false);
        NeoSnackbar.showError(
          context,
          title: 'GAGAL MEMBUAT MATERI',
          message: examProv.errorMessage ?? 'Gagal membuat materi baru.',
        );
        return;
      }
      _selectedCourseId = newCourse.id;
    } else {
      if (_selectedCourseId == null) {
        NeoSnackbar.showError(
          context,
          title: 'MATA KULIAH KOSONG',
          message: 'Pilih mata kuliah terlebih dahulu sebelum menyimpan.',
        );
        return;
      }
    }

    final score = double.tryParse(_scoreController.text) ?? 10.0;

    final Map<String, dynamic> payload = {
      'course_id': _selectedCourseId,
      'type': _selectedType,
      'body': _bodyController.text.trim(),
      'max_score': score,
    };

    if (_selectedType == 'mcq') {
      final options = _optionControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      if (options.length < 2) {
        NeoSnackbar.showError(
          context,
          title: 'OPSI TIDAK CUKUP',
          message: 'Isi minimal 2 opsi jawaban untuk soal pilihan ganda.',
        );
        return;
      }

      final letters = ['A', 'B', 'C', 'D'];
      payload['options'] = options.asMap().entries.map((e) {
        final prefix = e.key < letters.length ? '${letters[e.key]}. ' : '';
        return e.value.startsWith(RegExp(r'^[A-D]\.')) ? e.value : '$prefix${e.value}';
      }).toList();

      final correctIndex = _correctOptionIndex.clamp(0, options.length - 1);
      final correctLetter = correctIndex < letters.length ? letters[correctIndex] : 'A';
      payload['correct_option'] = correctLetter;
    } else {
      if (_rubricController.text.trim().isNotEmpty) {
        payload['rubric'] = _rubricController.text.trim();
      }
      if (_modelAnswerController.text.trim().isNotEmpty) {
        payload['model_answer'] = _modelAnswerController.text.trim();
      }
    }

    setState(() => _isSubmitting = true);
    final success = await widget.onSubmit(payload);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
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
                color: NeoColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                border: Border(bottom: BorderSide(color: NeoColors.ink, width: 3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline, color: NeoColors.ink, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'BUAT SOAL MANUAL',
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

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Materi Selector & Mode Switcher
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'MATERI / MATA KULIAH',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: NeoColors.ink,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isCreatingNewCourse = !_isCreatingNewCourse;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isCreatingNewCourse ? NeoColors.surface : NeoColors.primary,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: NeoColors.ink, width: 1.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isCreatingNewCourse ? Icons.list_alt : Icons.add_circle_outline,
                                    size: 13,
                                    color: NeoColors.ink,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isCreatingNewCourse ? 'PILIH YANG ADA' : '+ BUAT MATERI BARU',
                                    style: const TextStyle(
                                      fontFamily: 'Space Grotesk',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                      color: NeoColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (!_isCreatingNewCourse) ...[
                        Builder(
                          builder: (context) {
                            final provCourses = context.watch<ExamProvider>().courses;
                            final coursesList = provCourses.isNotEmpty ? provCourses : widget.courses;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: NeoColors.bg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: NeoColors.ink, width: 2),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: coursesList.any((c) => c.id == _selectedCourseId)
                                      ? _selectedCourseId
                                      : (coursesList.isNotEmpty ? coursesList.first.id : null),
                                  isExpanded: true,
                                  dropdownColor: NeoColors.surface,
                                  hint: const Text('Pilih Mata Kuliah'),
                                  items: coursesList.map((c) {
                                    return DropdownMenuItem<String>(
                                      value: c.id,
                                      child: Text(
                                        '${c.code} — ${c.name}',
                                        style: const TextStyle(
                                          fontFamily: 'Space Grotesk',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: NeoColors.ink,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedCourseId = val),
                                ),
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: NeoColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: NeoColors.ink, width: 2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.auto_stories, size: 16, color: NeoColors.ink),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'TAMBAH MATERI BARU',
                                    style: TextStyle(
                                      fontFamily: 'Space Grotesk',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: NeoColors.ink,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Otomatis dibuat & disimpan',
                                    style: TextStyle(
                                      fontFamily: 'Hanken Grotesk',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                      color: NeoColors.ink.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              NeoTextField(
                                label: 'KODE MATERI (CONTOH: IF4501)',
                                controller: _newCourseCodeController,
                                hintText: 'Masukkan kode materi...',
                              ),
                              const SizedBox(height: 8),
                              NeoTextField(
                                label: 'NAMA MATERI / TOPIK SOAL',
                                controller: _newCourseNameController,
                                hintText: 'Contoh: Pemrograman Mobile / Jaringan Komputer',
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Tipe Soal Segment
                      const Text(
                        'TIPE SOAL',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: NeoColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedType = 'mcq'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedType == 'mcq' ? NeoColors.info : NeoColors.bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: NeoColors.ink, width: 2),
                                  boxShadow: _selectedType == 'mcq'
                                      ? const [BoxShadow(color: NeoColors.ink, offset: Offset(2, 2))]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'PILIHAN GANDA',
                                  style: TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: NeoColors.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedType = 'essay'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedType == 'essay' ? NeoColors.secondary : NeoColors.bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: NeoColors.ink, width: 2),
                                  boxShadow: _selectedType == 'essay'
                                      ? const [BoxShadow(color: NeoColors.ink, offset: Offset(2, 2))]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'ESSAY / URAIAN',
                                  style: TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: NeoColors.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Pertanyaan Body
                      const Text(
                        'PERTANYAAN / NASKAH SOAL',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: NeoColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      NeoTextField(
                        controller: _bodyController,
                        hintText: 'Tuliskan butir soal di sini...',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 14),

                      // Bobot Poin
                      const Text(
                        'BOBOT POIN MAKSIMUM',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: NeoColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      NeoTextField(
                        controller: _scoreController,
                        hintText: '10',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 14),

                      // MCQ Options
                      if (_selectedType == 'mcq') ...[
                        const Text(
                          'PILIHAN JAWABAN (PILIH SATU UNTUK KUNCI)',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: NeoColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...['A', 'B', 'C', 'D'].asMap().entries.map((entry) {
                          final idx = entry.key;
                          final letter = entry.value;
                          final isCorrect = _correctOptionIndex == idx;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() => _correctOptionIndex = idx),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isCorrect ? NeoColors.success : NeoColors.bg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: NeoColors.ink, width: 2),
                                    ),
                                    child: Text(
                                      letter,
                                      style: const TextStyle(
                                        fontFamily: 'Space Mono',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: NeoColors.ink,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: NeoTextField(
                                    controller: _optionControllers[idx],
                                    hintText: 'Isi pilihan $letter...',
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ] else ...[
                        // Essay Rubric & Model Answer
                        const Text(
                          'PANDUAN RUBRIK PENILAIAN (OPSIONAL)',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: NeoColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        NeoTextField(
                          controller: _rubricController,
                          hintText: 'Contoh: 1. Penjelasan konsep (5 poin), 2. Contoh kasus (5 poin)',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'KUNCI / MODEL JAWABAN (OPSIONAL)',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: NeoColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        NeoTextField(
                          controller: _modelAnswerController,
                          hintText: 'Tuliskan referensi jawaban yang diharapkan...',
                          maxLines: 2,
                        ),
                      ],

                      const SizedBox(height: 18),
                      NeoButton(
                        text: _isSubmitting ? 'MENYIMPAN...' : 'SIMPAN KE BANK SOAL',
                        backgroundColor: NeoColors.success,
                        onPressed: _isSubmitting ? null : _handleSubmit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
