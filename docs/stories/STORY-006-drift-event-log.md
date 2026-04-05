# STORY-006: Drift Event Log (Local SQLite Append-Only Event Log with Balance Computation)
Status: TODO
Sprint: 2
Points: 5

## User Story
As a flutter-dev agent, I want the local Drift database to have a fully working, append-only Events table with balance computation queries and a SyncQueue table, so that all subsequent transaction features can write events locally and read computed balances without any network dependency.

## Acceptance Criteria
- [ ] AC1: Drift `Events` table is created with all fields defined in DATA_MODEL.md: `id`, `shop_id`, `event_type` (CHECK IN CREDIT/PAYMENT/REVERSAL/REMINDER_SENT), `party_type` (CHECK IN CUSTOMER/SUPPLIER), `party_id`, `amount_paisa` (>= 0), `note`, `voice_note_path`, `device_id`, `actor_label`, `device_timestamp`, `server_timestamp`, `created_at`.
- [ ] AC2: All four indexes defined in DATA_MODEL.md are present: `idx_events_party`, `idx_events_shop`, `idx_events_device_ts`, `idx_events_server_ts`.
- [ ] AC3: The Drift DAO exposes an `insertEvent()` method that appends a new event and simultaneously inserts a corresponding `SyncQueue` row with status PENDING.
- [ ] AC4: There is no `updateEvent()` or `deleteEvent()` method. Corrections are modelled as REVERSAL events only.
- [ ] AC5: `computeBalance(partyType, partyId)` method replays the event log for the given party and returns an integer paisa balance: sum of CREDIT amounts minus sum of PAYMENT and REVERSAL amounts.
- [ ] AC6: `computeBalance` returns 0 (not null) when a party has no events.
- [ ] AC7: `watchEventsForParty(partyType, partyId)` returns a Drift `Stream` of event lists ordered by `device_timestamp` ascending, usable by Riverpod `StreamProvider`.
- [ ] AC8: `SyncQueue` table is created with all fields in DATA_MODEL.md; `idx_syncqueue_status` index is present.
- [ ] AC9: All monetary amounts in tests use integer paisa with no floating-point arithmetic.
- [ ] AC10: Unit tests cover: insert event, balance computation (credit only, payment only, mixed, zero balance, reversal), and stream emission on new insert.

## Technical Notes
### Flutter
- Drift table classes: `EventsTable`, `SyncQueueTable` in `lib/core/database/tables/`.
- DAO: `EventsDao` in `lib/core/database/daos/events_dao.dart`.
- `insertEvent()` should be wrapped in a Drift transaction so the Events insert and SyncQueue insert are atomic.
- `computeBalance()`: use a Drift typed query — `SELECT SUM(amount_paisa) FROM events WHERE party_type=? AND party_id=? AND event_type IN ('CREDIT')` minus `SELECT SUM(amount_paisa) FROM events WHERE party_type=? AND party_id=? AND event_type IN ('PAYMENT','REVERSAL')`. Handle NULL sums (no rows) as 0.
- `device_id` is populated from a `DeviceIdService` that generates and persists a UUID at first launch (stored in SharedPreferences).
- Riverpod provider: `eventsForPartyProvider(PartyKey)` wraps `watchEventsForParty` as a `StreamProvider.autoDispose.family`.
- Run `dart run build_runner build` after table definitions to generate Drift code.

### Django
- No new Django work required in this story. The Events and SyncQueue are purely client-side constructs at this stage. Django sync endpoints are covered in STORY-013.

## Offline Behaviour
This story IS the offline foundation. Every write goes directly to the local SQLite database. There is no network call in any code path in this story. The SyncQueue rows created here will be flushed by STORY-013 when connectivity is available.

## Dependencies
- STORY-002 (Flutter project scaffold must be in place with Drift dependency in pubspec.yaml)

## Definition of Done
- [ ] All ACs passing
- [ ] flutter test passing
- [ ] flutter analyze clean
- [ ] python -m pytest passing
- [ ] Offline behaviour verified manually
