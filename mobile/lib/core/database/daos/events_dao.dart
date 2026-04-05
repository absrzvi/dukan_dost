import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/events_table.dart';
import '../tables/sync_queue_table.dart';

part 'events_dao.g.dart';

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
    final payloadMap = <String, dynamic>{
      'id': id,
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

  /// Stream of events for a party, ordered by deviceTimestamp descending.
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
                OrderingTerm(expression: e.deviceTimestamp, mode: OrderingMode.desc),
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
