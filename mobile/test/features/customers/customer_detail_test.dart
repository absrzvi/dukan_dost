// ignore_for_file: avoid_relative_lib_imports

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/constants/app_strings.dart';
import '../../../lib/core/constants/event_constants.dart';
import '../../../lib/core/database/app_database.dart';
import '../../../lib/core/providers/database_provider.dart';
import '../../../lib/features/customers/screens/customer_detail_screen.dart';
import '../../../lib/features/customers/widgets/event_bubble.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase _makeDb() => AppDatabase.forTesting(NativeDatabase.memory());

Override _dbOverride(AppDatabase db) =>
    appDatabaseProvider.overrideWithValue(db);

Future<String> _seedShopAndCustomer(AppDatabase db) async {
  const shopId = 'shop-test-001';
  const customerId = 'cust-test-001';
  final now = DateTime.now().millisecondsSinceEpoch;

  await db.into(db.shops).insert(ShopsCompanion.insert(
        id: shopId,
        name: 'Test Shop',
        phone: '03001234567',
        deviceId: 'test-device',
        sessionToken: 'test-token',
        createdAt: now,
        updatedAt: now,
      ));

  await db.into(db.customers).insert(CustomersCompanion.insert(
        id: customerId,
        shopId: shopId,
        name: 'Test Customer',
        phone: const Value(null),
        createdAt: now,
        updatedAt: now,
      ));

  return customerId;
}

Future<void> _seedCreditEvent(
  AppDatabase db,
  String customerId, {
  int amountPaisa = 100000,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.eventsDao.insertEvent(
    id: 'evt-credit-$now',
    shopId: 'shop-test-001',
    eventType: EventType.credit,
    partyType: PartyType.customer,
    partyId: customerId,
    amountPaisa: amountPaisa,
    deviceId: 'test-device',
    deviceTimestamp: now,
  );
}

Future<void> _seedPaymentEvent(
  AppDatabase db,
  String customerId, {
  int amountPaisa = 50000,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch + 1;
  await db.eventsDao.insertEvent(
    id: 'evt-payment-$now',
    shopId: 'shop-test-001',
    eventType: EventType.payment,
    partyType: PartyType.customer,
    partyId: customerId,
    amountPaisa: amountPaisa,
    deviceId: 'test-device',
    deviceTimestamp: now,
  );
}

Widget _buildScreen(
  AppDatabase db, {
  String customerId = 'cust-test-001',
  String customerName = 'Test Customer',
  String? customerPhone,
}) {
  return ProviderScope(
    overrides: [_dbOverride(db)],
    child: MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: CustomerDetailScreen(
          customerId: customerId,
          customerName: customerName,
          customerPhone: customerPhone,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. CustomerDetailScreen renders customer name in AppBar
  // -------------------------------------------------------------------------
  testWidgets('renders customer name in AppBar', (tester) async {
    final db = _makeDb();
    addTearDown(db.close);
    await _seedShopAndCustomer(db);

    await tester.pumpWidget(_buildScreen(db, customerName: 'علی احمد'));
    await tester.pumpAndSettle();

    expect(find.text('علی احمد'), findsAtLeastNWidgets(1));
  });

  // -------------------------------------------------------------------------
  // 2. Empty state renders AppStrings.noTransactions when no events
  // -------------------------------------------------------------------------
  testWidgets('shows noTransactions empty state when no events', (tester) async {
    final db = _makeDb();
    addTearDown(db.close);
    await _seedShopAndCustomer(db);

    await tester.pumpWidget(_buildScreen(db));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.noTransactions), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. CREDIT event bubble is right-aligned (AlignmentDirectional.centerEnd)
  // -------------------------------------------------------------------------
  testWidgets('CREDIT event bubble is right-aligned', (tester) async {
    final db = _makeDb();
    addTearDown(db.close);
    final customerId = await _seedShopAndCustomer(db);
    await _seedCreditEvent(db, customerId);

    await tester.pumpWidget(_buildScreen(db, customerId: customerId));
    await tester.pumpAndSettle();

    // Find the Align widget inside EventBubble for CREDIT
    final alignFinder = find.descendant(
      of: find.byType(EventBubble),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Align &&
            w.alignment == AlignmentDirectional.centerEnd,
      ),
    );
    expect(alignFinder, findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. PAYMENT event bubble is left-aligned (AlignmentDirectional.centerStart)
  // -------------------------------------------------------------------------
  testWidgets('PAYMENT event bubble is left-aligned', (tester) async {
    final db = _makeDb();
    addTearDown(db.close);
    final customerId = await _seedShopAndCustomer(db);
    await _seedPaymentEvent(db, customerId);

    await tester.pumpWidget(_buildScreen(db, customerId: customerId));
    await tester.pumpAndSettle();

    final alignFinder = find.descendant(
      of: find.byType(EventBubble),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Align &&
            w.alignment == AlignmentDirectional.centerStart,
      ),
    );
    expect(alignFinder, findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Balance header shows red colour when balance > 0
  // -------------------------------------------------------------------------
  testWidgets('balance header shows red when balance is positive',
      (tester) async {
    final db = _makeDb();
    addTearDown(db.close);
    final customerId = await _seedShopAndCustomer(db);
    await _seedCreditEvent(db, customerId, amountPaisa: 100000);

    await tester.pumpWidget(_buildScreen(db, customerId: customerId));
    await tester.pumpAndSettle();

    // Find the large balance Text widget and verify its colour is red
    final balanceTextFinder = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.style != null &&
          w.style!.color == const Color(0xFFD32F2F) && // AppColors.balancePositive
          (w.style!.fontSize ?? 0) >= 24,
    );
    expect(balanceTextFinder, findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 6. Both action buttons (credit and payment) are present
  // -------------------------------------------------------------------------
  testWidgets('credit and payment action buttons are present', (tester) async {
    final db = _makeDb();
    addTearDown(db.close);
    await _seedShopAndCustomer(db);

    await tester.pumpWidget(_buildScreen(db));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('credit_button')), findsOneWidget);
    expect(find.byKey(const Key('payment_button')), findsOneWidget);
  });
}
