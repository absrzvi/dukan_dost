import 'package:drift/drift.dart';

/// Tracks backup history and metadata.
@TableIndex(name: 'idx_backups_shop_type', columns: {#shopId, #backupType, #createdAt})
class Backups extends Table {
  /// Auto ID — autoincrement
  IntColumn get id => integer().autoIncrement()();

  /// Shop this backup belongs to
  TextColumn get shopId => text()();

  /// Destination type: LOCAL | GDRIVE
  TextColumn get backupType => text()();

  /// Local file path (for LOCAL type)
  TextColumn get filePath => text().nullable()();

  /// Google Drive file ID (for GDRIVE type)
  TextColumn get gdriveFileId => text().nullable()();

  /// Backup file size in bytes
  IntColumn get fileSizeBytes => integer()();

  /// Backup status: IN_PROGRESS | COMPLETED | FAILED
  TextColumn get status => text()();

  /// When backup was initiated (unix epoch millis)
  IntColumn get createdAt => integer()();

  /// When backup finished (unix epoch millis)
  IntColumn get completedAt => integer().nullable()();
}
