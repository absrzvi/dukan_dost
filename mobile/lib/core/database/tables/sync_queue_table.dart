import 'package:drift/drift.dart';

/// Tracks events pending upload to the server.
@TableIndex(name: 'idx_syncqueue_status', columns: {#status})
class SyncQueue extends Table {
  /// Queue order — autoincrement
  IntColumn get id => integer().autoIncrement()();

  /// FK to Events.id
  TextColumn get eventId => text().unique()();

  /// Sync status: PENDING | IN_FLIGHT | SYNCED | FAILED
  TextColumn get status => text().withDefault(const Constant('PENDING'))();

  /// Number of failed attempts
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  /// Unix epoch millis of last sync attempt
  IntColumn get lastAttemptAt => integer().nullable()();

  /// JSON payload for this event (stored for sync worker)
  TextColumn get payload => text().nullable()();

  /// When queued (unix epoch millis)
  IntColumn get createdAt => integer()();
}
