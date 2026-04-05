import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';

/// Full-screen celebration overlay shown when a customer's balance hits zero.
/// Used by both CreditEntryScreen and PaymentEntryScreen.
class HisaabSaafOverlay extends StatelessWidget {
  const HisaabSaafOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const Dialog.fullscreen(
      backgroundColor: AppColors.hisaabSaafGreen,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 80, color: Colors.white),
          SizedBox(height: 24),
          Text(
            AppStrings.hisaabSaaf,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Text(
            AppStrings.hisaabSaafSubtitle,
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
