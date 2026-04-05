import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/amount_formatter.dart';
import '../models/customer_with_balance.dart';
import '../providers/customers_provider.dart';
import '../widgets/add_customer_sheet.dart';
import '../widgets/customer_list_tile.dart';

/// Full customer list screen with search, sort, summary panel, and FAB.
///
/// Reactive: updates automatically when the Drift DB changes.
/// Offline-first: all data from local DB; no network required.
class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key, required this.shopId});

  final String shopId;

  @override
  ConsumerState<CustomerListScreen> createState() =>
      _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  bool _searchOpen = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchController.clear();
        ref.read(customerSearchQueryProvider.notifier).state = '';
      }
    });
  }

  void _openAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AddCustomerSheet(shopId: widget.shopId),
    );
  }

  Future<void> _onRefresh() async {
    // Invalidate the provider so it re-fetches from the local DB.
    // In STORY-013 this would also trigger a network sync.
    ref.invalidate(customersWithBalancesProvider(widget.shopId));
  }

  @override
  Widget build(BuildContext context) {
    final totalOwed = ref.watch(totalOwedProvider(widget.shopId));
    final filteredAsync =
        ref.watch(customersWithBalancesProvider(widget.shopId));
    final filtered =
        ref.watch(filteredCustomersProvider(widget.shopId));
    final sort = ref.watch(customerSortProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: _searchOpen
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                    hintText: '${AppStrings.customers}...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  onChanged: (v) {
                    ref.read(customerSearchQueryProvider.notifier).state = v;
                  },
                )
              : const Text(AppStrings.customers),
          actions: [
            IconButton(
              icon: Icon(_searchOpen ? Icons.close : Icons.search),
              onPressed: _toggleSearch,
              tooltip: AppStrings.customers,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openAddSheet,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          tooltip: AppStrings.addCustomer,
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            // Summary panel
            _SummaryPanel(totalOwedPaisa: totalOwed),

            // Sort bar
            _SortBar(
              currentSort: sort,
              onSortChanged: (s) =>
                  ref.read(customerSortProvider.notifier).state = s,
            ),

            // Customer list
            Expanded(
              child: filteredAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
                data: (_) {
                  if (filtered.isEmpty) {
                    return _EmptyState(onAdd: _openAddSheet);
                  }
                  return RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return CustomerListTile(
                          key: ValueKey(item.customer.id),
                          item: item,
                          onTap: () => _navigateToDetail(context, item),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, CustomerWithBalance item) {
    // STORY-010 stub: navigate to customer detail
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(item.customer.name)),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary panel
// ---------------------------------------------------------------------------

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.totalOwedPaisa});

  final int totalOwedPaisa;

  @override
  Widget build(BuildContext context) {
    final color = totalOwedPaisa > 0
        ? AppColors.balancePositive
        : AppColors.balanceNegative;
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            AppStrings.totalOwed,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            AmountFormatter.format(totalOwedPaisa),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sort bar
// ---------------------------------------------------------------------------

class _SortBar extends StatelessWidget {
  const _SortBar({
    required this.currentSort,
    required this.onSortChanged,
  });

  final CustomerSort currentSort;
  final ValueChanged<CustomerSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Text(
            AppStrings.sortBy,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          DropdownButton<CustomerSort>(
            value: currentSort,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(
                value: CustomerSort.balanceDesc,
                child: Text(AppStrings.sortBalanceDesc),
              ),
              DropdownMenuItem(
                value: CustomerSort.balanceAsc,
                child: Text(AppStrings.sortBalanceAsc),
              ),
              DropdownMenuItem(
                value: CustomerSort.nameAsc,
                child: Text(AppStrings.sortNameAsc),
              ),
              DropdownMenuItem(
                value: CustomerSort.lastActivity,
                child: Text(AppStrings.sortLastActivity),
              ),
            ],
            onChanged: (v) {
              if (v != null) onSortChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          const Text(
            AppStrings.noCustomers,
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, color: AppColors.primary),
            label: const Text(
              AppStrings.addCustomerNow,
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
