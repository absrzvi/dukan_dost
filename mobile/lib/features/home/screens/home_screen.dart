import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/sync/sync_provider.dart';
import '../../backup/screens/backup_screen.dart';
import '../../customers/screens/customer_list_screen.dart';
import '../../suppliers/screens/suppliers_screen.dart';
import '../../transactions/providers/transactions_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Activate auto-sync (triggers on offline→online transitions).
    ref.watch(autoSyncProvider);

    final shopIdAsync = ref.watch(currentShopIdProvider);

    return shopIdAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text(e.toString())),
      ),
      data: (shopId) {
        if (shopId == null) {
          return const Scaffold(
            body: Center(child: Text(AppStrings.shopNotFound)),
          );
        }

        final screens = [
          CustomerListScreen(shopId: shopId),
          SuppliersScreen(shopId: shopId),
        ];

        return Scaffold(
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const DrawerHeader(
                  decoration: BoxDecoration(color: AppColors.primary),
                  child: Text(
                    'Dukaan Dost',
                    style: TextStyle(color: Colors.white, fontSize: 22),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text(AppStrings.backup),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BackupScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: screens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textSecondary,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.people_outline),
                activeIcon: Icon(Icons.people),
                label: AppStrings.customers,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.store_outlined),
                activeIcon: Icon(Icons.store),
                label: AppStrings.suppliers,
              ),
            ],
          ),
        );
      },
    );
  }
}
