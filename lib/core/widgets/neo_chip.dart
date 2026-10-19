import 'package:flutter/material.dart';
import '../theme/neo_theme.dart';

class NeoChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color selectedColor;

  const NeoChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.selectedColor = NeoColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : NeoColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: NeoColors.ink, width: 2),
          boxShadow: [
            BoxShadow(
              color: NeoColors.ink,
              offset: isSelected ? const Offset(1, 1) : const Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        transform: isSelected
            ? Matrix4.translationValues(2, 2, 0)
            : Matrix4.identity(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: NeoColors.ink),
              const SizedBox(width: 6),
            ],
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                fontSize: 12,
                color: NeoColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
