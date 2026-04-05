import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukan_dost/features/onboarding/screens/shop_setup_screen.dart';
import 'package:dukan_dost/core/constants/app_strings.dart';

Widget _buildTestApp() {
  return const ProviderScope(
    child: MaterialApp(
      home: ShopSetupScreen(),
    ),
  );
}

void main() {
  group('ShopSetupScreen', () {
    testWidgets('renders shop name and locality fields', (tester) async {
      await tester.pumpWidget(_buildTestApp());

      // Shop name field
      expect(find.byKey(const Key('shopNameField')), findsOneWidget);

      // Locality field
      expect(find.byKey(const Key('localityField')), findsOneWidget);

      // Labels
      expect(find.text(AppStrings.shopName), findsWidgets);
    });

    testWidgets('submit button is disabled when name is empty', (tester) async {
      await tester.pumpWidget(_buildTestApp());

      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('submitButton')),
      );

      expect(button.onPressed, isNull);
    });

    testWidgets('submit button is enabled when name has text', (tester) async {
      await tester.pumpWidget(_buildTestApp());

      await tester.enterText(
        find.byKey(const Key('shopNameField')),
        'کریم جنرل اسٹور',
      );
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('submitButton')),
      );

      expect(button.onPressed, isNotNull);
    });
  });
}
