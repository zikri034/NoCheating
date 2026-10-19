import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_button.dart';

class BlockchainReceiptDialog extends StatefulWidget {
  final String attemptId;
  final String examTitle;

  const BlockchainReceiptDialog({
    super.key,
    required this.attemptId,
    required this.examTitle,
  });

  static Future<void> show(BuildContext context, {required String attemptId, required String examTitle}) {
    return showDialog(
      context: context,
      builder: (_) => BlockchainReceiptDialog(attemptId: attemptId, examTitle: examTitle),
    );
  }

  @override
  State<BlockchainReceiptDialog> createState() => _BlockchainReceiptDialogState();
}

class _BlockchainReceiptDialogState extends State<BlockchainReceiptDialog> {
  bool _isLoading = true;
  bool _isVerifying = false;
  List<Map<String, dynamic>> _receipts = [];
  Map<String, dynamic>? _verificationResult;

  @override
  void initState() {
    super.initState();
    _fetchReceipts();
  }

  Future<void> _fetchReceipts() async {
    setState(() => _isLoading = true);
    try {
      final dio = DioClient.create();
      final res = await dio.get('/chain/receipt/${widget.attemptId}');
      final data = res.data as Map<String, dynamic>;
      final list = (data['receipts'] as List).cast<Map<String, dynamic>>();

      if (mounted) {
        setState(() {
          _receipts = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyChain() async {
    setState(() => _isVerifying = true);
    try {
      final dio = DioClient.create();
      final res = await dio.get('/chain/verify');
      final data = res.data as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _verificationResult = data;
          _isVerifying = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  color: NeoColors.tertiary,
                  border: Border(bottom: BorderSide(color: NeoColors.ink, width: 3)),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: NeoColors.ink, size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'BUKTI INTEGRITAS BLOCKCHAIN (T13)',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
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
                child: _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(color: NeoColors.ink),
                        ),
                      )
                    : Column(
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
                          const SizedBox(height: 4),
                          Text(
                            'Attempt ID: ${widget.attemptId}',
                            style: TextStyle(
                              fontFamily: 'Space Mono',
                              fontSize: 11,
                              color: NeoColors.ink.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Verification result banner
                          if (_verificationResult != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _verificationResult!['valid'] == true
                                    ? NeoColors.success
                                    : NeoColors.danger,
                                border: Border.all(color: NeoColors.ink, width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _verificationResult!['valid'] == true
                                        ? Icons.check_circle
                                        : Icons.warning,
                                    color: NeoColors.ink,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _verificationResult!['valid'] == true
                                          ? 'INTEGRITAS VALID: Seluruh rantai hash ${_verificationResult!['blockCount']} blok terverifikasi bebas manipulasi!'
                                          : 'MANIPULASI TERDETEKSI pada blok #${_verificationResult!['corruptedIndex']}: ${_verificationResult!['error']}',
                                      style: const TextStyle(
                                        fontFamily: 'Hanken Grotesk',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: NeoColors.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (_receipts.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: NeoColors.surface,
                                border: Border.all(color: NeoColors.ink, width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Belum ada bukti blok blockchain yang dicatat untuk ujian ini.',
                                style: TextStyle(
                                  fontFamily: 'Hanken Grotesk',
                                  fontSize: 13,
                                  color: NeoColors.ink,
                                ),
                              ),
                            )
                          else
                            ..._receipts.map((b) {
                              final idx = b['idx'];
                              final type = b['type'] ?? 'BLOCK';
                              final hash = b['hash'] ?? '';
                              final qrPayload = b['qr_payload'] ?? 'SAFEEXAM:BLOCK:$idx:$hash:$type';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: NeoColors.ink, width: 2),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: const [
                                    BoxShadow(color: NeoColors.ink, offset: Offset(2, 2), blurRadius: 0),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: type == 'SUBMISSION' ? NeoColors.primary : NeoColors.secondary,
                                            border: Border.all(color: NeoColors.ink, width: 1.5),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'BLOK #$idx — $type',
                                            style: const TextStyle(
                                              fontFamily: 'Space Grotesk',
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                              color: NeoColors.ink,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Nonce: ${b['nonce']}',
                                          style: const TextStyle(
                                            fontFamily: 'Space Mono',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: NeoColors.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // QR Code & Hash display
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(color: NeoColors.ink, width: 2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: QrImageView(
                                            data: qrPayload,
                                            version: QrVersions.auto,
                                            size: 90.0,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'BLOCK HASH (SHA-256):',
                                                style: TextStyle(
                                                  fontFamily: 'Space Grotesk',
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 10,
                                                  color: NeoColors.ink,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              SelectableText(
                                                hash,
                                                style: const TextStyle(
                                                  fontFamily: 'Space Mono',
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: NeoColors.ink,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              const Text(
                                                'PREVIOUS HASH:',
                                                style: TextStyle(
                                                  fontFamily: 'Space Grotesk',
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 10,
                                                  color: NeoColors.ink,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              SelectableText(
                                                b['prev_hash'] ?? '',
                                                style: TextStyle(
                                                  fontFamily: 'Space Mono',
                                                  fontSize: 9,
                                                  color: NeoColors.ink.withValues(alpha: 0.6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),

                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: NeoButton(
                                  text: _isVerifying ? 'VERIFIKASI...' : 'VERIFIKASI RANTAI',
                                  variant: NeoButtonVariant.secondary,
                                  onPressed: _isVerifying ? null : _verifyChain,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: NeoButton(
                                  text: 'TUTUP',
                                  variant: NeoButtonVariant.primary,
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                            ],
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
