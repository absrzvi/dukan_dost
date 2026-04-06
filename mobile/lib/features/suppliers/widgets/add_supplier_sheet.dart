import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../providers/suppliers_provider.dart';

/// Modal bottom sheet for creating a new supplier.
///
/// On save: calls [SuppliersRepository.createSupplier] and dismisses.
class AddSupplierSheet extends ConsumerStatefulWidget {
  const AddSupplierSheet({super.key, required this.shopId});

  final String shopId;

  @override
  ConsumerState<AddSupplierSheet> createState() => _AddSupplierSheetState();
}

class _AddSupplierSheetState extends ConsumerState<AddSupplierSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _debtController = TextEditingController();
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _debtController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(suppliersRepositoryProvider);
      final phone = _phoneController.text.trim();
      final debtText = _debtController.text.trim();

      // Parse rupees to paisa
      int? initialDebtPaisa;
      if (debtText.isNotEmpty) {
        final rupees = int.tryParse(debtText.replaceAll(',', ''));
        if (rupees != null && rupees > 0) {
          initialDebtPaisa = rupees * 100;
        }
      }

      await repo.createSupplier(
        shopId: widget.shopId,
        name: _nameController.text.trim(),
        phone: phone.isEmpty ? null : phone,
        dueDate: _dueDate,
        initialDebtPaisa: initialDebtPaisa,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.addSupplier,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Supplier name (required)
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: AppStrings.supplierName,
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return AppStrings.supplierNameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone (optional)
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: AppStrings.phoneNumber,
                  hintText: '+92 3XX XXXXXXX',
                  border: OutlineInputBorder(),
                  suffixText: AppStrings.optional,
                ),
              ),
              const SizedBox(height: 16),

              // Initial debt in rupees (optional)
              TextFormField(
                controller: _debtController,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: AppStrings.initialDebt,
                  hintText: '0',
                  border: OutlineInputBorder(),
                  prefixText: 'PKR ',
                  suffixText: AppStrings.optional,
                ),
              ),
              const SizedBox(height: 16),

              // Due date picker (optional)
              OutlinedButton.icon(
                onPressed: _pickDueDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  _dueDate != null
                      ? '${AppStrings.dueDate}: ${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                      : '${AppStrings.dueDate} ${AppStrings.optional}',
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text(AppStrings.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(AppStrings.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
