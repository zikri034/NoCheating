import 'package:flutter/material.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/local_exam_database.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/widgets/neo_text_field.dart';

class CurrencyConverterDialog extends StatefulWidget {
  final int initialFeeIdr;
  final String examTitle;

  const CurrencyConverterDialog({
    super.key,
    required this.initialFeeIdr,
    required this.examTitle,
  });

  static Future<void> show(BuildContext context, {required int initialFeeIdr, required String examTitle}) {
    return showDialog(
      context: context,
      builder: (_) => CurrencyConverterDialog(initialFeeIdr: initialFeeIdr, examTitle: examTitle),
    );
  }

  @override
  State<CurrencyConverterDialog> createState() => _CurrencyConverterDialogState();
}

class _CurrencyConverterDialogState extends State<CurrencyConverterDialog> {
  final TextEditingController _amountController = TextEditingController();
  final LocalExamDatabase _localDb = LocalExamDatabase();
  bool _isLoading = true;
  String _source = 'cache';
  String _updatedAt = '';
  Map<String, double> _rates = {
    'USD': 0.00006154,
    'EUR': 0.00005714,
    'MYR': 0.00027397,
    'JPY': 0.00921659,
  };

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.initialFeeIdr.toString();
    _amountController.addListener(() => setState(() {}));
    _fetchRates();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchRates() async {
    setState(() => _isLoading = true);
    try {
      final dio = DioClient.create();
      final response = await dio.get('/fx');
      final data = response.data as Map<String, dynamic>;

      final rawRates = data['rates'] as Map<String, dynamic>;
      final parsedRates = <String, double>{};
      rawRates.forEach((k, v) {
        parsedRates[k] = (v as num).toDouble();
      });

      final source = data['source'] as String? ?? 'live';
      final updatedAt = data['updated_at'] as String? ?? DateTime.now().toIso8601String();

      // Cache to SQLite
      await _localDb.saveFxRates(
        base: 'IDR',
        rates: parsedRates,
        source: source,
        updatedAt: DateTime.tryParse(updatedAt) ?? DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _rates = parsedRates;
          _source = source;
          _updatedAt = updatedAt;
          _isLoading = false;
        });
      }
    } catch (_) {
      // Offline fallback: load from SQLite
      final cached = await _localDb.getCachedFxRates(base: 'IDR');
      if (mounted) {
        setState(() {
          if (cached != null) {
            _rates = Map<String, double>.from(cached['rates'] as Map);
            _source = cached['source'] as String? ?? 'cache';
            _updatedAt = cached['updated_at'] as String? ?? '';
          } else {
            _source = 'demo';
            _updatedAt = DateTime.now().toIso8601String();
          }
          _isLoading = false;
        });
      }
    }
  }

  double _getAmount() {
    final text = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(text) ?? 0.0;
  }

  String _formatCurrency(String currency, double amount) {
    if (currency == 'JPY') {
      return '¥ ${amount.toStringAsFixed(0)}';
    } else if (currency == 'USD') {
      return '\$ ${amount.toStringAsFixed(2)}';
    } else if (currency == 'EUR') {
      return '€ ${amount.toStringAsFixed(2)}';
    } else if (currency == 'MYR') {
      return 'RM ${amount.toStringAsFixed(2)}';
    }
    return '$currency ${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final amountIdr = _getAmount();

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
                  color: NeoColors.secondary,
                  border: Border(bottom: BorderSide(color: NeoColors.ink, width: 3)),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.currency_exchange, color: NeoColors.ink, size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'KONVERSI KURS UJIAN (F09)',
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
                        fontSize: 17,
                        color: NeoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Input amount in IDR
                    NeoTextField(
                      controller: _amountController,
                      label: 'NOMINAL BIAYA (IDR)',
                      keyboardType: TextInputType.number,
                      hintText: 'Masukkan nominal rupiah...',
                    ),
                    const SizedBox(height: 12),

                    // Source and cache status badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _source == 'live'
                                ? NeoColors.success
                                : (_source == 'cache' ? NeoColors.primary : NeoColors.warning),
                            border: Border.all(color: NeoColors.ink, width: 1.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _source == 'live'
                                ? 'KURS LIVE (ONLINE)'
                                : (_source == 'cache' ? 'KURS CACHE (OFFLINE)' : 'KURS CONTOH (DEMO)'),
                            style: const TextStyle(
                              fontFamily: 'Space Mono',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: NeoColors.ink,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isLoading ? null : _fetchRates,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: NeoColors.ink),
                                )
                              : const Icon(Icons.refresh, size: 16, color: NeoColors.ink),
                          label: const Text(
                            'Perbarui',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.w700,
                              color: NeoColors.ink,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_updatedAt.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Pembaruan: ${_updatedAt.length >= 10 ? _updatedAt.substring(0, 10) : _updatedAt}',
                          style: TextStyle(
                            fontFamily: 'Space Mono',
                            fontSize: 10,
                            color: NeoColors.ink.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),

                    const Text(
                      'EKUIVALEN MATA UANG INTERNASIONAL:',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: NeoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Converted Currencies Grid
                    ...['USD', 'EUR', 'MYR', 'JPY'].map((curr) {
                      final rate = _rates[curr] ?? 0.0;
                      final convertedValue = amountIdr * rate;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: NeoColors.ink, width: 2),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: NeoColors.ink, offset: Offset(2, 2), blurRadius: 0),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: NeoColors.surface,
                                    border: Border.all(color: NeoColors.ink, width: 1.5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    curr,
                                    style: const TextStyle(
                                      fontFamily: 'Space Mono',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: NeoColors.ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '1 IDR = ${rate.toStringAsFixed(curr == 'JPY' ? 4 : 8)}',
                                  style: TextStyle(
                                    fontFamily: 'Space Mono',
                                    fontSize: 11,
                                    color: NeoColors.ink.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _formatCurrency(curr, convertedValue),
                              style: const TextStyle(
                                fontFamily: 'Space Mono',
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: NeoColors.ink,
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
