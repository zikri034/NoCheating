import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/widgets/neo_snackbar.dart';
import '../../../../core/widgets/neo_tag.dart';
import '../../../../core/widgets/neo_text_field.dart';
import '../providers/exam_provider.dart';

class ExtractQuestionsDialog extends StatefulWidget {
  final String? initialCourseId;

  const ExtractQuestionsDialog({
    super.key,
    this.initialCourseId,
  });

  @override
  State<ExtractQuestionsDialog> createState() => _ExtractQuestionsDialogState();
}

class _ExtractQuestionsDialogState extends State<ExtractQuestionsDialog> {
  String? _selectedCourseId;
  PlatformFile? _pickedFile;

  // New course controllers
  bool _isCreatingNewCourse = false;
  final _newCourseCodeController = TextEditingController();
  final _newCourseNameController = TextEditingController();

  bool _isExtracting = false;
  bool _isSaving = false;
  String? _errorMessage;

  String? _detectedTopic;
  List<Map<String, dynamic>> _extractedQuestions = [];
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    final examProv = context.read<ExamProvider>();
    if (examProv.courses.isEmpty) {
      _isCreatingNewCourse = true;
    } else if (widget.initialCourseId != null) {
      _selectedCourseId = widget.initialCourseId;
    } else if (examProv.courses.isNotEmpty) {
      _selectedCourseId = examProv.courses.first.id;
    }
  }

  @override
  void dispose() {
    _newCourseCodeController.dispose();
    _newCourseNameController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'txt'],
      );

      if (files.isNotEmpty) {
        setState(() {
          _pickedFile = files.first;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memilih berkas: ${e.toString()}';
      });
    }
  }

  Future<void> _handleExtract() async {
    if (_pickedFile == null || _pickedFile!.path == null) {
      setState(() {
        _errorMessage = 'Silakan pilih berkas dokumen terlebih dahulu';
      });
      NeoSnackbar.showError(
        context,
        title: 'BERKAS BELUM DIPILIH',
        message: 'Pilih file PDF, Word (.docx), atau TXT naskah soal.',
      );
      return;
    }

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
    });

    try {
      final examProv = context.read<ExamProvider>();
      final res = await examProv.extractQuestionsFromDocument(
        _pickedFile!.path!,
        _pickedFile!.name,
      );

      final extractedData = res['extracted'] as Map<String, dynamic>? ?? {};
      final questionsList = (extractedData['questions'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      setState(() {
        _detectedTopic = extractedData['course_topic_detected'] as String?;
        _extractedQuestions = questionsList;
        _selectedIndices.clear();
        for (int i = 0; i < questionsList.length; i++) {
          _selectedIndices.add(i);
        }

        // Prefill new course fields with detected topic if available
        if (_detectedTopic != null && _detectedTopic!.trim().isNotEmpty) {
          if (_newCourseNameController.text.trim().isEmpty) {
            _newCourseNameController.text = _detectedTopic!.trim();
          }
          if (_newCourseCodeController.text.trim().isEmpty) {
            final words = _detectedTopic!.trim().split(RegExp(r'\s+'));
            if (words.length >= 2) {
              final codeCandidate = words.map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').take(4).join();
              _newCourseCodeController.text = codeCandidate.length >= 2 ? codeCandidate : 'TOPIC';
            } else {
              _newCourseCodeController.text = _detectedTopic!.length >= 4
                  ? _detectedTopic!.substring(0, 4).toUpperCase()
                  : 'MATERI';
            }
          }
        }
      });

      if (mounted) {
        NeoSnackbar.showSuccess(
          context,
          title: 'EKSTRAKSI BERHASIL',
          message: 'Gemini AI berhasil mengekstrak ${questionsList.length} butir soal dari dokumen.',
        );
      }
    } catch (e) {
      final err = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _errorMessage = err;
      });
      if (mounted) {
        NeoSnackbar.showError(
          context,
          title: 'EKSTRAKSI GAGAL',
          message: err,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExtracting = false;
        });
      }
    }
  }

  void _toggleQuestion(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIndices.length == _extractedQuestions.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.clear();
        for (int i = 0; i < _extractedQuestions.length; i++) {
          _selectedIndices.add(i);
        }
      }
    });
  }

  Future<void> _handleSave() async {
    final examProv = context.read<ExamProvider>();
    final messenger = ScaffoldMessenger.of(context);
    String targetCourseId;

    if (_selectedIndices.isEmpty) {
      setState(() {
        _errorMessage = 'Pilih minimal satu butir soal untuk disimpan';
      });
      NeoSnackbar.showError(
        context,
        title: 'BELUM ADA SOAL DIPILIH',
        message: 'Pilih minimal satu butir soal untuk disimpan ke bank.',
      );
      return;
    }

    if (_isCreatingNewCourse) {
      final code = _newCourseCodeController.text.trim();
      final name = _newCourseNameController.text.trim();
      if (code.isEmpty || name.isEmpty) {
        setState(() {
          _errorMessage = 'Silakan isi Kode Materi dan Nama Materi baru';
        });
        NeoSnackbar.showError(
          context,
          title: 'DATA MATERI KURANG',
          message: 'Silakan isi Kode Materi dan Nama Materi baru.',
        );
        return;
      }

      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });

      try {
        final newCourse = await examProv.createCourse(code, name);
        if (!mounted) return;
        if (newCourse == null) {
          setState(() {
            _isSaving = false;
            _errorMessage = examProv.errorMessage ?? 'Gagal membuat materi baru';
          });
          return;
        }
        targetCourseId = newCourse.id;
        _selectedCourseId = newCourse.id;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
        return;
      }
    } else {
      if (_selectedCourseId == null || _selectedCourseId!.isEmpty) {
        setState(() {
          _errorMessage = 'Silakan pilih mata kuliah / materi tujuan';
        });
        NeoSnackbar.showError(
          context,
          title: 'MATA KULIAH KOSONG',
          message: 'Silakan pilih mata kuliah tujuan atau buat materi baru.',
        );
        return;
      }

      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });

      targetCourseId = _selectedCourseId!;
    }

    try {
      final questionsToSave = _selectedIndices.map((i) {
        final q = _extractedQuestions[i];
        final type = (q['type'] as String?)?.toLowerCase() == 'essay' ? 'essay' : 'mcq';
        List<String>? options;
        if (type == 'mcq' && q['options'] is List) {
          options = (q['options'] as List)
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }

        return {
          'type': type,
          'body': (q['body'] as String?)?.trim() ?? '',
          'options': options,
          'correct_option': q['correct_option']?.toString().trim(),
          'rubric': q['rubric']?.toString().trim(),
          'model_answer': q['model_answer']?.toString().trim(),
          'max_score': double.tryParse(q['max_score']?.toString() ?? '') ?? 10.0,
        };
      }).toList();

      final created = await examProv.createQuestionsBatch(
        courseId: targetCourseId,
        questions: questionsToSave,
      );

      if (mounted) {
        Navigator.of(context).pop(created);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
            padding: EdgeInsets.zero,
            content: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: NeoColors.success,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NeoColors.ink, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: NeoColors.ink,
                    offset: Offset(4, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: NeoColors.ink, width: 2),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: NeoColors.ink, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BERHASIL SIMPAN KE BANK SOAL',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: NeoColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${created.length} butir soal telah berhasil disimpan ke bank soal!',
                          style: const TextStyle(
                            fontFamily: 'Hanken Grotesk',
                            fontWeight: FontWeight.w600,
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
          ),
        );
      }
    } catch (e) {
      final err = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        setState(() {
          _errorMessage = err;
        });
        NeoSnackbar.showError(
          context,
          title: 'GAGAL MENYIMPAN SOAL',
          message: err,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final examProv = context.watch<ExamProvider>();
    final courses = examProv.courses;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
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
                  const Icon(Icons.auto_awesome, color: NeoColors.ink, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'EKSTRAKSI SOAL DARI DOKUMEN',
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

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
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
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Materi Selector & Mode Switcher
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'MATERI / MATA KULIAH TUJUAN',
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: NeoColors.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: NeoColors.ink, width: 2),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: courses.any((c) => c.id == _selectedCourseId)
                                ? _selectedCourseId
                                : (courses.isNotEmpty ? courses.first.id : null),
                            isExpanded: true,
                            dropdownColor: NeoColors.surface,
                            hint: const Text('Pilih Mata Kuliah'),
                            items: courses.map((c) {
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
                            onChanged: (val) {
                              setState(() {
                                _selectedCourseId = val;
                              });
                            },
                          ),
                        ),
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
                            if (_detectedTopic != null && _detectedTopic!.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: NeoColors.tertiary.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: NeoColors.ink, width: 1.5),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.auto_awesome, size: 14, color: NeoColors.ink),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Topik AI terdeteksi: "$_detectedTopic"',
                                        style: const TextStyle(
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
                            ],
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
                    const SizedBox(height: 16),

                    // File Selector Section
                    const Text(
                      'PILIH BERKAS NASKAH SOAL (PDF / WORD .DOCX / TXT)',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: NeoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _isExtracting ? null : _pickFile,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          color: _pickedFile != null ? NeoColors.info.withValues(alpha: 0.12) : NeoColors.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: NeoColors.ink, width: 2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _pickedFile != null ? NeoColors.info : NeoColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: NeoColors.ink, width: 2),
                              ),
                              child: Icon(
                                _pickedFile?.extension == 'pdf'
                                    ? Icons.picture_as_pdf
                                    : Icons.description,
                                color: NeoColors.ink,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pickedFile != null
                                        ? _pickedFile!.name
                                        : 'Sentuh untuk memilih berkas...',
                                    style: TextStyle(
                                      fontFamily: 'Space Grotesk',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: _pickedFile != null ? NeoColors.ink : Colors.black54,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _pickedFile != null
                                        ? '${((_pickedFile!.lengthSync() ?? 0) / 1024).toStringAsFixed(1)} KB — Siap dianalisis'
                                        : 'Mendukung format .pdf, .docx, .doc, .txt',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: NeoColors.secondary,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: NeoColors.ink, width: 2),
                              ),
                              child: const Text(
                                'PILIH',
                                style: TextStyle(
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
                    ),
                    const SizedBox(height: 14),

                    // Extract Action Button
                    if (_extractedQuestions.isEmpty)
                      NeoButton(
                        text: _isExtracting ? 'GEMINI SEDANG MEMPROSES...' : 'EKSTRAK DENGAN GEMINI AI',
                        backgroundColor: NeoColors.tertiary,
                        onPressed: (_pickedFile == null || _isExtracting) ? null : _handleExtract,
                      ),

                    // Results Section
                    if (_extractedQuestions.isNotEmpty) ...[
                      const Divider(color: NeoColors.ink, thickness: 2, height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'HASIL EKSTRAKSI (${_extractedQuestions.length} SOAL)',
                                  style: const TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: NeoColors.ink,
                                  ),
                                ),
                                if (_detectedTopic != null && _detectedTopic!.isNotEmpty)
                                  Text(
                                    'Topik: $_detectedTopic',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black87,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _toggleSelectAll,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              _selectedIndices.length == _extractedQuestions.length
                                  ? 'Batal'
                                  : 'Pilih Semua (${_selectedIndices.length})',
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
                      const SizedBox(height: 8),

                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _extractedQuestions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final q = _extractedQuestions[index];
                          final isSelected = _selectedIndices.contains(index);
                          final isMcq = q['type'] == 'mcq';
                          final options = (q['options'] as List? ?? []).map((e) => e.toString()).toList();
                          final correctOpt = q['correct_option']?.toString();

                          return GestureDetector(
                            onTap: () => _toggleQuestion(index),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? NeoColors.surface : NeoColors.bg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? NeoColors.ink : Colors.black26,
                                  width: isSelected ? 2.5 : 1.5,
                                ),
                                boxShadow: isSelected
                                    ? const [
                                        BoxShadow(
                                          color: NeoColors.ink,
                                          offset: Offset(3, 3),
                                          blurRadius: 0,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: isSelected,
                                          activeColor: NeoColors.primary,
                                          checkColor: NeoColors.ink,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          onChanged: (_) => _toggleQuestion(index),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: NeoColors.ink,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '#${q['number'] ?? (index + 1)}',
                                          style: const TextStyle(
                                            fontFamily: 'Space Mono',
                                            fontWeight: FontWeight.w700,
                                            fontSize: 10,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      NeoTag(
                                        label: isMcq ? 'PG' : 'ESSAY',
                                        customColor: isMcq ? NeoColors.info : NeoColors.secondary,
                                        textColor: NeoColors.ink,
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${q['max_score'] ?? 10} Poin',
                                        style: const TextStyle(
                                          fontFamily: 'Space Mono',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                          color: NeoColors.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text(
                                      q['body'] ?? '',
                                      style: const TextStyle(
                                        fontFamily: 'Space Grotesk',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: NeoColors.ink,
                                      ),
                                    ),
                                  ),
                                  if (isMcq && options.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    ...options.map((opt) {
                                      final isCorrect = correctOpt != null &&
                                          (opt.startsWith(correctOpt) || opt == correctOpt);
                                      return Container(
                                        margin: const EdgeInsets.only(left: 4, bottom: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isCorrect ? NeoColors.success.withValues(alpha: 0.25) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(4),
                                          border: isCorrect
                                              ? Border.all(color: NeoColors.success, width: 1.5)
                                              : null,
                                        ),
                                        child: Row(
                                          children: [
                                            if (isCorrect)
                                              const Icon(Icons.check_circle, size: 14, color: Colors.green)
                                            else
                                              const Icon(Icons.radio_button_unchecked, size: 14, color: Colors.black45),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                opt,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w500,
                                                  color: NeoColors.ink,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                  if (!isMcq && (q['rubric'] != null || q['model_answer'] != null)) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      margin: const EdgeInsets.only(left: 4),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: NeoColors.bg,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.black12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (q['rubric'] != null)
                                            Text(
                                              'Rubrik: ${q['rubric']}',
                                              style: const TextStyle(fontSize: 11, color: Colors.black87),
                                            ),
                                          if (q['model_answer'] != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Kunci: ${q['model_answer']}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isExtracting ? null : _handleExtract,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: NeoColors.ink, width: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                'ULANG',
                                style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: NeoColors.ink,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: NeoButton(
                              text: _isSaving
                                  ? 'MENYIMPAN...'
                                  : 'SIMPAN (${_selectedIndices.length} SOAL)',
                              backgroundColor: NeoColors.success,
                              onPressed: (_selectedIndices.isEmpty || _isSaving) ? null : _handleSave,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
