import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;
  final Color? backgroundColor;
  final double fontSize;
  final bool showBorder;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.textColor,
    this.backgroundColor,
    this.fontSize = 11,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = textColor ?? color;
    final effectiveBgColor = backgroundColor ?? color.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: BorderRadius.circular(6),
        border: showBorder
            ? Border.all(color: color.withValues(alpha: 0.3))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          color: effectiveTextColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
