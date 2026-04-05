import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/amount_formatter.dart';

/// Reusable numeric keypad for entering PKR amounts.
///
/// Iron Rule: All amounts are integer paisa. Never floats.
/// Tracks input as a string like "150" or "150.50", converts to paisa on each
/// change:
///   "150"   → 15000 paisa
///   "150.5" → 15050 paisa
///   "150.50"→ 15050 paisa
///
/// Only 2 decimal places are allowed.
class AmountKeypad extends StatefulWidget {
  const AmountKeypad({
    super.key,
    required this.onAmountChanged,
    this.initialPaisa = 0,
  });

  /// Called whenever the amount changes. Value is always int paisa.
  final ValueChanged<int> onAmountChanged;

  /// Optional initial value in paisa.
  final int initialPaisa;

  @override
  State<AmountKeypad> createState() => _AmountKeypadState();
}

class _AmountKeypadState extends State<AmountKeypad> {
  /// Raw string typed by user, e.g. "150" or "150.50"
  String _rawInput = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialPaisa > 0) {
      // Convert paisa back to display string
      final rupees = widget.initialPaisa ~/ 100;
      final paisa = widget.initialPaisa % 100;
      if (paisa == 0) {
        _rawInput = rupees.toString();
      } else {
        _rawInput = '$rupees.${paisa.toString().padLeft(2, '0')}';
      }
    }
  }

  /// Convert the current raw string to integer paisa.
  int get _currentPaisa {
    if (_rawInput.isEmpty) return 0;
    final parts = _rawInput.split('.');
    final rupeePart = int.tryParse(parts[0]) ?? 0;
    int paisaPart = 0;
    if (parts.length == 2 && parts[1].isNotEmpty) {
      // Pad to 2 digits: "5" → "50", "50" → "50"
      final padded = parts[1].padRight(2, '0');
      paisaPart = int.tryParse(padded.substring(0, 2)) ?? 0;
    }
    return rupeePart * 100 + paisaPart;
  }

  String get _displayAmount {
    if (_rawInput.isEmpty) return 'PKR 0';
    final paisa = _currentPaisa;
    // Show decimal portion in display if user has typed it
    if (_rawInput.contains('.')) {
      final decimalPart = _rawInput.split('.')[1];
      final rupeePart = _currentPaisa ~/ 100;
      final formattedRupees =
          AmountFormatter.format(rupeePart * 100).replaceFirst('PKR ', '');
      return 'PKR $formattedRupees.${decimalPart.padRight(2, '0')}';
    }
    return AmountFormatter.format(paisa);
  }

  void _onKey(String key) {
    setState(() {
      if (key == '⌫') {
        if (_rawInput.isNotEmpty) {
          _rawInput = _rawInput.substring(0, _rawInput.length - 1);
        }
      } else if (key == '.') {
        // Only one decimal point allowed
        if (!_rawInput.contains('.')) {
          if (_rawInput.isEmpty) {
            _rawInput = '0.';
          } else {
            _rawInput = '$_rawInput.';
          }
        }
      } else {
        // Digit key
        if (_rawInput.contains('.')) {
          final decimalPart = _rawInput.split('.')[1];
          // Only allow up to 2 decimal places
          if (decimalPart.length >= 2) return;
        }
        // Prevent leading zeros for integer part
        if (_rawInput == '0') {
          _rawInput = key;
        } else {
          _rawInput = '$_rawInput$key';
        }
      }
    });
    widget.onAmountChanged(_currentPaisa);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Amount display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE0E0E0)),
            ),
          ),
          child: Text(
            _displayAmount,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),

        // Keypad grid
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              _KeyRow(keys: const ['1', '2', '3'], onKey: _onKey),
              _KeyRow(keys: const ['4', '5', '6'], onKey: _onKey),
              _KeyRow(keys: const ['7', '8', '9'], onKey: _onKey),
              _KeyRow(keys: const ['.', '0', '⌫'], onKey: _onKey),
            ],
          ),
        ),
      ],
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.keys, required this.onKey});

  final List<String> keys;
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: keys
          .map((k) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: _KeyButton(label: k, onTap: () => onKey(k)),
                ),
              ))
          .toList(),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBackspace = label == '⌫';
    return Material(
      color: isBackspace
          ? const Color(0xFFFFEBEE)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: isBackspace ? AppColors.creditColor : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
