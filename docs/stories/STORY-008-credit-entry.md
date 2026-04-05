# STORY-008: Credit Entry (Record a Udhaar / Credit Transaction)
Status: PARTIAL - AC11 (voice note) deferred to STORY-010
Sprint: 3
Points: 5

## User Story
As a kiryana store owner, I want to record a credit (udhaar) transaction for a customer in under 10 seconds — tap the customer, tap the credit button, enter the amount, and save — so that I can log credit during the brief gap between serving customers without disrupting the flow of business.

## Acceptance Criteria
- [ ] AC1: From the customer list or customer detail screen, tapping the credit (udhaar) button opens an amount entry screen with a large numeric keypad.
- [ ] AC2: The numeric keypad accepts integer amounts only; the display shows PKR value formatted from paisa (e.g. entering 500 shows "PKR 500").
- [ ] AC3: Tapping save writes a `CREDIT` event to the local Drift `Events` table instantly, with no network call on the critical path.
- [ ] AC4: The event record contains: client-generated UUID, `shop_id`, `event_type=CREDIT`, `party_type=CUSTOMER`, `party_id`, `amount_paisa`, `device_id`, `actor_label`, `device_timestamp` (current UTC millis), `server_timestamp=null`.
- [ ] AC5: Simultaneously with the Events insert, a `SyncQueue` row is created with `status=PENDING` for this event (atomic Drift transaction).
- [ ] AC6: After saving, the updated balance is displayed immediately — computed by replaying the local event log without a network call.
- [ ] AC7: If the customer's balance after this credit reaches exactly zero, the "Hisaab saaf" celebration state is shown (animated confirmation that the account is clear).
- [ ] AC8: After saving, the app optionally prompts the store owner to notify the customer via WhatsApp with a pre-filled Urdu message showing the new balance; the store owner can dismiss without sending.
- [ ] AC9: The pre-filled WhatsApp notification message uses the shop name from the local `Shops` table and is formatted as: "Assalamualaikum [Name] bhai, [Shop Name] mein aaj PKR [amount] ka udhaar hua. Aapka total baqi: PKR [balance]. Shukriya."
- [ ] AC10: An optional free-text note field is available on the entry screen (always optional, never required).
- [ ] AC11: An optional voice note recording button is available; recorded audio is saved to a local file path and `voice_note_path` is stored on the event.
- [ ] AC12: The entire flow from tapping the credit button to the save confirmation completes in under 10 seconds on target hardware (manual timing criterion).
- [ ] AC13: Amount zero is not accepted; the save button is disabled until amount > 0.
- [ ] AC14: All user-facing strings are in Urdu.

## Technical Notes
### Flutter
- Screen: `CreditEntryScreen` — receives `customerId` as a route argument.
- Large numeric keypad widget: custom `AmountKeypad` widget, integer-only input, shows PKR label. Store raw paisa value as `int`.
- On save: call `EventsDao.insertEvent(...)` inside a Drift transaction that also inserts `SyncQueue` row.
- "Hisaab saaf" state: after insert, re-compute balance; if balance == 0, push a `HisaabSaafScreen` or show a full-screen overlay with celebration animation (Lottie or Flutter `AnimationController`).
- WhatsApp deep link: `url_launcher` to open `https://wa.me/{phone}?text={encodedMessage}`. Only shown if customer has a phone number.
- Voice note: use `flutter_sound` or `record` package. Save to app documents directory. Store relative path in `voice_note_path`.
- Riverpod: `creditEntryProvider` manages entry form state (amount, note, voice note path).

### Django
- No new endpoints required. The CREDIT event reaches the server via the sync engine (STORY-013) using `POST /api/sync/events`.

## Offline Behaviour
The entire credit entry flow is offline-capable. The Events insert and SyncQueue insert are local SQLite operations. The balance recomputation reads from the local event log. The WhatsApp deep link opens the WhatsApp app locally — no server involved. The voice note is saved to local device storage. The SyncQueue entry for this event will be flushed by the sync engine (STORY-013) when connectivity is next detected.

## Dependencies
- STORY-006 (Drift event log and insertEvent must be implemented)
- STORY-007 (customer list screen for navigation entry point)

## Definition of Done
- [ ] All ACs passing
- [ ] flutter test passing
- [ ] flutter analyze clean
- [ ] python -m pytest passing
- [ ] Offline behaviour verified manually
