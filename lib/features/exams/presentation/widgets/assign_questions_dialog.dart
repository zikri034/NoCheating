import 'package:flutter/material.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/widgets/neo_chip.dart';
import '../../../../core/widgets/neo_tag.dart';
import '../../data/models/question_model.dart';
import 'extract_questions_dialog.dart';

class AssignQuestionsDialog extends StatefulWidget {
  final String examId;
  final String? examTitle;
  final String? courseId;
  final String? courseName;
  final String? courseCode;
  final List<QuestionModel> availableQuestions;
  final Future<bool> Function(String examId, List<String> questionIds) onSubmit;

  const AssignQuestionsDialog({
    super.key,
    required this.examId,
    this.examTitle,
    this.courseId,
    this.courseName,
    this.courseCode,
    required this.availableQuestions,
    required this.onSubmit,
  });

  @override
  State<AssignQuestionsDialog> createState() => _AssignQuestionsDialogState();
}

class _AssignQuestionsDialogState extends State<AssignQuestionsDialog> {
  final Set<String> _selectedIds = {};
  late List<QuestionModel> _currentQuestions;
  final TextEditingController _searchController = TextEditingController();

  String _filterMode = 'course'; // 'course' = Soal materi ini, 'all' = Semua materi
  String _selectedType = 'all'; // 'all', 'mcq', 'essay'
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _currentQuestions = List.from(widget.availableQuestions);

    // If no courseId or no questions match this course, default to 'all'
    final hasMatching = widget.courseId != null &&
        _currentQuestions.any((q) => q.courseId == widget.courseId);
    _filterMode = hasMatching ? 'course' : 'all';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  int get _matchingCourseCount {
    if (widget.courseId == null) return 0;
    return _currentQuestions.where((q) => q.courseId == widget.courseId).length;
  }

  List<QuestionModel> get _filteredQuestions {
    return _currentQuestions.where((q) {
      if (_filterMode == 'course' && widget.courseId != null) {
        if (q.courseId != widget.courseId) return false;
      }
      if (_selectedType == 'mcq' && q.type != 'mcq') return false;
      if (_selectedType == 'essay' && q.type != 'essay') return false;
      final qText = _searchController.text.trim().toLowerCase();
      if (qText.isNotEmpty) {
        final matchBody = q.body.toLowerCase().contains(qText);
        final matchCourse = (q.courseName?.toLowerCase().contains(qText) ?? false) ||
            (q.courseCode?.toLowerCase().contains(qText) ?? false);
        return matchBody || matchCourse;
      }
      return true;
    }).toList();
  }

  void _selectAllFiltered() {
    final filtered = _filteredQuestions;
    setState(() {
      for (final q in filtered) {
        _selectedIds.add(q.id);
      }
    });
  }

