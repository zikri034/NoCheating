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
  List<Map<String, dynamic>> _reviews = [];
  String _selectedStatus = 'ALL';

  final Map<String, TextEditingController> _scoreControllers = {};
  final Map<String, TextEditingController> _commentControllers = {};
  final Set<String> _finalizingIds = {};

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    for (final c in _scoreControllers.values) {
      c.dispose();
    }
    for (final c in _commentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final statusParam = _selectedStatus == 'ALL' ? null : _selectedStatus;
      final data = await _examRepo.fetchEssayReviews(
        status: statusParam,
        examId: widget.examId,
      );

      // Initialize controllers for each review item
      for (final r in data) {
        final gradeId = r['grade_id']?.toString() ?? '';
        final currentScore = r['teacher_score'] ?? r['ai_score'] ?? 0;
        final currentComment = r['teacher_comment']?.toString() ?? '';

        _scoreControllers[gradeId] = TextEditingController(text: '$currentScore');
        _commentControllers[gradeId] = TextEditingController(text: currentComment);
      }

      setState(() {
        _reviews = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _finalizeGrade(String gradeId, double maxScore) async {
    final scoreStr = _scoreControllers[gradeId]?.text.trim() ?? '0';
    final parsedScore = double.tryParse(scoreStr);
    if (parsedScore == null || parsedScore < 0 || parsedScore > maxScore) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: NeoColors.danger,
          content: Text('Skor harus berupa angka antara 0 dan $maxScore'),
        ),
      );
      return;
    }

    final comment = _commentControllers[gradeId]?.text.trim();

    setState(() {
      _finalizingIds.add(gradeId);
    });

    try {
      await _examRepo.finalizeEssayGrade(
        gradeId,
        teacherScore: parsedScore,
        teacherComment: comment?.isNotEmpty == true ? comment : null,
        finalize: true,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: NeoColors.success,
          content: Text('Nilai essay berhasil difinalisasi!'),
        ),
      );

      _loadReviews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: NeoColors.danger,
          content: Text('Gagal: ${e.toString().replaceAll('Exception: ', '')}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _finalizingIds.remove(gradeId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeoColors.bg,
      appBar: AppBar(
        backgroundColor: NeoColors.primary,
        elevation: 0,
        title: Text(
          widget.examTitle != null ? 'REVIEW: ${widget.examTitle}' : 'REVIEW ESSAY (GEMINI AI)',
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
                  _buildFilterChip('ALL', 'Semua'),
                  const SizedBox(width: 8),
                  _buildFilterChip('needs_review', 'Perlu Review'),
                  const SizedBox(width: 8),
                  _buildFilterChip('ai_graded', 'Dinilai AI'),
                  const SizedBox(width: 8),
                  _buildFilterChip('finalized', 'Final'),
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
                              NeoButton(text: 'COBA LAGI', onPressed: _loadReviews),
                            ],
                          ),
                        ),
                      )
                    : _reviews.isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada jawaban essay dalam antrean.',
                              style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: NeoColors.ink,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadReviews,
                            color: NeoColors.ink,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _reviews.length,
                              separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                return _buildReviewCard(_reviews[index]);
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
        _loadReviews();
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
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: NeoColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> r) {
    final gradeId = r['grade_id']?.toString() ?? '';
    final studentName = r['student_name'] ?? 'Mahasiswa';
    final studentNim = r['student_nim'] ?? '-';
    final courseName = r['course_name'] ?? '';
    final maxScore = (r['max_score'] as num?)?.toDouble() ?? 50.0;
    final aiScore = r['ai_score'] != null ? '${r['ai_score']}' : '-';
    final status = r['status']?.toString() ?? 'pending';
    final confidence = r['confidence']?.toString() ?? 'medium';
    final flags = (r['flags'] as List?)?.cast<String>() ?? [];
    final aiBreakdown = r['ai_json'] as Map<String, dynamic>?;

    final isFinalizing = _finalizingIds.contains(gradeId);

    NeoTagVariant statusVariant;
    String statusLabel;
    switch (status) {
      case 'finalized':
        statusVariant = NeoTagVariant.success;
        statusLabel = 'FINAL';
        break;
      case 'needs_review':
        statusVariant = NeoTagVariant.danger;
        statusLabel = 'PERLU REVIEW';
        break;
      case 'ai_graded':
        statusVariant = NeoTagVariant.info;
        statusLabel = 'DINILAI AI';
        break;
      case 'pending_manual':
        statusVariant = NeoTagVariant.warning;
        statusLabel = 'MANUAL';
        break;
      default:
        statusVariant = NeoTagVariant.warning;
        statusLabel = 'MENUNGGU';
    }

    return NeoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Student info & status tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: NeoColors.ink,
                      ),
                    ),
                    Text(
                      'NIM: $studentNim • $courseName',
                      style: const TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              NeoTag(label: statusLabel, variant: statusVariant),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: NeoColors.ink, thickness: 1.5),
          const SizedBox(height: 8),

          // Question Prompt & Rubric
          const Text(
            'PERTANYAAN SOAL:',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.5,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            r['question_text'] ?? '-',
            style: const TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: NeoColors.ink,
            ),
          ),
          const SizedBox(height: 10),

          // Student Answer Box
          const Text(
            'JAWABAN MAHASISWA:',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.5,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NeoColors.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NeoColors.ink, width: 2),
            ),
            child: Text(
              r['answer_text']?.toString().isNotEmpty == true
                  ? r['answer_text']!
                  : '(Tidak dijawab / kosong)',
              style: const TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontSize: 13,
                color: NeoColors.ink,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Gemini AI Evaluation Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF), // Subtle soft blue accent
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NeoColors.ink, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: NeoColors.tertiary, size: 18),
                        const SizedBox(width: 6),
                        const Text(
                          'EVALUASI GEMINI AI',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: NeoColors.ink,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Skor AI: $aiScore / $maxScore',
                      style: const TextStyle(
                        fontFamily: 'Space Mono',
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: NeoColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Confidence & Flags Badges
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    NeoTag(
                      label: 'Confidence: ${confidence.toUpperCase()}',
                      variant: confidence == 'high'
                          ? NeoTagVariant.success
                          : confidence == 'medium'
                              ? NeoTagVariant.info
                              : NeoTagVariant.warning,
                    ),
                    ...flags.map((flag) => NeoTag(
                          label: flag.replaceAll('_', ' ').toUpperCase(),
                          variant: NeoTagVariant.danger,
                        )),
                  ],
                ),

                if (aiBreakdown != null) ...[
                  const SizedBox(height: 10),
                  // Rubric Breakdown
                  if (aiBreakdown['rubric_breakdown'] is List) ...[
                    const Text(
                      'Rincian Rubrik:',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: NeoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...((aiBreakdown['rubric_breakdown'] as List).map((item) {
                      final crit = item['criterion'] ?? '';
                      final pts = item['points'] ?? 0;
                      final maxPts = item['max_points'] ?? 0;
                      final com = item['comment'] ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $crit: $pts/$maxPts pts — $com',
                          style: const TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 11.5),
                        ),
                      );
                    })),
                    const SizedBox(height: 6),
                  ],

                  // Feedback
                  if (aiBreakdown['feedback'] != null) ...[
                    Text(
                      'Umpan Balik AI: "${aiBreakdown['feedback']}"',
                      style: const TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Lecturer Overriding Form
          const Text(
            'FORMULIR KOREKSI DOSEN:',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.5,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: NeoTextField(
                  label: 'NILAI FINAL (MAKS $maxScore)',
                  controller: _scoreControllers[gradeId] ?? TextEditingController(),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: NeoTextField(
                  label: 'CATATAN DOSEN',
                  controller: _commentControllers[gradeId] ?? TextEditingController(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          NeoButton(
            text: isFinalizing ? 'MEMFINALISASI...' : 'FINALISASI NILAI',
            variant: NeoButtonVariant.primary,
            onPressed: isFinalizing ? null : () => _finalizeGrade(gradeId, maxScore),
          ),
        ],
      ),
    );
  }
}
