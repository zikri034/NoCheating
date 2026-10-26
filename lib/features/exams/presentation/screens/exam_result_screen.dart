import 'package:flutter/material.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_card.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/widgets/neo_tag.dart';
import '../widgets/blockchain_receipt_dialog.dart';

class ExamResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  final VoidCallback onBackToExams;

  const ExamResultScreen({
    super.key,
    required this.result,
    required this.onBackToExams,
  });

  @override
  Widget build(BuildContext context) {
    final attempt = result['attempt'] as Map<String, dynamic>? ?? {};
    final score = attempt['total_score'];
    final mcqScore = attempt['mcq_score'];
    final maxMcqScore = attempt['max_mcq_score'];
    final essayScore = attempt['essay_score'];
    final maxEssayScore = attempt['max_essay_score'];
    final status = attempt['status'] as String? ?? 'submitted';
    final hasEssay = attempt['has_essay'] == true;
    final isFinalized = status == 'graded' || attempt['is_finalized'] == true;
    final answers = (result['answers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final mcqAnswers = answers.where((a) => a['type'] == 'mcq').toList();
    final essayAnswers = answers.where((a) => a['type'] == 'essay').toList();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBackToExams();
      },
      child: Scaffold(
        backgroundColor: NeoColors.bg,
        appBar: AppBar(
          backgroundColor: NeoColors.primary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: NeoColors.ink),
            onPressed: onBackToExams,
          ),
          title: const Text(
            'HASIL UJIAN',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: NeoColors.ink,
            ),
          ),
          shape: const Border(
            bottom: BorderSide(color: NeoColors.ink, width: 3),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NeoCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NeoColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: NeoColors.ink, width: 3),
                      ),
                      child: const Icon(Icons.check, size: 40, color: NeoColors.ink),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'UJIAN TELAH DIKUMPULKAN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: NeoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasEssay
                          ? 'Nilai Pilihan Ganda (PG) sudah langsung dinilai oleh sistem. Nilai essay akan digabungkan setelah direview dosen.'
                          : 'Seluruh jawaban telah dinilai secara otomatis oleh sistem.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 1. NILAI PILIHAN GANDA (LANGSUNG)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: NeoColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: NeoColors.ink, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.check_circle_outline, size: 16, color: NeoColors.ink),
                                  SizedBox(width: 6),
                                  Text(
                                    'NILAI PILIHAN GANDA (PG)',
                                    style: TextStyle(
                                      fontFamily: 'Space Grotesk',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: NeoColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                              const NeoTag(
                                label: 'LANGSUNG DINILAI',
                                variant: NeoTagVariant.success,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${mcqScore ?? score ?? 0}',
                                style: const TextStyle(
                                  fontFamily: 'Space Mono',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 32,
                                  color: NeoColors.ink,
                                ),
                              ),
                              if (maxMcqScore != null)
                                Text(
                                  ' / $maxMcqScore poin',
                                  style: const TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Nilai pilihan ganda langsung tersedia tanpa menunggu finalisasi dosen.',
                            style: TextStyle(
                              fontFamily: 'Hanken Grotesk',
                              fontSize: 11,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. NILAI ESSAY (JIKA ADA)
                    if (hasEssay) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isFinalized ? NeoColors.surface : const Color(0xFFFFF9E6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: NeoColors.ink, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.edit_note, size: 16, color: NeoColors.ink),
                                    SizedBox(width: 6),
                                    Text(
                                      'NILAI ESSAY',
                                      style: TextStyle(
                                        fontFamily: 'Space Grotesk',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: NeoColors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                                NeoTag(
                                  label: isFinalized ? 'SELESAI DIREVIEW' : 'MENUNGGU REVIEW DOSEN',
                                  variant: isFinalized ? NeoTagVariant.success : NeoTagVariant.warning,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (isFinalized)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${essayScore ?? 0}',
                                    style: const TextStyle(
                                      fontFamily: 'Space Mono',
                                      fontWeight: FontWeight.w900,
                                      fontSize: 32,
                                      color: NeoColors.ink,
                                    ),
                                  ),
                                  if (maxEssayScore != null)
                                    Text(
                                      ' / $maxEssayScore poin',
                                      style: const TextStyle(
                                        fontFamily: 'Space Grotesk',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                ],
                              )
                            else
                              const Text(
                                'Dalam Proses Review',
                                style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: Color(0xFFB78103),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              isFinalized
                                  ? 'Dosen telah selesai mereview seluruh jawaban essay Anda.'
                                  : 'Jawaban essay sedang dalam antrean review dosen. Nilai akhir akan diperbarui setelah review.',
                              style: const TextStyle(
                                fontFamily: 'Hanken Grotesk',
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // 3. TOTAL NILAI
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: NeoColors.primary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: NeoColors.ink, width: 2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isFinalized ? 'TOTAL NILAI AKHIR' : 'TOTAL SEMENTARA (PG)',
                                style: const TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: NeoColors.ink,
                                ),
                              ),
                              Text(
                                isFinalized ? 'PG + Essay' : 'Hanya Pilihan Ganda',
                                style: const TextStyle(
                                  fontFamily: 'Hanken Grotesk',
                                  fontSize: 10,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            score != null ? '$score' : '0',
                            style: const TextStyle(
                              fontFamily: 'Space Mono',
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                              color: NeoColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Rincian Soal Pilihan Ganda
              if (mcqAnswers.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'RINCIAN PILIHAN GANDA (${mcqAnswers.where((a) => a['is_correct'] == true).length}/${mcqAnswers.length} Benar):',
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: NeoColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                ...mcqAnswers.asMap().entries.map((entry) => _buildMcqResultCard(entry.key + 1, entry.value)),
              ],

              // Essay Evaluation Breakdown
              if (essayAnswers.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'RINCIAN SOAL ESSAY:',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: NeoColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                ...essayAnswers.asMap().entries.map((entry) => _buildEssayResultCard(entry.key + 1, entry.value, isFinalized)),
              ],

              const SizedBox(height: 24),
              NeoButton(
                text: 'BUKTI INTEGRITAS BLOCKCHAIN (T13)',
                variant: NeoButtonVariant.secondary,
                onPressed: () {
                  final attemptId = attempt['id']?.toString() ?? '';
                  final examTitle = result['exam']?['title']?.toString() ?? 'Ujian SafeExam';
                  BlockchainReceiptDialog.show(context, attemptId: attemptId, examTitle: examTitle);
                },
              ),
              const SizedBox(height: 12),
              NeoButton(
                text: 'KEMBALI KE DAFTAR UJIAN',
                variant: NeoButtonVariant.primary,
                onPressed: onBackToExams,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMcqResultCard(int index, Map<String, dynamic> ma) {
    final questionText = ma['question_text'] ?? '-';
    final selectedOption = ma['selected_option'] ?? '(Tidak dijawab)';
    final isCorrect = ma['is_correct'] == true;
    final maxScore = ma['max_score'] ?? 0;
    final awarded = ma['awarded_score'] ?? (isCorrect ? maxScore : 0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeoCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: NeoColors.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: NeoColors.ink, width: 1.5),
                  ),
                  child: Text(
                    'No. $index',
                    style: const TextStyle(
                      fontFamily: 'Space Mono',
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
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
                      fontSize: 13,
                      color: NeoColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                NeoTag(
                  label: isCorrect ? 'BENAR (+$awarded)' : 'SALAH (0)',
                  variant: isCorrect ? NeoTagVariant.success : NeoTagVariant.danger,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isCorrect ? const Color(0xFFE8F8EE) : const Color(0xFFFDECEB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: NeoColors.ink, width: 1.2),
              ),
              child: Text(
                'Jawaban Anda: $selectedOption',
                style: const TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: NeoColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEssayResultCard(int index, Map<String, dynamic> ea, bool isFinalized) {
    final questionText = ea['question_text'] ?? '-';
    final answerText = ea['answer_text'] ?? '(Tidak dijawab)';
    final maxScore = ea['max_score'] ?? 0;
    final isProvisional = ea['is_provisional'] == true;
    final aiScore = ea['essay_ai_score'];
    final finalScore = ea['essay_final_score'];
    final displayedScore = finalScore ?? aiScore;

    final aiBreakdown = ea['ai_breakdown'] as Map<String, dynamic>?;
    final feedback = aiBreakdown?['feedback']?.toString();
    final teacherComment = ea['teacher_comment']?.toString();
    final rubricList = (aiBreakdown?['rubric_breakdown'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: NeoCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    questionText,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: NeoColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                NeoTag(
                  label: isProvisional ? 'NILAI SEMENTARA (AI)' : 'NILAI FINAL',
                  variant: isProvisional ? NeoTagVariant.warning : NeoTagVariant.success,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(color: NeoColors.ink, thickness: 1.5),
            const SizedBox(height: 8),

            // Answer preview
            const Text(
              'Jawaban Anda:',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NeoColors.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NeoColors.ink, width: 1.5),
              ),
              child: Text(
                answerText,
                style: const TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),

            // Score Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Skor Diperoleh:',
                  style: TextStyle(fontFamily: 'Hanken Grotesk', fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  displayedScore != null ? '$displayedScore / $maxScore' : 'Menunggu Review',
                  style: const TextStyle(
                    fontFamily: 'Space Mono',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: NeoColors.ink,
                  ),
                ),
              ],
            ),

            // AI Rubric breakdown
            if (rubricList.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Rincian Rubrik Penilaian:',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: NeoColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              ...rubricList.map((rb) {
                final c = rb['criterion'] ?? '';
                final pts = rb['points'] ?? 0;
                final maxPts = rb['max_points'] ?? 0;
                final com = rb['comment'] ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '• $c: $pts/$maxPts pts ($com)',
                    style: const TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 11),
                  ),
                );
              }),
            ],

            // AI Feedback
            if (feedback != null && feedback.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: NeoColors.ink, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: NeoColors.tertiary, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Umpan Balik AI (Gemini):',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: NeoColors.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '"$feedback"',
                      style: const TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Lecturer comment
            if (teacherComment != null && teacherComment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: NeoColors.ink, width: 1.5),
                ),
                child: Text(
                  'Catatan Dosen: "$teacherComment"',
                  style: const TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: NeoColors.ink,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
