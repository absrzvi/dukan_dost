import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';

/// Shared singleton [AppDatabase] for the whole app.
/// Disposed automatically when the outermost [ProviderScope] is destroyed.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
