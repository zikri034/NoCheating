import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_card.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/widgets/neo_tag.dart';
import '../../../../core/widgets/neo_text_field.dart';
import '../../data/repositories/exam_repository.dart';

class EssayReviewScreen extends StatefulWidget {
  final String? examId;
  final String? examTitle;

  const EssayReviewScreen({
    super.key,
    this.examId,
    this.examTitle,
  });

  @override
  State<EssayReviewScreen> createState() => _EssayReviewScreenState();
}

class _EssayReviewScreenState extends State<EssayReviewScreen> {
  final ExamRepository _examRepo = ExamRepository();

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _students = [];
  String _selectedStatus = 'needs_review'; // Default: Perlu Review

  @override
  void initState() {
    super.initState();
    _loadStudentReviews();
  }

  Future<void> _loadStudentReviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final statusParam = _selectedStatus == 'ALL' ? null : _selectedStatus;
      final data = await _examRepo.fetchStudentEssayReviews(
        status: statusParam,
        examId: widget.examId,
      );

      if (mounted) {
        setState(() {
          _students = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _openStudentReview(Map<String, dynamic> student) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentEssayDetailScreen(
          student: student,
          examTitle: widget.examTitle,
          onGraded: _loadStudentReviews,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _students.where((s) => s['needs_review'] == true).length;

    return Scaffold(
      backgroundColor: NeoColors.bg,
      appBar: AppBar(
        backgroundColor: NeoColors.primary,
        elevation: 0,
        title: Text(
          widget.examTitle != null ? 'REVIEW: ${widget.examTitle}' : 'REVIEW ESSAY MAHASISWA',
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: NeoColors.ink,
          ),
        ),
        shape: const Border(
          bottom: BorderSide(color: NeoColors.ink, width: 3),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs (Neo-brutalist Chips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: NeoColors.surface,
              border: Border(
                bottom: BorderSide(color: NeoColors.ink, width: 2),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('needs_review', 'Perlu Review ($pendingCount)'),
                  const SizedBox(width: 8),
                  _buildFilterChip('ALL', 'Semua Mahasiswa'),
                  const SizedBox(width: 8),
                  _buildFilterChip('finalized', 'Sudah Selesai Dinilai'),
                ],
              ),
            ),
          ),

          // Content List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: NeoColors.ink))
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              NeoButton(text: 'COBA LAGI', onPressed: _loadStudentReviews),
                            ],
                          ),
                        ),
                      )
                    : _students.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: NeoColors.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: NeoColors.ink, width: 2),
                                    ),
                                    child: const Icon(Icons.check_circle_outline, size: 40, color: NeoColors.ink),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _selectedStatus == 'needs_review'
                                        ? 'Semua jawaban essay telah selesai direview!'
                                        : 'Tidak ada mahasiswa yang ditemukan.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Space Grotesk',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: NeoColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadStudentReviews,
                            color: NeoColors.ink,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _students.length,
                              separatorBuilder: (ctx, i) => const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                return _buildStudentCard(_students[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedStatus == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = value;
        });
        _loadStudentReviews();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? NeoColors.primary : NeoColors.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: NeoColors.ink, width: 2),
          boxShadow: isSelected
              ? const [BoxShadow(color: NeoColors.ink, offset: Offset(2, 2))]
              : null,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: NeoColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final studentName = student['student_name'] ?? 'Mahasiswa';
    final studentNim = student['student_nim'] ?? '-';
    final essays = (student['essays'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final mcqScore = student['mcq_score'] ?? 0;
    final maxMcqScore = student['max_mcq_score'] ?? 0;
    final maxEssayScore = student['max_essay_score'] ?? 0;
    final aiSum = student['ai_essay_score_sum'] ?? 0;
    final finalEssaySum = student['final_essay_score_sum'];
    final isFinalized = student['all_finalized'] == true;

    return NeoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isFinalized ? NeoColors.success : NeoColors.warning,
                  shape: BoxShape.circle,
                  border: Border.all(color: NeoColors.ink, width: 2),
                ),
                child: const Icon(Icons.person, color: NeoColors.ink, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: NeoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NIM: $studentNim • ${essays.length} Soal Essay',
                      style: const TextStyle(
                        fontFamily: 'Space Mono',
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              NeoTag(
                label: isFinalized ? 'SUDAH DINILAI' : 'PERLU REVIEW',
                variant: isFinalized ? NeoTagVariant.success : NeoTagVariant.warning,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: NeoColors.ink, thickness: 1.5),
          const SizedBox(height: 10),

          // Score Summary Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: NeoColors.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: NeoColors.ink, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Skor PG (Langsung):',
                        style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$mcqScore / $maxMcqScore',
                        style: const TextStyle(fontFamily: 'Space Mono', fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: NeoColors.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: NeoColors.ink, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFinalized ? 'Nilai Essay Final:' : 'Saran AI Essay:',
                        style: const TextStyle(fontFamily: 'Space Grotesk', fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isFinalized ? '$finalEssaySum / $maxEssayScore' : '$aiSum / $maxEssayScore',
                        style: TextStyle(
                          fontFamily: 'Space Mono',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: isFinalized ? Colors.black : const Color(0xFFB78103),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          NeoButton(
            text: isFinalized ? 'LIHAT / UBAH PENILAIAN ESSAY' : 'REVIEW JAWABAN ESSAY',
            icon: const Icon(Icons.arrow_forward, size: 16, color: NeoColors.ink),
            variant: isFinalized ? NeoButtonVariant.secondary : NeoButtonVariant.primary,
            onPressed: () => _openStudentReview(student),
          ),
        ],
      ),
    );
  }
}

/// Detail Review Semua Jawaban Essay dari 1 Mahasiswa
class StudentEssayDetailScreen extends StatefulWidget {
  final Map<String, dynamic> student;
  final String? examTitle;
  final VoidCallback onGraded;

  const StudentEssayDetailScreen({
    super.key,
    required this.student,
    this.examTitle,
    required this.onGraded,
  });

  @override
  State<StudentEssayDetailScreen> createState() => _StudentEssayDetailScreenState();
}

class _StudentEssayDetailScreenState extends State<StudentEssayDetailScreen> {
  final ExamRepository _examRepo = ExamRepository();

  late final TextEditingController _totalScoreController;
  late final TextEditingController _commentController;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    final isFinalized = student['all_finalized'] == true;
    final initialScore = isFinalized
        ? (student['final_essay_score_sum'] ?? 0)
        : (student['ai_essay_score_sum'] ?? 0);

    _totalScoreController = TextEditingController(text: '$initialScore');
    _commentController = TextEditingController(text: student['teacher_comment']?.toString() ?? '');
  }

  @override
  void dispose() {
    _totalScoreController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitFinalStudentGrade() async {
    final student = widget.student;
    final attemptId = student['attempt_id']?.toString() ?? '';
    final maxEssayScore = double.tryParse(student['max_essay_score']?.toString() ?? '') ?? 100.0;

    final scoreStr = _totalScoreController.text.trim();
    final parsedScore = double.tryParse(scoreStr);
    if (parsedScore == null || parsedScore < 0 || parsedScore > maxEssayScore) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: NeoColors.danger,
          content: Text('Total nilai essay harus berupa angka antara 0 dan $maxEssayScore poin.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final comment = _commentController.text.trim();
      await _examRepo.finalizeStudentEssays(
        attemptId,
        totalEssayScore: parsedScore,
        teacherComment: comment.isNotEmpty ? comment : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: NeoColors.success,
          content: Text('Penilaian essay untuk ${student['student_name']} berhasil disimpan!'),
        ),
      );

      widget.onGraded();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: NeoColors.danger,
          content: Text('Gagal menyimpan nilai: ${e.toString().replaceAll('Exception: ', '')}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    final studentName = student['student_name'] ?? 'Mahasiswa';
    final studentNim = student['student_nim'] ?? '-';
    final essays = (student['essays'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final mcqScore = student['mcq_score'] ?? 0;
    final maxMcqScore = student['max_mcq_score'] ?? 0;
    final maxEssayScore = student['max_essay_score'] ?? 0;
    final aiSum = student['ai_essay_score_sum'] ?? 0;
    final isFinalized = student['all_finalized'] == true;

    return Scaffold(
      backgroundColor: NeoColors.bg,
      appBar: AppBar(
        backgroundColor: NeoColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: NeoColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'REVIEW: $studentName',
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: NeoColors.ink,
          ),
        ),
        shape: const Border(
          bottom: BorderSide(color: NeoColors.ink, width: 3),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Student Overview Header Card
            NeoCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: NeoColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'NIM: $studentNim • ${essays.length} Butir Soal Essay',
                            style: const TextStyle(
                              fontFamily: 'Space Mono',
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      NeoTag(
                        label: isFinalized ? 'FINAL' : 'PERLU REVIEW',
                        variant: isFinalized ? NeoTagVariant.success : NeoTagVariant.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: NeoColors.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: NeoColors.ink, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nilai PG: $mcqScore / $maxMcqScore pts',
                          style: const TextStyle(fontFamily: 'Space Mono', fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                        Text(
                          'Bobot Essay: Maks $maxEssayScore pts',
                          style: const TextStyle(fontFamily: 'Space Mono', fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section Title for Questions
            const Text(
              'DAFTAR JAWABAN ESSAY MAHASISWA:',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: NeoColors.ink,
              ),
            ),
            const SizedBox(height: 12),

            // Sequential Essay Answers
            ...essays.asMap().entries.map((entry) => _buildEssayQuestionCard(entry.key + 1, entry.value)),

            const SizedBox(height: 20),

            // Consolidated Final Grading Form at the bottom
            NeoCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.rate_review, color: NeoColors.ink, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'PENILAIAN AKHIR ESSAY SISWA',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: NeoColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Nilai seluruh soal essay diakumulasikan menjadi satu nilai akhir untuk mahasiswa ini.',
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // AI Suggestion Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: NeoColors.ink, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: NeoColors.tertiary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rekomendasi Total AI (Gemini):',
                                style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: NeoColors.ink,
                                ),
                              ),
                              Text(
                                '$aiSum / $maxEssayScore Poin',
                                style: const TextStyle(
                                  fontFamily: 'Space Mono',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: NeoColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: NeoColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: const BorderSide(color: NeoColors.ink, width: 1.5),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _totalScoreController.text = '$aiSum';
                            });
                          },
                          child: const Text(
                            'GUNAKAN SARAN AI',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              color: NeoColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Single Total Essay Score Input
                  NeoTextField(
                    label: 'TOTAL NILAI ESSAY (MAKSIMAL $maxEssayScore POIN)',
                    controller: _totalScoreController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),

                  // Optional Comment Input
                  NeoTextField(
                    label: 'CATATAN DOSEN UNTUK MAHASISWA (OPSIONAL)',
                    controller: _commentController,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 18),

                  NeoButton(
                    text: _isSubmitting ? 'MENYIMPAN PENILAIAN...' : 'SIMPAN & SELESAIKAN PENILAIAN SISWA',
                    icon: const Icon(Icons.check, size: 18, color: NeoColors.ink),
                    backgroundColor: NeoColors.primary,
                    onPressed: _isSubmitting ? null : _submitFinalStudentGrade,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildEssayQuestionCard(int index, Map<String, dynamic> ea) {
    final questionText = ea['question_text'] ?? '-';
    final studentAnswer = ea['student_answer'] ?? '(Tidak dijawab)';
    final maxScore = ea['max_score'] ?? 0;
    final aiScore = ea['ai_score'];

    Map<String, dynamic>? aiBreakdown;
    if (ea['ai_json'] is Map) {
      aiBreakdown = Map<String, dynamic>.from(ea['ai_json'] as Map);
    } else if (ea['ai_json'] is String && (ea['ai_json'] as String).isNotEmpty) {
      try {
        final parsed = jsonDecode(ea['ai_json'] as String);
        if (parsed is Map) aiBreakdown = Map<String, dynamic>.from(parsed);
      } catch (_) {}
    }

    final feedback = aiBreakdown?['feedback']?.toString();
    final rubricList = (aiBreakdown?['rubric_breakdown'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: NeoCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Question header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: NeoColors.primary,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: NeoColors.ink, width: 1.5),
                  ),
                  child: Text(
                    'Soal #$index',
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: NeoColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    questionText,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: NeoColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                NeoTag(
                  label: 'Bobot: $maxScore',
                  variant: NeoTagVariant.info,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Student Answer Box
            const Text(
              'Jawaban Mahasiswa:',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NeoColors.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NeoColors.ink, width: 1.5),
              ),
              child: Text(
                studentAnswer,
                style: const TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: 13,
                  height: 1.4,
                  color: NeoColors.ink,
                ),
              ),
            ),

            // AI Evaluation Context (Helpful for lecturer)
            if (aiScore != null || feedback != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9FB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: NeoColors.ink, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: NeoColors.tertiary, size: 14),
                        const SizedBox(width: 4),
                        const Text(
                          'Analisis Gemini AI:',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: NeoColors.ink,
                          ),
                        ),
                        const Spacer(),
                        if (aiScore != null)
                          Text(
                            'Estimasi AI: $aiScore / $maxScore pts',
                            style: const TextStyle(
                              fontFamily: 'Space Mono',
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: NeoColors.ink,
                            ),
                          ),
                      ],
                    ),
                    if (feedback != null && feedback.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '"$feedback"',
                        style: const TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontStyle: FontStyle.italic,
                          fontSize: 11.5,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                    if (rubricList.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ...rubricList.map((rb) {
                        final crit = rb['criterion'] ?? '';
                        final pts = rb['points'] ?? 0;
                        final mPts = rb['max_points'] ?? 0;
                        return Text(
                          '• $crit: $pts/$mPts pts',
                          style: const TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 10.5),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
