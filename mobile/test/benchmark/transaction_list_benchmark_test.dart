import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Mock transaction model for benchmark purposes
class MockTransaction {
  final String id;
  final String customerName;
  final int amountPaisa; // Always integer paisa — no floats
  final String eventType; // 'CREDIT' or 'PAYMENT'
  final DateTime timestamp;
  final String? note;

  const MockTransaction({
    required this.id,
    required this.customerName,
    required this.amountPaisa,
    required this.eventType,
    required this.timestamp,
    this.note,
  });
}

// Generate 500 mock transactions
List<MockTransaction> generateMockTransactions(int count) {
  return List.generate(count, (i) {
    final isCredit = i % 3 != 0;
    return MockTransaction(
      id: 'event-$i',
      customerName: 'Customer ${i % 50}', // 50 unique customers
      amountPaisa: (i + 1) * 5000, // e.g. PKR 50, 100, 150...
      eventType: isCredit ? 'CREDIT' : 'PAYMENT',
      timestamp: DateTime.now().subtract(Duration(days: i)),
      note: i % 5 == 0 ? 'Note for transaction $i' : null,
    );
  });
}

// Widget that renders the transaction list (mirrors the chat-thread design)
class TransactionListWidget extends StatelessWidget {
  final List<MockTransaction> transactions;

  const TransactionListWidget({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Ahmed bhai'),
          // Running balance pinned at top — design principle from PRD
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: Colors.green.shade50,
              padding: const EdgeInsets.all(8),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: Text('کل باقی', style: TextStyle(fontSize: 14))),
                  Flexible(
                    child: Text(
                      'PKR 1,500',
                      style: TextStyle(
                        fontSize: 24, // Numbers are dominant — design principle
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: ListView.builder(
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final tx = transactions[index];
            final isCredit = tx.eventType == 'CREDIT';

            // Chat-thread layout: credit on right, payment on left
            return Align(
              alignment:
                  isCredit ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxWidth: 280),
                decoration: BoxDecoration(
                  color: isCredit ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PKR ${(tx.amountPaisa / 100).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20, // Numbers are dominant
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      tx.timestamp.toString().substring(0, 16),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    if (tx.note != null)
                      Text(
                        tx.note!,
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

void main() {
  group('Transaction List Benchmark', () {
    testWidgets(
      'renders 500 transactions without errors',
      (WidgetTester tester) async {
        // Generate 500 mock transactions
        final transactions = generateMockTransactions(500);
        expect(transactions.length, equals(500));

        // Set a realistic mobile viewport (375 logical px wide — design target)
        // physicalSize = logical size * devicePixelRatio
        tester.view.physicalSize = const Size(750, 1624);
        tester.view.devicePixelRatio = 2.0;

        final stopwatch = Stopwatch()..start();

        // Pump the widget
        await tester.pumpWidget(
          TransactionListWidget(transactions: transactions),
        );

        stopwatch.stop();

        // Verify the list renders without overflow errors
        expect(tester.takeException(), isNull);

        // Verify key UI elements are present
        expect(find.text('Ahmed bhai'), findsOneWidget);
        expect(find.text('کل باقی'), findsOneWidget); // Urdu label

        // Verify at least some transaction items are rendered (visible viewport)
        expect(find.byType(ListView), findsOneWidget);

        // Log build time for manual review
        // ignore: avoid_print
        print('✅ 500-transaction list build time: ${stopwatch.elapsedMilliseconds}ms');
        // ignore: avoid_print
        print('✅ NOTE: 60fps smoothness must be validated manually on a physical Tecno Spark or equivalent low-end Android device before STORY-002 begins.');
      },
    );

    testWidgets(
      'monetary amounts are never displayed as floats',
      (WidgetTester tester) async {
        final transactions = [
          MockTransaction(
            id: 'test-1',
            customerName: 'Test Customer',
            amountPaisa: 150000, // PKR 1,500 — should display as "1500" not "1500.0"
            eventType: 'CREDIT',
            timestamp: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(
          TransactionListWidget(transactions: transactions),
        );

        // Amount should display as integer, never as float
        expect(find.text('PKR 1500'), findsOneWidget);
        expect(find.textContaining('1500.0'), findsNothing);
      },
    );

    test('mock transaction uses integer paisa — no floating point', () {
      final tx = MockTransaction(
        id: 'test-paisa',
        customerName: 'Ahmed bhai',
        amountPaisa: 75050, // PKR 750.50
        eventType: 'CREDIT',
        timestamp: DateTime.now(),
      );

      // amountPaisa must be an integer type
      expect(tx.amountPaisa, isA<int>());
      expect(tx.amountPaisa, equals(75050));
    });
  });
}
