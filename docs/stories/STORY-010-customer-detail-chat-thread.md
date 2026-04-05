# STORY-010: Customer Detail / Chat-Thread View (Transaction History Per Customer)
Status: TODO
Sprint: 3
Points: 5

## User Story
As a kiryana store owner, I want to open a customer's profile and see their full transaction history displayed as a chat-thread — with credits on one side, payments on the other, and the running balance pinned at the top — so that I can instantly resolve disputes at the counter and share the full history with a customer over WhatsApp if needed.

## Acceptance Criteria
- [ ] AC1: Tapping a customer on the home screen navigates to a `CustomerDetailScreen` that displays the customer's name, current balance (large, high-contrast), and "no phone" indicator if applicable.
- [ ] AC2: The transaction history is rendered as a chat-thread: CREDIT events bubble on the right (money given), PAYMENT events bubble on the left (money received). REVERSAL events are shown with a strikethrough or "cancelled" label inline.
- [ ] AC3: Each bubble shows the amount in PKR, the timestamp formatted as "DD MMM, HH:mm" (e.g. "03 Apr, 14:35"), and an optional note if present.
- [ ] AC4: A voice note play button appears inline on any event that has a `voice_note_path`; tapping it plays the recording.
- [ ] AC5: The running balance is pinned at the top of the screen (not inside the scroll area) and updates reactively via a Drift `StreamProvider`.
- [ ] AC6: The transaction history loads within 2 seconds for up to 500 events (performance criterion — no network call, local Drift query only).
- [ ] AC7: The last reminder sent date is visible on this screen (derived from the most recent `REMINDER_SENT` event for this customer).
- [ ] AC8: A "Takaza bhejna" (send reminder) button is present; tapping it opens the reminder flow from STORY-011.
- [ ] AC9: A "History share karein" button generates a plain-text formatted history and opens it in WhatsApp as a pre-filled message to the customer's phone number.
- [ ] AC10: The plain-text history format includes shop name, customer name, each transaction with date and amount, and the current balance at the bottom.
- [ ] AC11: If the customer has no phone number, the "History share karein" and reminder buttons show a tooltip directing the store owner to add a phone number first.
- [ ] AC12: The store owner can flag/unflag the customer for follow-up from this screen; flagging updates the `is_flagged` field in Drift and queues a sync.
- [ ] AC13: All user-facing strings are in Urdu.

## Technical Notes
### Flutter
- Screen: `CustomerDetailScreen` — receives `customerId` as route argument.
- Balance: `StreamProvider` wrapping `EventsDao.watchEventsForParty(CUSTOMER, customerId)` with a derived provider computing the balance.
- Chat thread: `ListView.builder` with items rendered as `ChatBubbleWidget(event)`. Align right for CREDIT, left for PAYMENT. Use distinct background colours (e.g. amber for credit, green for payment).
- Voice note playback: `just_audio` or `audioplayers` package. Load from `voice_note_path` stored in event.
- Last reminder: query `EventsDao` for the most recent event where `event_type=REMINDER_SENT AND party_id=customerId`. Display as "Aakhri takaza: DD MMM".
- History share: build a plain-text string from the event list. Use `url_launcher` to open `wa.me/{phone}?text={encoded}`. URL-encode the full string.
- Flag toggle: `CustomersDao.setFlagged(customerId, bool)` updates local Drift row and creates a SyncQueue entry (customer update).
- Navigation to credit/payment entry: two FABs or prominently placed buttons for "+ Udhaar" and "- Wapsi".

### Django
- `GET /api/customers/{id}/events` is defined in API_CONTRACTS.md and can be used for an online cross-check after sync, but the screen never waits for it.

## Offline Behaviour
The entire customer detail screen is served from the local Drift database. All event history, balances, voice notes, and timestamps are available offline. The "History share karein" WhatsApp deep link is a device-level operation requiring no server. Flagging a customer writes locally and queues for sync. The screen must never show a loading spinner gated on network.

## Dependencies
- STORY-006 (Drift event log and watchEventsForParty stream)
- STORY-008 (credit entry navigation)
- STORY-009 (payment entry navigation)

## Definition of Done
- [ ] All ACs passing
- [ ] flutter test passing
- [ ] flutter analyze clean
- [ ] python -m pytest passing
- [ ] Offline behaviour verified manually
