import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_text_field.dart';
import '../../../../core/widgets/neo_chip.dart';
import '../../../../core/widgets/neo_empty_state.dart';
import '../../../../core/widgets/neo_snackbar.dart';
import '../../../../core/services/geofence_service.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/widgets/neo_tag.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/exam_model.dart';
import '../../data/models/question_model.dart';
import '../../data/models/course_model.dart';
import '../providers/exam_provider.dart';
import '../widgets/exam_card.dart';
import '../widgets/exam_detail_dialog.dart';
import '../widgets/create_exam_dialog.dart';
import '../widgets/create_question_dialog.dart';
import '../widgets/assign_questions_dialog.dart';
import '../widgets/extract_questions_dialog.dart';
import '../../data/repositories/attempt_repository.dart';
import '../providers/exam_runner_provider.dart';
import 'exam_runner_screen.dart';
import 'exam_location_screen.dart';
import 'exam_monitor_screen.dart';
import 'essay_review_screen.dart';
import 'exam_result_screen.dart';
import '../../data/repositories/exam_repository.dart';

class _BankListItem {
  final bool isHeader;
  final String? courseTitle;
  final String? courseId;
  final List<String>? groupQuestionIds;
  final QuestionModel? question;
  final int? questionNumber;

  _BankListItem.header({
    required this.courseTitle,
    required this.courseId,
    required this.groupQuestionIds,
  })  : isHeader = true,
        question = null,
        questionNumber = null;

