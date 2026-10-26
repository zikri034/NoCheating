import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_tag.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../data/models/exam_model.dart';
import '../../data/models/question_model.dart';

class ExamDetailDialog extends StatelessWidget {
  final ExamModel exam;
  final List<QuestionModel> questions;
  final int enrollmentCount;
  final bool isLecturer;
  final VoidCallback onEnroll;
  final VoidCallback? onAddQuestions;
  final VoidCallback? onStartExam;
  final VoidCallback? onMonitor;
  final VoidCallback? onViewLocation;
  final VoidCallback? onReviewEssay;
  final VoidCallback? onDeleteExam;
  final VoidCallback? onViewResult;

  const ExamDetailDialog({
    super.key,
    required this.exam,
    required this.questions,
    required this.enrollmentCount,
    required this.isLecturer,
    required this.onEnroll,
    this.onAddQuestions,
    this.onStartExam,
    this.onMonitor,
    this.onViewLocation,
    this.onReviewEssay,
    this.onDeleteExam,
    this.onViewResult,
  });

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd MMM yyyy, HH:mm').format(dt.toLocal());
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
            // Header bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: NeoColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                border: Border(bottom: BorderSide(color: NeoColors.ink, width: 3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'DETAIL UJIAN',
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: NeoColors.ink,
                      ),
                    ),
                  ),
                  if (isLecturer && onDeleteExam != null) ...[
                    GestureDetector(
                      onTap: onDeleteExam,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: NeoColors.danger.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: NeoColors.ink, width: 2),
                        ),
                        child: const Icon(Icons.delete_outline, size: 16, color: NeoColors.danger),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(5),
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

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status & Course
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (exam.courseCode != null)
                          Flexible(
                            child: NeoTag(
                              label: exam.courseCode!,
                              variant: NeoTagVariant.primary,
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        const SizedBox(width: 8),
                        NeoTag(
                          label: exam.computedStatus,
                          variant: exam.statusVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      exam.title,
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: NeoColors.ink,
                      ),
                    ),
                    if (exam.courseName != null && exam.courseName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${exam.courseCode != null ? "${exam.courseCode!} • " : ""}${exam.courseName!}',
                        style: const TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                    if (exam.description != null && exam.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        exam.description!,
                        style: const TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Information Grid
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: NeoColors.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: NeoColors.ink, width: 2),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            Icons.calendar_today,
                            'Mulai',
                            '${_formatDateTime(exam.startAt)} WIB',
                          ),
                          const Divider(color: NeoColors.ink, thickness: 1),
                          _buildInfoRow(
                            Icons.event_available,
                            'Selesai',
                            '${_formatDateTime(exam.endAt)} WIB',
                          ),
                          const Divider(color: NeoColors.ink, thickness: 1),
                          _buildInfoRow(
                            Icons.timer_outlined,
                            'Durasi Pengerjaan',
                            '${exam.durationMin} Menit',
                          ),
                          if (exam.lecturerName != null) ...[
                            const Divider(color: NeoColors.ink, thickness: 1),
                            _buildInfoRow(
                              Icons.person_outline,
                              'Dosen Pengampu',
                              exam.lecturerName!,
                            ),
                          ],
                          const Divider(color: NeoColors.ink, thickness: 1),
                          _buildInfoRow(
                            Icons.people_outline,
                            'Peserta Terdaftar',
                            '$enrollmentCount Mahasiswa',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Requirements Box
                    const Text(
                      'KETENTUAN UJIAN',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: NeoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        NeoTag(
                          label: exam.requireBiometric ? 'BIOMETRIK WAJIB (FACE/FINGERPRINT)' : 'BIOMETRIK OPSIONAL',
                          icon: Icons.fingerprint,
                          variant: exam.requireBiometric ? NeoTagVariant.warning : NeoTagVariant.muted,
                        ),
                        NeoTag(
                          label: exam.requireGeofence ? 'LOKASI/GEOFENCE WAJIB' : 'LOKASI BEBAS',
                          icon: Icons.location_on,
                          variant: exam.requireGeofence ? NeoTagVariant.info : NeoTagVariant.muted,
                        ),
                        if (exam.feeIdr != null && exam.feeIdr! > 0)
                          NeoTag(
                            label: 'BIAYA: Rp ${NumberFormat('#,###').format(exam.feeIdr)}',
                            icon: Icons.monetization_on,
                            variant: NeoTagVariant.primary,
                          ),
                      ],
                    ),
                    if (!isLecturer && exam.hasSubmitted) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: NeoColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: NeoColors.ink, width: 2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: NeoColors.success, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'UJIAN TELAH DIKERJAKAN',
                                    style: TextStyle(
                                      fontFamily: 'Space Grotesk',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: NeoColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    exam.myAttemptScore != null
                                        ? 'Nilai Anda: ${exam.myAttemptScore!.toStringAsFixed(1)} (${exam.myAttemptStatus == 'graded' ? 'FINAL' : 'SEMENTARA'})'
                                        : 'Status: Menunggu finalisasi nilai dosen',
                                    style: const TextStyle(
                                      fontFamily: 'Hanken Grotesk',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Questions Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'DAFTAR SOAL (${questions.length})',
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: NeoColors.ink,
                          ),
                        ),
                        if (isLecturer && onAddQuestions != null)
                          GestureDetector(
                            onTap: onAddQuestions,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: NeoColors.primary,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: NeoColors.ink, width: 2),
                              ),
                              child: const Text(
                                '+ PILIH SOAL',
                                style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  color: NeoColors.ink,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (questions.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: NeoColors.tertiary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: NeoColors.ink, width: 2),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Belum ada butir soal pada ujian ini.',
                              style: TextStyle(
                                fontFamily: 'Hanken Grotesk',
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: NeoColors.ink,
                              ),
                            ),
                            if (isLecturer && onAddQuestions != null) ...[
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: onAddQuestions,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: NeoColors.primary,
                                    borderRadius: BorderRadius.circular(6),
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
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_task, size: 16, color: NeoColors.ink),
                                      SizedBox(width: 6),
                                      Text(
                                        'AMBIL DARI BANK SOAL',
                                        style: TextStyle(
                                          fontFamily: 'Space Grotesk',
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: NeoColors.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: questions.length,
                        separatorBuilder: (_, i) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final q = questions[index];
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: NeoColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: NeoColors.ink, width: 2),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: q.type == 'mcq' ? NeoColors.info : NeoColors.tertiary,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: NeoColors.ink, width: 1.5),
                                  ),
                                  child: Text(
                                    '${index + 1}. ${q.type.toUpperCase()}',
                                    style: const TextStyle(
                                      fontFamily: 'Space Mono',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      color: NeoColors.ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
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
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${q.maxScore.toInt()} pt',
                                  style: const TextStyle(
                                    fontFamily: 'Space Mono',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    color: NeoColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Footer actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: NeoColors.bg,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
                border: Border(top: BorderSide(color: NeoColors.ink, width: 3)),
              ),
              child: Row(
                children: [
                  if (!isLecturer) ...[
                    if (exam.requireGeofence) ...[
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: NeoColors.surface,
                          side: const BorderSide(color: NeoColors.ink, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.map_outlined, color: NeoColors.ink),
                        tooltip: 'Peta Lokasi & Geofence',
                        onPressed: onViewLocation,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (!isLecturer && exam.hasSubmitted)
                      Expanded(
                        child: NeoButton(
                          text: 'LIHAT HASIL UJIAN',
                          icon: const Icon(Icons.assignment_turned_in, size: 18, color: NeoColors.ink),
                          fontSize: 13,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          backgroundColor: NeoColors.success,
                          onPressed: () {
                            Navigator.of(context).pop();
                            onViewResult?.call();
                          },
                        ),
                      )
                    else if (exam.computedStatus == 'SELESAI')
                      Expanded(
                        child: NeoButton(
                          text: 'UJIAN TELAH SELESAI',
                          fontSize: 13,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          variant: NeoButtonVariant.secondary,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      )
                    else if (exam.isEnrolled)
                      Expanded(
                        child: NeoButton(
                          text: 'MULAI KERJAKAN UJIAN',
                          fontSize: 13,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          variant: NeoButtonVariant.primary,
                          onPressed: () {
                            Navigator.of(context).pop();
                            onStartExam?.call();
                          },
                        ),
                      )
                    else
                      Expanded(
                        child: NeoButton(
                          text: 'DAFTAR UJIAN SEKARANG',
                          fontSize: 13,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          variant: NeoButtonVariant.primary,
                          onPressed: () {
                            Navigator.of(context).pop();
                            onEnroll();
                          },
                        ),
                      ),
                  ] else ...[
                    Expanded(
                      child: NeoButton(
                        text: 'MONITOR',
                        fontSize: 13,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        icon: const Icon(Icons.visibility_outlined, size: 18, color: NeoColors.ink),
                        variant: NeoButtonVariant.primary,
                        onPressed: () {
                          Navigator.of(context).pop();
                          onMonitor?.call();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: NeoButton(
                        text: 'REVIEW AI',
                        fontSize: 13,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        icon: const Icon(Icons.auto_awesome, size: 18, color: NeoColors.ink),
                        variant: NeoButtonVariant.secondary,
                        onPressed: () {
                          Navigator.of(context).pop();
                          onReviewEssay?.call();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: NeoColors.ink),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: 'Space Mono',
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: NeoColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
