// ignore_for_file: avoid_relative_lib_imports

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/constants/event_constants.dart';
import '../../../lib/core/database/app_database.dart';
import '../../../lib/core/providers/database_provider.dart';
import '../../../lib/features/customers/providers/customers_provider.dart';
import '../../../lib/features/customers/repositories/customers_repository.dart';
import '../../../lib/features/customers/screens/customer_list_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase _makeDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// Seed a single customer row and return its id.
Future<String> _seedCustomer(
  AppDatabase db, {
  required String shopId,
  required String name,
  String? phone,
  int isFlagged = 0,
}) async {
  final repo = CustomersRepository(
    db: db,
    customersDao: db.customersDao,
    eventsDao: db.eventsDao,
  );
  final c = await repo.createCustomer(
    shopId: shopId,
    name: name,
    phone: phone,
  );
  if (isFlagged == 1) {
    await repo.updateCustomer(customerId: c.id, isFlagged: 1);
  }
  return c.id;
}

/// Seed a CREDIT event for a customer, with optional custom timestamp.
Future<void> _seedCredit(
  AppDatabase db, {
  required String shopId,
  required String customerId,
  required int amountPaisa,
  String deviceId = 'test-device',
  DateTime? at,
}) async {
  final ts = (at ?? DateTime.now()).millisecondsSinceEpoch;
  await db.eventsDao.insertEvent(
    id: 'evt-${ts}_${customerId.hashCode}',
    shopId: shopId,
    eventType: EventType.credit,
    partyType: PartyType.customer,
    partyId: customerId,
    amountPaisa: amountPaisa,
    deviceId: deviceId,
    deviceTimestamp: ts,
  );
}

/// Seed a PAYMENT event for a customer.
// ignore: unused_element
Future<void> _seedPayment(
  AppDatabase db, {
  required String shopId,
  required String customerId,
  required int amountPaisa,
  String deviceId = 'test-device',
}) async {
  await db.eventsDao.insertEvent(
    id: 'pmt-${DateTime.now().microsecondsSinceEpoch}',
    shopId: shopId,
    eventType: EventType.payment,
    partyType: PartyType.customer,
    partyId: customerId,
    amountPaisa: amountPaisa,
    deviceId: deviceId,
    deviceTimestamp: DateTime.now().millisecondsSinceEpoch,
  );
}

/// Returns an override for [appDatabaseProvider] that uses an in-memory DB.
Override _dbOverride(AppDatabase db) {
  return appDatabaseProvider.overrideWithValue(db);
}

// ---------------------------------------------------------------------------
// Unit tests — provider logic (no Flutter widget pump needed)
// ---------------------------------------------------------------------------

