// ignore_for_file: avoid_relative_lib_imports

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/constants/event_constants.dart';
import '../../../lib/core/database/app_database.dart';
import '../../../lib/core/providers/database_provider.dart';
import '../../../lib/features/suppliers/models/supplier_with_balance.dart';
import '../../../lib/features/suppliers/providers/suppliers_provider.dart';
import '../../../lib/features/suppliers/repositories/suppliers_repository.dart';
import '../../../lib/features/suppliers/screens/suppliers_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase _makeDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// Seed a supplier and return its id.
Future<String> _seedSupplier(
  AppDatabase db, {
  required String shopId,
  required String name,
  String? phone,
  int? initialDebtPaisa,
  DateTime? dueDate,
}) async {
  final repo = SuppliersRepository(
    db: db,
    suppliersDao: db.suppliersDao,
    eventsDao: db.eventsDao,
  );
  final s = await repo.createSupplier(
    shopId: shopId,
    name: name,
    phone: phone,
    dueDate: dueDate,
    initialDebtPaisa: initialDebtPaisa,
  );
  return s.id;
}

/// Returns an override for [appDatabaseProvider] using in-memory DB.
Override _dbOverride(AppDatabase db) =>
    appDatabaseProvider.overrideWithValue(db);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const shopId = 'shop-test-supplier-001';

  // -------------------------------------------------------------------------
  // 1. SuppliersScreen renders empty state
  // -------------------------------------------------------------------------
  group('SuppliersScreen widget', () {
    testWidgets('renders empty state when no suppliers', (tester) async {
      final db = _makeDb();
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [_dbOverride(db)],
          child: const MaterialApp(
            home: SuppliersScreen(shopId: shopId),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('کوئی سپلائر نہیں'), findsOneWidget);
    });

    testWidgets('shows supplier name and balance when data is present',
        (tester) async {
      final db = _makeDb();
      addTearDown(db.close);

      await _seedSupplier(
        db,
        shopId: shopId,
        name: 'حمید سٹور',
        initialDebtPaisa: 200000,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [_dbOverride(db)],
          child: const MaterialApp(
            home: SuppliersScreen(shopId: shopId),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('حمید سٹور'), findsOneWidget);
      // PKR 2,000 formatted
      expect(find.textContaining('PKR 2,000'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 2. SupplierWithBalance.isOverdue
  // -------------------------------------------------------------------------
  group('SupplierWithBalance.isOverdue', () {
    test('isOverdue is true when dueDate is in the past', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 1));
      const supplier = SupplierWithBalance(
        supplier: _FakeSupplier.instance,
        balancePaisa: 10000,
        dueDateAt: null,
      );
      // Use explicit dueDateAt
      final item = SupplierWithBalance(
        supplier: supplier.supplier,
        balancePaisa: 10000,
        dueDateAt: pastDate,
      );
      expect(item.isOverdue, isTrue);
    });

    test('isOverdue is false when dueDate is in the future', () {
      final futureDate = DateTime.now().add(const Duration(days: 5));
      final item = SupplierWithBalance(
        supplier: _FakeSupplier.instance,
        balancePaisa: 10000,
        dueDateAt: futureDate,
      );
      expect(item.isOverdue, isFalse);
    });

    test('isOverdue is false when dueDateAt is null', () {
      const item = SupplierWithBalance(
        supplier: _FakeSupplier.instance,
        balancePaisa: 10000,
        dueDateAt: null,
      );
      expect(item.isOverdue, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // 3. totalOwedToSuppliersProvider sums only positive balances
  // -------------------------------------------------------------------------
  group('totalOwedToSuppliersProvider', () {
    test('sums only suppliers with positive balance', () async {
      final db = _makeDb();
      addTearDown(db.close);

      // Supplier A: owes 200 PKR
      await _seedSupplier(
        db,
        shopId: shopId,
        name: 'سپلائر A',
        initialDebtPaisa: 20000,
      );
      // Supplier B: owes 300 PKR
      await _seedSupplier(
        db,
        shopId: shopId,
        name: 'سپلائر B',
        initialDebtPaisa: 30000,
      );
      // Supplier C: no events → balance 0
      await _seedSupplier(db, shopId: shopId, name: 'سپلائر C');

      final container = ProviderContainer(overrides: [_dbOverride(db)]);
      addTearDown(container.dispose);

      await container.read(suppliersWithBalancesProvider(shopId).future);

      final total = container.read(totalOwedToSuppliersProvider(shopId));
      expect(total, 50000);
    });

    test('returns 0 when no suppliers have positive balance', () async {
      final db = _makeDb();
      addTearDown(db.close);

      await _seedSupplier(db, shopId: shopId, name: 'Zero Supplier');

      final container = ProviderContainer(overrides: [_dbOverride(db)]);
      addTearDown(container.dispose);

      await container.read(suppliersWithBalancesProvider(shopId).future);

      final total = container.read(totalOwedToSuppliersProvider(shopId));
      expect(total, 0);
    });
  });

  // -------------------------------------------------------------------------
  // 4. createSupplier with initialDebt > 0 creates a CREDIT event
  // -------------------------------------------------------------------------
  group('createSupplier with initialDebt', () {
    test('creates a CREDIT event when initialDebtPaisa > 0', () async {
      final db = _makeDb();
      addTearDown(db.close);

      final supplierId = await _seedSupplier(
        db,
        shopId: shopId,
        name: 'مہنگا سپلائر',
        initialDebtPaisa: 50000,
      );

      // Verify a CREDIT event was inserted for this supplier
      final events = await (db.select(db.events)
            ..where(
              (e) => e.partyId.equals(supplierId) &
                  e.partyType.equals(PartyType.supplier) &
                  e.eventType.equals(EventType.credit),
            ))
          .get();

      expect(events.length, 1);
      expect(events.first.amountPaisa, 50000);
    });

    test('does NOT create a CREDIT event when initialDebtPaisa is null',
        () async {
      final db = _makeDb();
      addTearDown(db.close);

      final supplierId = await _seedSupplier(
        db,
        shopId: shopId,
        name: 'خالی سپلائر',
      );

      final events = await (db.select(db.events)
            ..where(
              (e) =>
                  e.partyId.equals(supplierId) &
                  e.partyType.equals(PartyType.supplier),
            ))
          .get();

      expect(events.isEmpty, isTrue);
    });
  });
}

// ---------------------------------------------------------------------------
// Fake Supplier for unit tests that don't need a real DB supplier row.
// ---------------------------------------------------------------------------

class _FakeSupplier {
  const _FakeSupplier._();
  static const Supplier instance = Supplier(
    id: 'fake-supplier-id',
    shopId: 'fake-shop-id',
    name: 'Fake Supplier',
    phone: null,
    invoiceAmountPaisa: 0,
    dueDate: null,
    isPaid: 0,
    createdAt: 0,
    updatedAt: 0,
    isDeleted: 0,
  );
}
