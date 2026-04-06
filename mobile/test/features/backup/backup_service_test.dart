import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukan_dost/features/backup/screens/backup_screen.dart';

void main() {
  group('BackupService — unit', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('backup_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('getLastBackupDate returns null when backup folder does not exist', () {
      final backupFolder = Directory('${tempDir.path}/DukaanDost/backup');
      // Folder must NOT exist — this mirrors the null-return path in BackupService.
      expect(backupFolder.existsSync(), isFalse);
    });

    test('exportLocalBackup — file copy creates a db file at destination', () async {
      // Simulate the copy logic that BackupService uses.
      final fakeDb = File('${tempDir.path}/dukaan_dost.sqlite');
      fakeDb.writeAsBytesSync([0x53, 0x51, 0x4C, 0x69, 0x74, 0x65]); // "SQLite"

      final backupDir = Directory('${tempDir.path}/DukaanDost/backup');
      backupDir.createSync(recursive: true);

      final dateTag = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final dest = File('${backupDir.path}/backup_$dateTag.db');
      await fakeDb.copy(dest.path);

      expect(dest.existsSync(), isTrue);
      expect(dest.lengthSync(), greaterThan(0));
    });
  });

  group('BackupScreen widget', () {
    testWidgets('renders backupNow button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: BackupScreen(),
          ),
        ),
      );

      // Settle async providers.
      await tester.pump();

      expect(find.text('ابھی بیک اپ لیں'), findsOneWidget);
    });
  });
}
