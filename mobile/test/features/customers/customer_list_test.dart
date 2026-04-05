// ignore_for_file: avoid_relative_lib_imports

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/constants/event_constants.dart';
import '../../../lib/core/database/app_database.dart';
import '../../../lib/features/customers/providers/customers_provider.dart';
import '../../../lib/features/customers/repositories/customers_repository.dart';
import '../../../lib/features/customers/screens/customer_list_screen.dart';
import '../../../lib/features/transactions/providers/transactions_provider.dart';

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

/// Seed a CREDIT event for a customer.
Future<void> _seedCredit(
  AppDatabase db, {
  required String shopId,
  required String customerId,
  required int amountPaisa,
  String deviceId = 'test-device',
}) async {
  await db.eventsDao.insertEvent(
    id: 'evt-${DateTime.now().microsecondsSinceEpoch}',
    shopId: shopId,
    eventType: EventType.credit,
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
  // 4. CustomerListScreen widget tests
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
