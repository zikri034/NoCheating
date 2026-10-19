import 'package:flutter/material.dart';
import '../theme/neo_theme.dart';
import 'neo_button.dart';

class NeoDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;

  const NeoDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
  });

  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'KONFIRMASI',
    String cancelLabel = 'BATAL',
    bool isDangerous = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => NeoDialog(
        title: title,
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: 15,
            color: NeoColors.ink,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: NeoButton(
                  text: cancelLabel,
                  backgroundColor: NeoColors.surface,
                  textColor: NeoColors.ink,
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeoButton(
                  text: confirmLabel,
                  backgroundColor: isDangerous ? NeoColors.danger : NeoColors.primary,
                  textColor: isDangerous ? Colors.white : NeoColors.ink,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: NeoColors.surface,
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
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: NeoColors.ink, width: 2),
                ),
              ),
              child: Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: NeoColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 16),
            content,
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 24),
              ...actions!,
            ],
          ],
        ),
      ),
    );
  }
}
