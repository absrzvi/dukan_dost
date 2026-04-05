# STORY-011: WhatsApp Reminder Flow (Gentle / Firm / Final Templates, Deep Link, REMINDER_SENT Event)
Status: TODO
Sprint: 3
Points: 5

## User Story
As a kiryana store owner, I want to send a one-tap WhatsApp reminder to a customer who has an overdue balance — with the correct Urdu template pre-filled based on how many days overdue they are — so that I can collect payments faster without spending time composing individual messages.

## Acceptance Criteria
- [ ] AC1: Customers with a balance older than 7 days show an inline "Takaza" (remind) button directly on the customer list item, requiring no drill-down.
- [ ] AC2: Tapping the inline "Takaza" button opens WhatsApp (via `wa.me/` deep link) with the appropriate pre-filled Urdu template based on days overdue: Gentle (7–13 days), Firm (14–20 days), Final (21+ days).
- [ ] AC3: Gentle template (7–13 days): "Assalamualaikum [Name] bhai, umeed hai khairiyat se honge. [Shop Name] ka PKR [X] baaki hai. Thoda waqt mile toh ada kar dein. Shukriya."
- [ ] AC4: Firm template (14–20 days): "Assalamualaikum [Name] bhai, [Shop Name] ka PKR [X] kaafi dino se baaki hai. Guzarish hai jaldi ada kar dein. Shukriya."
- [ ] AC5: Final template (21+ days): "Assalamualaikum [Name] bhai, [Shop Name] ka PKR [X] bohot din se baaki hai. Aaj hi ada kar dein toh meherbani hogi. Shukriya."
- [ ] AC6: The store owner can preview and edit the pre-filled text inside WhatsApp before sending (this is inherent to the WhatsApp deep link behaviour — no app-side editing required).
- [ ] AC7: Immediately when the "Takaza" button is tapped (before WhatsApp opens), a `REMINDER_SENT` event is written to the local Drift `Events` table with `event_type=REMINDER_SENT`, `party_type=CUSTOMER`, `party_id`, `amount_paisa=current balance`, and `note` containing the template type (GENTLE/FIRM/FINAL) and channel (WHATSAPP).
- [ ] AC8: The `REMINDER_SENT` event also creates a SyncQueue entry (atomic Drift transaction).
- [ ] AC9: The `last_reminder_at` field on the `Customers` table is updated to the current timestamp when the reminder is dispatched.
- [ ] AC10: The customer detail screen (STORY-010) displays the last reminder sent date derived from the `REMINDER_SENT` event.
- [ ] AC11: For customers without a phone number, the inline "Takaza" button is replaced with an SMS fallback indicator; tapping it opens the device SMS app with a pre-filled message (same template content). The REMINDER_SENT event is logged with `channel=SMS`.
- [ ] AC12: Days overdue is computed as the number of days since the last CREDIT event for that customer; displayed as "X din" on the list item for 7+ day customers.
- [ ] AC13: All Urdu template strings are stored as constants in a dedicated `reminder_templates.dart` file.
- [ ] AC14: Unit tests cover template selection logic: correct template chosen for 7, 13, 14, 20, 21, 30 days overdue.

## Technical Notes
### Flutter
- `ReminderService` class in `lib/features/reminders/services/reminder_service.dart`.
- `selectTemplate(daysOverdue)` → returns `ReminderTemplate` enum (GENTLE/FIRM/FINAL).
- `buildWhatsAppUri(phone, shopName, customerName, balancePaisa, template)` → returns a `Uri` with `wa.me/{phone}?text={encoded}`. Use `Uri.encodeFull` on the message text.
- On tap: (1) call `EventsDao.insertEvent(REMINDER_SENT event)` in Drift transaction with SyncQueue entry, (2) `CustomersDao.updateLastReminder(customerId, now)`, (3) `url_launcher.launchUrl(whatsappUri)`.
- SMS fallback: `url_launcher` with `sms:` scheme — `sms:{phone}?body={encoded}`.
- Overdue badge on customer list item: `ReminderBadgeWidget` shown when `days_overdue >= 7`. Days overdue computed in the `watchCustomers` Drift query (or a derived Riverpod provider).
- `reminder_templates.dart`: const Strings with `[Name]`, `[Shop Name]`, `[X]` as literal placeholders replaced at runtime via `String.replaceAll`.

### Django
- `POST /api/reminders/log` is defined in API_CONTRACTS.md. The Flutter REMINDER_SENT event is synced via the normal sync engine (STORY-013) — no separate reminder-specific sync call is needed. The `/api/reminders/log` endpoint is an alternative direct log path but the sync engine covers it.

## Offline Behaviour
The REMINDER_SENT event is written to the local Drift database immediately when the button is tapped. The WhatsApp deep link is opened on the device — no server required. The `last_reminder_at` field is updated locally. Everything syncs to the server when connectivity is next available via the sync engine (STORY-013). The reminder flow must work identically whether the device is online or offline.

## Dependencies
- STORY-006 (Drift event log — REMINDER_SENT event insert)
- STORY-007 (customer list screen — inline remind button placement)
- STORY-010 (customer detail screen — last reminder date display)

## Definition of Done
- [ ] All ACs passing
- [ ] flutter test passing
- [ ] flutter analyze clean
- [ ] python -m pytest passing
- [ ] Offline behaviour verified manually
