import 'package:flutter/material.dart';
import '../theme/neo_theme.dart';

enum NeoButtonVariant { primary, secondary, danger }

class NeoButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final NeoButtonVariant variant;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? textColor;
  final EdgeInsetsGeometry? padding;
  final double? fontSize;
  final Widget? icon;

  const NeoButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = NeoButtonVariant.primary,
    this.borderRadius = 12.0,
    this.backgroundColor,
    this.textColor,
    this.padding,
    this.fontSize,
    this.icon,
  });

  @override
  State<NeoButton> createState() => _NeoButtonState();
}

class _NeoButtonState extends State<NeoButton> {
  bool _isPressed = false;

  Color _getBackgroundColor() {
    if (widget.backgroundColor != null) {
      return widget.backgroundColor!;
    }
    switch (widget.variant) {
      case NeoButtonVariant.primary:
        return NeoColors.primary;
      case NeoButtonVariant.secondary:
        return NeoColors.tertiary;
      case NeoButtonVariant.danger:
        return NeoColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: _isPressed ? _getBackgroundColor().withValues(alpha: 0.8) : _getBackgroundColor(),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: NeoColors.ink, width: 3),
          boxShadow: [
            BoxShadow(
              color: NeoColors.ink,
              offset: _isPressed ? const Offset(2, 2) : const Offset(6, 6),
              blurRadius: 0,
            ),
          ],
        ),
        transform: _isPressed
            ? (Matrix4.translationValues(4, 4, 0))
            : Matrix4.identity(),
        child: widget.icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  widget.icon!,
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.text.toUpperCase(),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: widget.fontSize ?? 16,
                        color: widget.textColor ?? NeoColors.ink,
                      ),
                    ),
                  ),
                ],
              )
            : Text(
                widget.text.toUpperCase(),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w800,
                  fontSize: widget.fontSize ?? 16,
                  color: widget.textColor ?? NeoColors.ink,
                ),
              ),
      ),
    );
  }
}
