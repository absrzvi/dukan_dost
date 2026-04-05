import 'package:flutter/foundation.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/event_constants.dart';
import '../../../core/utils/amount_formatter.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../../transactions/repositories/event_repository.dart';

/// Result returned by [ReminderService.sendReminder].
enum ReminderResult { sentViaWhatsApp, noPhone, failed }

/// Template type constants — matches the note stored in the REMINDER_SENT event.
class ReminderTemplateType {
  static const String gentle = 'gentle';
  static const String firm = 'firm';
  static const String finalReminder = 'final';
}

/// Select the appropriate template type based on [daysOverdue].
///
/// < 7  → gentle
/// 7-29 → firm
/// 30+  → final
String selectTemplateType(int daysOverdue) {
  if (daysOverdue < 7) return ReminderTemplateType.gentle;
  if (daysOverdue < 30) return ReminderTemplateType.firm;
  return ReminderTemplateType.finalReminder;
}

/// Build the full reminder message from a template type and customer data.
String buildReminderMessage({
  required String templateType,
  required String customerName,
  required int balancePaisa,
  required int daysOverdue,
  required String shopName,
}) {
  final amount = AmountFormatter.format(balancePaisa);
  final days = daysOverdue.toString();

  switch (templateType) {
    case ReminderTemplateType.gentle:
      return AppStrings.gentleTemplate
          .replaceAll('{name}', customerName)
          .replaceAll('{amount}', amount)
          .replaceAll('{shopName}', shopName);
    case ReminderTemplateType.firm:
      return AppStrings.firmTemplate
          .replaceAll('{name}', customerName)
          .replaceAll('{amount}', amount)
          .replaceAll('{days}', days)
          .replaceAll('{shopName}', shopName);
    case ReminderTemplateType.finalReminder:
      return AppStrings.finalTemplate
          .replaceAll('{name}', customerName)
          .replaceAll('{amount}', amount)
          .replaceAll('{days}', days)
          .replaceAll('{shopName}', shopName);
    default:
      return AppStrings.gentleTemplate
          .replaceAll('{name}', customerName)
          .replaceAll('{amount}', amount)
          .replaceAll('{shopName}', shopName);
  }
}

/// Service responsible for the WhatsApp reminder flow.
///
/// Flow (offline-first):
///   1. Write REMINDER_SENT event to local Drift DB (amountPaisa=0, note=templateType).
///   2. Open WhatsApp deep link (or SMS fallback if no phone).
class ReminderService {
  ReminderService(this._eventRepository);

  final EventRepository _eventRepository;

  /// Exposed for testing only.
  @visibleForTesting
  EventRepository get eventRepository => _eventRepository;

  /// Send a reminder to a customer.
  ///
  /// Writes the REMINDER_SENT event BEFORE opening WhatsApp (offline-first guarantee).
  Future<ReminderResult> sendReminder({
    required String shopId,
    required String customerId,
    required String customerName,
    required String? customerPhone,
    required int balancePaisa,
    required int daysOverdue,
    required String templateType,
    required String shopName,
    required String deviceId,
    required String actorLabel,
  }) async {
    // Build message text (used as note and WhatsApp body)
    final message = buildReminderMessage(
      templateType: templateType,
      customerName: customerName,
      balancePaisa: balancePaisa,
      daysOverdue: daysOverdue,
      shopName: shopName,
    );

    // Step 1: Write event locally FIRST (offline-first guarantee)
    await _eventRepository.addEvent(
      shopId: shopId,
      eventType: EventType.reminderSent,
      partyType: PartyType.customer,
      partyId: customerId,
      amountPaisa: 0,
      note: templateType,
      deviceId: deviceId,
      actorLabel: actorLabel,
    );

    // Step 2: Open WhatsApp or return noPhone
    if (customerPhone == null || customerPhone.trim().isEmpty) {
      return ReminderResult.noPhone;
    }

    try {
      final opened = await WhatsAppHelper.sendMessage(
        phone: customerPhone,
        message: message,
      );
      return opened ? ReminderResult.sentViaWhatsApp : ReminderResult.failed;
    } catch (_) {
      return ReminderResult.failed;
    }
  }
}
