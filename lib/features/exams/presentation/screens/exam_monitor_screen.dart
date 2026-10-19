import 'package:flutter/material.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_card.dart';
import '../../../../core/widgets/neo_tag.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../data/repositories/exam_repository.dart';

class ExamMonitorScreen extends StatefulWidget {
  final String examId;

  const ExamMonitorScreen({super.key, required this.examId});

  @override
  State<ExamMonitorScreen> createState() => _ExamMonitorScreenState();
}

class _ExamMonitorScreenState extends State<ExamMonitorScreen> {
  final ExamRepository _repository = ExamRepository();

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _monitorData;

  @override
  void initState() {
    super.initState();
    _loadMonitorData();
  }

  Future<void> _loadMonitorData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _repository.fetchExamMonitor(widget.examId);
      setState(() {
        _monitorData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final exam = _monitorData?['exam'] as Map<String, dynamic>?;
    final stats = _monitorData?['stats'] as Map<String, dynamic>?;
    final participants = (_monitorData?['participants'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      backgroundColor: NeoColors.bg,
      appBar: AppBar(
        title: const Text(
          'MONITOR INTEGRITAS UJIAN',
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: NeoColors.ink,
          ),
        ),
        backgroundColor: NeoColors.primary,
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: NeoColors.ink, width: 3),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: NeoColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: NeoColors.ink),
            tooltip: 'Segarkan Data',
            onPressed: _loadMonitorData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: NeoColors.ink))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: NeoCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: NeoColors.danger),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: 'Hanken Grotesk'),
                          ),
                          const SizedBox(height: 16),
                          NeoButton(text: 'COBA LAGI', onPressed: _loadMonitorData),
                        ],
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMonitorData,
                  color: NeoColors.ink,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Header Card
                      if (exam != null)
                        NeoCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exam['title'] ?? 'Ujian',
                                style: const TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${exam['course_code'] ?? ''} - ${exam['course_name'] ?? ''}',
                                style: const TextStyle(
                                  fontFamily: 'Hanken Grotesk',
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  NeoTag(
                                    label: 'BATAS KRITIS: ${exam['max_critical'] ?? 3}X',
                                    variant: NeoTagVariant.danger,
                                  ),
                                  if (exam['require_geofence'] == true)
                                    const NeoTag(
                                      label: 'GEOFENCE AKTIF',
                                      variant: NeoTagVariant.info,
                                    ),
                                  if (exam['require_biometric'] == true)
                                    const NeoTag(
                                      label: 'BIOMETRIK WAJIB',
                                      variant: NeoTagVariant.secondary,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Stats Grid
                      if (stats != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'TOTAL PESERTA',
                                '${stats['total_participants'] ?? 0}',
                                NeoColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'AKTIF',
                                '${stats['active_count'] ?? 0}',
                                NeoColors.info,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'DIHENTIKAN',
                                '${stats['terminated_count'] ?? 0}',
                                NeoColors.danger,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'SELESAI',
                                '${stats['submitted_count'] ?? 0}',
                                NeoColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Section Title
                      const Text(
                        'PESERTA UJIAN & LINIMASA KEJADIAN',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (participants.isEmpty)
                        const NeoCard(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'Belum ada mahasiswa yang memulai ujian ini.',
                              style: TextStyle(fontFamily: 'Hanken Grotesk', color: Colors.black54),
                            ),
                          ),
                        )
                      else
                        ...participants.map((p) => _buildParticipantCard(p, exam?['max_critical'] ?? 3)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatCard(String title, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: NeoColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NeoColors.ink, width: 2.5),
        boxShadow: const [
          BoxShadow(color: NeoColors.ink, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.5,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantCard(Map<String, dynamic> p, int maxCritical) {
    final status = p['status'] as String? ?? 'in_progress';
    final criticalCount = (p['critical_count'] as num?)?.toInt() ?? 0;
    final violations = (p['violations'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    NeoTagVariant statusVariant;
    String statusLabel;

    if (status == 'terminated') {
      statusVariant = NeoTagVariant.danger;
      statusLabel = 'DIHENTIKAN';
    } else if (status == 'submitted' || status == 'graded') {
      statusVariant = NeoTagVariant.success;
      statusLabel = 'SELESAI';
    } else {
      statusVariant = NeoTagVariant.info;
      statusLabel = 'SEDANG MENGERJAKAN';
    }

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['student_name'] ?? 'Mahasiswa',
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'NIM: ${p['student_nim'] ?? '-'} • ${p['student_email'] ?? ''}',
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
            const SizedBox(height: 10),
            const Divider(color: NeoColors.ink, thickness: 1.5),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pelanggaran Kritis:',
                  style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 13),
                ),
                Text(
                  '$criticalCount / $maxCritical',
                  style: TextStyle(
                    fontFamily: 'Space Mono',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: criticalCount > 0 ? NeoColors.danger : NeoColors.ink,
                  ),
                ),
              ],
            ),

            if (violations.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: NeoColors.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: NeoColors.ink, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Linimasa Pelanggaran:',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...violations.map((v) => _buildViolationItem(v)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildViolationItem(Map<String, dynamic> v) {
    final severity = v['severity'] as String? ?? 'warn';
    final type = v['type'] as String? ?? 'unknown';
    final occurredAt = DateTime.tryParse(v['occurred_at']?.toString() ?? '');
    final timeStr = occurredAt != null
        ? '${occurredAt.hour.toString().padLeft(2, '0')}:${occurredAt.minute.toString().padLeft(2, '0')}:${occurredAt.second.toString().padLeft(2, '0')}'
        : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: severity == 'critical' ? NeoColors.danger : NeoColors.primary,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: NeoColors.ink, width: 1),
            ),
            child: Text(
              severity.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Space Mono',
                fontWeight: FontWeight.w800,
                fontSize: 9,
                color: severity == 'critical' ? Colors.white : NeoColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              type,
              style: const TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            timeStr,
            style: const TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
