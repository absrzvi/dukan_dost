import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/events_table.dart';
import '../tables/sync_queue_table.dart';

part 'events_dao.g.dart';

// ---------------------------------------------------------------------------
// Timestamp helpers
// ---------------------------------------------------------------------------

/// Converts an ISO 8601 string (as returned by GET /api/sync/events) to
/// epoch milliseconds (as stored in the local Events table).
/// Used when writing events received from GET /api/sync/events.
// ignore: unused_element
int? _isoToEpochMillis(String? iso) {
  if (iso == null) return null;
  return DateTime.parse(iso).millisecondsSinceEpoch;
}

/// DAO for the append-only Events table plus SyncQueue entries.
///
/// Iron Rules:
///   - No updateEvent() or deleteEvent() — corrections are REVERSAL events.
///   - Every insertEvent() is wrapped in a Drift transaction so the Events row
///     and the SyncQueue row are written atomically.
///   - All monetary amounts are integer paisa — never floating point.
@DriftAccessor(tables: [Events, SyncQueue])
class EventsDao extends DatabaseAccessor<AppDatabase> with _$EventsDaoMixin {
  EventsDao(super.db);

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Insert a new event and simultaneously queue it for sync.
  /// Returns the inserted [Event] companion data.
  Future<Event> insertEvent({
    required String id,
    required String shopId,
    required String eventType,
    required String partyType,
    required String partyId,
    required int amountPaisa,
    String? note,
    String? voiceNotePath,
    required String deviceId,
    String? actorLabel,
    required int deviceTimestamp,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final eventCompanion = EventsCompanion.insert(
      id: id,
      shopId: shopId,
      eventType: eventType,
      partyType: partyType,
      partyId: partyId,
      amountPaisa: amountPaisa,
      note: Value(note),
      voiceNotePath: Value(voiceNotePath),
      deviceId: deviceId,
      actorLabel: Value(actorLabel),
      deviceTimestamp: deviceTimestamp,
      serverTimestamp: const Value(null),
      createdAt: now,
    );

    // Build the sync payload matching POST /api/sync/events body.
    // shop_id is included for cross-validation: server ignores it if it matches
    // the session shop, returns 403 if it doesn't.
    // Note: voiceNotePath is intentionally excluded — voice note sync is out of scope.
    final payloadMap = <String, dynamic>{
      'id': id,
      'shop_id': shopId,
      'event_type': eventType,
      'party_type': partyType,
      'party_id': partyId,
      'amount_paisa': amountPaisa,
      if (note != null) 'note': note,
      'device_id': deviceId,
      if (actorLabel != null) 'actor_label': actorLabel,
      'device_timestamp':
          DateTime.fromMillisecondsSinceEpoch(deviceTimestamp, isUtc: true)
              .toIso8601String(),
    };
    final payloadJson = jsonEncode(payloadMap);

    final syncCompanion = SyncQueueCompanion.insert(
      eventId: id,
      status: const Value('PENDING'),
      retryCount: const Value(0),
      lastAttemptAt: const Value(null),
      payload: Value(payloadJson),
      createdAt: now,
    );

    return db.transaction(() async {
      await into(events).insert(eventCompanion);
      await into(syncQueue).insert(syncCompanion);
      return (select(events)..where((e) => e.id.equals(id))).getSingle();
    });
  }

  // ---------------------------------------------------------------------------
  // Balance computation — replay the event log
  // ---------------------------------------------------------------------------

  /// Compute balance for a party in integer paisa.
  ///
  /// Positive result  → party owes the shop (shop extended credit).
  /// Negative result  → shop owes the party (supplier balance).
  ///
  /// Logic:
  ///   balance = SUM(CREDIT) - SUM(PAYMENT) - SUM(REVERSAL)
  ///   REMINDER_SENT rows have amountPaisa = 0 and are naturally excluded.
  Future<int> computeBalance(String partyId, String partyType) async {
    final creditSum = await _sumForTypes(
      partyId,
      partyType,
      const ['CREDIT'],
    );
    final debitSum = await _sumForTypes(
      partyId,
      partyType,
      const ['PAYMENT', 'REVERSAL'],
    );
    return creditSum - debitSum;
  }

  Future<int> _sumForTypes(
    String partyId,
    String partyType,
    List<String> types,
  ) async {
    final amountExpr = events.amountPaisa.sum();
    final query = selectOnly(events)
      ..addColumns([amountExpr])
      ..where(events.partyId.equals(partyId))
      ..where(events.partyType.equals(partyType))
      ..where(events.eventType.isIn(types));

    final row = await query.getSingle();
    return row.read(amountExpr) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  /// Stream of events for a party, ordered by deviceTimestamp ascending.
  /// Use with Riverpod StreamProvider.
  Stream<List<Event>> watchEventsForParty(
    String partyId,
    String partyType,
  ) {
    return (select(events)
          ..where(
            (e) =>
                e.partyId.equals(partyId) & e.partyType.equals(partyType),
          )
          ..orderBy([
            (e) =>
                OrderingTerm(expression: e.deviceTimestamp, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  /// Stream of all PENDING SyncQueue entries with their event payloads.
  /// Used by the sync worker (STORY-013).
  Stream<List<SyncQueueData>> watchPendingSync() {
    return (select(syncQueue)
          ..where((sq) => sq.status.equals('PENDING'))
          ..orderBy([(sq) => OrderingTerm(expression: sq.id)]))
        .watch();
  }

  /// Returns the most recent CREDIT event timestamp (epoch millis) for a
  /// customer, or null if no CREDIT events exist.
  /// Used to compute daysOverdue for the customer list.
  Future<int?> lastCreditTimestamp(String partyId, String partyType) async {
    final tsExpr = events.deviceTimestamp.max();
    final query = selectOnly(events)
      ..addColumns([tsExpr])
      ..where(events.partyId.equals(partyId))
      ..where(events.partyType.equals(partyType))
      ..where(events.eventType.equals('CREDIT'));
    final row = await query.getSingle();
    return row.read(tsExpr);
  }

  /// Returns the most recent event timestamp (epoch millis) for a party across
  /// all event types, or null if no events exist.
  Future<int?> lastActivityTimestamp(String partyId, String partyType) async {
    final tsExpr = events.deviceTimestamp.max();
    final query = selectOnly(events)
      ..addColumns([tsExpr])
      ..where(events.partyId.equals(partyId))
      ..where(events.partyType.equals(partyType));
    final row = await query.getSingle();
    return row.read(tsExpr);
  }

  /// Stream of all events for a shop, ordered by deviceTimestamp descending.
  Stream<List<Event>> watchShopEvents(String shopId) {
    return (select(events)
          ..where((e) => e.shopId.equals(shopId))
          ..orderBy([
            (e) => OrderingTerm(
                  expression: e.deviceTimestamp,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }
}
