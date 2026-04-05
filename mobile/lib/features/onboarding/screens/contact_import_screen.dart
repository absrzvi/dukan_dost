import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/database/app_database.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import 'walkthrough_screen.dart';

class ContactImportScreen extends ConsumerStatefulWidget {
  const ContactImportScreen({super.key});

  @override
  ConsumerState<ContactImportScreen> createState() =>
      _ContactImportScreenState();
}

class _ContactImportScreenState extends ConsumerState<ContactImportScreen> {
  final _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  String _searchQuery = '';
  bool _isImporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Contact> _filtered(List<Contact> contacts) {
    if (_searchQuery.isEmpty) return contacts;
    final q = _searchQuery.toLowerCase();
    return contacts.where((c) {
      final name = c.displayName.toLowerCase();
      final phone = c.phones.map((p) => p.number).join(' ').toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  Future<void> _onImport(List<Contact> allContacts) async {
    if (_isImporting) return;
    setState(() => _isImporting = true);

    final shopId = ref.read(authProvider).shopId ?? '';
    final db = ref.read(appDatabaseProvider);
    const uuid = Uuid();
    final now = DateTime.now().millisecondsSinceEpoch;

    final selected = allContacts.where((c) => _selectedIds.contains(c.id)).toList();

    for (final contact in selected) {
      final phone = contact.phones.isNotEmpty
          ? contact.phones.first.number.replaceAll(' ', '')
          : null;

      // Check for duplicate: same phone+shop_id
      if (phone != null && phone.isNotEmpty) {
        final existing = await (db.select(db.customers)
              ..where((c) =>
                  c.shopId.equals(shopId) & c.phone.equals(phone) & c.isDeleted.equals(0)))
            .getSingleOrNull();
        if (existing != null) continue;
      }

      final customerId = uuid.v4();
      await db.into(db.customers).insert(CustomersCompanion(
            id: Value(customerId),
            shopId: Value(shopId),
            name: Value(contact.displayName.isNotEmpty
                ? contact.displayName
                : (phone ?? 'نامعلوم')),
            phone: Value(phone),
            isFlagged: const Value(0),
            createdAt: Value(now),
            updatedAt: Value(now),
            isDeleted: const Value(0),
          ));

      // Enqueue sync
      await db.into(db.syncQueue).insert(SyncQueueCompanion(
            eventId: Value('CUSTOMER_CREATE_$customerId'),
            status: const Value('PENDING'),
            retryCount: const Value(0),
            createdAt: Value(now),
          ));
    }

    setState(() => _isImporting = false);
    _navigateNext();
  }

  void _navigateNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WalkthroughScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactImportProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          AppStrings.importContacts,
          textDirection: TextDirection.rtl,
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _navigateNext,
            child: const Text(
              AppStrings.skipImport,
              textDirection: TextDirection.rtl,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: contactsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'رابطے نہیں مل سکے',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _navigateNext,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white),
                  child: const Text(AppStrings.skipImport,
                      textDirection: TextDirection.rtl),
                ),
              ],
            ),
          ),
          data: (contacts) {
            final filtered = _filtered(contacts);
            return Column(
              children: [
                // Permission rationale & search
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'اپنے موبائل کے رابطے گاہکوں میں شامل کریں تاکہ آسانی سے ڈھونڈ سکیں',
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        textDirection: TextDirection.rtl,
                        onChanged: (v) =>
                            setState(() => _searchQuery = v.trim()),
                        decoration: InputDecoration(
                          hintText: AppStrings.searchContacts,
                          hintStyle: const TextStyle(
                              color: AppColors.textSecondary),
                          prefixIcon:
                              const Icon(Icons.search, color: AppColors.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                // Contact list
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'کوئی رابطہ نہیں ملا',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final contact = filtered[index];
                            final phone = contact.phones.isNotEmpty
                                ? contact.phones.first.number
                                : '';
                            final isSelected =
                                _selectedIds.contains(contact.id);

                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (_) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedIds.remove(contact.id);
                                  } else {
                                    _selectedIds.add(contact.id);
                                  }
                                });
                              },
                              title: Text(
                                contact.displayName,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                    color: AppColors.textPrimary),
                              ),
                              subtitle: phone.isNotEmpty
                                  ? Text(phone,
                                      style: const TextStyle(
                                          color: AppColors.textSecondary))
                                  : null,
                              activeColor: AppColors.primary,
                              controlAffinity:
                                  ListTileControlAffinity.trailing,
                            );
                          },
                        ),
                ),
                // Bottom buttons
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _navigateNext,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(
                                color: AppColors.textSecondary),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            AppStrings.skipImport,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _selectedIds.isEmpty || _isImporting
                              ? null
                              : () => _onImport(contacts),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppColors.primary.withValues(alpha: 0.4),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isImporting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  '${AppStrings.importContacts} (${_selectedIds.length})',
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
