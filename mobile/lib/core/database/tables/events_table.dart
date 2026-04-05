import 'package:drift/drift.dart';

/// Append-only transaction log — source of truth for all balances.
/// Iron Rule: No UPDATE or DELETE. Editing means a REVERSAL entry.
@TableIndex(name: 'idx_events_party', columns: {#partyType, #partyId})
@TableIndex(name: 'idx_events_shop', columns: {#shopId})
@TableIndex(name: 'idx_events_device_ts', columns: {#deviceTimestamp})
@TableIndex(name: 'idx_events_server_ts', columns: {#serverTimestamp})
class Events extends Table {
  /// Client-generated UUIDv4 — PRIMARY KEY
  TextColumn get id => text()();

  /// Shop this event belongs to
  TextColumn get shopId => text()();

  /// Type of ledger event: CREDIT | PAYMENT | REVERSAL | REMINDER_SENT
  TextColumn get eventType => text()();

  /// Whether this involves a CUSTOMER or SUPPLIER
  TextColumn get partyType => text()();

  /// FK to Customers or Suppliers (UUID)
  TextColumn get partyId => text()();

  /// Amount in paisa (always positive; direction implied by event_type)
  /// Iron Rule: integer paisa only — never floating point
  IntColumn get amountPaisa => integer()();

  /// Optional text note
  TextColumn get note => text().nullable()();

  /// Local file path to voice recording
  TextColumn get voiceNotePath => text().nullable()();

  /// Device that created this event
  TextColumn get deviceId => text()();

  /// Human label for the device/actor (e.g. "Main phone")
  TextColumn get actorLabel => text().nullable()();

  /// Unix epoch millis when event was created on device
  IntColumn get deviceTimestamp => integer()();

  /// Unix epoch millis assigned by server on sync; NULL if unsynced
  IntColumn get serverTimestamp => integer().nullable()();

  /// Row creation time (unix epoch millis)
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
