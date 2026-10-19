import 'package:flutter/material.dart';

class NeoCard extends StatelessWidget {
  final Widget child;
  final Widget? header;
  final Color backgroundColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const NeoCard({
    super.key,
    required this.child,
    this.header,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.borderRadius = 12.0,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFF0D0D0D), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF0D0D0D),
            offset: Offset(6, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDE59),
                border: const Border(
                  bottom: BorderSide(color: Color(0xFF0D0D0D), width: 3),
                ),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(borderRadius),
                ),
              ),
              child: header,
            ),
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}
