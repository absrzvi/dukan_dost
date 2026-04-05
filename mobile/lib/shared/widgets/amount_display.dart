import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/amount_formatter.dart';

/// Large, dominant PKR amount display widget.
/// Iron Rule: Takes [int paisa] — never displays floats.
/// Design principle: Numbers are dominant — large, high contrast.
class AmountDisplay extends StatelessWidget {
  /// Amount in paisa (integer only — Iron Rule: no floating point for money)
  final int paisa;

  /// Optional color override (defaults to textAmount)
  final Color? color;

  /// Optional font size override (defaults to 32)
  final double fontSize;

  const AmountDisplay({
    super.key,
    required this.paisa,
    this.color,
    this.fontSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      AmountFormatter.format(paisa),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: color ?? AppColors.textAmount,
        letterSpacing: 0.5,
      ),
    );
  }
}
