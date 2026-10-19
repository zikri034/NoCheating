import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_card.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/widgets/neo_tag.dart';
import '../../../../core/widgets/neo_text_field.dart';
import '../providers/exam_runner_provider.dart';
import 'exam_result_screen.dart';

class ExamRunnerScreen extends StatefulWidget {
  final String examId;

  const ExamRunnerScreen({super.key, required this.examId});

  @override
  State<ExamRunnerScreen> createState() => _ExamRunnerScreenState();
}

class _ExamRunnerScreenState extends State<ExamRunnerScreen> with WidgetsBindingObserver {
  final TextEditingController _essayController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final runner = context.read<ExamRunnerProvider>();
      runner.initExamSession(widget.examId);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _essayController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) {
      context.read<ExamRunnerProvider>().onAppLifecycleChanged(state);
    }
  }

  void _syncEssayController(ExamRunnerProvider runner) {
    final q = runner.currentQuestion;
    if (q != null && q.type == 'essay') {
      final existingText = runner.answers[q.id]?['answer_text'] as String? ?? '';
      if (_essayController.text != existingText) {
        _essayController.text = existingText;
      }
    }
  }

  void _showQuestionsGrid(BuildContext context) {
    final runner = context.read<ExamRunnerProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: NeoColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: NeoColors.ink, width: 3),
            boxShadow: const [
              BoxShadow(
                color: NeoColors.ink,
                offset: Offset(0, -4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              // Modal Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: NeoColors.primary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
                  border: Border(bottom: BorderSide(color: NeoColors.ink, width: 3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'NAVIGASI NOMOR SOAL',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: NeoColors.ink,
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

              // Legend
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildLegendItem(NeoColors.surface, 'Belum'),
                    _buildLegendItem(NeoColors.success, 'Dijawab'),
                    _buildLegendItem(NeoColors.primary, 'Ragu-ragu'),
                  ],
                ),
              ),
              const Divider(color: NeoColors.ink, thickness: 2, height: 2),

              // Grid Numbers
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: runner.questions.length,
                  itemBuilder: (context, index) {
                    final q = runner.questions[index];
                    final isCurrent = index == runner.currentIndex;
                    final isAnswered = runner.isQuestionAnswered(q.id);
                    final isDoubtful = runner.isQuestionDoubtful(q.id);

                    Color bg = NeoColors.surface;
                    if (isDoubtful) {
                      bg = NeoColors.primary;
                    } else if (isAnswered) {
                      bg = NeoColors.success;
                    }

                    return GestureDetector(
                      onTap: () {
                        runner.selectQuestion(index);
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCurrent ? NeoColors.danger : NeoColors.ink,
                            width: isCurrent ? 3.5 : 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: NeoColors.ink,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontFamily: 'Space Mono',
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: isCurrent ? NeoColors.danger : NeoColors.ink,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: NeoColors.ink, width: 1.5),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: NeoColors.ink,
          ),
        ),
      ],
    );
  }

  void _showSubmitConfirmationDialog(BuildContext context) {
    final runner = context.read<ExamRunnerProvider>();
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
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
                const Text(
                  'KUMPULKAN UJIAN?',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: NeoColors.ink,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: NeoColors.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NeoColors.ink, width: 2),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('Total Soal:', '${runner.questions.length}'),
                      const Divider(color: NeoColors.ink, thickness: 1),
                      _buildSummaryRow('Soal Terjawab:', '${runner.answeredCount}', color: NeoColors.success),
                      const Divider(color: NeoColors.ink, thickness: 1),
                      _buildSummaryRow('Belum Dijawab:', '${runner.unansweredCount}',
                          color: runner.unansweredCount > 0 ? NeoColors.danger : NeoColors.ink),
                      const Divider(color: NeoColors.ink, thickness: 1),
                      _buildSummaryRow('Ragu-ragu:', '${runner.doubtfulQuestions.length}', color: NeoColors.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (runner.unansweredCount > 0)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NeoColors.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: NeoColors.danger, width: 1.5),
                    ),
                    child: Text(
                      'Peringatan: Ada ${runner.unansweredCount} soal yang belum Anda jawab!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: NeoColors.danger,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: NeoButton(
                        text: 'KEMBALI',
                        variant: NeoButtonVariant.secondary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NeoButton(
                        text: 'KUMPULKAN',
                        variant: NeoButtonVariant.primary,
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await runner.submitExam();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontFamily: 'Hanken Grotesk', fontWeight: FontWeight.w600, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Space Mono',
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: color ?? NeoColors.ink,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final runner = context.watch<ExamRunnerProvider>();

    // Redirect to Result Screen upon submission
    if (runner.isSubmitted && runner.submissionResult != null) {
      return ExamResultScreen(
        result: runner.submissionResult!,
        onBackToExams: () => Navigator.of(context).pop(),
      );
    }

    if (runner.isLoading) {
      return Scaffold(
        backgroundColor: NeoColors.bg,
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: NeoColors.ink),
              SizedBox(height: 16),
              Text(
                'MEMPERSIAPKAN UJIAN...',
                style: TextStyle(fontFamily: 'Space Grotesk', fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
    }

    if (runner.errorMessage != null && runner.attempt == null) {
      return Scaffold(
        backgroundColor: NeoColors.bg,
        appBar: AppBar(
          backgroundColor: NeoColors.primary,
          title: const Text('SAFEEXAM', style: TextStyle(fontFamily: 'Space Grotesk', fontWeight: FontWeight.w800)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: NeoCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: NeoColors.danger),
                  const SizedBox(height: 12),
                  Text(
                    runner.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  NeoButton(
                    text: 'KEMBALI',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    _syncEssayController(runner);
    final question = runner.currentQuestion;

    // PopScope prevents accidental back exit during exam (PRD Section 5)
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: NeoColors.danger,
              content: Text('Keluar dari ujian dilarang. Harap kumpulkan ujian untuk selesai.'),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: NeoColors.bg,
        appBar: AppBar(
          backgroundColor: runner.isTimeCritical ? NeoColors.danger : NeoColors.primary,
          elevation: 0,
          automaticallyImplyLeading: false,
          shape: const Border(
            bottom: BorderSide(color: NeoColors.ink, width: 3),
          ),
          title: Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 20,
                color: runner.isTimeCritical ? Colors.white : NeoColors.ink,
              ),
              const SizedBox(width: 6),
              Text(
                runner.formattedRemainingTime,
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: runner.isTimeCritical ? Colors.white : NeoColors.ink,
                ),
              ),
              const Spacer(),
              // Question Grid Icon
              GestureDetector(
                onTap: () => _showQuestionsGrid(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: NeoColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: NeoColors.ink, width: 2),
                    boxShadow: const [
                      BoxShadow(color: NeoColors.ink, offset: Offset(2, 2), blurRadius: 0),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.grid_view_rounded, size: 16, color: NeoColors.ink),
                      const SizedBox(width: 4),
                      Text(
                        '${runner.currentIndex + 1}/${runner.questions.length}',
                        style: const TextStyle(
                          fontFamily: 'Space Mono',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: NeoColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => _showSubmitConfirmationDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: NeoColors.secondary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NeoColors.ink, width: 2),
                    boxShadow: const [
                      BoxShadow(color: NeoColors.ink, offset: Offset(2, 2), blurRadius: 0),
                    ],
                  ),
                  child: const Text(
                    'KUMPULKAN',
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
        body: question == null
            ? const Center(child: Text('Tidak ada soal'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Integrity Violation Alert Banner (PRD F05)
                    if (runner.latestViolationAlert != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: NeoColors.danger,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: NeoColors.ink, width: 3),
                          boxShadow: const [
                            BoxShadow(color: NeoColors.ink, offset: Offset(3, 3), blurRadius: 0),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    runner.latestViolationAlert!,
                                    style: const TextStyle(
                                      fontFamily: 'Space Grotesk',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Pelanggaran Kritis: ${runner.criticalCount}/${runner.maxCritical} (Batas ${runner.maxCritical}x)',
                                    style: const TextStyle(
                                      fontFamily: 'Space Mono',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => runner.clearViolationAlert(),
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Question Header Card
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        NeoTag(
                          label: 'SOAL ${runner.currentIndex + 1} DARI ${runner.questions.length}',
                          variant: NeoTagVariant.primary,
                        ),
                        NeoTag(
                          label: question.type.toUpperCase(),
                          variant: question.type == 'mcq' ? NeoTagVariant.info : NeoTagVariant.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Question Body Card
                    NeoCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            question.body,
                            style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: NeoColors.ink,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${question.maxScore.toInt()} Poin',
                                style: const TextStyle(
                                  fontFamily: 'Space Mono',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              Row(
                                children: [
                                  Checkbox(
                                    value: runner.isQuestionDoubtful(question.id),
                                    activeColor: NeoColors.primary,
                                    checkColor: NeoColors.ink,
                                    onChanged: (_) => runner.toggleDoubt(question.id),
                                  ),
                                  const Text(
                                    'Ragu-ragu',
                                    style: TextStyle(
                                      fontFamily: 'Hanken Grotesk',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: NeoColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Answer Component: MCQ vs Essay
                    if (question.type == 'mcq' && question.options != null) ...[
                      const Text(
                        'PILIH JAWABAN:',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: NeoColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: question.options!.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 10),
                        itemBuilder: (context, optIdx) {
                          final optText = question.options![optIdx];
                          final currentSelected = runner.answers[question.id]?['selected_option'];
                          final isSelected = currentSelected == optText;
                          final letter = String.fromCharCode(65 + optIdx); // A, B, C, D

                          return GestureDetector(
                            onTap: () => runner.selectOption(question.id, optText),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? NeoColors.info : NeoColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: NeoColors.ink,
                                  width: isSelected ? 3 : 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: NeoColors.ink,
                                    offset: isSelected ? const Offset(1, 1) : const Offset(4, 4),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              transform: isSelected ? Matrix4.translationValues(3, 3, 0) : Matrix4.identity(),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isSelected ? NeoColors.primary : NeoColors.bg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: NeoColors.ink, width: 2),
                                    ),
                                    child: Center(
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
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      optText,
                                      style: TextStyle(
                                        fontFamily: 'Hanken Grotesk',
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        fontSize: 14,
                                        color: NeoColors.ink,
                                      ),
                                    ),
                                  ),
                                  if (isSelected) const Icon(Icons.check_circle, color: NeoColors.ink, size: 20),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      // Essay Input Field
                      const Text(
                        'JAWABAN ESSAY (MAKS 3000 KARAKTER):',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: NeoColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      NeoTextField(
                        controller: _essayController,
                        hintText: 'Ketikkan jawaban essay Anda secara lengkap dan runtut di sini...',
                        maxLines: 7,
                        onChanged: (val) {
                          runner.setAnswerText(question.id, val);
                        },
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_essayController.text.length} / 3000 karakter',
                          style: const TextStyle(
                            fontFamily: 'Space Mono',
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Autosave status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: NeoColors.bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: NeoColors.ink, width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            runner.answers[question.id]?['is_synced'] == true
                                ? Icons.cloud_done_outlined
                                : Icons.lock_clock_outlined,
                            size: 14,
                            color: NeoColors.ink,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            runner.answers[question.id]?['is_synced'] == true
                                ? 'Tersinkron ke server'
                                : 'Tersimpan lokal di perangkat (terenkripsi AES-GCM)',
                            style: const TextStyle(
                              fontFamily: 'Hanken Grotesk',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: NeoColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: NeoColors.surface,
            border: Border(top: BorderSide(color: NeoColors.ink, width: 3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: NeoButton(
                  text: 'SEBELUMNYA',
                  variant: NeoButtonVariant.secondary,
                  onPressed: runner.currentIndex > 0 ? () => runner.prevQuestion() : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeoButton(
                  text: runner.currentIndex < runner.questions.length - 1 ? 'SELANJUTNYA' : 'SELESAI',
                  variant: NeoButtonVariant.primary,
                  onPressed: () {
                    if (runner.currentIndex < runner.questions.length - 1) {
                      runner.nextQuestion();
                    } else {
                      _showSubmitConfirmationDialog(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
