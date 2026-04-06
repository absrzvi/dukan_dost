import '../../../core/database/app_database.dart';

/// A supplier enriched with a computed balance from the event log.
///
/// Iron Rules:
///   - [balancePaisa] is ALWAYS computed from event-log replay — never stored.
///   - Positive [balancePaisa] means the shop owes the supplier.
class SupplierWithBalance {
  const SupplierWithBalance({
    required this.supplier,
    required this.balancePaisa,
    this.dueDateAt,
  });

  final Supplier supplier;

  /// Computed balance in integer paisa. Never stored.
  /// Positive value = shop owes supplier.
  final int balancePaisa;

  /// Due date parsed from supplier.dueDate (epoch millis), or null.
  final DateTime? dueDateAt;

  /// True if due date is set and is before now (past due).
  bool get isOverdue =>
      dueDateAt != null && dueDateAt!.isBefore(DateTime.now());
}
