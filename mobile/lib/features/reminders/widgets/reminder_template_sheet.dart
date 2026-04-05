import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/database_provider.dart';
import '../providers/reminders_provider.dart';
import '../services/reminder_service.dart';
import '../../transactions/providers/transactions_provider.dart';

/// Shows a modal bottom sheet that lets the user pick a reminder template
/// and then send it via WhatsApp.
///
/// Returns [ReminderResult] when popped (or null if cancelled).
Future<ReminderResult?> showReminderTemplateSheet(
  BuildContext context, {
  required String customerId,
  required String customerName,
  required String? customerPhone,
  required int balancePaisa,
  required int daysOverdue,
}) async {
  return showModalBottomSheet<ReminderResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ReminderTemplateSheet(
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      balancePaisa: balancePaisa,
      daysOverdue: daysOverdue,
    ),
  );
}

class _ReminderTemplateSheet extends ConsumerStatefulWidget {
  const _ReminderTemplateSheet({
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.balancePaisa,
    required this.daysOverdue,
  });

  final String customerId;
  final String customerName;
  final String? customerPhone;
  final int balancePaisa;
  final int daysOverdue;

  @override
  ConsumerState<_ReminderTemplateSheet> createState() =>
      _ReminderTemplateSheetState();
}

class _ReminderTemplateSheetState
    extends ConsumerState<_ReminderTemplateSheet> {
  late String _selectedType;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _selectedType = selectTemplateType(widget.daysOverdue);
  }

  String _labelForType(String type) {
    switch (type) {
      case ReminderTemplateType.gentle:
        return AppStrings.reminderGentleLabel;
      case ReminderTemplateType.firm:
        return AppStrings.reminderFirmLabel;
      case ReminderTemplateType.finalReminder:
        return AppStrings.reminderFinalLabel;
      default:
        return AppStrings.reminderGentleLabel;
    }
  }

  String _previewMessage(String type, String shopName) {
    return buildReminderMessage(
      templateType: type,
      customerName: widget.customerName,
      balancePaisa: widget.balancePaisa,
      daysOverdue: widget.daysOverdue,
      shopName: shopName,
    );
  }

  Future<void> _send(String shopId, String shopName) async {
    setState(() => _sending = true);
    final service = ref.read(reminderServiceProvider);
    final deviceId = ref.read(deviceIdProvider);
    final actorLabel = ref.read(actorLabelProvider);

    final result = await service.sendReminder(
      shopId: shopId,
      customerId: widget.customerId,
      customerName: widget.customerName,
      customerPhone: widget.customerPhone,
      balancePaisa: widget.balancePaisa,
      daysOverdue: widget.daysOverdue,
      templateType: _selectedType,
      shopName: shopName,
      deviceId: deviceId,
      actorLabel: actorLabel,
    );

    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(currentShopIdProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 20,
        ),
        child: shopAsync.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SizedBox(
            height: 80,
            child: Center(child: Text(e.toString())),
          ),
          data: (shopId) {
            // Fetch shop name synchronously from DB for preview
            final db = ref.read(appDatabaseProvider);
            return FutureBuilder<String>(
              future: db
                  .select(db.shops)
                  .get()
                  .then((s) => s.isNotEmpty ? s.first.name : ''),
              builder: (context, snap) {
                final shopName = snap.data ?? '';
                final sid = shopId ?? '';
                return _buildContent(sid, shopName);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(String shopId, String shopName) {
    const templateTypes = [
      ReminderTemplateType.gentle,
      ReminderTemplateType.firm,
      ReminderTemplateType.finalReminder,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title
        const Text(
          AppStrings.reminderButton,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // Template selector cards
        ...templateTypes.map((type) => InkWell(
              onTap: () => setState(() => _selectedType = type),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _selectedType == type
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: _selectedType == type
                          ? AppColors.primary
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _labelForType(type),
                      style:
                          const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            )),

        const SizedBox(height: 8),

        // Message preview
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _previewMessage(_selectedType, shopName),
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),

        const SizedBox(height: 16),

        // Send button
        ElevatedButton(
          key: const Key('send_reminder_button'),
          onPressed: _sending ? null : () => _send(shopId, shopName),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366), // WhatsApp green
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _sending
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text(
                  AppStrings.sendViaWhatsapp,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
        ),

        const SizedBox(height: 8),

        // Cancel button
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(null),
          child: const Text(AppStrings.cancel),
        ),

        const SizedBox(height: 8),
      ],
    );
  }
}
