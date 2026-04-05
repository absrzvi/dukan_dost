import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_colors.dart';

class DukaanDostApp extends ConsumerWidget {
  const DukaanDostApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'دکان دوست',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: AppColors.surface,
        ),
        useMaterial3: true,
        // Large, readable text — design principle: numbers are dominant
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: AppColors.textAmount,
          ),
          displayMedium: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textAmount,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: AppColors.textPrimary),
          bodyMedium: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ),
      // Placeholder home — will be replaced by router in STORY-004
      home: const Scaffold(
        body: Center(
          child: Text('دکان دوست', style: TextStyle(fontSize: 32)),
        ),
      ),
    );
  }
}
