import 'package:flutter/material.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/widgets/neo_tag.dart';
import '../../data/models/question_model.dart';
import 'extract_questions_dialog.dart';

class AssignQuestionsDialog extends StatefulWidget {
  final String examId;
  final List<QuestionModel> availableQuestions;
  final Future<bool> Function(String examId, List<String> questionIds) onSubmit;

  const AssignQuestionsDialog({
    super.key,
    required this.examId,
    required this.availableQuestions,
    required this.onSubmit,
  });

  @override
  State<AssignQuestionsDialog> createState() => _AssignQuestionsDialogState();
}

class _AssignQuestionsDialogState extends State<AssignQuestionsDialog> {
  final Set<String> _selectedIds = {};
  late List<QuestionModel> _currentQuestions;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _currentQuestions = List.from(widget.availableQuestions);
  }


  void _toggleQuestion(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _handleAssign() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu soal')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final success = await widget.onSubmit(widget.examId, _selectedIds.toList());
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
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
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
                color: NeoColors.tertiary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                border: Border(bottom: BorderSide(color: NeoColors.ink, width: 3)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'PILIH SOAL DARI BANK SOAL',
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
                        shape: BoxShape.circle,
                        border: Border.all(color: NeoColors.ink, width: 2),
                      ),
                      child: const Icon(Icons.close, size: 16, color: NeoColors.ink),
                    ),
                  ),
                ],
              ),
            ),

            // Selection Counter & Upload Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: NeoColors.bg,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedIds.length} Soal Dipilih',
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: NeoColors.ink,
                        ),
                      ),
                      if (_selectedIds.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() => _selectedIds.clear()),
                          child: const Text('Reset Pilihan', style: TextStyle(color: NeoColors.danger)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final List<QuestionModel>? created = await showDialog<List<QuestionModel>>(
                        context: context,
                        builder: (_) => const ExtractQuestionsDialog(),
                      );
                      if (created != null && created.isNotEmpty) {
                        setState(() {
                          _currentQuestions.insertAll(0, created);
                          for (final q in created) {
                            _selectedIds.add(q.id);
                          }
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 14, color: NeoColors.ink),
                          SizedBox(width: 6),
                          Text(
                            'UNGGAH BERKAS SOAL AI (PDF/WORD)',
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
                ],
              ),
            ),
            const Divider(color: NeoColors.ink, thickness: 2, height: 2),

            // Questions list
            Expanded(
              child: _currentQuestions.isEmpty
                  ? const Center(
                      child: Text(
                        'Tidak ada soal di bank soal.',
                        style: TextStyle(fontFamily: 'Hanken Grotesk', color: NeoColors.ink),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _currentQuestions.length,
                      separatorBuilder: (_, i) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final q = _currentQuestions[index];
                        final isSelected = _selectedIds.contains(q.id);

                        return GestureDetector(
                          onTap: () => _toggleQuestion(q.id),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? NeoColors.primary.withValues(alpha: 0.25) : NeoColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? NeoColors.ink : NeoColors.muted,
                                width: isSelected ? 2.5 : 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  activeColor: NeoColors.primary,
                                  checkColor: NeoColors.ink,
                                  onChanged: (_) => _toggleQuestion(q.id),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          NeoTag(
                                            label: q.type.toUpperCase(),
                                            variant: q.type == 'mcq' ? NeoTagVariant.info : NeoTagVariant.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${q.maxScore.toInt()} Poin',
                                            style: const TextStyle(
                                              fontFamily: 'Space Mono',
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        q.body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Hanken Grotesk',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: NeoColors.ink,
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
            ),

            // Footer
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
                      text: _isSubmitting ? 'MENYIMPAN...' : 'TAMBAHKAN KE UJIAN',
                      variant: NeoButtonVariant.primary,
                      onPressed: _isSubmitting ? null : _handleAssign,
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
