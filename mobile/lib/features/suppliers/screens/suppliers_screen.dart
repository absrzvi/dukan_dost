import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/amount_formatter.dart';
import '../models/supplier_with_balance.dart';
import '../providers/suppliers_provider.dart';
import '../widgets/add_supplier_sheet.dart';
import '../widgets/supplier_list_tile.dart';

/// Suppliers list screen — shows all active (non-paid, non-deleted) suppliers
/// for the shop, with a summary panel and add FAB.
///
/// Reactive: updates automatically when the Drift DB changes.
/// Offline-first: all data from local DB; no network required.
class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key, required this.shopId});

  final String shopId;

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AddSupplierSheet(shopId: shopId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalOwed = ref.watch(totalOwedToSuppliersProvider(shopId));
    final suppliersAsync = ref.watch(suppliersWithBalancesProvider(shopId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: const Text(AppStrings.suppliers),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openAddSheet(context),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          tooltip: AppStrings.addSupplier,
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            // Summary panel
            _SummaryPanel(totalOwedPaisa: totalOwed),

            // Supplier list
            Expanded(
              child: suppliersAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
                data: (suppliers) {
                  if (suppliers.isEmpty) {
                    return _EmptyState(
                        onAdd: () => _openAddSheet(context));
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: suppliers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = suppliers[index];
                      return SupplierListTile(
                        key: ValueKey(item.supplier.id),
                        item: item,
                        onTap: () => _onTapSupplier(context, item),
                        onLongPress: () =>
                            _showActionSheet(context, ref, item),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTapSupplier(BuildContext context, SupplierWithBalance item) {
    // Stub: SupplierDetailScreen will be built in a future story
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.supplierComingSoon),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showActionSheet(
    BuildContext context,
    WidgetRef ref,
    SupplierWithBalance item,
  ) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.check_circle_outline,
                    color: AppColors.paymentColor),
                title: const Text(AppStrings.markPaid),
                onTap: () async {
                  Navigator.pop(context);
                  final repo = ref.read(suppliersRepositoryProvider);
                  await repo.markPaid(item.supplier.id, item.supplier.shopId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: AppColors.creditColor),
                title: const Text(AppStrings.deleteSupplier),
                onTap: () async {
                  Navigator.pop(context);
                  final repo = ref.read(suppliersRepositoryProvider);
                  await repo.deleteSupplier(
                      item.supplier.id, item.supplier.shopId);
                },
              ),
            ],
          ),
        ),
      ),
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
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            AppStrings.totalOwedToSuppliers,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            AmountFormatter.format(totalOwedPaisa),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.balancePositive,
            ),
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
          const Icon(Icons.store_outlined,
              size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          const Text(
            AppStrings.noSuppliers,
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
              AppStrings.addSupplier,
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
