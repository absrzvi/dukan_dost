import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/daos/suppliers_dao.dart';
import '../../../core/providers/database_provider.dart';
import '../models/supplier_with_balance.dart';
import '../repositories/suppliers_repository.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Provides a [SuppliersDao] backed by the shared AppDatabase singleton.
final suppliersDaoProvider = Provider<SuppliersDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.suppliersDao;
});

/// Provides the [SuppliersRepository] singleton.
final suppliersRepositoryProvider = Provider<SuppliersRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SuppliersRepository(
    db: db,
    suppliersDao: db.suppliersDao,
    eventsDao: db.eventsDao,
  );
});

/// Stream of all active suppliers with computed balances for a shop.
final suppliersWithBalancesProvider =
    StreamProvider.autoDispose.family<List<SupplierWithBalance>, String>(
        (ref, shopId) {
  final repo = ref.watch(suppliersRepositoryProvider);
  return repo.watchSuppliersWithBalances(shopId);
});

/// Sum of all positive balances (shop owes these suppliers) in paisa.
final totalOwedToSuppliersProvider =
    Provider.autoDispose.family<int, String>((ref, shopId) {
  final asyncData = ref.watch(suppliersWithBalancesProvider(shopId));
  final suppliers = asyncData.valueOrNull ?? [];
  return suppliers
      .where((s) => s.balancePaisa > 0)
      .fold<int>(0, (sum, s) => sum + s.balancePaisa);
});

/// Count of overdue suppliers (due date in the past).
final overdueSupplierCountProvider =
    Provider.autoDispose.family<int, String>((ref, shopId) {
  final asyncData = ref.watch(suppliersWithBalancesProvider(shopId));
  final suppliers = asyncData.valueOrNull ?? [];
  return suppliers.where((s) => s.isOverdue).length;
});
