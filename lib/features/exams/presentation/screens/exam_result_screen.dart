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
    final status = attempt['status'] as String? ?? 'submitted';
    final hasEssay = attempt['has_essay'] == true;
    final answers = (result['answers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final essayAnswers = answers.where((a) => a['type'] == 'essay').toList();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: NeoColors.bg,
        appBar: AppBar(
          backgroundColor: NeoColors.primary,
          elevation: 0,
          automaticallyImplyLeading: false,
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: NeoColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: NeoColors.ink, width: 3),
                      ),
                      child: const Icon(Icons.check, size: 48, color: NeoColors.ink),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'UJIAN SELESAI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: NeoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasEssay
                          ? 'Jawaban Anda telah tersimpan aman di server. Pilihan ganda telah dinilai, dan essay dinilai secara otomatis oleh Gemini AI.'
                          : 'Seluruh jawaban telah dinilai secara otomatis oleh sistem.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Score Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NeoColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: NeoColors.ink, width: 2.5),
                      ),
                      child: Column(
                        children: [
                          Text(
                            status == 'graded' ? 'NILAI AKHIR' : 'NILAI SEMENTARA',
                            style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: NeoColors.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            score != null ? '$score' : '0',
                            style: const TextStyle(
                              fontFamily: 'Space Mono',
                              fontWeight: FontWeight.w800,
                              fontSize: 44,
                              color: NeoColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          NeoTag(
                            label: status == 'graded' ? 'SELESAI DINILAI' : 'MENUNGGU FINALISASI DOSEN',
                            variant: status == 'graded' ? NeoTagVariant.success : NeoTagVariant.warning,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Essay Evaluation Breakdown (PRD F07)
              if (essayAnswers.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'RINCIAN PENILAIAN ESSAY:',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: NeoColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                ...essayAnswers.map((ea) => _buildEssayResultCard(ea)),
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

  Widget _buildEssayResultCard(Map<String, dynamic> ea) {
    final questionText = ea['question_text'] ?? '-';
    final answerText = ea['answer_text'] ?? '(Tidak dijawab)';
    final maxScore = ea['max_score'] ?? 0;
    final isProvisional = ea['is_provisional'] == true;
    final aiScore = ea['essay_ai_score'];
    final finalScore = ea['essay_final_score'];
    final displayedScore = finalScore ?? aiScore ?? 0;

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
                  '$displayedScore / $maxScore',
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
