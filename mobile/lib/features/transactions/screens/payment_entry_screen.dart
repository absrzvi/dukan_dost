import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/event_constants.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/amount_formatter.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../../../shared/widgets/amount_keypad.dart';
import '../../../shared/widgets/hisaab_saaf_overlay.dart';
import '../providers/transactions_provider.dart';

/// Payment entry screen. Records a PAYMENT event for a given customer.
///
/// Constructor params:
///   [customerId]    — UUID of the customer
///   [customerName]  — display name of the customer
///   [customerPhone] — optional phone number for WhatsApp receipt
class PaymentEntryScreen extends ConsumerStatefulWidget {
  const PaymentEntryScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
  });

  final String customerId;
  final String customerName;
  final String? customerPhone;

  @override
  ConsumerState<PaymentEntryScreen> createState() => _PaymentEntryScreenState();
}

class _PaymentEntryScreenState extends ConsumerState<PaymentEntryScreen> {
  int _amountPaisa = 0;
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_amountPaisa <= 0 || _saving) return;
    setState(() => _saving = true);

    try {
      final shopId = await ref.read(currentShopIdProvider.future);
      if (shopId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.shopNotFound)),
          );
        }
        setState(() => _saving = false);
        return;
      }

      final note = _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim();

      final deviceId = ref.read(deviceIdProvider);
      final actorLabel = ref.read(actorLabelProvider);

      await ref.read(eventRepositoryProvider).addEvent(
            shopId: shopId,
            eventType: EventType.payment,
            partyType: PartyType.customer,
            partyId: widget.customerId,
            amountPaisa: _amountPaisa,
            note: note,
            deviceId: deviceId,
            actorLabel: actorLabel,
          );

      // Compute new balance
      final newBalance = await ref
          .read(eventRepositoryProvider)
          .computeBalance(widget.customerId, PartyType.customer);

      // Invalidate cached balance so the previous screen refreshes on pop
      ref.invalidate(customerBalanceProvider(widget.customerId));

      if (!mounted) return;

      if (newBalance == 0) {
        // Full-screen celebration overlay
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const HisaabSaafOverlay(),
        );
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.of(context).pop(); // pop dialog
            Navigator.of(context).pop(); // pop screen
          }
        });
      } else if (newBalance < 0) {
        // Overpayment — balance went negative
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.accent,
            content: Text(
              AppStrings.overpaymentWarning,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        Navigator.of(context).pop();
      } else {
        // Partial or full payment, balance still positive
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.paymentColor,
            content: const Text(
              AppStrings.paymentSaved,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            action: widget.customerPhone != null
                ? SnackBarAction(
                    label: AppStrings.whatsappNotify,
                    textColor: Colors.white,
                    onPressed: () => _sendWhatsApp(
                      shopId: shopId,
                      newBalance: newBalance,
                    ),
                  )
                : null,
          ),
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.saveError)),
        );
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _sendWhatsApp({
    required String shopId,
    required int newBalance,
  }) async {
    final phone = widget.customerPhone;
    if (phone == null) return;

    final db = ref.read(appDatabaseProvider);
    final shop = await db.select(db.shops).getSingleOrNull();
    final shopName = shop?.name ?? '';

    final message = AppStrings.whatsappPaymentTemplate
        .replaceAll('{amount}', AmountFormatter.format(_amountPaisa))
        .replaceAll('{remaining}', AmountFormatter.format(newBalance))
        .replaceAll('{shopName}', shopName);

    await WhatsAppHelper.sendMessage(phone: phone, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync =
        ref.watch(customerBalanceProvider(widget.customerId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.paymentColor,
          foregroundColor: Colors.white,
          title: const Text(AppStrings.paymentEntry),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Customer name + current balance
              Container(
                width: double.infinity,
                color: AppColors.surface,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.customerName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          '${AppStrings.currentBalance}: ',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        balanceAsync.when(
                          loading: () => const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (_, __) => const Text('—'),
                          data: (balance) => Text(
                            AmountFormatter.format(balance),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: balance > 0
                                  ? AppColors.balancePositive
                                  : AppColors.balanceZero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // "Amount being paid" label
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  AppStrings.amountBeingPaid,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              // Keypad
              AmountKeypad(
                onAmountChanged: (paisa) {
                  setState(() => _amountPaisa = paisa);
                },
              ),

              // Partial payment badge or overpayment indicator
              balanceAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (balance) {
                  if (_amountPaisa > 0 && _amountPaisa < balance) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.paymentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.paymentColor, width: 1),
                          ),
                          child: const Text(
                            AppStrings.partialPayment,
                            style: TextStyle(
                              color: AppColors.paymentColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  if (_amountPaisa > balance) {
                    return const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        AppStrings.amountExceedsBalance,
                        style: TextStyle(
                          color: AppColors.creditColor,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Note field
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextFormField(
                  controller: _noteController,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    hintText: AppStrings.addNote,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
              ),

              const SizedBox(height: 16),

              // Save button — enabled when amountPaisa > 0 (overpayment allowed)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_amountPaisa > 0 && !_saving) ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.paymentColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.balanceZero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            AppStrings.saveButton,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
