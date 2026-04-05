import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukan_dost/app.dart';

void main() {
  testWidgets('App renders دکان دوست text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: DukaanDostApp()),
    );
    expect(find.text('دکان دوست'), findsWidgets);
  });
}
