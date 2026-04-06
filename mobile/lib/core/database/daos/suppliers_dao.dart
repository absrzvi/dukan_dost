import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/suppliers_table.dart';

part 'suppliers_dao.g.dart';

/// DAO for the Suppliers table.
///
/// Provides watch, upsert, soft-delete, mark-paid, and single-row lookup.
/// All balance logic lives in EventsDao — never stored on the supplier row.
@DriftAccessor(tables: [Suppliers])
class SuppliersDao extends DatabaseAccessor<AppDatabase>
    with _$SuppliersDaoMixin {
  SuppliersDao(super.db);

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  /// Stream of all non-deleted, non-paid suppliers for a shop,
  /// ordered by due_date ASC (most urgent first), nulls last.
  Stream<List<Supplier>> watchSuppliers(String shopId) {
    return (select(suppliers)
          ..where(
            (s) =>
                s.shopId.equals(shopId) &
                s.isDeleted.equals(0) &
                s.isPaid.equals(0),
          )
          ..orderBy([
            (s) => OrderingTerm(
                  expression: s.dueDate,
                  mode: OrderingMode.asc,
                  nulls: NullsOrder.last,
                ),
          ]))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Insert or update a supplier (upsert by primary key).
  Future<void> upsertSupplier(SuppliersCompanion supplier) async {
    await into(suppliers).insertOnConflictUpdate(supplier);
  }

  /// Mark a supplier as paid — sets is_paid = 1 and updates updated_at.
  Future<void> markPaidSupplier(String supplierId) async {
    await (update(suppliers)..where((s) => s.id.equals(supplierId))).write(
      SuppliersCompanion(
        isPaid: const Value(1),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Soft delete — sets is_deleted = 1 and updates updated_at.
  Future<void> softDeleteSupplier(String supplierId) async {
    await (update(suppliers)..where((s) => s.id.equals(supplierId))).write(
      SuppliersCompanion(
        isDeleted: const Value(1),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Single-row lookup
  // ---------------------------------------------------------------------------

  /// Returns a supplier by id, or null if not found / soft-deleted.
  Future<Supplier?> getSupplier(String supplierId) async {
    return (select(suppliers)
          ..where((s) => s.id.equals(supplierId) & s.isDeleted.equals(0)))
        .getSingleOrNull();
  }
}
