import 'package:drift/drift.dart';

/// Customer records — used for WhatsApp deep links and balance lookups.
@TableIndex(name: 'idx_customers_shop', columns: {#shopId})
@TableIndex(name: 'idx_customers_phone', columns: {#shopId, #phone})
class Customers extends Table {
  /// Client-generated UUIDv4 — PRIMARY KEY
  TextColumn get id => text()();

  /// Owning shop
  TextColumn get shopId => text()();

  /// Customer name (required)
  TextColumn get name => text()();

  /// Phone number (optional); used for WhatsApp deep links
  TextColumn get phone => text().nullable()();

  /// 1 if flagged for follow-up tomorrow
  IntColumn get isFlagged => integer().withDefault(const Constant(0))();

  /// Unix epoch millis of last reminder sent
  IntColumn get lastReminderAt => integer().nullable()();

  /// Row creation time (unix epoch millis)
  IntColumn get createdAt => integer()();

  /// Last modification time (unix epoch millis)
  IntColumn get updatedAt => integer()();

  /// Soft delete flag
  IntColumn get isDeleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
