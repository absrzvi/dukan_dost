import '../../../core/database/app_database.dart';

/// A customer enriched with a computed balance and activity metadata.
///
/// Iron Rules:
///   - [balancePaisa] is ALWAYS computed from event-log replay — never stored.
///   - Positive [balancePaisa] means the customer owes the shop.
///   - Negative [balancePaisa] means the shop owes the customer (overpaid).
class CustomerWithBalance {
  const CustomerWithBalance({
    required this.customer,
    required this.balancePaisa,
    this.daysOverdue,
    this.lastActivityAt,
  });

  final Customer customer;

  /// Computed balance in integer paisa. Never stored.
  final int balancePaisa;

  /// Days since last CREDIT event when balance > 0; null if no transactions.
  final int? daysOverdue;

  /// DateTime of the most recent event for this customer; null if no events.
  final DateTime? lastActivityAt;
}