  Future<void> _handleAssign() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu butir soal untuk dimasukkan ke ujian')),
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
    final filtered = _filteredQuestions;
    final matchingCount = _matchingCourseCount;
    final hasCourseContext = widget.courseName != null || widget.courseCode != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
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
                  const Icon(Icons.playlist_add_check_rounded, color: NeoColors.ink, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'PILIH SOAL UNTUK UJIAN',
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

            // Target Exam & Materi Banner
            if (hasCourseContext || widget.examTitle != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: NeoColors.primary,
                  border: Border(bottom: BorderSide(color: NeoColors.ink, width: 2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school, size: 16, color: NeoColors.ink),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.examTitle != null)
                            Text(
                              widget.examTitle!,
                              style: const TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: NeoColors.ink,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text(
                            'Materi: ${widget.courseCode != null ? "[${widget.courseCode}] " : ""}${widget.courseName ?? "Umum"}',
                            style: const TextStyle(
                              fontFamily: 'Hanken Grotesk',
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: NeoColors.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Filter Tabs & Search
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: NeoColors.bg,
              child: Column(
                children: [
                  // Filter Mode (Materi Ini vs Semua Materi)
                  if (widget.courseId != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _filterMode = 'course'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: _filterMode == 'course' ? NeoColors.primary : NeoColors.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: NeoColors.ink, width: 2),
                                boxShadow: _filterMode == 'course'
                                    ? const [BoxShadow(color: NeoColors.ink, offset: Offset(2, 2))]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'SOAL MATERI INI ($matchingCount)',
                                style: const TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  color: NeoColors.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _filterMode = 'all'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: _filterMode == 'all' ? NeoColors.tertiary : NeoColors.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: NeoColors.ink, width: 2),
                                boxShadow: _filterMode == 'all'
                                    ? const [BoxShadow(color: NeoColors.ink, offset: Offset(2, 2))]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'SEMUA MATERI (${_currentQuestions.length})',
                                style: const TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  color: NeoColors.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Search Field
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: NeoColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: NeoColors.ink, width: 1.5),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(
                              fontFamily: 'Hanken Grotesk',
                              fontSize: 12,
                              color: NeoColors.ink,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Cari pertanyaan butir soal...',
                              hintStyle: TextStyle(fontSize: 12, color: NeoColors.muted),
                              prefixIcon: Icon(Icons.search, size: 16, color: NeoColors.ink),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Type Filters
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            NeoChip(
                              label: 'SEMUA',
                              isSelected: _selectedType == 'all',
                              selectedColor: NeoColors.primary,
                              onTap: () => setState(() => _selectedType = 'all'),
                            ),
                            const SizedBox(width: 4),
                            NeoChip(
                              label: 'PG',
                              isSelected: _selectedType == 'mcq',
                              selectedColor: NeoColors.info,
                              onTap: () => setState(() => _selectedType = 'mcq'),
                            ),
                            const SizedBox(width: 4),
                            NeoChip(
                              label: 'ESSAY',
                              isSelected: _selectedType == 'essay',
                              selectedColor: NeoColors.secondary,
                              onTap: () => setState(() => _selectedType = 'essay'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Actions & Counter
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selectedIds.length} Dipilih  •  ${filtered.length} Ditampilkan',
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: NeoColors.ink,
                          ),
                        ),
                      ),
                      if (filtered.isNotEmpty)
                        GestureDetector(
                          onTap: _selectAllFiltered,
                          child: const Text(
                            'PILIH SEMUA',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: NeoColors.ink,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      if (_selectedIds.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _selectedIds.clear()),
                          child: const Text(
                            'RESET',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: NeoColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // AI Extract Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: NeoColors.bg,
              child: GestureDetector(
                onTap: () async {
                  final List<QuestionModel>? created = await showDialog<List<QuestionModel>>(
                    context: context,
                    builder: (_) => ExtractQuestionsDialog(initialCourseId: widget.courseId),
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
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: BoxDecoration(
                    color: NeoColors.tertiary,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: NeoColors.ink, width: 1.5),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: NeoColors.ink),
                      SizedBox(width: 6),
                      Text(
                        'UNGGAH BERKAS SOAL AI UNTUK MATERI INI',
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

            const Divider(color: NeoColors.ink, thickness: 2, height: 2),

            // Questions list
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book, size: 40, color: NeoColors.muted),
                            const SizedBox(height: 8),
                            Text(
                              _filterMode == 'course' && widget.courseName != null
                                  ? 'Belum ada soal untuk materi "${widget.courseName}".'
                                  : 'Tidak ada soal yang cocok dengan filter.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Hanken Grotesk',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: NeoColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Gunakan tab "SEMUA MATERI" untuk memilih dari mata kuliah lain, atau unggah naskah soal baru dengan AI.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Hanken Grotesk',
                                fontSize: 11,
                                color: NeoColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, i) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final q = filtered[index];
                        final isSelected = _selectedIds.contains(q.id);
                        final isCourseMatch = widget.courseId == null || q.courseId == widget.courseId;

                        return GestureDetector(
                          onTap: () => _toggleQuestion(q.id),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected ? NeoColors.primary.withValues(alpha: 0.25) : NeoColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? NeoColors.ink : NeoColors.muted,
                                width: isSelected ? 2.5 : 1.5,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Checkbox(
                                      value: isSelected,
                                      activeColor: NeoColors.primary,
                                      checkColor: NeoColors.ink,
                                      onChanged: (_) => _toggleQuestion(q.id),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Tags Row
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          NeoTag(
                                            label: q.type.toUpperCase(),
                                            variant: q.type == 'mcq' ? NeoTagVariant.info : NeoTagVariant.primary,
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: NeoColors.bg,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: NeoColors.ink, width: 1),
                                            ),
                                            child: Text(
                                              '${q.maxScore.toInt()} Poin',
                                              style: const TextStyle(
                                                fontFamily: 'Space Mono',
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          // Course Tag
                                          if (q.courseName != null || q.courseCode != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isCourseMatch
                                                    ? NeoColors.tertiary.withValues(alpha: 0.4)
                                                    : NeoColors.warning.withValues(alpha: 0.3),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: NeoColors.ink, width: 1),
                                              ),
                                              child: Text(
                                                '${q.courseCode != null ? "[${q.courseCode}] " : ""}${q.courseName ?? ""}',
                                                style: const TextStyle(
                                                  fontFamily: 'Space Grotesk',
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: NeoColors.ink,
                                                ),
                                              ),
                                            ),
                                          if (!isCourseMatch && widget.courseId != null)
                                            const NeoTag(
                                              label: 'BEDA MATERI',
                                              customColor: NeoColors.warning,
                                              textColor: NeoColors.ink,
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
                        );
                      },
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: NeoColors.bg,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
                border: Border(top: BorderSide(color: NeoColors.ink, width: 3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: NeoButton(
                      text: _isSubmitting
                          ? 'MENYIMPAN...'
                          : 'TAMBAHKAN ${_selectedIds.length} SOAL KE UJIAN',
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
