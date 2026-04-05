import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/daos/customers_dao.dart';
import '../../../core/providers/database_provider.dart';
import '../models/customer_with_balance.dart';
import '../repositories/customers_repository.dart';

// ---------------------------------------------------------------------------
// Sort order
// ---------------------------------------------------------------------------

enum CustomerSort { balanceDesc, balanceAsc, nameAsc, lastActivity }

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Provides a [CustomersDao] backed by the shared AppDatabase singleton.
final customersDaoProvider = Provider<CustomersDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.customersDao;
});

/// Provides the [CustomersRepository] singleton.
final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CustomersRepository(
    db: db,
    customersDao: db.customersDao,
    eventsDao: db.eventsDao,
  );
});

/// Stream of all customers with computed balances for a shop.
final customersWithBalancesProvider =
    StreamProvider.autoDispose.family<List<CustomerWithBalance>, String>(
        (ref, shopId) {
  final repo = ref.watch(customersRepositoryProvider);
  return repo.watchCustomersWithBalances(shopId);
});

/// Current search query text entered by the user.
final customerSearchQueryProvider = StateProvider<String>((ref) => '');

/// Current sort order chosen by the user.
final customerSortProvider =
    StateProvider<CustomerSort>((ref) => CustomerSort.balanceDesc);

/// Derived provider: filtered + sorted customer list for a shop.
final filteredCustomersProvider =
    Provider.autoDispose.family<List<CustomerWithBalance>, String>(
        (ref, shopId) {
  final asyncData = ref.watch(customersWithBalancesProvider(shopId));
  final query = ref.watch(customerSearchQueryProvider).toLowerCase();
  final sort = ref.watch(customerSortProvider);

  final allCustomers = asyncData.valueOrNull ?? [];

  // 1. Apply search filter
  final filtered = query.isEmpty
      ? allCustomers
      : allCustomers
          .where(
            (c) => c.customer.name.toLowerCase().contains(query),
          )
          .toList();

  // 2. Separate flagged customers — always first (AC6)
  final flagged =
      filtered.where((c) => c.customer.isFlagged == 1).toList();
  final unflagged =
      filtered.where((c) => c.customer.isFlagged != 1).toList();

  // 3. Apply sort to the unflagged segment
  int Function(CustomerWithBalance, CustomerWithBalance) comparator;
  switch (sort) {
    case CustomerSort.balanceDesc:
      comparator = (a, b) => b.balancePaisa.compareTo(a.balancePaisa);
    case CustomerSort.balanceAsc:
      comparator = (a, b) => a.balancePaisa.compareTo(b.balancePaisa);
    case CustomerSort.nameAsc:
      comparator = (a, b) => a.customer.name.compareTo(b.customer.name);
    case CustomerSort.lastActivity:
      comparator = (a, b) {
        final aTs = a.lastActivityAt?.millisecondsSinceEpoch ?? 0;
        final bTs = b.lastActivityAt?.millisecondsSinceEpoch ?? 0;
        return bTs.compareTo(aTs);
      };
  }
  unflagged.sort(comparator);
  flagged.sort(comparator);

  return [...flagged, ...unflagged];
});

/// Flag state for a single customer — autoDispose so it cleans up with the screen.
final customerFlagProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, customerId) async {
  final repo = ref.watch(customersRepositoryProvider);
  final customer = await repo.getCustomer(customerId);
  return customer?.isFlagged == 1;
});

/// Sum of all positive balances (customers who owe the shop) in paisa.
final totalOwedProvider =
    Provider.autoDispose.family<int, String>((ref, shopId) {
  final asyncData = ref.watch(customersWithBalancesProvider(shopId));
  final customers = asyncData.valueOrNull ?? [];
  return customers
      .where((c) => c.balancePaisa > 0)
      .fold<int>(0, (sum, c) => sum + c.balancePaisa);
});

/// Sum of absolute negative balances (shop owes these customers) in paisa.
/// Returns positive value representing the total the shop owes.
final totalShopOwesPaisaProvider =
    Provider.autoDispose.family<int, String>((ref, shopId) {
  final asyncData = ref.watch(customersWithBalancesProvider(shopId));
  final customers = asyncData.valueOrNull ?? [];
  return customers
      .where((c) => c.balancePaisa < 0)
      .fold<int>(0, (sum, c) => sum + c.balancePaisa.abs());
});

/// Net position in paisa: totalOwed - totalShopOwes. Can be negative.
final netPositionPaisaProvider =
    Provider.autoDispose.family<int, String>((ref, shopId) {
  final owed = ref.watch(totalOwedProvider(shopId));
  final owes = ref.watch(totalShopOwesPaisaProvider(shopId));
  return owed - owes;
});
