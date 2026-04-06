import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/amount_formatter.dart';
import '../models/supplier_with_balance.dart';

/// Reusable list tile for a single supplier with balance and overdue info.
class SupplierListTile extends StatelessWidget {
  const SupplierListTile({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
  });

  final SupplierWithBalance item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final supplier = item.supplier;
    final balance = item.balancePaisa;
    final overdue = item.isOverdue;
    final dueDateAt = item.dueDateAt;

    // Days until due (negative = overdue)
    int? daysUntilDue;
    if (dueDateAt != null) {
      daysUntilDue = dueDateAt.difference(DateTime.now()).inDays;
    }

    final bool isUrgent = daysUntilDue != null && daysUntilDue <= 2 && !overdue;

    final Color balanceColor =
        balance > 0 ? AppColors.balancePositive : AppColors.balanceZero;

    final String avatarLetter =
        supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        border: overdue
            ? const Border(
                left: BorderSide(color: AppColors.overdueRed, width: 4),
              )
            : isUrgent
                ? const Border(
                    left: BorderSide(color: AppColors.accent, width: 4),
                  )
                : null,
      ),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            avatarLetter,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            supplier.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        subtitle: dueDateAt != null
            ? Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${AppStrings.dueDate}: ${_formatDate(dueDateAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (overdue)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.overdueRed,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          AppStrings.overdue,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              )
            : null,
        trailing: Text(
          AmountFormatter.format(balance.abs()),
          style: TextStyle(
            color: balanceColor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
