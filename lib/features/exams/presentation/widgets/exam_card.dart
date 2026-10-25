import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_card.dart';
import '../../../../core/widgets/neo_tag.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../data/models/exam_model.dart';
import 'timezone_converter_dialog.dart';
import 'currency_converter_dialog.dart';

class ExamCard extends StatelessWidget {
  final ExamModel exam;
  final bool isLecturer;
  final VoidCallback onTap;
  final VoidCallback onEnroll;
  final VoidCallback? onStartExam;
  final VoidCallback? onMonitor;
  final VoidCallback? onViewLocation;
  final VoidCallback? onReviewEssay;

  const ExamCard({
    super.key,
    required this.exam,
    required this.isLecturer,
    required this.onTap,
    required this.onEnroll,
    this.onStartExam,
    this.onMonitor,
    this.onViewLocation,
    this.onReviewEssay,
  });

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd MMM yyyy, HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: NeoCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top badges: Course & Status
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
                fontSize: 18,
                color: NeoColors.ink,
              ),
            ),
            if (exam.courseName != null) ...[
              const SizedBox(height: 4),
              Text(
                exam.courseName!,
                style: const TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Details: Schedule & Duration
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NeoColors.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NeoColors.ink, width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: NeoColors.ink),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${_formatDateTime(exam.startAt)} WIB',
                          style: const TextStyle(
                            fontFamily: 'Space Mono',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: NeoColors.ink,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => TimezoneConverterDialog.show(
                          context,
                          examTime: exam.startAt,
                          examTitle: exam.title,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: NeoColors.surface,
                            border: Border.all(color: NeoColors.ink, width: 1.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.public, size: 12, color: NeoColors.ink),
                              SizedBox(width: 4),
                              Text(
                                '4 ZONA',
                                style: TextStyle(
                                  fontFamily: 'Space Mono',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: NeoColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: NeoColors.ink),
                      const SizedBox(width: 6),
                      Text(
                        '${exam.durationMin} Menit',
                        style: const TextStyle(
                          fontFamily: 'Space Mono',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: NeoColors.ink,
                        ),
                      ),
                      if (exam.lecturerName != null) ...[
                        const Spacer(),
                        const Icon(Icons.person_outline, size: 16, color: NeoColors.ink),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            exam.lecturerName!,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                              fontFamily: 'Hanken Grotesk',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: NeoColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Requirements Badges
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (exam.requireBiometric)
                  const NeoTag(
                    label: 'BIOMETRIK',
                    icon: Icons.fingerprint,
                    variant: NeoTagVariant.warning,
                  ),
                if (exam.requireGeofence)
                  const NeoTag(
                    label: 'LOKASI/GEOFENCE',
                    icon: Icons.location_on_outlined,
                    variant: NeoTagVariant.info,
                  ),
                if (exam.feeIdr != null && exam.feeIdr! > 0)
                  GestureDetector(
                    onTap: () => CurrencyConverterDialog.show(
                      context,
                      initialFeeIdr: exam.feeIdr!,
                      examTitle: exam.title,
                    ),
                    child: NeoTag(
                      label: 'Rp ${NumberFormat('#,###').format(exam.feeIdr)} (KURS)',
                      icon: Icons.currency_exchange,
                      variant: NeoTagVariant.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Action Row
            Row(
              children: [
                if (!isLecturer) ...[
                  if (exam.isEnrolled)
                    Expanded(
                      child: NeoButton(
                        text: 'KERJAKAN',
                        variant: NeoButtonVariant.primary,
                        onPressed: onStartExam ?? onTap,
                      ),
                    )
                  else
                    Expanded(
                      child: NeoButton(
                        text: 'DAFTAR',
                        variant: NeoButtonVariant.primary,
                        onPressed: onEnroll,
                      ),
                    ),
                  if (exam.requireGeofence) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: NeoColors.surface,
                        side: const BorderSide(color: NeoColors.ink, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.map_outlined, color: NeoColors.ink, size: 20),
                      tooltip: 'Lihat Peta Lokasi',
                      onPressed: onViewLocation,
                    ),
                  ],
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.arrow_forward, color: NeoColors.ink, size: 16),
                    label: const Text(
                      'DETAIL',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        color: NeoColors.ink,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: NeoButton(
                      text: 'KELOLA',
                      fontSize: 13,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      variant: NeoButtonVariant.secondary,
                      onPressed: onTap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: NeoButton(
                      text: 'MONITOR',
                      fontSize: 13,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      variant: NeoButtonVariant.primary,
                      onPressed: onMonitor ?? onTap,
                    ),
                  ),
                  if (onReviewEssay != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: NeoColors.tertiary,
                        side: const BorderSide(color: NeoColors.ink, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.auto_awesome, color: NeoColors.ink, size: 20),
                      tooltip: 'Review Essay AI',
                      onPressed: onReviewEssay,
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
