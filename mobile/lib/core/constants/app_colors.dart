import 'package:flutter/material.dart';

class AppColors {
  // Primary palette
  static const Color primary = Color(0xFF1B5E20); // deep green — trust/money
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color accent = Color(0xFFFF6F00); // amber — overdue alerts

  // Ledger colors
  static const Color creditColor = Color(0xFFD32F2F); // red — money going out (udhaar)
  static const Color paymentColor = Color(0xFF2E7D32); // green — money coming in (wapsi)
  static const Color overdueRed = Color(0xFFB71C1C); // dark red — 7+ days overdue
  static const Color hisaabSaafGreen = Color(0xFF1B5E20); // celebration green

  // Balance semantic colors
  static const Color balancePositive = Color(0xFFD32F2F); // red — customer owes shop
  static const Color balanceZero = Color(0xFF9E9E9E);     // grey — settled
  static const Color balanceNegative = Color(0xFF2E7D32); // green — shop owes customer

  // Background
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color chatBubbleCredit = Color(0xFFFFEBEE); // light red bubble
  static const Color chatBubblePayment = Color(0xFFE8F5E9); // light green bubble

  // Text
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textAmount = Color(0xFF212121); // always high contrast for numbers

  // Offline indicator
  static const Color offlineBanner = Color(0xFFFF8F00);

  // Event bubble colours (MINOR-1 / STORY-010)
  static const Color creditBubbleBg = Color(0xFFECEFF1);
  static const Color creditBubbleBorder = Color(0xFFB0BEC5);
  static const Color reversalBubbleBg = Color(0xFFEEEEEE);

  // Reminder amber (MINOR-4 / STORY-010)
  static const Color reminderAmber = Color(0xFFFF8F00); // amber[800]

  // WhatsApp brand green
  static const Color whatsappGreen = Color(0xFF25D366);
}
