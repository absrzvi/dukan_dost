import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/event_constants.dart';
import '../../../core/utils/amount_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../../transactions/screens/credit_entry_screen.dart';
import '../../transactions/screens/payment_entry_screen.dart';
import '../providers/customers_provider.dart';
import '../widgets/event_bubble.dart';

/// Customer detail screen — chat-thread style transaction history.
///
/// Constructor params:
///   [customerId]    — UUID of the customer
///   [customerName]  — display name
///   [customerPhone] — optional phone number for WhatsApp
class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
  });

  final String customerId;
  final String customerName;
  final String? customerPhone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(customerEventsStreamProvider(customerId));
    final balance = eventsAsync.whenOrNull(
          data: (events) {
            int b = 0;
            for (final e in events) {
              if (e.eventType == EventType.credit) {
                b += e.amountPaisa;
              } else if (e.eventType == EventType.payment ||
                  e.eventType == EventType.reversal) {
                b -= e.amountPaisa;
              }
            }
            return b;
          },
        ) ??
        0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: Text(customerName),
          actions: [
            _DetailPopupMenu(
              customerId: customerId,
              customerName: customerName,
              customerPhone: customerPhone,
              events: eventsAsync.valueOrNull ?? [],
              balance: balance,
            ),
          ],
        ),
        body: Column(
          children: [
            // Sticky balance header
            _BalanceHeader(balancePaisa: balance),

            // Chat-thread event list
            Expanded(
              child: eventsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
                data: (events) {
                  if (events.isEmpty) {
                    return const Center(
                      child: Text(
                        AppStrings.noTransactions,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: events.length,
                    itemBuilder: (context, index) =>
                        EventBubble(event: events[index]),
                  );
                },
              ),
            ),

            // Bottom action bar
            _BottomActionBar(
              customerId: customerId,
              customerName: customerName,
              customerPhone: customerPhone,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Balance header
// ---------------------------------------------------------------------------

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.balancePaisa});

  final int balancePaisa;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (balancePaisa > 0) {
      color = AppColors.balancePositive;
    } else if (balancePaisa < 0) {
      color = AppColors.balanceNegative;
    } else {
      color = AppColors.balanceZero;
    }

    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          const Text(
            AppStrings.currentBalance,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AmountFormatter.format(balancePaisa.abs()),
            style: TextStyle(
              fontSize: 28,
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
// Bottom action bar
// ---------------------------------------------------------------------------

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.customerId,
    required this.customerName,
    this.customerPhone,
  });

  final String customerId;
  final String customerName;
  final String? customerPhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // ادھار لکھیں (Credit) — outlined red
          Expanded(
            child: OutlinedButton(
              key: const Key('credit_button'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CreditEntryScreen(
                      customerId: customerId,
                      customerName: customerName,
                      customerPhone: customerPhone,
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.creditColor,
                side: const BorderSide(color: AppColors.creditColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                AppStrings.creditEntry,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // ادائیگی لکھیں (Payment) — filled green
          Expanded(
            child: ElevatedButton(
              key: const Key('payment_button'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PaymentEntryScreen(
                      customerId: customerId,
                      customerName: customerName,
                      customerPhone: customerPhone,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.paymentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                AppStrings.paymentEntry,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppBar popup menu
// ---------------------------------------------------------------------------

class _DetailPopupMenu extends ConsumerWidget {
  const _DetailPopupMenu({
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.events,
    required this.balance,
  });

  final String customerId;
  final String customerName;
  final String? customerPhone;
  final List<dynamic> events;
  final int balance;

  Future<void> _shareHistory(BuildContext context) async {
    final phone = customerPhone;
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.noPhone)),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('${AppStrings.customers}: $customerName');
    buffer.writeln(
        '${AppStrings.currentBalance}: ${AmountFormatter.format(balance)}');
    buffer.writeln('---');

    for (final e in events) {
      final date = DateFormatter.formatDate(e.deviceTimestamp);
      if (e.eventType == EventType.credit) {
        buffer.writeln('$date: ${AppStrings.creditLabel} ${AmountFormatter.format(e.amountPaisa)}');
      } else if (e.eventType == EventType.payment) {
        buffer.writeln('$date: ${AppStrings.paymentLabel} ${AmountFormatter.format(e.amountPaisa)}');
      }
    }

    await WhatsAppHelper.sendMessage(
      phone: phone,
      message: buffer.toString(),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text(AppStrings.confirmDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              AppStrings.deleteCustomer,
              style: TextStyle(color: AppColors.creditColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final repo = ref.read(customersRepositoryProvider);
      await repo.deleteCustomer(customerId);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _toggleFlag(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(customersRepositoryProvider);
    final customer = await repo.getCustomer(customerId);
    if (customer == null) return;
    final newFlag = customer.isFlagged == 1 ? 0 : 1;
    await repo.updateCustomer(customerId: customerId, isFlagged: newFlag);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        switch (value) {
          case 'flag':
            await _toggleFlag(context, ref);
          case 'share':
            await _shareHistory(context);
          case 'delete':
            await _confirmDelete(context, ref);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'flag',
          child: Text(AppStrings.flagCustomer),
        ),
        const PopupMenuItem(
          value: 'share',
          child: Text(AppStrings.shareHistory),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Text(
            AppStrings.deleteCustomer,
            style: TextStyle(color: AppColors.creditColor),
          ),
        ),
      ],
    );
  }
}
