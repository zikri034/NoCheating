import 'package:flutter/material.dart';
import '../theme/neo_theme.dart';

/// Neo-Brutalist floating Snackbar component with 3px border and hard shadow.
class NeoSnackbar {
  static void showSuccess(
    BuildContext context, {
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context,
      title: title,
      message: message,
      backgroundColor: NeoColors.success,
      icon: Icons.check_circle_rounded,
      duration: duration,
    );
  }

  static void showWarning(
    BuildContext context, {
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 5),
  }) {
    _show(
      context,
      title: title,
      message: message,
      backgroundColor: NeoColors.warning,
      icon: Icons.warning_amber_rounded,
      duration: duration,
    );
  }

  static void showError(
    BuildContext context, {
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 5),
  }) {
    _show(
      context,
      title: title,
      message: message,
      backgroundColor: NeoColors.danger,
      icon: Icons.error_rounded,
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext context, {
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context,
      title: title,
      message: message,
      backgroundColor: NeoColors.info,
      icon: Icons.info_rounded,
      duration: duration,
    );
  }

  static void _show(
    BuildContext context, {
    required String title,
    String? message,
    required Color backgroundColor,
    required IconData icon,
    required Duration duration,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: NeoColors.ink, width: 3),
            boxShadow: const [
              BoxShadow(
                color: NeoColors.ink,
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: NeoColors.ink, width: 2),
                ),
                child: Icon(icon, color: NeoColors.ink, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: NeoColors.ink,
                      ),
                    ),
                    if (message != null && message.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: const TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: NeoColors.ink,
                        ),
                      ),
                    ],
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
