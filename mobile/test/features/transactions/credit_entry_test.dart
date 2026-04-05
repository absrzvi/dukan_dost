// ignore_for_file: avoid_relative_lib_imports

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/constants/app_strings.dart';
import '../../../lib/core/database/app_database.dart';
import '../../../lib/core/providers/database_provider.dart';
import '../../../lib/features/transactions/providers/transactions_provider.dart';
import '../../../lib/features/transactions/screens/credit_entry_screen.dart';
import '../../../lib/shared/widgets/amount_keypad.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase _makeDb() => AppDatabase.forTesting(NativeDatabase.memory());

Override _dbOverride(AppDatabase db) =>
    appDatabaseProvider.overrideWithValue(db);

// ---------------------------------------------------------------------------
// AmountKeypad unit-style widget tests
// ---------------------------------------------------------------------------

void main() {
  group('AmountKeypad', () {
    testWidgets('tapping 1-5-0 produces amountPaisa = 15000', (tester) async {
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmountKeypad(
              onAmountChanged: (paisa) => result = paisa,
            ),
          ),
        ),
      );

      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();

      expect(result, 15000);
    });

    testWidgets('backspace removes last digit', (tester) async {
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmountKeypad(
              onAmountChanged: (paisa) => result = paisa,
            ),
          ),
        ),
      );

      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();
      // Backspace removes '5'
      await tester.tap(find.text('⌫'));
      await tester.pump();

      // Now only '1' remains → 100 paisa
      expect(result, 100);
    });

    testWidgets('decimal input 1-5-0-.-5-0 produces amountPaisa = 15050',
        (tester) async {
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmountKeypad(
              onAmountChanged: (paisa) => result = paisa,
            ),
          ),
        ),
      );

      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();
      await tester.tap(find.text('.'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();

      expect(result, 15050);
    });

    testWidgets('result is always int (never double)', (tester) async {
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmountKeypad(
              onAmountChanged: (paisa) => result = paisa,
            ),
          ),
        ),
      );

      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();

      expect(result, isA<int>());
      expect(result, 2500);
    });
  });

  // ---------------------------------------------------------------------------
  // CreditEntryScreen widget tests
  // ---------------------------------------------------------------------------

  group('CreditEntryScreen', () {
    testWidgets('save button is disabled when amountPaisa == 0',
        (tester) async {
      final db = _makeDb();
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _dbOverride(db),
            // Provide resolved values so the screen does not hang in loading
            customerBalanceProvider('cust-001')
                .overrideWith((ref) async => 0),
            currentShopIdProvider.overrideWith((ref) async => 'shop-001'),
          ],
          child: const MaterialApp(
            home: CreditEntryScreen(
              customerId: 'cust-001',
              customerName: 'احمد بھائی',
            ),
          ),
        ),
      );

      // Pump enough frames for the async providers to resolve
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find the ElevatedButton with AppStrings.saveButton text
      final saveButton = find.widgetWithText(ElevatedButton, AppStrings.saveButton);
      expect(saveButton, findsOneWidget);

      final btn = tester.widget<ElevatedButton>(saveButton);
      // onPressed should be null (disabled) when amount is zero
      expect(btn.onPressed, isNull);
    });

    testWidgets('renders customer name', (tester) async {
      final db = _makeDb();
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _dbOverride(db),
            customerBalanceProvider('cust-002')
                .overrideWith((ref) async => 5000),
            currentShopIdProvider.overrideWith((ref) async => 'shop-001'),
          ],
          child: const MaterialApp(
            home: CreditEntryScreen(
              customerId: 'cust-002',
              customerName: 'ظفر علی',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('ظفر علی'), findsOneWidget);
    });
  });
}
