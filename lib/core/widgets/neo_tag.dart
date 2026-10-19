import 'package:flutter/material.dart';
import '../theme/neo_theme.dart';

enum NeoTagVariant { info, success, warning, danger, muted, primary, secondary, tertiary }

class NeoTag extends StatelessWidget {
  final String label;
  final NeoTagVariant? variant;
  final Color? customColor;
  final Color textColor;
  final IconData? icon;

  const NeoTag({
    super.key,
    required this.label,
    this.variant,
    this.customColor,
    this.textColor = NeoColors.ink,
    this.icon,
  });

  Color _getBackgroundColor() {
    if (customColor != null) return customColor!;
    switch (variant ?? NeoTagVariant.info) {
      case NeoTagVariant.info:
        return NeoColors.info;
      case NeoTagVariant.success:
        return NeoColors.success;
      case NeoTagVariant.warning:
      case NeoTagVariant.primary:
        return NeoColors.primary;
      case NeoTagVariant.secondary:
        return NeoColors.secondary;
      case NeoTagVariant.tertiary:
        return NeoColors.tertiary;
      case NeoTagVariant.danger:
        return NeoColors.danger;
      case NeoTagVariant.muted:
        return NeoColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
