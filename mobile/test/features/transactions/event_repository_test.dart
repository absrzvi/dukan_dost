// ignore_for_file: avoid_relative_lib_imports

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/constants/event_constants.dart';
import '../../../lib/core/database/app_database.dart';
import '../../../lib/features/transactions/repositories/event_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a fully in-memory AppDatabase — no file I/O, no path_provider.
AppDatabase _makeTestDatabase() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

/// Extension on AppDatabase to support a testing constructor.
/// We need to add `AppDatabase.forTesting` — see below.
extension _Repo on AppDatabase {
  EventRepository get repo => EventRepository(database: this);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late EventRepository repo;

  const shopId = 'shop-uuid-001';
  const customerId = 'customer-uuid-001';
  const deviceId = 'test-device-001';

  setUp(() {
    db = _makeTestDatabase();
    repo = db.repo;
  });

  tearDown(() async {
    await db.close();
  });

  // -------------------------------------------------------------------------
  // 1. addEvent inserts event row and SyncQueue row atomically
  // -------------------------------------------------------------------------
  test('addEvent inserts Event row and SyncQueue row atomically', () async {
    await repo.addEvent(
      shopId: shopId,
      eventType: EventType.credit,
      partyType: PartyType.customer,
      partyId: customerId,
      amountPaisa: 50000,
      deviceId: deviceId,
    );

    final allEvents = await db.select(db.events).get();
    final allQueue = await db.select(db.syncQueue).get();

    expect(allEvents.length, 1);
    expect(allQueue.length, 1);
    expect(allQueue.first.eventId, allEvents.first.id);
    expect(allQueue.first.status, 'PENDING');
  });

  // -------------------------------------------------------------------------
  // 2. computeBalance returns 0 for party with no events
  // -------------------------------------------------------------------------
  test('computeBalance returns 0 for party with no events', () async {
    final balance = await repo.computeBalance('no-such-party', PartyType.customer);
    expect(balance, 0);
  });

  // -------------------------------------------------------------------------
  // 3. computeBalance correctly sums CREDIT events
  // -------------------------------------------------------------------------
  test('computeBalance correctly sums CREDIT events', () async {
    await repo.addEvent(
      shopId: shopId,
      eventType: EventType.credit,
      partyType: PartyType.customer,
      partyId: customerId,
      amountPaisa: 30000,
      deviceId: deviceId,
    );
    await repo.addEvent(
      shopId: shopId,
      eventType: EventType.credit,
      partyType: PartyType.customer,
      partyId: customerId,
      amountPaisa: 20000,
      deviceId: deviceId,
    );

    final balance = await repo.computeBalance(customerId, PartyType.customer);
    expect(balance, 50000);
  });

  // -------------------------------------------------------------------------
  // 4. computeBalance correctly subtracts PAYMENT events
  // -------------------------------------------------------------------------
  test('computeBalance correctly subtracts PAYMENT events', () async {
    // Only a payment with no prior credit — balance goes negative.
    await repo.addEvent(
      shopId: shopId,
      eventType: EventType.payment,
      partyType: PartyType.customer,
      partyId: customerId,
      amountPaisa: 10000,
      deviceId: deviceId,
    );

    final balance = await repo.computeBalance(customerId, PartyType.customer);
    expect(balance, -10000);
  });

  // -------------------------------------------------------------------------
  // 5. computeBalance: CREDIT then PAYMENT = net balance
  // -------------------------------------------------------------------------
  test('computeBalance: CREDIT then PAYMENT = net balance', () async {
    await repo.addEvent(
      shopId: shopId,
      eventType: EventType.credit,
      partyType: PartyType.customer,
      partyId: customerId,
      amountPaisa: 100000,
      deviceId: deviceId,
    );
    await repo.addEvent(
      shopId: shopId,
      eventType: EventType.payment,
      partyType: PartyType.customer,
      partyId: customerId,
      amountPaisa: 40000,
      deviceId: deviceId,
    );

    final balance = await repo.computeBalance(customerId, PartyType.customer);
    expect(balance, 60000);
  });

  // -------------------------------------------------------------------------
  // 6. REVERSAL event negates a CREDIT — balance returns to 0
  // -------------------------------------------------------------------------
  test('REVERSAL event negates a CREDIT — balance returns to 0', () async {
    await repo.addEvent(
      shopId: shopId,
      eventType: EventType.credit,
      partyType: PartyType.customer,
      partyId: customerId,
      amountPaisa: 50000,
      deviceId: deviceId,
    );
    await repo.addEvent(
      shopId: shopId,
      eventType: EventType.reversal,
      partyType: PartyType.customer,
      partyId: customerId,
      amountPaisa: 50000,
      deviceId: deviceId,
    );

    final balance = await repo.computeBalance(customerId, PartyType.customer);
    expect(balance, 0);
  });

  // -------------------------------------------------------------------------
  // 7. REMINDER_SENT event does not affect balance
  // -------------------------------------------------------------------------
  test('REMINDER_SENT event does not affect balance', () async {
    await repo.addEvent(
      shopId: shopId,
      eventType: EventType.credit,
      partyType: PartyType.customer,
      partyId: customerId,
      amountPaisa: 25000,
      deviceId: deviceId,
    );
    await repo.addEvent(
      shopId: shopId,
      eventType: EventType.reminderSent,
      partyType: PartyType.customer,
      partyId: customerId,
      amountPaisa: 0,
      deviceId: deviceId,
    );

    final balance = await repo.computeBalance(customerId, PartyType.customer);
    expect(balance, 25000);
  });

  // -------------------------------------------------------------------------
  // 8. amountPaisa is stored and retrieved as int — never double
  // -------------------------------------------------------------------------
  test('amountPaisa is stored as int (never double)', () async {
    await repo.addEvent(
      shopId: shopId,
      eventType: EventType.credit,
      partyType: PartyType.customer,
      partyId: customerId,
      amountPaisa: 150000,
      deviceId: deviceId,
    );

    final rows = await db.select(db.events).get();
    expect(rows.first.amountPaisa, isA<int>());
    expect(rows.first.amountPaisa, 150000);
  });

  // -------------------------------------------------------------------------
  // 9. watchEvents stream emits updated list after new event added
  // -------------------------------------------------------------------------
  test('watchEvents stream emits updated list after new event added',
      () async {
    final stream = repo.watchEvents(customerId, PartyType.customer);

    // Collect first emission before inserting — should be empty.
    final firstEmission = await stream.first;
    expect(firstEmission, isEmpty);

    // Now insert and collect second emission.
    await repo.addEvent(
      shopId: shopId,
      eventType: EventType.credit,
      partyType: PartyType.customer,
      partyId: customerId,
      amountPaisa: 10000,
      deviceId: deviceId,
    );

    final secondEmission = await stream.first;
    expect(secondEmission.length, 1);
    expect(secondEmission.first.amountPaisa, 10000);
  });
}
