import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/event_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/amount_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../../transactions/screens/credit_entry_screen.dart';
import '../../transactions/screens/payment_entry_screen.dart';
import '../providers/customers_provider.dart';
import '../widgets/event_bubble.dart';
import '../../reminders/services/reminder_service.dart';
import '../../reminders/widgets/reminder_template_sheet.dart';

/// Customer detail screen — chat-thread style transaction history.
///
/// Constructor params:
///   [customerId]   — UUID of the customer
///   [customerName] — display name
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
    // MAJOR-3: reactive isFlagged from DB — no local state
    final isFlagged = ref
            .watch(customerFlaggedProvider(customerId))
            .valueOrNull ??
        false;

    final eventsAsync =
        ref.watch(customerEventsStreamProvider(customerId));
    final balancePaisa = eventsAsync.whenOrNull(
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

    // Derive days overdue from last CREDIT event
    final daysOverdue = eventsAsync.whenOrNull(
          data: (events) {
            int? lastCreditTs;
            for (int i = events.length - 1; i >= 0; i--) {
              if (events[i].eventType == EventType.credit) {
                lastCreditTs = events[i].deviceTimestamp;
                break;
              }
            }
            if (balancePaisa > 0 && lastCreditTs != null) {
              final lastCredit =
                  DateTime.fromMillisecondsSinceEpoch(lastCreditTs);
              return DateTime.now().difference(lastCredit).inDays;
            }
            return 0;
          },
        ) ??
        0;

    // Derive last reminder date from events stream
    final lastReminderTs = eventsAsync.whenOrNull(
      data: (events) {
        for (int i = events.length - 1; i >= 0; i--) {
          if (events[i].eventType == EventType.reminderSent) {
            return events[i].deviceTimestamp;
          }
        }
        return null;
      },
    );

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
              isFlagged: isFlagged,
              balancePaisa: balancePaisa,
              daysOverdue: daysOverdue,
            ),
          ],
        ),
        body: Column(
          children: [
            // Sticky balance header
            _BalanceHeader(
              balancePaisa: balancePaisa,
              lastReminderTs: lastReminderTs,
            ),

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
              balancePaisa: balancePaisa,
              daysOverdue: daysOverdue,
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
  const _BalanceHeader({
    required this.balancePaisa,
    this.lastReminderTs,
  });

  final int balancePaisa;
  final int? lastReminderTs;

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
          if (lastReminderTs != null) ...[
            const SizedBox(height: 4),
            Text(
              '${AppStrings.lastReminder}: ${DateFormatter.formatDate(lastReminderTs!)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom action bar
// ---------------------------------------------------------------------------

class _BottomActionBar extends ConsumerWidget {
  const _BottomActionBar({
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.balancePaisa = 0,
    this.daysOverdue = 0,
  });

  final String customerId;
  final String customerName;
  final String? customerPhone;
  final int balancePaisa;
  final int daysOverdue;

  Future<void> _showReminderSheet(BuildContext context) async {
    final result = await showReminderTemplateSheet(
      context,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      balancePaisa: balancePaisa,
      daysOverdue: daysOverdue,
    );
    if (!context.mounted || result == null) return;
    final msg = result == ReminderResult.sentViaWhatsApp
        ? AppStrings.reminderSentSuccess
        : result == ReminderResult.noPhone
            ? AppStrings.noPhoneSmsComingSoon
            : AppStrings.reminderSentSuccess;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          const SizedBox(width: 8),
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
          const SizedBox(width: 8),
          // یاد دہانی (Reminder) — outlined amber  MAJOR-1: guard on null phone
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('reminder_button'),
              icon: const Icon(Icons.notifications_outlined, size: 18),
              label: const Text(
                AppStrings.reminderButton,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () => _showReminderSheet(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.reminderAmber,
                side: const BorderSide(color: AppColors.reminderAmber),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
    required this.isFlagged,
    required this.balancePaisa,
    required this.daysOverdue,
  });

  final String customerId;
  final String customerName;
  final String? customerPhone;
  final bool isFlagged;
  // MAJOR-2: live balance/daysOverdue passed from parent
  final int balancePaisa;
  final int daysOverdue;

  /// IMPORTANT-1: accepts pre-computed balancePaisa to avoid duplication.
  Future<void> _shareHistory(
    BuildContext context,
    WidgetRef ref,
    int balancePaisa,
  ) async {
    final phone = customerPhone;
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.noPhoneForWhatsApp)),
      );
      return;
    }

    // Read events fresh at tap time
    final eventsAsync =
        ref.read(customerEventsStreamProvider(customerId));
    final List<Event> events = eventsAsync.valueOrNull ?? [];

    // Read shop name for share footer
    String shopName = '';
    final db = ref.read(appDatabaseProvider);
    final shops = await db.select(db.shops).get();
    if (shops.isNotEmpty) shopName = shops.first.name;

    if (!context.mounted) return;

    final buffer = StringBuffer();
    // IMPORTANT-2: use AppStrings.customerName instead of AppStrings.customers
    buffer.writeln('${AppStrings.customerName}: $customerName');
    buffer.writeln(
        '${AppStrings.currentBalance}: ${AmountFormatter.format(balancePaisa)}');
    buffer.writeln('---');

    for (final e in events) {
      final date = DateFormatter.formatDate(e.deviceTimestamp);
      if (e.eventType == EventType.credit) {
        buffer.writeln(
            '$date: ${AppStrings.creditLabel} ${AmountFormatter.format(e.amountPaisa)}');
      } else if (e.eventType == EventType.payment) {
        buffer.writeln(
            '$date: ${AppStrings.paymentLabel} ${AmountFormatter.format(e.amountPaisa)}');
      }
    }

    if (shopName.isNotEmpty) {
      // MINOR-6: use AppStrings.thankYouShop constant
      buffer.writeln('${AppStrings.thankYouShop} $shopName');
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
      // IMPORTANT-3: wrap in try/catch
      try {
        final repo = ref.read(customersRepositoryProvider);
        await repo.deleteCustomer(customerId);
        // IMPORTANT-4: popUntil instead of single pop
        if (context.mounted) {
          Navigator.of(context).popUntil(
            (route) => route.isFirst || route.settings.name == '/customers',
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.saveError)),
          );
        }
      }
    }
  }

  Future<void> _toggleFlag(BuildContext context, WidgetRef ref) async {
    // IMPORTANT-3: wrap in try/catch
    try {
      final repo = ref.read(customersRepositoryProvider);
      final customer = await repo.getCustomer(customerId);
      if (customer == null) return;
      final newFlag = customer.isFlagged == 1 ? 0 : 1;
      await repo.updateCustomer(customerId: customerId, isFlagged: newFlag);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newFlag == 1
                  ? AppStrings.flagConfirmed
                  : AppStrings.unflagConfirmed,
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.saveError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPhone = customerPhone != null;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        switch (value) {
          case 'flag':
            await _toggleFlag(context, ref);
          case 'reminder':
            {
              final result = await showReminderTemplateSheet(
                context,
                customerId: customerId,
                customerName: customerName,
                customerPhone: customerPhone,
                balancePaisa: balancePaisa,
                daysOverdue: daysOverdue,
              );
              if (context.mounted && result != null) {
                final msg = result == ReminderResult.sentViaWhatsApp
                    ? AppStrings.reminderSentSuccess
                    : result == ReminderResult.noPhone
                        ? AppStrings.noPhoneSmsComingSoon
                        : AppStrings.reminderSentSuccess;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(msg)));
              }
            }
          case 'share':
            // IMPORTANT-1: pass pre-computed balancePaisa
            await _shareHistory(context, ref, balancePaisa);
          case 'delete':
            await _confirmDelete(context, ref);
        }
      },
      itemBuilder: (_) => [
        // MAJOR-3: isFlagged comes from reactive provider, passed as param
        PopupMenuItem(
          value: 'flag',
          child: Text(isFlagged
              ? AppStrings.unflagCustomer
              : AppStrings.flagCustomer),
        ),
        const PopupMenuItem(
          value: 'reminder',
          child: Text(AppStrings.reminderButton),
        ),
        PopupMenuItem(
          value: 'share',
          enabled: hasPhone,
          child: Text(
            AppStrings.shareHistory,
            style: TextStyle(
              color: hasPhone ? null : AppColors.textSecondary,
            ),
          ),
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
