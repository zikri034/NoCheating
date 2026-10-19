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
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/exam_model.dart';
import '../../data/models/question_model.dart';
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
        onAddQuestions: isLecturer
            ? () {
                Navigator.of(context).pop();
                _showAssignQuestionsDialog(examId);
              }
            : null,
      ),
    );
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

  void _showCreateExamDialog() {
    final examProv = context.read<ExamProvider>();
    showDialog(
      context: context,
      builder: (_) => CreateExamDialog(
        courses: examProv.courses,
        onSubmit: (data) async {
          final success = await examProv.createExam(data);
          if (mounted) {
            if (success) {
              await examProv.loadExams();
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

  void _showExtractQuestionsDialog() {
    showDialog(
      context: context,
      builder: (_) => const ExtractQuestionsDialog(),
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

  void _showAssignQuestionsDialog(String examId) {
    final examProv = context.read<ExamProvider>();
    showDialog(
      context: context,
      builder: (_) => AssignQuestionsDialog(
        examId: examId,
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
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionBankView(ExamProvider examProv) {
    final questions = examProv.questions.where((q) {
      if (_selectedQuestionType == 'mcq' && q.type != 'mcq') return false;
      if (_selectedQuestionType == 'essay' && q.type != 'essay') return false;
      final query = _questionSearchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        return q.body.toLowerCase().contains(query);
      }
      return true;
    }).toList();

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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    NeoChip(
                      label: 'SEMUA (${examProv.questions.length})',
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
              Text(
                '${questions.length} Butir Soal Ditampilkan',
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: NeoColors.ink,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showExtractQuestionsDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: NeoColors.tertiary,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: NeoColors.ink, width: 1.5),
                  ),
                  child: const Row(
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: NeoColors.secondary,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: NeoColors.ink, width: 1.5),
                  ),
                  child: const Row(
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
                            message: 'Bank soal masih kosong atau tidak cocok dengan filter. Unggah dokumen ujian dengan Gemini AI atau buat butir soal manual.',
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton.icon(
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
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: questions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          return _buildQuestionCard(questions[index], index + 1);
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(QuestionModel q, int number) {
    final isMcq = q.type == 'mcq';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NeoColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeoColors.ink, width: 2.5),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: NeoColors.ink,
                  borderRadius: BorderRadius.circular(6),
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
              const SizedBox(width: 8),
              NeoTag(
                label: isMcq ? 'PILIHAN GANDA' : 'ESSAY',
                customColor: isMcq ? NeoColors.info : NeoColors.secondary,
                textColor: NeoColors.ink,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: NeoColors.bg,
                  borderRadius: BorderRadius.circular(6),
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
            ],
          ),
          const SizedBox(height: 10),
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