  _BankListItem.question({
    required this.question,
    required this.questionNumber,
  })  : isHeader = false,
        courseTitle = null,
        courseId = null,
        groupQuestionIds = null;
}

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _questionSearchController = TextEditingController();
  final GeofenceService _geofenceService = GeofenceService();
  final BiometricService _biometricService = BiometricService();

  int _selectedLecturerTab = 0; // 0 = Ujian, 1 = Bank Soal
  String _selectedQuestionType = 'all'; // all, mcq, essay
  String _selectedQuestionCourseId = 'all'; // 'all' or course.id
  final Set<String> _selectedBankQuestionIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final examProv = context.read<ExamProvider>();
      final authProv = context.read<AuthProvider>();
      examProv.loadExams();
      if (authProv.currentUser?.role == 'lecturer') {
        examProv.loadCourses();
        examProv.loadQuestions();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _questionSearchController.dispose();
    super.dispose();
  }

  void _showDetailDialog(String examId) async {
    final examProv = context.read<ExamProvider>();
    final authProv = context.read<AuthProvider>();
    final isLecturer = authProv.currentUser?.role == 'lecturer';

    final detail = await examProv.getExamDetail(examId);
    if (!mounted || detail == null) return;

    showDialog(
      context: context,
      builder: (_) => ExamDetailDialog(
        exam: detail['exam'],
        questions: detail['questions'],
        enrollmentCount: detail['enrollment_count'],
        isLecturer: isLecturer,
        onEnroll: () => _handleEnroll(examId),
        onStartExam: () => _startExam(examId),
        onMonitor: isLecturer ? () => _showExamMonitor(examId) : null,
        onViewLocation: () => _showExamLocation(detail['exam']),
        onReviewEssay: isLecturer ? () => _showEssayReviews(examId, detail['exam']?.title) : null,
        onDeleteExam: isLecturer ? () => _confirmDeleteExam(examId, detail['exam']?.title ?? 'Ujian') : null,
        onAddQuestions: isLecturer
            ? () {
                Navigator.of(context).pop();
                _showAssignQuestionsDialog(examId);
              }
            : null,
        onViewResult: () => _viewExamResult(examId, detail['exam']?.myAttemptId),
      ),
    );
  }

  Future<void> _viewExamResult(String examId, [String? attemptId]) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: NeoColors.ink),
      ),
    );

    try {
      final attemptRepo = AttemptRepository();
      Map<String, dynamic> result;
      if (attemptId != null && attemptId.isNotEmpty) {
        result = await attemptRepo.fetchAttemptResult(attemptId);
      } else {
        final examRepo = ExamRepository();
        result = await examRepo.fetchMyExamResult(examId);
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExamResultScreen(
            result: result,
            onBackToExams: () => Navigator.of(context).pop(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: NeoColors.danger,
          content: Text('Gagal memuat hasil ujian: ${e.toString().replaceAll('Exception: ', '')}'),
        ),
      );
    }
  }

  Future<void> _startExam(String examId) async {
    final examProv = context.read<ExamProvider>();
    final exam = examProv.exams.cast<ExamModel?>().firstWhere(
          (e) => e?.id == examId,
          orElse: () => null,
        );

    // 1. Biometric verification if required (PRD F02 & F04)
    if (exam != null && exam.requireBiometric) {
      final authenticated = await _biometricService.authenticate(
        localizedReason: 'Verifikasi biometrik wajib sebelum mengerjakan ujian.',
      );
      if (!authenticated) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: NeoColors.danger,
            content: Text('Autentikasi biometrik gagal atau dibatalkan.'),
          ),
        );
        return;
      }
    }

    // 2. Geofence verification if required (PRD F06)
    if (exam != null && exam.requireGeofence && exam.venueLat != null && exam.venueLng != null) {
      final status = await _geofenceService.checkGeofence(
        venueLat: exam.venueLat!,
        venueLng: exam.venueLng!,
        radiusMeters: (exam.venueRadiusM ?? 100).toDouble(),
      );

      if (status == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: NeoColors.danger,
            content: Text('Gagal membaca lokasi GPS. Pastikan izin lokasi aktif.'),
          ),
        );
        return;
      }

      if (status.isMocked) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: NeoColors.danger,
            content: Text('Dilarang menggunakan lokasi tiruan/palsu!'),
          ),
        );
        return;
      }

      if (!status.isInside) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: NeoColors.danger,
            content: Text(
              'Anda berada di luar radius lokasi ujian (${status.distanceMeters.round()} m > ${exam.venueRadiusM ?? 100} m).',
            ),
          ),
        );
        return;
      }
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => ExamRunnerProvider(repository: AttemptRepository()),
          child: ExamRunnerScreen(examId: examId),
        ),
      ),
    ).then((_) {
      if (mounted) {
        context.read<ExamProvider>().loadExams();
      }
    });
  }

  void _showExamMonitor(String examId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamMonitorScreen(examId: examId),
      ),
    );
  }

  void _showExamLocation(ExamModel exam) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamLocationScreen(exam: exam),
      ),
    );
  }

  void _showEssayReviews(String examId, [String? examTitle]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EssayReviewScreen(examId: examId, examTitle: examTitle),
      ),
    );
  }

  void _showCreateExamDialog({List<String>? initialSelectedQuestionIds}) {
    final examProv = context.read<ExamProvider>();
    showDialog(
      context: context,
      builder: (_) => CreateExamDialog(
        courses: examProv.courses,
        initialSelectedQuestionIds: initialSelectedQuestionIds,
        onSubmit: (data) async {
          final success = await examProv.createExam(data);
          if (mounted) {
            if (success) {
              await examProv.loadExams();
              if (initialSelectedQuestionIds != null && initialSelectedQuestionIds.isNotEmpty) {
                setState(() {
                  _selectedBankQuestionIds.clear();
                });
              }
              if (!mounted) return success;
              NeoSnackbar.showSuccess(
                context,
                title: 'UJIAN BERHASIL DIBUAT',
                message: 'Ujian baru berhasil dibuat dan siap dijadwalkan!',
              );
            } else {
              NeoSnackbar.showError(
                context,
                title: 'GAGAL MEMBUAT UJIAN',
                message: examProv.errorMessage ?? 'Gagal membuat ujian',
              );
            }
          }
          return success;
        },
      ),
    );
  }

  void _confirmDeleteExam(String examId, String examTitle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeoColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: NeoColors.ink, width: 3),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: NeoColors.danger, size: 24),
            SizedBox(width: 8),
            Text(
              'HAPUS UJIAN?',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: NeoColors.ink,
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus ujian "$examTitle"? Seluruh data ujian, peserta, dan butir soal terkait pada ujian ini akan dihapus.',
          style: const TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: 13,
            color: NeoColors.ink,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'BATAL',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontWeight: FontWeight.w800,
                color: NeoColors.ink,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NeoColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              side: const BorderSide(color: NeoColors.ink, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              final examProv = context.read<ExamProvider>();
              final success = await examProv.deleteExam(examId);
              if (mounted) {
                if (success) {
                  NeoSnackbar.showSuccess(
                    context,
                    title: 'UJIAN DIHAPUS',
                    message: 'Ujian "$examTitle" berhasil dihapus dari sistem.',
                  );
                } else {
                  NeoSnackbar.showError(
                    context,
                    title: 'GAGAL MENGHAPUS',
                    message: examProv.errorMessage ?? 'Gagal menghapus ujian.',
                  );
                }
              }
            },
            child: const Text(
              'HAPUS',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSelectExamDialog(List<String> questionIds) {
    final examProv = context.read<ExamProvider>();
    final exams = examProv.exams;

    if (exams.isEmpty) {
      NeoSnackbar.showWarning(
        context,
        title: 'BELUM ADA UJIAN',
        message: 'Buat ujian terlebih dahulu sebelum memasukkan butir soal.',
      );
      return;
    }

    final selectedQuestions = examProv.questions.where((q) => questionIds.contains(q.id)).toList();
    final questionCourseIds = selectedQuestions.map((q) => q.courseId).where((id) => id.isNotEmpty).toSet();
    final questionCourseNames = selectedQuestions
        .map((q) => '${q.courseCode != null ? "[${q.courseCode}] " : ""}${q.courseName ?? "Materi"}')
        .toSet();

    // Smart default: find an exam that matches the selected questions' course
    String selectedExamId = exams.first.id;
    if (questionCourseIds.length == 1) {
      final matchingExam = exams.where((e) => e.courseId == questionCourseIds.first).firstOrNull;
      if (matchingExam != null) {
        selectedExamId = matchingExam.id;
      }
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (innerCtx, setDialogState) {
          final currentExam = exams.firstWhere((e) => e.id == selectedExamId, orElse: () => exams.first);
          final isMismatch = questionCourseIds.isNotEmpty &&
              questionCourseIds.length == 1 &&
              currentExam.courseId != questionCourseIds.first;
          final isMulti = questionCourseIds.length > 1;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: NeoColors.primary,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                      border: Border(bottom: BorderSide(color: NeoColors.ink, width: 3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.playlist_add, color: NeoColors.ink, size: 22),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'MASUKKAN SOAL KE UJIAN',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: NeoColors.ink,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(dialogCtx).pop(),
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
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Selected questions & Materi summary
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: NeoColors.tertiary,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: NeoColors.ink, width: 2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_box_outlined, color: NeoColors.ink, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${questionIds.length} butir soal dipilih untuk dialokasikan.',
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
                              if (questionCourseNames.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: NeoColors.surface,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: NeoColors.ink, width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.school, size: 12, color: NeoColors.ink),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Materi Soal: ${questionCourseNames.join(", ")}',
                                          style: const TextStyle(
                                            fontFamily: 'Space Grotesk',
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                            color: NeoColors.ink,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'PILIH UJIAN TUJUAN',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: NeoColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: NeoColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: NeoColors.ink, width: 2),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedExamId,
                              items: exams.map((ex) {
                                final isCourseMatch = questionCourseIds.contains(ex.courseId);
                                return DropdownMenuItem<String>(
                                  value: ex.id,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              ex.title,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontFamily: 'Hanken Grotesk',
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: NeoColors.ink,
                                              ),
                                            ),
                                          ),
                                          if (isCourseMatch)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: NeoColors.success,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: NeoColors.ink, width: 1),
                                              ),
                                              child: const Text(
                                                'SESUAI',
                                                style: TextStyle(
                                                  fontFamily: 'Space Mono',
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: NeoColors.ink,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      Text(
                                        '${ex.courseCode != null ? "[${ex.courseCode}] " : ""}${ex.courseName ?? "Materi Umum"}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Space Grotesk',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                          color: NeoColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => selectedExamId = val);
                                }
                              },
                            ),
                          ),
                        ),

                        // Mismatch or Multi-Course Warnings
                        if (isMismatch) ...[
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: NeoColors.warning.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: NeoColors.ink, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 20, color: NeoColors.ink),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Perhatian: Materi ujian (${currentExam.courseName}) berbeda dari materi butir soal (${questionCourseNames.first}).',
                                    style: const TextStyle(
                                      fontFamily: 'Hanken Grotesk',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: NeoColors.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (isMulti) ...[
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: NeoColors.secondary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: NeoColors.ink, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 20, color: NeoColors.ink),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Catatan: Soal yang dipilih berasal dari ${questionCourseIds.length} materi berbeda.',
                                    style: const TextStyle(
                                      fontFamily: 'Hanken Grotesk',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: NeoColors.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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
                            text: 'ALOKASIKAN KE UJIAN',
                            variant: NeoButtonVariant.primary,
                            onPressed: () async {
                              Navigator.of(dialogCtx).pop();
                              final success = await examProv.assignQuestions(selectedExamId, questionIds);
                              if (!mounted) return;
                              if (success) {
                                setState(() {
                                  _selectedBankQuestionIds.clear();
                                });
                                final targetExam = exams.firstWhere((e) => e.id == selectedExamId);
                                NeoSnackbar.showSuccess(
                                  context,
                                  title: 'BERHASIL DIALOKASIKAN',
                                  message: '${questionIds.length} butir soal berhasil dimasukkan ke "${targetExam.title}".',
                                );
                                await examProv.loadExams();
                              } else {
                                NeoSnackbar.showError(
                                  context,
                                  title: 'GAGAL MENAMBAHKAN',
                                  message: examProv.errorMessage ?? 'Gagal menambahkan soal ke ujian',
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showExtractQuestionsDialog() {
    showDialog(
      context: context,
      builder: (_) => ExtractQuestionsDialog(
        initialCourseId: _selectedQuestionCourseId != 'all' ? _selectedQuestionCourseId : null,
      ),
    ).then((_) {
      if (mounted) {
        context.read<ExamProvider>().loadQuestions();
      }
    });
  }

  void _showCreateQuestionDialog() {
    final examProv = context.read<ExamProvider>();
    showDialog(
      context: context,
      builder: (_) => CreateQuestionDialog(
        courses: examProv.courses,
        initialCourseId: _selectedQuestionCourseId != 'all' ? _selectedQuestionCourseId : null,
        onSubmit: (data) async {
          final success = await examProv.createQuestion(data);
          if (mounted) {
            if (success) {
              NeoSnackbar.showSuccess(
                context,
                title: 'BERHASIL MENAMBAHKAN SOAL',
                message: 'Soal baru berhasil ditambahkan ke bank soal!',
              );
            } else {
              NeoSnackbar.showError(
                context,
                title: 'GAGAL MENAMBAHKAN SOAL',
                message: examProv.errorMessage ?? 'Gagal menambahkan soal ke bank soal',
              );
            }
          }
          return success;
        },
      ),
    );
  }

  void _showCreateCourseDialog() {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
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
                mainAxisSize: MainAxisSize.min,
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
                        const Icon(Icons.category_outlined, color: NeoColors.ink, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'TAMBAH MATERI BARU',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: NeoColors.ink,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(dialogCtx).pop(),
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
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          NeoTextField(
                            label: 'KODE MATERI (CONTOH: IF4501)',
                            controller: codeCtrl,
                            hintText: 'Masukkan kode unik materi...',
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Kode materi tidak boleh kosong';
                              if (v.trim().length < 2) return 'Minimal 2 karakter';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          NeoTextField(
                            label: 'NAMA MATERI / MATA KULIAH',
                            controller: nameCtrl,
                            hintText: 'Contoh: Pemrograman Aplikasi Mobile',
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Nama materi tidak boleh kosong';
                              if (v.trim().length < 2) return 'Minimal 2 karakter';
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          NeoButton(
                            text: isSaving ? 'MENYIMPAN...' : 'SIMPAN MATERI',
                            backgroundColor: NeoColors.secondary,
                            icon: const Icon(Icons.check, size: 18, color: NeoColors.ink),
                            onPressed: isSaving ? null : () async {
                              if (!formKey.currentState!.validate()) return;
                              setDialogState(() => isSaving = true);

                              final examProv = context.read<ExamProvider>();
                              final created = await examProv.createCourse(
                                codeCtrl.text.trim(),
                                nameCtrl.text.trim(),
                              );

                              if (!dialogCtx.mounted) return;
                              if (created != null) {
                                Navigator.of(dialogCtx).pop();
                                if (mounted) {
                                  setState(() {
                                    _selectedQuestionCourseId = created.id;
                                  });
                                  NeoSnackbar.showSuccess(
                                    context,
                                    title: 'MATERI BERHASIL DIBUAT',
                                    message: 'Materi [${created.code}] ${created.name} berhasil ditambahkan!',
                                  );
                                }
                              } else {
                                setDialogState(() => isSaving = false);
                                NeoSnackbar.showError(
                                  dialogCtx,
                                  title: 'GAGAL MEMBUAT MATERI',
                                  message: examProv.errorMessage ?? 'Gagal membuat materi',
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAssignQuestionsDialog(String examId) {
    final examProv = context.read<ExamProvider>();
    ExamModel? targetExam;
    try {
      targetExam = examProv.exams.firstWhere((e) => e.id == examId);
    } catch (_) {}

    showDialog(
      context: context,
      builder: (_) => AssignQuestionsDialog(
        examId: examId,
        examTitle: targetExam?.title,
        courseId: targetExam?.courseId,
        courseName: targetExam?.courseName,
        courseCode: targetExam?.courseCode,
        availableQuestions: examProv.questions,
        onSubmit: (id, qids) async {
          final success = await examProv.assignQuestions(id, qids);
          if (mounted && success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: NeoColors.success,
                content: Text('${qids.length} soal berhasil ditambahkan ke ujian!', style: const TextStyle(color: NeoColors.ink)),
              ),
            );
          }
          return success;
        },
      ),
    );
  }

  Future<void> _confirmDeleteQuestion(QuestionModel q) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: NeoColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: NeoColors.ink, width: 3),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: NeoColors.danger, size: 24),
            SizedBox(width: 8),
            Text(
              'HAPUS SOAL',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: NeoColors.ink,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apakah Anda yakin ingin menghapus butir soal ini dari bank soal?',
              style: TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: NeoColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NeoColors.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(
                q.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text(
              'BATAL',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontWeight: FontWeight.w700,
                color: NeoColors.ink,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NeoColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              side: const BorderSide(color: NeoColors.ink, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text(
              'HAPUS',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final examProv = context.read<ExamProvider>();
      final success = await examProv.deleteQuestion(q.id);
      if (mounted) {
        if (success) {
          setState(() {
            _selectedBankQuestionIds.remove(q.id);
          });
          NeoSnackbar.showSuccess(
            context,
            title: 'SOAL DIHAPUS',
            message: 'Butir soal berhasil dihapus dari bank soal.',
          );
        } else {
          NeoSnackbar.showError(
            context,
            title: 'GAGAL MENGHAPUS',
            message: examProv.errorMessage ?? 'Gagal menghapus butir soal.',
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteSelectedQuestions() async {
    final count = _selectedBankQuestionIds.length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: NeoColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: NeoColors.ink, width: 3),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: NeoColors.danger, size: 24),
            SizedBox(width: 8),
            Text(
              'HAPUS BANYAK SOAL',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: NeoColors.ink,
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus $count butir soal terpilih dari bank soal secara permanen?',
          style: const TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: NeoColors.ink,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text(
              'BATAL',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontWeight: FontWeight.w700,
                color: NeoColors.ink,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NeoColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              side: const BorderSide(color: NeoColors.ink, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text(
              'HAPUS SEMUA',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final examProv = context.read<ExamProvider>();
      final idsToDelete = _selectedBankQuestionIds.toList();
      final success = await examProv.deleteQuestionsBatch(idsToDelete);
      if (mounted) {
        if (success) {
          setState(() {
            _selectedBankQuestionIds.clear();
          });
          NeoSnackbar.showSuccess(
            context,
            title: 'SOAL DIHAPUS',
            message: '$count butir soal berhasil dihapus dari bank soal.',
          );
        } else {
          NeoSnackbar.showError(
            context,
            title: 'GAGAL MENGHAPUS',
            message: examProv.errorMessage ?? 'Gagal menghapus butir soal terpilih.',
          );
        }
      }
    }
  }

  Future<void> _handleEnroll(String examId) async {
    final examProv = context.read<ExamProvider>();
    final success = await examProv.enrollExam(examId);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: NeoColors.success,
          content: Text('Berhasil mendaftar ke ujian ini!', style: TextStyle(color: NeoColors.ink)),
        ),
      );
    } else if (examProv.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: NeoColors.danger,
          content: Text(examProv.errorMessage!, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final examProv = context.watch<ExamProvider>();
    final isLecturer = authProv.currentUser?.role == 'lecturer';

    return Scaffold(
      backgroundColor: NeoColors.bg,
      appBar: AppBar(
        backgroundColor: NeoColors.primary,
        elevation: 0,
        title: Text(
          isLecturer && _selectedLecturerTab == 1 ? 'BANK SOAL' : 'DAFTAR UJIAN',
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: NeoColors.ink,
          ),
        ),
        shape: const Border(
          bottom: BorderSide(color: NeoColors.ink, width: 3),
        ),
        actions: [
          if (isLecturer) ...[
            if (_selectedLecturerTab == 0)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: _showCreateExamDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: NeoColors.secondary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: NeoColors.ink, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: NeoColors.ink,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, size: 16, color: NeoColors.ink),
                        SizedBox(width: 4),
                        Text(
                          'BUAT UJIAN',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: NeoColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: _showExtractQuestionsDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: NeoColors.tertiary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: NeoColors.ink, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: NeoColors.ink,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: NeoColors.ink),
                        SizedBox(width: 4),
                        Text(
                          'AI EKSTRAK',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: NeoColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: _showCreateQuestionDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: NeoColors.secondary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: NeoColors.ink, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: NeoColors.ink,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, size: 16, color: NeoColors.ink),
                        SizedBox(width: 4),
                        Text(
                          'BUAT SOAL',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: NeoColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
      body: Column(
        children: [
          // Lecturer Navigation Switcher (PRD Neo-Brutalist Tabs)
          if (isLecturer)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: NeoColors.surface,
                border: Border(bottom: BorderSide(color: NeoColors.ink, width: 3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedLecturerTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _selectedLecturerTab == 0 ? NeoColors.primary : NeoColors.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: NeoColors.ink, width: 2),
                          boxShadow: _selectedLecturerTab == 0
                              ? const [
                                  BoxShadow(
                                    color: NeoColors.ink,
                                    offset: Offset(3, 3),
                                    blurRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_outlined, size: 16, color: NeoColors.ink),
                            SizedBox(width: 6),
                            Text(
                              'DAFTAR UJIAN',
                              style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: NeoColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedLecturerTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _selectedLecturerTab == 1 ? NeoColors.tertiary : NeoColors.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: NeoColors.ink, width: 2),
                          boxShadow: _selectedLecturerTab == 1
                              ? const [
                                  BoxShadow(
                                    color: NeoColors.ink,
                                    offset: Offset(3, 3),
                                    blurRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.collections_bookmark_outlined, size: 16, color: NeoColors.ink),
                            const SizedBox(width: 6),
                            Text(
                              'BANK SOAL (${examProv.questions.length})',
                              style: const TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: NeoColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Main View Content
          Expanded(
            child: isLecturer && _selectedLecturerTab == 1
                ? _buildQuestionBankView(examProv)
                : _buildExamsListView(examProv, isLecturer),
          ),
        ],
      ),
    );
  }

  Widget _buildExamsListView(ExamProvider examProv, bool isLecturer) {
    return Column(
      children: [
        // Search & Filter Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: NeoColors.surface,
            border: Border(bottom: BorderSide(color: NeoColors.ink, width: 3)),
          ),
          child: Column(
            children: [
              // Search Field
              NeoTextField(
                controller: _searchController,
                hintText: 'Cari judul ujian, mata kuliah, dosen...',
                prefixIcon: const Icon(Icons.search, color: NeoColors.ink),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: NeoColors.ink),
                        onPressed: () {
                          _searchController.clear();
                          examProv.onSearchChanged('');
                          setState(() {});
                        },
                      )
                    : null,
                onChanged: (val) {
                  setState(() {});
                  examProv.onSearchChanged(val);
                },
              ),
              const SizedBox(height: 12),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    NeoChip(
                      label: 'SEMUA',
                      isSelected: examProv.selectedTab == ExamFilterTab.all,
                      selectedColor: NeoColors.primary,
                      onTap: () => examProv.selectTab(ExamFilterTab.all),
                    ),
                    const SizedBox(width: 8),
                    NeoChip(
                      label: 'AKAN DATANG',
                      isSelected: examProv.selectedTab == ExamFilterTab.upcoming,
                      selectedColor: NeoColors.info,
                      onTap: () => examProv.selectTab(ExamFilterTab.upcoming),
                    ),
                    const SizedBox(width: 8),
                    NeoChip(
                      label: 'BERLANGSUNG',
                      isSelected: examProv.selectedTab == ExamFilterTab.active,
                      selectedColor: NeoColors.success,
                      onTap: () => examProv.selectTab(ExamFilterTab.active),
                    ),
                    const SizedBox(width: 8),
                    NeoChip(
                      label: 'SELESAI',
                      isSelected: examProv.selectedTab == ExamFilterTab.finished,
                      selectedColor: NeoColors.muted,
                      onTap: () => examProv.selectTab(ExamFilterTab.finished),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Exams List View
        Expanded(
          child: RefreshIndicator(
            color: NeoColors.ink,
            backgroundColor: NeoColors.primary,
            onRefresh: () => examProv.loadExams(),
            child: examProv.isLoading && examProv.exams.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: NeoColors.ink),
                  )
                : examProv.exams.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 40),
                          NeoEmptyState(
                            title: 'TIDAK ADA UJIAN',
                            message: 'Tidak ada ujian yang cocok dengan filter atau kata kunci pencarian.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: examProv.exams.length,
                        separatorBuilder: (_, i) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final exam = examProv.exams[index];
                          return ExamCard(
                            exam: exam,
                            isLecturer: isLecturer,
                            onTap: () => _showDetailDialog(exam.id),
                            onEnroll: () => _handleEnroll(exam.id),
                            onStartExam: () => _startExam(exam.id),
                            onMonitor: () => _showExamMonitor(exam.id),
                            onViewLocation: () => _showExamLocation(exam),
                            onReviewEssay: isLecturer ? () => _showEssayReviews(exam.id, exam.title) : null,
                            onViewResult: () => _viewExamResult(exam.id, exam.myAttemptId),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionBankView(ExamProvider examProv) {
    // Gather all distinct courses from provider & questions
    final courses = List<CourseModel>.from(examProv.courses);
    for (final q in examProv.questions) {
      if (q.courseId.isNotEmpty && !courses.any((c) => c.id == q.courseId)) {
        courses.add(CourseModel(
          id: q.courseId,
          code: q.courseCode ?? 'MAT',
          name: q.courseName ?? 'Materi Terkait',
          lecturerId: '',
        ));
      }
    }

    final questions = examProv.questions.where((q) {
      if (_selectedQuestionCourseId != 'all' && q.courseId != _selectedQuestionCourseId) {
        return false;
      }
      if (_selectedQuestionType == 'mcq' && q.type != 'mcq') return false;
      if (_selectedQuestionType == 'essay' && q.type != 'essay') return false;
      final query = _questionSearchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matchesBody = q.body.toLowerCase().contains(query);
        final matchesCourse = (q.courseName?.toLowerCase().contains(query) ?? false) ||
            (q.courseCode?.toLowerCase().contains(query) ?? false);
        return matchesBody || matchesCourse;
      }
      return true;
    }).toList();

    // Group questions by course
    final Map<String, List<QuestionModel>> groups = {};
    for (final q in questions) {
      final key = q.courseId.isNotEmpty ? q.courseId : 'unknown';
      groups.putIfAbsent(key, () => []).add(q);
    }

    final List<_BankListItem> listItems = [];
    int globalNumber = 0;
    for (final entry in groups.entries) {
      final groupQuestions = entry.value;
      final firstQ = groupQuestions.first;
      final courseCode = firstQ.courseCode;
      final courseName = firstQ.courseName;
      final title = courseName != null
          ? (courseCode != null ? '[$courseCode] $courseName' : courseName)
          : (courseCode ?? 'Materi Belum Ditentukan');

      listItems.add(_BankListItem.header(
        courseTitle: title,
        courseId: entry.key,
        groupQuestionIds: groupQuestions.map((q) => q.id).toList(),
      ));

      for (final q in groupQuestions) {
        globalNumber++;
        listItems.add(_BankListItem.question(
          question: q,
          questionNumber: globalNumber,
        ));
      }
    }

    return Column(
      children: [
        // Question Search & Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: NeoColors.surface,
            border: Border(bottom: BorderSide(color: NeoColors.ink, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeoTextField(
                controller: _questionSearchController,
                hintText: 'Cari pertanyaan butir soal...',
                prefixIcon: const Icon(Icons.search, color: NeoColors.ink),
                suffixIcon: _questionSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: NeoColors.ink),
                        onPressed: () {
                          _questionSearchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              // Type Filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    NeoChip(
                      label: 'SEMUA TIPE (${examProv.questions.length})',
                      isSelected: _selectedQuestionType == 'all',
                      selectedColor: NeoColors.primary,
                      onTap: () => setState(() => _selectedQuestionType = 'all'),
                    ),
                    const SizedBox(width: 8),
                    NeoChip(
                      label: 'PILIHAN GANDA',
                      isSelected: _selectedQuestionType == 'mcq',
                      selectedColor: NeoColors.info,
                      onTap: () => setState(() => _selectedQuestionType = 'mcq'),
                    ),
                    const SizedBox(width: 8),
                    NeoChip(
                      label: 'ESSAY',
                      isSelected: _selectedQuestionType == 'essay',
                      selectedColor: NeoColors.secondary,
                      onTap: () => setState(() => _selectedQuestionType = 'essay'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Materi / Course Filter Chips
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: NeoColors.ink,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'MATERI',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          NeoChip(
                            label: 'SEMUA MATERI (${examProv.questions.length})',
                            isSelected: _selectedQuestionCourseId == 'all',
                            selectedColor: NeoColors.tertiary,
                            onTap: () => setState(() => _selectedQuestionCourseId = 'all'),
                          ),
                          ...courses.map((c) {
                            final count = examProv.questions.where((q) => q.courseId == c.id).length;
                            return Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: NeoChip(
                                label: '${c.code} • ${c.name} ($count)',
                                isSelected: _selectedQuestionCourseId == c.id,
                                selectedColor: NeoColors.primary,
                                onTap: () => setState(() => _selectedQuestionCourseId = c.id),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Counter & Quick Actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: NeoColors.surface,
            border: Border(bottom: BorderSide(color: NeoColors.ink, width: 2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${questions.length} Butir Soal (${groups.length} Materi)',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: NeoColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showCreateCourseDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: NeoColors.primary,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: NeoColors.ink, width: 1.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.category_outlined, size: 12, color: NeoColors.ink),
                      SizedBox(width: 3),
                      Text(
                        '+ MATERI',
                        style: TextStyle(
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
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _showExtractQuestionsDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: NeoColors.tertiary,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: NeoColors.ink, width: 1.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 12, color: NeoColors.ink),
                      SizedBox(width: 4),
                      Text(
                        'AI EKSTRAK',
                        style: TextStyle(
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
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _showCreateQuestionDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: NeoColors.secondary,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: NeoColors.ink, width: 1.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 13, color: NeoColors.ink),
                      SizedBox(width: 3),
                      Text(
                        'TAMBAH',
                        style: TextStyle(
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
        ),

        // Questions List
        Expanded(
          child: RefreshIndicator(
            color: NeoColors.ink,
            backgroundColor: NeoColors.primary,
            onRefresh: () => examProv.loadQuestions(),
            child: examProv.isLoadingQuestions && examProv.questions.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: NeoColors.ink),
                  )
                : questions.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 40),
                          const NeoEmptyState(
                            title: 'BELUM ADA SOAL',
                            message: 'Bank soal masih kosong atau tidak cocok dengan filter materi. Unggah dokumen ujian dengan Gemini AI atau buat butir soal manual.',
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _showCreateCourseDialog,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: NeoColors.primary,
                                    foregroundColor: NeoColors.ink,
                                    side: const BorderSide(color: NeoColors.ink, width: 2),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  icon: const Icon(Icons.category_outlined, size: 18),
                                  label: const Text(
                                    'BUAT MATERI BARU',
                                    style: TextStyle(
                                      fontFamily: 'Space Grotesk',
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _showExtractQuestionsDialog,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: NeoColors.tertiary,
                                    foregroundColor: NeoColors.ink,
                                    side: const BorderSide(color: NeoColors.ink, width: 2),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  icon: const Icon(Icons.auto_awesome, size: 18),
                                  label: const Text(
                                    'UNGGAH NASKAH SOAL (AI)',
                                    style: TextStyle(
                                      fontFamily: 'Space Grotesk',
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: listItems.length,
                        separatorBuilder: (_, index) {
                          if (index < listItems.length - 1 && listItems[index + 1].isHeader) {
                            return const SizedBox(height: 18);
                          }
                          return const SizedBox(height: 12);
                        },
                        itemBuilder: (context, index) {
                          final item = listItems[index];
                          if (item.isHeader) {
                            final allGroupSelected = item.groupQuestionIds != null &&
                                item.groupQuestionIds!.isNotEmpty &&
                                item.groupQuestionIds!.every((id) => _selectedBankQuestionIds.contains(id));

                            return Container(
                              margin: const EdgeInsets.only(top: 4, bottom: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: NeoColors.tertiary,
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
                                  const Icon(Icons.school_rounded, size: 20, color: NeoColors.ink),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.courseTitle ?? 'MATERI',
                                      style: const TextStyle(
                                        fontFamily: 'Space Grotesk',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: NeoColors.ink,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: NeoColors.surface,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: NeoColors.ink, width: 1.5),
                                    ),
                                    child: Text(
                                      '${item.groupQuestionIds?.length ?? 0} Soal',
                                      style: const TextStyle(
                                        fontFamily: 'Space Mono',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: NeoColors.ink,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      if (item.groupQuestionIds == null) return;
                                      setState(() {
                                        if (allGroupSelected) {
                                          _selectedBankQuestionIds.removeAll(item.groupQuestionIds!);
                                        } else {
                                          _selectedBankQuestionIds.addAll(item.groupQuestionIds!);
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: allGroupSelected
                                            ? NeoColors.danger.withValues(alpha: 0.2)
                                            : NeoColors.surface,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: NeoColors.ink, width: 1.5),
                                      ),
                                      child: Text(
                                        allGroupSelected ? 'BATAL' : 'PILIH SEMUA',
                                        style: TextStyle(
                                          fontFamily: 'Space Grotesk',
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10,
                                          color: allGroupSelected ? NeoColors.danger : NeoColors.ink,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return _buildQuestionCard(item.question!, item.questionNumber!);
                        },
                      ),
          ),
        ),
        if (_selectedBankQuestionIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: NeoColors.surface,
              border: Border(top: BorderSide(color: NeoColors.ink, width: 3)),
              boxShadow: [
                BoxShadow(
                  color: NeoColors.ink,
                  offset: Offset(0, -4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: NeoColors.tertiary,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: NeoColors.ink, width: 1.5),
                        ),
                        child: Text(
                          '${_selectedBankQuestionIds.length} Soal Dipilih',
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: NeoColors.ink,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _confirmDeleteSelectedQuestions,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: NeoColors.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: NeoColors.danger, width: 1.5),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_forever, size: 13, color: NeoColors.danger),
                              SizedBox(width: 3),
                              Text(
                                'Hapus Terpilih',
                                style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: NeoColors.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _selectedBankQuestionIds.clear()),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close, size: 13, color: NeoColors.ink),
                            SizedBox(width: 2),
                            Text(
                              'Batal',
                              style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: NeoColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: NeoColors.secondary,
                            foregroundColor: NeoColors.ink,
                            elevation: 0,
                            side: const BorderSide(color: NeoColors.ink, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.add_box_outlined, size: 14, color: NeoColors.ink),
                          label: const Text(
                            'BUAT UJIAN',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                          onPressed: () => _showCreateExamDialog(
                            initialSelectedQuestionIds: _selectedBankQuestionIds.toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: NeoColors.primary,
                            foregroundColor: NeoColors.ink,
                            elevation: 0,
                            side: const BorderSide(color: NeoColors.ink, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.playlist_add, size: 16, color: NeoColors.ink),
                          label: const Text(
                            'MASUKKAN KE UJIAN',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                          onPressed: () => _showSelectExamDialog(_selectedBankQuestionIds.toList()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuestionCard(QuestionModel q, int number) {
    final isMcq = q.type == 'mcq';
    final isSelected = _selectedBankQuestionIds.contains(q.id);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected ? NeoColors.primary.withValues(alpha: 0.15) : NeoColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? NeoColors.ink : NeoColors.ink,
          width: isSelected ? 3 : 2.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: NeoColors.ink,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: isSelected,
                    activeColor: NeoColors.primary,
                    checkColor: NeoColors.ink,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedBankQuestionIds.add(q.id);
                        } else {
                          _selectedBankQuestionIds.remove(q.id);
                        }
                      });
                    },
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
                    '#$number',
                    style: const TextStyle(
                      fontFamily: 'Space Mono',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
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
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: NeoColors.bg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: NeoColors.ink, width: 1.5),
                  ),
                  child: Text(
                    '${q.maxScore.toStringAsFixed(0)} Poin',
                    style: const TextStyle(
                      fontFamily: 'Space Mono',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: NeoColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showSelectExamDialog([q.id]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: NeoColors.tertiary,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: NeoColors.ink, width: 1.5),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 12, color: NeoColors.ink),
                        SizedBox(width: 2),
                        Text(
                          'KE UJIAN',
                          style: TextStyle(
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
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _confirmDeleteQuestion(q),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: NeoColors.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: NeoColors.danger, width: 1.5),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, size: 12, color: NeoColors.danger),
                        SizedBox(width: 2),
                        Text(
                          'HAPUS',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            color: NeoColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (q.courseName != null || q.courseCode != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: NeoColors.tertiary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: NeoColors.ink, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school, size: 12, color: NeoColors.ink),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${q.courseCode != null ? "[${q.courseCode}] " : ""}${q.courseName ?? ""}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
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
          Text(
            q.body,
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: NeoColors.ink,
            ),
          ),
          if (isMcq && q.options != null && q.options!.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...q.options!.map((opt) {
              final isCorrect = q.correctOption != null &&
                  (opt.startsWith(q.correctOption!) || opt == q.correctOption);
              return Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isCorrect ? NeoColors.success.withValues(alpha: 0.25) : NeoColors.bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCorrect ? NeoColors.success : Colors.black12,
                    width: isCorrect ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 16,
                      color: isCorrect ? Colors.green.shade800 : Colors.black45,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isCorrect ? FontWeight.w800 : FontWeight.w500,
                          color: NeoColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (!isMcq && (q.rubric != null || q.modelAnswer != null)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NeoColors.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (q.rubric != null) ...[
                    const Text(
                      'RUBRIK PENILAIAN:',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        color: NeoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      q.rubric!,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                  if (q.modelAnswer != null) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'KUNCI JAWABAN / MODEL ANSWER:',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        color: NeoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      q.modelAnswer!,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
