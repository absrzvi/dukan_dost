// ignore_for_file: avoid_relative_lib_imports

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/constants/app_strings.dart';
import '../../../lib/core/constants/event_constants.dart';
import '../../../lib/core/database/app_database.dart';
import '../../../lib/core/providers/database_provider.dart';
import '../../../lib/features/transactions/providers/transactions_provider.dart';
import '../../../lib/features/transactions/repositories/event_repository.dart';
import '../../../lib/features/transactions/screens/payment_entry_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase _makeDb() => AppDatabase.forTesting(NativeDatabase.memory());

Override _dbOverride(AppDatabase db) =>
    appDatabaseProvider.overrideWithValue(db);

// ---------------------------------------------------------------------------
// PaymentEntryScreen widget tests
// ---------------------------------------------------------------------------

void main() {
  group('PaymentEntryScreen', () {
    testWidgets('renders customer name and balance', (tester) async {
      final db = _makeDb();
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _dbOverride(db),
            customerBalanceProvider('cust-001')
                .overrideWith((ref) async => 10000), // PKR 100
            currentShopIdProvider.overrideWith((ref) async => 'shop-001'),
          ],
          child: const MaterialApp(
            home: PaymentEntryScreen(
              customerId: 'cust-001',
              customerName: 'علی بھائی',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('علی بھائی'), findsOneWidget);
      // Balance is displayed somewhere on screen
      expect(find.textContaining('PKR'), findsWidgets);
    });

    testWidgets('save button is disabled when amountPaisa == 0',
        (tester) async {
      final db = _makeDb();
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _dbOverride(db),
            customerBalanceProvider('cust-001')
                .overrideWith((ref) async => 10000),
            currentShopIdProvider.overrideWith((ref) async => 'shop-001'),
          ],
          child: const MaterialApp(
            home: PaymentEntryScreen(
              customerId: 'cust-001',
              customerName: 'علی بھائی',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final saveButton =
          find.widgetWithText(ElevatedButton, AppStrings.saveButton);
      expect(saveButton, findsOneWidget);

      final btn = tester.widget<ElevatedButton>(saveButton);
      expect(btn.onPressed, isNull);
    });

    testWidgets('save button is disabled when amount > currentBalance',
        (tester) async {
      final db = _makeDb();
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _dbOverride(db),
            customerBalanceProvider('cust-002')
                .overrideWith((ref) async => 5000), // PKR 50
            currentShopIdProvider.overrideWith((ref) async => 'shop-001'),
          ],
          child: const MaterialApp(
            home: PaymentEntryScreen(
              customerId: 'cust-002',
              customerName: 'ظفر علی',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Type an amount larger than balance: 100 (PKR) = 10000 paisa > 5000
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();

      // Save button should be ENABLED (overpayment is now allowed per story spec)
      final saveButton =
          find.widgetWithText(ElevatedButton, AppStrings.saveButton);
      expect(saveButton, findsOneWidget);

      final btn = tester.widget<ElevatedButton>(saveButton);
      expect(btn.onPressed, isNotNull);

      // Overpayment warning text should be visible
      expect(find.text(AppStrings.amountExceedsBalance), findsOneWidget);
    });

    testWidgets('save button enabled when 0 < amount <= currentBalance',
        (tester) async {
      final db = _makeDb();
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _dbOverride(db),
            customerBalanceProvider('cust-003')
                .overrideWith((ref) async => 20000), // PKR 200
            currentShopIdProvider.overrideWith((ref) async => 'shop-001'),
          ],
          child: const MaterialApp(
            home: PaymentEntryScreen(
              customerId: 'cust-003',
              customerName: 'احمد بھائی',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Type PKR 100 = 10000 paisa (within balance of 20000)
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();

      final saveButton =
          find.widgetWithText(ElevatedButton, AppStrings.saveButton);
      expect(saveButton, findsOneWidget);

      final btn = tester.widget<ElevatedButton>(saveButton);
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('partial payment badge shown when amount < balance',
        (tester) async {
      final db = _makeDb();
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _dbOverride(db),
            customerBalanceProvider('cust-partial')
                .overrideWith((ref) async => 20000), // PKR 200
            currentShopIdProvider.overrideWith((ref) async => 'shop-001'),
          ],
          child: const MaterialApp(
            home: PaymentEntryScreen(
              customerId: 'cust-partial',
              customerName: 'جزوی گاہک',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter PKR 100 = 10000 paisa (less than balance of 20000)
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();

      // Partial payment badge should be visible
      expect(find.text(AppStrings.partialPayment), findsOneWidget);
    });

    testWidgets('after save PAYMENT event is created with correct amountPaisa',
        (tester) async {
      final db = _makeDb();
      addTearDown(db.close);

      // Seed a CREDIT event via repository so balance == 15000
      const shopId = 'shop-001';
      const customerId = 'cust-pay-001';
      final repo = EventRepository(database: db);
      await repo.addEvent(
        shopId: shopId,
        eventType: EventType.credit,
        partyType: PartyType.customer,
        partyId: customerId,
        amountPaisa: 15000,
        deviceId: 'dev-001',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _dbOverride(db),
            // Use the real balance from the seeded data
            currentShopIdProvider.overrideWith((ref) async => shopId),
          ],
          child: const MaterialApp(
            home: PaymentEntryScreen(
              customerId: customerId,
              customerName: 'ٹیسٹ گاہک',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter PKR 100 = 10000 paisa (within balance of 15000)
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();

      // Scroll down to reveal the Save button and tap it
      await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, AppStrings.saveButton));
      await tester.pump();
      await tester.tap(
          find.widgetWithText(ElevatedButton, AppStrings.saveButton),
          warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Check PAYMENT event was written to DB
      final events = await db.select(db.events).get();
      final paymentEvents = events
          .where((e) => e.eventType == 'PAYMENT' && e.partyId == customerId)
          .toList();
      expect(paymentEvents, hasLength(1));
      expect(paymentEvents.first.amountPaisa, 10000);
    });

    testWidgets(
        'full payment (amount == balance) triggers hisaab saaf overlay',
        (tester) async {
      final db = _makeDb();
      addTearDown(db.close);

      const shopId = 'shop-001';
      const customerId = 'cust-full-pay';
      final repo = EventRepository(database: db);
      // Seed exactly PKR 100 = 10000 paisa credit
      await repo.addEvent(
        shopId: shopId,
        eventType: EventType.credit,
        partyType: PartyType.customer,
        partyId: customerId,
        amountPaisa: 10000,
        deviceId: 'dev-001',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _dbOverride(db),
            currentShopIdProvider.overrideWith((ref) async => shopId),
          ],
          child: const MaterialApp(
            home: PaymentEntryScreen(
              customerId: customerId,
              customerName: 'پورا ادائیگی گاہک',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter exactly PKR 100 = 10000 paisa (equal to balance)
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();

      await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, AppStrings.saveButton));
      await tester.pump();
      await tester.tap(
          find.widgetWithText(ElevatedButton, AppStrings.saveButton),
          warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // HisaabSaafOverlay should be shown (hisaabSaaf string visible)
      expect(find.text(AppStrings.hisaabSaaf), findsOneWidget);
    });

    testWidgets('overpayment (amount > balance) shows overpayment warning',
        (tester) async {
      final db = _makeDb();
      addTearDown(db.close);

      const shopId = 'shop-001';
      const customerId = 'cust-overpay';
      final repo = EventRepository(database: db);
      // Seed PKR 50 = 5000 paisa credit
      await repo.addEvent(
        shopId: shopId,
        eventType: EventType.credit,
        partyType: PartyType.customer,
        partyId: customerId,
        amountPaisa: 5000,
        deviceId: 'dev-001',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _dbOverride(db),
            currentShopIdProvider.overrideWith((ref) async => shopId),
          ],
          child: const MaterialApp(
            home: PaymentEntryScreen(
              customerId: customerId,
              customerName: 'زیادہ ادائیگی گاہک',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter PKR 100 = 10000 paisa (more than balance of 5000)
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();

      await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, AppStrings.saveButton));
      await tester.pump();
      await tester.tap(
          find.widgetWithText(ElevatedButton, AppStrings.saveButton),
          warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Overpayment snackbar should be shown
      expect(find.text(AppStrings.overpaymentWarning), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // WhatsApp template substitution unit test
  // ---------------------------------------------------------------------------

  group('WhatsApp payment template', () {
    test('substitution produces correct message', () {
      const template = AppStrings.whatsappPaymentTemplate;
      final message = template
          .replaceAll('{amount}', 'PKR 100')
          .replaceAll('{remaining}', 'PKR 50')
          .replaceAll('{shopName}', 'راشد اسٹور');

      expect(message, contains('PKR 100'));
      expect(message, contains('PKR 50'));
      expect(message, contains('راشد اسٹور'));
      expect(message, isNot(contains('{amount}')));
      expect(message, isNot(contains('{remaining}')));
      expect(message, isNot(contains('{shopName}')));
    });
  });
}