void main() {
  const shopId = 'shop-test-001';

  // -------------------------------------------------------------------------
  // 1. filteredCustomersProvider filters by search query
  // -------------------------------------------------------------------------
  group('filteredCustomersProvider', () {
    test('filters customers by name (case-insensitive)', () async {
      final db = _makeDb();
      addTearDown(db.close);

      await _seedCustomer(db, shopId: shopId, name: 'علی احمد');
      await _seedCustomer(db, shopId: shopId, name: 'Usman Khan');

      final container = ProviderContainer(overrides: [_dbOverride(db)]);
      addTearDown(container.dispose);

      // Wait for the stream to load
      await container
          .read(customersWithBalancesProvider(shopId).future);

      // Filter by "usman"
      container.read(customerSearchQueryProvider.notifier).state = 'usman';

      final filtered = container.read(filteredCustomersProvider(shopId));
      expect(filtered.length, 1);
      expect(filtered.first.customer.name, 'Usman Khan');
    });

    test('returns all customers when search query is empty', () async {
      final db = _makeDb();
      addTearDown(db.close);

      await _seedCustomer(db, shopId: shopId, name: 'احمد');
      await _seedCustomer(db, shopId: shopId, name: 'بلال');

      final container = ProviderContainer(overrides: [_dbOverride(db)]);
      addTearDown(container.dispose);

      await container.read(customersWithBalancesProvider(shopId).future);

      final filtered = container.read(filteredCustomersProvider(shopId));
      expect(filtered.length, 2);
    });
  });

  // -------------------------------------------------------------------------
  // 2. sort by balanceDesc orders correctly
  // -------------------------------------------------------------------------
  group('sort by balanceDesc', () {
    test('orders customers by descending balance', () async {
      final db = _makeDb();
      addTearDown(db.close);

      final idA = await _seedCustomer(db, shopId: shopId, name: 'A');
      final idB = await _seedCustomer(db, shopId: shopId, name: 'B');

      await _seedCredit(db,
          shopId: shopId, customerId: idA, amountPaisa: 10000);
      await _seedCredit(db,
          shopId: shopId, customerId: idB, amountPaisa: 50000);

      final container = ProviderContainer(overrides: [_dbOverride(db)]);
      addTearDown(container.dispose);

      container.read(customerSortProvider.notifier).state =
          CustomerSort.balanceDesc;

      await container.read(customersWithBalancesProvider(shopId).future);

      final sorted = container.read(filteredCustomersProvider(shopId));
      expect(sorted.length, 2);
      expect(sorted[0].balancePaisa, greaterThan(sorted[1].balancePaisa));
      expect(sorted[0].customer.name, 'B');
    });
  });

  // -------------------------------------------------------------------------
  // 3. totalOwedProvider sums only positive balances
  // -------------------------------------------------------------------------
  group('totalOwedProvider', () {
    test('sums only customers with positive balance', () async {
      final db = _makeDb();
      addTearDown(db.close);

      final idA = await _seedCustomer(db, shopId: shopId, name: 'A');
      final idB = await _seedCustomer(db, shopId: shopId, name: 'B');
      // C has no events — balance = 0
      await _seedCustomer(db, shopId: shopId, name: 'C');

      await _seedCredit(db,
          shopId: shopId, customerId: idA, amountPaisa: 20000);
      await _seedCredit(db,
          shopId: shopId, customerId: idB, amountPaisa: 30000);

      final container = ProviderContainer(overrides: [_dbOverride(db)]);
      addTearDown(container.dispose);

      await container.read(customersWithBalancesProvider(shopId).future);

      final total = container.read(totalOwedProvider(shopId));
      expect(total, 50000);
    });

    test('returns 0 when no customers have positive balance', () async {
      final db = _makeDb();
      addTearDown(db.close);

      await _seedCustomer(db, shopId: shopId, name: 'Zero');

      final container = ProviderContainer(overrides: [_dbOverride(db)]);
      addTearDown(container.dispose);

      await container.read(customersWithBalancesProvider(shopId).future);

      final total = container.read(totalOwedProvider(shopId));
      expect(total, 0);
    });
  });

  // -------------------------------------------------------------------------
  // 4. Flagged customer appears before unflagged with higher balance (AC6)
  // -------------------------------------------------------------------------
  group('AC6 — flagged customers sort first', () {
    test('flagged customer appears before unflagged with higher balance',
        () async {
      final db = _makeDb();
      addTearDown(db.close);

      // unflagged customer with big balance
      final idHighBalance =
          await _seedCustomer(db, shopId: shopId, name: 'High Balance');
      await _seedCredit(db,
          shopId: shopId, customerId: idHighBalance, amountPaisa: 999999);

      // flagged customer with small balance
      final idFlagged = await _seedCustomer(db,
          shopId: shopId, name: 'Flagged Low', isFlagged: 1);
      await _seedCredit(db,
          shopId: shopId, customerId: idFlagged, amountPaisa: 100);

      final container = ProviderContainer(overrides: [_dbOverride(db)]);
      addTearDown(container.dispose);

      await container.read(customersWithBalancesProvider(shopId).future);

      final sorted = container.read(filteredCustomersProvider(shopId));
      expect(sorted.length, 2);
      expect(sorted[0].customer.isFlagged, 1,
          reason: 'flagged customer should come first');
      expect(sorted[1].customer.isFlagged, 0);
    });
  });

  // -------------------------------------------------------------------------
  // 5. Sort by balanceAsc orders correctly
  // -------------------------------------------------------------------------
  group('sort by balanceAsc', () {
    test('orders customers by ascending balance (lowest first)', () async {
      final db = _makeDb();
      addTearDown(db.close);

      final idA = await _seedCustomer(db, shopId: shopId, name: 'A');
      final idB = await _seedCustomer(db, shopId: shopId, name: 'B');
      final idC = await _seedCustomer(db, shopId: shopId, name: 'C');

      await _seedCredit(db,
          shopId: shopId, customerId: idA, amountPaisa: 30000);
      await _seedCredit(db,
          shopId: shopId, customerId: idB, amountPaisa: 10000);
      await _seedCredit(db,
          shopId: shopId, customerId: idC, amountPaisa: 20000);

      final container = ProviderContainer(overrides: [_dbOverride(db)]);
      addTearDown(container.dispose);

      container.read(customerSortProvider.notifier).state =
          CustomerSort.balanceAsc;
      await container.read(customersWithBalancesProvider(shopId).future);

      final sorted = container.read(filteredCustomersProvider(shopId));
      expect(sorted.length, 3);
      expect(sorted[0].balancePaisa,
          lessThanOrEqualTo(sorted[1].balancePaisa));
      expect(sorted[1].balancePaisa,
          lessThanOrEqualTo(sorted[2].balancePaisa));
      expect(sorted[0].customer.name, 'B');
    });
  });

  // -------------------------------------------------------------------------
  // 6. Sort by nameAsc orders alphabetically
  // -------------------------------------------------------------------------
  group('sort by nameAsc', () {
    test('orders customers alphabetically by name', () async {
      final db = _makeDb();
      addTearDown(db.close);

      await _seedCustomer(db, shopId: shopId, name: 'Zara');
      await _seedCustomer(db, shopId: shopId, name: 'Ahmed');
      await _seedCustomer(db, shopId: shopId, name: 'Bilal');

      final container = ProviderContainer(overrides: [_dbOverride(db)]);
      addTearDown(container.dispose);

      container.read(customerSortProvider.notifier).state =
          CustomerSort.nameAsc;
      await container.read(customersWithBalancesProvider(shopId).future);

      final sorted = container.read(filteredCustomersProvider(shopId));
      expect(sorted.length, 3);
      final names = sorted.map((c) => c.customer.name).toList();
      expect(names, ['Ahmed', 'Bilal', 'Zara']);
    });
  });

  // -------------------------------------------------------------------------
  // 7. isOverdue7Plus — 8-day-old credit with positive balance
  // -------------------------------------------------------------------------
  group('isOverdue7Plus', () {
    test(
        'customer with 8-day-old credit and positive balance has daysOverdue >= 7',
        () async {
      final db = _makeDb();
      addTearDown(db.close);

      final custId =
          await _seedCustomer(db, shopId: shopId, name: 'Old Debtor');
      final eightDaysAgo =
          DateTime.now().subtract(const Duration(days: 8));
      await _seedCredit(db,
          shopId: shopId,
          customerId: custId,
          amountPaisa: 5000,
          at: eightDaysAgo);

      final container = ProviderContainer(overrides: [_dbOverride(db)]);
      addTearDown(container.dispose);

      final customers =
          await container.read(customersWithBalancesProvider(shopId).future);
      expect(customers.length, 1);
      final c = customers.first;
      expect(c.daysOverdue, isNotNull);
      expect(c.daysOverdue! >= 7, isTrue,
          reason: '8-day-old credit should have daysOverdue >= 7');
    });

    test('customer with 6-day-old credit has daysOverdue < 7', () async {
      final db = _makeDb();
      addTearDown(db.close);

      final custId =
          await _seedCustomer(db, shopId: shopId, name: 'Recent Debtor');
      final sixDaysAgo =
          DateTime.now().subtract(const Duration(days: 6));
      await _seedCredit(db,
          shopId: shopId,
          customerId: custId,
          amountPaisa: 5000,
          at: sixDaysAgo);

      final container = ProviderContainer(overrides: [_dbOverride(db)]);
      addTearDown(container.dispose);

      final customers =
          await container.read(customersWithBalancesProvider(shopId).future);
      expect(customers.length, 1);
      final c = customers.first;
      expect(c.daysOverdue, isNotNull);
      expect(c.daysOverdue! < 7, isTrue,
          reason: '6-day-old credit should have daysOverdue < 7');
    });
  });

  // -------------------------------------------------------------------------
  // 8. CustomerListScreen widget tests
  // -------------------------------------------------------------------------
  group('CustomerListScreen widget', () {
    testWidgets('renders empty state when no customers', (tester) async {
      final db = _makeDb();
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [_dbOverride(db)],
          child: const MaterialApp(
            home: CustomerListScreen(shopId: shopId),
          ),
        ),
      );

      // Wait for async stream
      await tester.pumpAndSettle();

      expect(find.textContaining('کوئی گاہک نہیں'), findsOneWidget);
    });

    testWidgets('shows customer name and balance when data is present',
        (tester) async {
      final db = _makeDb();
      addTearDown(db.close);

      final custId =
          await _seedCustomer(db, shopId: shopId, name: 'ظفر علی');
      await _seedCredit(db,
          shopId: shopId, customerId: custId, amountPaisa: 150000);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [_dbOverride(db)],
          child: const MaterialApp(
            home: CustomerListScreen(shopId: shopId),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('ظفر علی'), findsOneWidget);
      // PKR 1,500 formatted
      expect(find.textContaining('PKR 1,500'), findsOneWidget);
    });
  });
}
