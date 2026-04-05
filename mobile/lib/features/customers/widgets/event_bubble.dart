import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/event_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/amount_formatter.dart';
import '../../../core/utils/date_formatter.dart';

// ---------------------------------------------------------------------------
// Voice note play button helper
// ---------------------------------------------------------------------------

class _VoiceNotePlayButton extends StatelessWidget {
  const _VoiceNotePlayButton({required this.voiceNotePath});

  // MINOR-2: required path for future audio playback
  final String voiceNotePath;

  @override
  Widget build(BuildContext context) {
    // TODO STORY-010: Implement actual audio playback using voiceNotePath
    return IconButton(
      icon: const Icon(Icons.play_circle_outline, size: 24),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.voiceNoteComingSoon),
          ),
        );
      },
    );
  }
}

/// Chat-bubble widget that renders a single [Event] in the customer detail
/// chat-thread view.
///
/// Alignment and colour scheme by event_type:
///   CREDIT       → right-aligned, blue-grey bubble, amount in red
///   PAYMENT      → left-aligned, green bubble, amount in white
///   REVERSAL     → center-aligned, grey bubble, strikethrough amount
///   REMINDER_SENT → center-aligned, small grey italic text
class EventBubble extends StatelessWidget {
  const EventBubble({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    switch (event.eventType) {
      case EventType.credit:
        return _CreditBubble(event: event);
      case EventType.payment:
        return _PaymentBubble(event: event);
      case EventType.reversal:
        return _ReversalBubble(event: event);
      case EventType.reminderSent:
        return _ReminderSentBubble(event: event);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
// CREDIT bubble — right-aligned, blue-grey
// ---------------------------------------------------------------------------

class _CreditBubble extends StatelessWidget {
  const _CreditBubble({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.creditBubbleBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: AppColors.creditBubbleBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label row
            const Text(
              AppStrings.creditLabel,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            // Amount
            Text(
              AmountFormatter.format(event.amountPaisa),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.balancePositive,
              ),
            ),
            // Note
            if (event.note != null && event.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  event.note!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            // Voice note playback
            if (event.voiceNotePath != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _VoiceNotePlayButton(
                  voiceNotePath: event.voiceNotePath!,
                ),
              ),
            // Timestamp
            const SizedBox(height: 4),
            Text(
              DateFormatter.formatDateTime(event.deviceTimestamp),
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PAYMENT bubble — left-aligned, green
// ---------------------------------------------------------------------------

class _PaymentBubble extends StatelessWidget {
  const _PaymentBubble({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: AppColors.paymentColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              AppStrings.paymentLabel,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              AmountFormatter.format(event.amountPaisa),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (event.note != null && event.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  event.note!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.white70,
                  ),
                ),
              ),
            // Voice note playback
            if (event.voiceNotePath != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _VoiceNotePlayButton(
                  voiceNotePath: event.voiceNotePath!,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              DateFormatter.formatDateTime(event.deviceTimestamp),
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// REVERSAL — center-aligned, grey, strikethrough
// ---------------------------------------------------------------------------

class _ReversalBubble extends StatelessWidget {
  const _ReversalBubble({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.reversalBubbleBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              AppStrings.reversalEvent,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              AmountFormatter.format(event.amountPaisa),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormatter.formatDateTime(event.deviceTimestamp),
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// REMINDER_SENT — center-aligned, small italic grey text
// ---------------------------------------------------------------------------

class _ReminderSentBubble extends StatelessWidget {
  const _ReminderSentBubble({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
        child: Text(
          '${AppStrings.reminderSent} — ${DateFormatter.formatDateTime(event.deviceTimestamp)}',
          style: const TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
