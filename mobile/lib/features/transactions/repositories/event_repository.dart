import 'package:uuid/uuid.dart';

import '../../../core/constants/event_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/events_dao.dart';

/// Repository for the append-only Events table.
///
/// Iron Rules (enforced here):
///   - No update or delete operations.
///   - Every write is atomic: Event row + SyncQueue row in one transaction.
///   - All monetary amounts are integer paisa — never floating point.
///   - Balances are COMPUTED by replaying the event log, never stored.
class EventRepository {
  EventRepository({required AppDatabase database})
      : _dao = database.eventsDao;

  final EventsDao _dao;
  final _uuid = const Uuid();

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Insert a new event atomically with a matching SyncQueue entry.
  ///
  /// [amountPaisa] must always be a non-negative integer.
  /// [eventType]   must be one of [EventType] constants.
  /// [partyType]   must be one of [PartyType] constants.
  Future<Event> addEvent({
    required String shopId,
    required String eventType,
    required String partyType,
    required String partyId,
    required int amountPaisa,
    String? note,
    String? deviceId,
    String? actorLabel,
  }) {
    assert(amountPaisa >= 0, 'amountPaisa must be >= 0');
    assert(
      eventType == EventType.credit ||
          eventType == EventType.payment ||
          eventType == EventType.reversal ||
          eventType == EventType.reminderSent,
      'eventType must be one of EventType constants',
    );
    assert(
      partyType == PartyType.customer || partyType == PartyType.supplier,
      'partyType must be one of PartyType constants',
    );

    final id = _uuid.v4();
    final effectiveDeviceId = deviceId ?? 'unknown-device';
    final now = DateTime.now().millisecondsSinceEpoch;

    return _dao.insertEvent(
      id: id,
      shopId: shopId,
      eventType: eventType,
      partyType: partyType,
      partyId: partyId,
      amountPaisa: amountPaisa,
      note: note,
      deviceId: effectiveDeviceId,
      actorLabel: actorLabel,
      deviceTimestamp: now,
    );
  }

  // ---------------------------------------------------------------------------
  // Balance
  // ---------------------------------------------------------------------------

  /// Compute balance for a party by replaying the event log.
  ///
  /// Returns integer paisa:
  ///   positive → party owes the shop (e.g. customer has outstanding credit)
  ///   negative → shop owes party (e.g. supplier balance)
  ///   0        → no events or fully settled
  Future<int> computeBalance(String partyId, String partyType) {
    return _dao.computeBalance(partyId, partyType);
  }

  // ---------------------------------------------------------------------------
  // Queries / Streams
  // ---------------------------------------------------------------------------

  /// Stream of events for a party ordered by deviceTimestamp descending.
  Stream<List<Event>> watchEvents(String partyId, String partyType) {
    return _dao.watchEventsForParty(partyId, partyType);
  }

  /// Stream of all events for a shop (used by sync worker).
  Stream<List<Event>> watchShopEvents(String shopId) {
    return _dao.watchShopEvents(shopId);
  }

  /// Stream of SyncQueue entries that are PENDING upload.
  Stream<List<SyncQueueData>> watchPendingSync() {
    return _dao.watchPendingSync();
  }
}
