import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/services/timezone_service.dart';

class TimezoneConverterDialog extends StatefulWidget {
  final DateTime examTime;
  final String examTitle;

  const TimezoneConverterDialog({
    super.key,
    required this.examTime,
    required this.examTitle,
  });

  static Future<void> show(BuildContext context, {required DateTime examTime, required String examTitle}) {
    return showDialog(
      context: context,
      builder: (_) => TimezoneConverterDialog(examTime: examTime, examTitle: examTitle),
    );
  }

  @override
  State<TimezoneConverterDialog> createState() => _TimezoneConverterDialogState();
}

class _TimezoneConverterDialogState extends State<TimezoneConverterDialog> {
  late DateTime _selectedTime;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.examTime;
    _updateRemaining();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    final now = DateTime.now();
    final diff = _selectedTime.difference(now);
    if (mounted) {
      setState(() {
        _remaining = diff.isNegative ? Duration.zero : diff;
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    if (days > 0) {
      return '${days}h ${hours}j ${minutes}m ${seconds}d';
    }
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final items = TimezoneService.convertToAllZones(_selectedTime);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: NeoColors.bg,
          border: Border.all(color: NeoColors.ink, width: 3),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: NeoColors.ink,
              offset: Offset(6, 6),
              blurRadius: 0,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: NeoColors.primary,
                  border: Border(bottom: BorderSide(color: NeoColors.ink, width: 3)),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.public, color: NeoColors.ink, size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'KONVERSI WAKTU UJIAN (F08)',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: NeoColors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: NeoColors.ink),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.examTitle,
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: NeoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Countdown card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: NeoColors.surface,
                        border: Border.all(color: NeoColors.ink, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, color: NeoColors.ink, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Hitung Mundur: ',
                            style: TextStyle(
                              fontFamily: 'Hanken Grotesk',
                              fontWeight: FontWeight.w700,
                              color: NeoColors.ink,
                            ),
                          ),
                          Text(
                            _formatDuration(_remaining),
                            style: const TextStyle(
                              fontFamily: 'Space Mono',
                              fontWeight: FontWeight.w800,
                              color: NeoColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'JADWAL DI 4 ZONA WAKTU (IANA DATA):',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: NeoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // List of 4 Timezones
                    ...items.map((item) {
                      Color badgeColor = NeoColors.surface;
                      if (item.zoneCode == 'WIB') badgeColor = NeoColors.primary;
                      if (item.zoneCode == 'WITA') badgeColor = NeoColors.secondary;
                      if (item.zoneCode == 'WIT') badgeColor = NeoColors.info;
                      if (item.zoneCode == 'London') badgeColor = NeoColors.tertiary;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: NeoColors.ink, width: 2),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(color: NeoColors.ink, offset: Offset(2, 2), blurRadius: 0),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeColor,
                                border: Border.all(color: NeoColors.ink, width: 1.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.zoneCode,
                                style: const TextStyle(
                                  fontFamily: 'Space Mono',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: NeoColors.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.formattedTime,
                                    style: const TextStyle(
                                      fontFamily: 'Space Mono',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: NeoColors.ink,
                                    ),
                                  ),
                                  Text(
                                    item.zoneName,
                                    style: TextStyle(
                                      fontFamily: 'Hanken Grotesk',
                                      fontSize: 11,
                                      color: NeoColors.ink.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (item.dayOffset.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: NeoColors.warning,
                                  border: Border.all(color: NeoColors.ink, width: 1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.dayOffset,
                                  style: const TextStyle(
                                    fontFamily: 'Space Mono',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: NeoColors.ink,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: NeoButton(
                        text: 'TUTUP',
                        variant: NeoButtonVariant.primary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
