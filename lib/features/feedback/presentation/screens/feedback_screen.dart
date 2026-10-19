import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/local_exam_database.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/widgets/neo_card.dart';
import '../../../../core/widgets/neo_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _impressionController = TextEditingController();
  final TextEditingController _suggestionController = TextEditingController();
  final LocalExamDatabase _localDb = LocalExamDatabase();

  int _selectedRating = 5;
  bool _isSubmitting = false;
  bool _isLoadingHistory = true;
  List<Map<String, dynamic>> _feedbacks = [];

  @override
  void initState() {
    super.initState();
    _syncPendingFeedbacks();
    _loadFeedbackHistory();
  }

  @override
  void dispose() {
    _impressionController.dispose();
    _suggestionController.dispose();
    super.dispose();
  }

  Future<void> _syncPendingFeedbacks() async {
    try {
      final pending = await _localDb.getPendingFeedbacks();
      if (pending.isEmpty) return;

      final dio = DioClient.create();
      final syncedIds = <int>[];

      for (final item in pending) {
        try {
          await dio.post('/feedback', data: {
            'impression': item['impression'],
            'suggestion': item['suggestion'],
            'rating': item['rating'],
          });
          syncedIds.add(item['id'] as int);
        } catch (_) {}
      }

      if (syncedIds.isNotEmpty) {
        await _localDb.markFeedbacksSynced(syncedIds);
      }
    } catch (_) {}
  }

  Future<void> _loadFeedbackHistory() async {
    setState(() => _isLoadingHistory = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLecturer = authProvider.currentUser?.role == 'lecturer';

    try {
      final dio = DioClient.create();
      final endpoint = isLecturer ? '/feedback' : '/feedback/me';
      final res = await dio.get(endpoint);
      final data = res.data as Map<String, dynamic>;
      final list = (data['feedbacks'] as List).cast<Map<String, dynamic>>();

      if (mounted) {
        setState(() {
          _feedbacks = list;
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _handleSubmit() async {
    final impression = _impressionController.text.trim();
    if (impression.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kesan wajib diisi minimal 5 karakter'),
          backgroundColor: NeoColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final suggestion = _suggestionController.text.trim();

    try {
      final dio = DioClient.create();
      await dio.post('/feedback', data: {
        'impression': impression,
        'suggestion': suggestion.isNotEmpty ? suggestion : null,
        'rating': _selectedRating,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saran & kesan berhasil dikirim ke dosen!'),
          backgroundColor: NeoColors.success,
        ),
      );

      _impressionController.clear();
      _suggestionController.clear();
      setState(() => _selectedRating = 5);
      _loadFeedbackHistory();
    } catch (_) {
      // Offline fallback: enqueue to SQLite
      await _localDb.enqueueFeedback(
        impression: impression,
        suggestion: suggestion.isNotEmpty ? suggestion : null,
        rating: _selectedRating,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tersimpan di antrean offline. Akan dikirim otomatis saat online.'),
          backgroundColor: NeoColors.warning,
        ),
      );

      _impressionController.clear();
      _suggestionController.clear();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLecturer = authProvider.currentUser?.role == 'lecturer';

    return Scaffold(
      backgroundColor: NeoColors.bg,
      appBar: AppBar(
        backgroundColor: NeoColors.primary,
        elevation: 0,
        title: const Text(
          'SARAN & KESAN (T6)',
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.w800,
            color: NeoColors.ink,
          ),
        ),
        shape: const Border(bottom: BorderSide(color: NeoColors.ink, width: 3)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: NeoColors.ink),
            onPressed: () {
              _syncPendingFeedbacks();
              _loadFeedbackHistory();
            },
            tooltip: 'Sinkronisasi',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // FORM INPUT (hanya untuk mahasiswa atau dosen yang ingin mengisi)
            if (!isLecturer) ...[
              NeoCard(
                header: const Text(
                  'EVALUASI MATA KULIAH PAM',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: NeoColors.ink,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Berikan masukan dan penilaian Anda untuk mata kuliah Pemrograman Aplikasi Mobile.',
                      style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 13, color: NeoColors.ink),
                    ),
                    const SizedBox(height: 16),

                    // Interactive Rating Stars
                    const Text(
                      'RATING KESELURUHAN (1 - 5):',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: NeoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (index) {
                        final star = index + 1;
                        final isSelected = star <= _selectedRating;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedRating = star),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? NeoColors.primary : NeoColors.surface,
                              border: Border.all(color: NeoColors.ink, width: 2),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(color: NeoColors.ink, offset: Offset(2, 2), blurRadius: 0),
                              ],
                            ),
                            child: Icon(
                              isSelected ? Icons.star : Icons.star_border,
                              color: NeoColors.ink,
                              size: 24,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),

                    NeoTextField(
                      controller: _impressionController,
                      label: 'KESAN KULIAH (WAJIB)',
                      hintText: 'Tuliskan kesan pembelajaran selama semester ini...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    NeoTextField(
                      controller: _suggestionController,
                      label: 'SARAN PERBAIKAN (OPSIONAL)',
                      hintText: 'Tuliskan saran untuk pengembangan materi/ujian...',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: NeoButton(
                        text: _isSubmitting ? 'MENGIRIM...' : 'KIRIM SARAN & KESAN',
                        variant: NeoButtonVariant.primary,
                        onPressed: _isSubmitting ? null : _handleSubmit,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // RIWAYAT / DAFTAR FEEDBACK
            NeoCard(
              header: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isLecturer ? 'REKAP SELURUH SARAN MAHASISWA' : 'RIWAYAT SARAN SAYA',
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: NeoColors.ink,
                    ),
                  ),
                  if (_isLoadingHistory)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: NeoColors.ink),
                    ),
                ],
              ),
              child: _feedbacks.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          isLecturer
                              ? 'Belum ada saran atau kesan yang dikirimkan mahasiswa.'
                              : 'Anda belum pernah mengirimkan saran dan kesan.',
                          style: const TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _feedbacks.length,
                      separatorBuilder: (context, index) => const Divider(color: NeoColors.ink, thickness: 1.5),
                      itemBuilder: (context, index) {
                        final fb = _feedbacks[index];
                        final rating = fb['rating'] as int? ?? 5;
                        final impression = fb['impression'] as String? ?? '';
                        final suggestion = fb['suggestion'] as String?;
                        final studentName = fb['student_name'] as String?;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: List.generate(
                                      rating,
                                      (_) => const Icon(Icons.star, size: 16, color: NeoColors.ink),
                                    ),
                                  ),
                                  if (studentName != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: NeoColors.secondary,
                                        border: Border.all(color: NeoColors.ink, width: 1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        studentName,
                                        style: const TextStyle(
                                          fontFamily: 'Space Grotesk',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                impression,
                                style: const TextStyle(
                                  fontFamily: 'Hanken Grotesk',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: NeoColors.ink,
                                ),
                              ),
                              if (suggestion != null && suggestion.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: NeoColors.surface,
                                    border: Border.all(color: NeoColors.ink, width: 1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Saran: $suggestion',
                                    style: TextStyle(
                                      fontFamily: 'Hanken Grotesk',
                                      fontSize: 12,
                                      color: NeoColors.ink.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
