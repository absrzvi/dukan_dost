import 'package:flutter/material.dart';

/// Displays text in either Urdu script or Roman Urdu based on [useRoman].
/// Design principle: Urdu script is primary; Roman Urdu is the toggle option.
class UrduText extends StatelessWidget {
  /// Urdu script string (primary)
  final String urdu;

  /// Roman Urdu string (toggle option)
  final String roman;

  /// If true, shows Roman Urdu; otherwise shows Urdu script
  final bool useRoman;

  final TextStyle? style;
  final TextAlign? textAlign;

  const UrduText({
    super.key,
    required this.urdu,
    required this.roman,
    this.useRoman = false,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      useRoman ? roman : urdu,
      style: style,
      textAlign: textAlign,
      textDirection: useRoman ? TextDirection.ltr : TextDirection.rtl,
    );
  }
}
