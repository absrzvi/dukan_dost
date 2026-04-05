import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/customers_table.dart';

part 'customers_dao.g.dart';

/// DAO for the Customers table.
///
/// Provides watch, upsert, soft-delete, and single-row lookup.
/// All balance logic lives in EventsDao — never stored on the customer row.
@DriftAccessor(tables: [Customers])
class CustomersDao extends DatabaseAccessor<AppDatabase>
    with _$CustomersDaoMixin {
  CustomersDao(super.db);

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  /// Stream of all non-deleted customers for a shop, ordered by name.
  Stream<List<Customer>> watchCustomers(String shopId) {
    return (select(customers)
          ..where((c) => c.shopId.equals(shopId) & c.isDeleted.equals(0))
          ..orderBy([(c) => OrderingTerm(expression: c.name)]))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Insert or update a customer (upsert by primary key).
  Future<void> upsertCustomer(CustomersCompanion customer) async {
    await into(customers).insertOnConflictUpdate(customer);
  }

  /// Soft delete — sets is_deleted = 1 and updates updated_at.
  Future<void> softDeleteCustomer(String customerId) async {
    await (update(customers)..where((c) => c.id.equals(customerId))).write(
      CustomersCompanion(
        isDeleted: const Value(1),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Single-row lookup
  // ---------------------------------------------------------------------------

  /// Returns a customer by id, or null if not found / soft-deleted.
  Future<Customer?> getCustomer(String customerId) async {
    return (select(customers)
          ..where((c) => c.id.equals(customerId) & c.isDeleted.equals(0)))
        .getSingleOrNull();
  }
}
