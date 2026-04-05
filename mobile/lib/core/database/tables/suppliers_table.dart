import 'package:drift/drift.dart';

/// Supplier invoices — separate mental model from customer ledger.
@TableIndex(name: 'idx_suppliers_shop', columns: {#shopId})
@TableIndex(name: 'idx_suppliers_due', columns: {#shopId, #dueDate})
class Suppliers extends Table {
  /// Client-generated UUIDv4 — PRIMARY KEY
  TextColumn get id => text()();

  /// Owning shop
  TextColumn get shopId => text()();

  /// Supplier name
  TextColumn get name => text()();

  /// Contact phone
  TextColumn get phone => text().nullable()();

  /// Invoice total in paisa — integer only, never floating point
  IntColumn get invoiceAmountPaisa => integer()();

  /// Unix epoch millis of payment due date
  IntColumn get dueDate => integer().nullable()();

  /// 1 if invoice is marked paid
  IntColumn get isPaid => integer().withDefault(const Constant(0))();

  /// Row creation time (unix epoch millis)
  IntColumn get createdAt => integer()();

  /// Last modification time (unix epoch millis)
  IntColumn get updatedAt => integer()();

  /// Soft delete flag
  IntColumn get isDeleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
