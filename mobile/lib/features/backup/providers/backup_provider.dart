import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/backup_service.dart';

/// Provides the [BackupService] singleton.
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});

/// Reads the last backup date from the filesystem.
final lastBackupDateProvider = FutureProvider.autoDispose<DateTime?>((ref) async {
  final service = ref.watch(backupServiceProvider);
  return service.getLastBackupDate();
});

/// Holds the current status message shown on the backup screen (success/error).
final backupStatusProvider = StateProvider<String?>((ref) => null);
