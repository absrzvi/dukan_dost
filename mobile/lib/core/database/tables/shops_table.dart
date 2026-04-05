import 'package:drift/drift.dart';

/// Local shop profile. One row per device (the authenticated shop).
class Shops extends Table {
  /// Shop UUID from server — PRIMARY KEY
  TextColumn get id => text()();

  /// Registered phone number
  TextColumn get phone => text()();

  /// Shop name (entered during onboarding)
  TextColumn get name => text()();

  /// Locality / area
  TextColumn get locality => text().nullable()();

  /// This device's unique ID
  TextColumn get deviceId => text()();

  /// Human label for this device
  TextColumn get actorLabel => text().nullable()();

  /// Auth session token (stored in secure storage, cached here)
  TextColumn get sessionToken => text()();

  /// Unix epoch millis of last successful sync
  IntColumn get lastSyncAt => integer().nullable()();

  /// Row creation time (unix epoch millis)
  IntColumn get createdAt => integer()();

  /// Last modification time (unix epoch millis)
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
