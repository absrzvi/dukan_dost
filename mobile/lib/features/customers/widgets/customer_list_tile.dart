import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/amount_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/customer_with_balance.dart';

/// Reusable list tile for a single customer with balance and overdue info.
class CustomerListTile extends StatelessWidget {
  const CustomerListTile({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
  });

  final CustomerWithBalance item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final customer = item.customer;
    final balance = item.balancePaisa;
    final overdue = item.daysOverdue;
    final isOverdue7Plus = overdue != null && overdue >= 7;
    final isOverdue1To7 = overdue != null && overdue >= 1 && overdue < 7;

    final Color balanceColor;
    if (balance > 0) {
      balanceColor = AppColors.balancePositive;
    } else if (balance < 0) {
      balanceColor = AppColors.balanceNegative;
    } else {
      balanceColor = AppColors.balanceZero;
    }

    final String lastName = customer.name.isNotEmpty ? customer.name : '?';
    final String avatarLetter = lastName[0].toUpperCase();

    return Container(
      decoration: BoxDecoration(
        border: isOverdue7Plus
            ? const Border(
                left: BorderSide(color: AppColors.overdueRed, width: 4),
              )
            : isOverdue1To7
                ? const Border(
                    left: BorderSide(color: AppColors.accent, width: 4),
                  )
                : null,
      ),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text(
                avatarLetter,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (customer.isFlagged == 1)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        title: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            customer.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        subtitle: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.lastActivityAt != null)
                Text(
                  DateFormatter.formatDate(
                    item.lastActivityAt!.millisecondsSinceEpoch,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              if (overdue != null && overdue > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOverdue7Plus
                        ? AppColors.overdueRed
                        : AppColors.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$overdue ${AppStrings.daysOverdue}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              AmountFormatter.format(balance.abs()),
              style: TextStyle(
                color: balanceColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            if (customer.phone == null)
              const Icon(
                Icons.phone_disabled,
                size: 14,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}
