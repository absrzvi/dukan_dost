import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../providers/backup_provider.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastBackupAsync = ref.watch(lastBackupDateProvider);
    final status = ref.watch(backupStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.backup),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Last backup card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          AppStrings.lastBackup,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        lastBackupAsync.when(
                          loading: () => const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (_, __) => const Text(AppStrings.neverBackedUp),
                          data: (date) => Text(
                            date == null
                                ? AppStrings.neverBackedUp
                                : _formatDate(date),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Status message
            if (status != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: status == AppStrings.backupSuccess
                        ? AppColors.paymentColor
                        : AppColors.creditColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            // Backup Now button
            ElevatedButton.icon(
              icon: const Icon(Icons.backup),
              label: const Text(AppStrings.backupNow),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => _doBackup(context, ref),
            ),

            const SizedBox(height: 12),

            // Restore button
            OutlinedButton.icon(
              icon: const Icon(Icons.restore),
              label: const Text(AppStrings.restoreBackup),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => _doRestore(context, ref),
            ),

            const SizedBox(height: 32),

            // Google Drive placeholder
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_outlined, color: AppColors.textSecondary),
                  SizedBox(width: 12),
                  Text(
                    AppStrings.googleDriveComingSoon,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _doBackup(BuildContext context, WidgetRef ref) async {
    final service = ref.read(backupServiceProvider);
    try {
      final path = await service.exportLocalBackup();
      ref.read(backupStatusProvider.notifier).state = AppStrings.backupSuccess;
      ref.invalidate(lastBackupDateProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.backupSuccess}: $path'),
            backgroundColor: AppColors.paymentColor,
          ),
        );
      }
    } catch (e) {
      ref.read(backupStatusProvider.notifier).state = AppStrings.backupFailed;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.backupFailed}: $e'),
            backgroundColor: AppColors.creditColor,
          ),
        );
      }
    }
  }

  Future<void> _doRestore(BuildContext context, WidgetRef ref) async {
    // File picker not available without the file_picker package.
    // Show a dialog instructing user to provide the path manually.
    // TODO STORY-015: Integrate file_picker package for proper file selection.
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.restoreWarning),
        backgroundColor: AppColors.accent,
      ),
    );
  }
}
