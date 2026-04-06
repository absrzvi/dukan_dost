import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Handles local SQLite backup export and restore.
class BackupService {
  /// The name of the Drift database file (must match AppDatabase._openConnection).
  static const String _dbFileName = 'dukaan_dost.sqlite';

  /// Returns the current Drift DB file path (in application documents directory).
  Future<String> _dbFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _dbFileName);
  }

  /// Copies the Drift SQLite DB to the external Documents folder.
  /// Returns the destination file path on success.
  Future<String> exportLocalBackup() async {
    final srcPath = await _dbFilePath();
    final srcFile = File(srcPath);

    if (!srcFile.existsSync()) {
      throw Exception('Database file not found: $srcPath');
    }

    // Use external storage if available, otherwise fall back to app documents dir.
    Directory? destDir;
    try {
      destDir = await getExternalStorageDirectory();
    } catch (_) {
      destDir = null;
    }
    destDir ??= await getApplicationDocumentsDirectory();

    final backupFolder = Directory(p.join(destDir.path, 'DukaanDost', 'backup'));
    if (!backupFolder.existsSync()) {
      backupFolder.createSync(recursive: true);
    }

    final dateTag =
        DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final destPath = p.join(backupFolder.path, 'backup_$dateTag.db');

    await srcFile.copy(destPath);
    debugPrint('[BackupService] Exported backup to $destPath');
    return destPath;
  }

  /// Returns the last modified date of the most recent backup file,
  /// or null if no backup has ever been made.
  Future<DateTime?> getLastBackupDate() async {
    Directory? destDir;
    try {
      destDir = await getExternalStorageDirectory();
    } catch (_) {
      destDir = null;
    }
    destDir ??= await getApplicationDocumentsDirectory();

    final backupFolder =
        Directory(p.join(destDir.path, 'DukaanDost', 'backup'));
    if (!backupFolder.existsSync()) return null;

    final files = backupFolder
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.db'))
        .toList();

    if (files.isEmpty) return null;

    files.sort(
      (a, b) =>
          b.statSync().modified.compareTo(a.statSync().modified),
    );
    return files.first.statSync().modified;
  }

  /// Copies [filePath] over the current DB file.
  /// IMPORTANT: The database connection must be closed before calling this.
  /// The app must be restarted after restore.
  Future<void> restoreFromFile(String filePath) async {
    final src = File(filePath);
    if (!await src.exists()) {
      throw ArgumentError('Backup file does not exist: $filePath');
    }

    // Validate SQLite magic bytes (first 16 bytes = "SQLite format 3\0")
    final headerChunks = await src.openRead(0, 16).toList();
    final bytes = headerChunks.expand((x) => x).toList();
    const sqliteMagic = [83, 81, 76, 105, 116, 101, 32, 102, 111, 114, 109, 97, 116, 32, 51, 0];
    if (bytes.length < 16 || !_listEquals(bytes.sublist(0, 16), sqliteMagic)) {
      throw ArgumentError('Not a valid SQLite database file');
    }

    final destPath = await _dbFilePath();
    await src.copy(destPath);
    debugPrint('[BackupService] Restored DB from $filePath — please restart the app.');
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
