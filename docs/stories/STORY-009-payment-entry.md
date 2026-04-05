# STORY-009: Payment Entry (Record a Payment / Wapsi Against Udhaar)
Status: TODO
Sprint: 3
Points: 3

## User Story
As a kiryana store owner, I want to record a payment received from a customer (wapsi) in under 10 seconds and see the remaining balance immediately, so that I can keep my ledger accurate in real time and optionally send the customer a WhatsApp receipt confirming the payment.

## Acceptance Criteria
- [ ] AC1: From the customer list or customer detail screen, tapping the payment (wapsi) button opens an amount entry screen with a large numeric keypad.
- [ ] AC2: The numeric keypad accepts integer amounts only; displays PKR value formatted from paisa.
- [ ] AC3: Tapping save writes a `PAYMENT` event to the local Drift `Events` table instantly with no network call on the critical path.
- [ ] AC4: The event record contains: client-generated UUID, `shop_id`, `event_type=PAYMENT`, `party_type=CUSTOMER`, `party_id`, `amount_paisa`, `device_id`, `actor_label`, `device_timestamp`, `server_timestamp=null`.
- [ ] AC5: Simultaneously with the Events insert, a `SyncQueue` row is created with `status=PENDING` (atomic Drift transaction).
- [ ] AC6: After saving, the remaining balance is displayed immediately — computed by replaying the local event log, with no network call.
- [ ] AC7: If the balance reaches exactly zero after this payment, the "Hisaab saaf" celebration state is shown.
- [ ] AC8: After saving a payment, the app optionally prompts the store owner to send a WhatsApp receipt to the customer; the pre-filled message confirms the payment and shows the new remaining balance: "Assalamualaikum [Name] bhai, [Shop Name] mein aaj PKR [amount] wapsi mili. Baqi balance: PKR [remaining]. Shukriya."
- [ ] AC9: If the remaining balance is zero, the receipt message reads: "Assalamualaikum [Name] bhai, [Shop Name] ka hisaab saaf ho gaya. Shukriya."
- [ ] AC10: Partial payments are fully supported — the remaining balance reflects exactly what is still owed after the partial payment.
- [ ] AC11: Amount zero is not accepted; the save button is disabled until amount > 0.
- [ ] AC12: An optional free-text note field is available (never required).
- [ ] AC13: All user-facing strings are in Urdu.

## Technical Notes
### Flutter
- Screen: `PaymentEntryScreen` — receives `customerId` as a route argument.
- Reuses the `AmountKeypad` widget built in STORY-008.
- On save: `EventsDao.insertEvent(...)` with `event_type=PAYMENT`.
- Balance after payment: `EventsDao.computeBalance(CUSTOMER, customerId)` — called immediately after insert.
- "Hisaab saaf": same celebration overlay/screen as STORY-008 (shared widget).
- WhatsApp receipt deep link: only shown if customer has a phone number; constructed with `url_launcher`.
- Riverpod: `paymentEntryProvider` manages entry form state.

### Django
- No new endpoints. PAYMENT event reaches server via sync engine (STORY-013).

## Offline Behaviour
Identical to credit entry (STORY-008): all writes are local SQLite operations. Balance recomputation is local. WhatsApp receipt is a device-level deep link. SyncQueue entry flushes on next connectivity event via STORY-013.

## Dependencies
- STORY-006 (Drift event log)
- STORY-008 (AmountKeypad widget and "Hisaab saaf" celebration state to be reused)

## Definition of Done
- [ ] All ACs passing
- [ ] flutter test passing
- [ ] flutter analyze clean
- [ ] python -m pytest passing
- [ ] Offline behaviour verified manually
