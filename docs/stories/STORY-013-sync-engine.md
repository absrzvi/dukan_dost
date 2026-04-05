# STORY-013: Sync Engine (SyncQueue Flush on Connectivity, Push + Pull Sync)
Status: TODO
Sprint: 4
Points: 8

## User Story
As a kiryana store owner, I want the app to automatically sync all locally recorded transactions and changes to the server whenever my phone has an internet connection — and pull down any events from other devices — so that my data is safely backed up without me having to think about it.

## Acceptance Criteria
- [ ] AC1: The sync engine is event-triggered on connectivity change (not polling). When the device transitions from offline to online, a sync cycle starts automatically within 5 seconds.
- [ ] AC2: A sync cycle consists of two phases in order: (1) push — flush all PENDING SyncQueue entries to the server; (2) pull — fetch events from the server since the last known `server_timestamp`.
- [ ] AC3: Push phase: all SyncQueue rows with `status=PENDING` are read, grouped into batches of up to 500 events, and posted to `POST /api/sync/events`. Each batch is sent sequentially.
- [ ] AC4: On a successful batch POST, the SyncQueue rows for those events are updated to `status=SYNCED` and the returned `server_timestamp` is written to the corresponding Events rows.
- [ ] AC5: If a batch POST fails (network error or 5xx), the SyncQueue rows are updated to `status=FAILED` and `retry_count` is incremented. Failed entries are retried on the next sync cycle.
- [ ] AC6: The server treats duplicate event UUIDs as idempotent (already specified in API_CONTRACTS.md). The client may safely re-send FAILED entries without risk of duplicate data on the server.
- [ ] AC7: Pull phase: `GET /api/sync/events?since={last_server_timestamp}` is called after push completes. Returns events created on other devices (or confirmed server timestamps for local events).
- [ ] AC8: Pulled events that already exist locally (matched by UUID) are used only to update the `server_timestamp` field on the local Events row — no new row is inserted.
- [ ] AC9: Pulled events with a UUID not present locally are inserted into the local Events table (from another device for the same shop).
- [ ] AC10: After a successful pull, the `last_sync_at` field in the local `Shops` table is updated to the current time.
- [ ] AC11: The sync engine respects the batch size limit: if `has_more=true` in the pull response, subsequent pull requests are made with the updated cursor until `has_more=false`.
- [ ] AC12: A `SyncStatus` Riverpod provider exposes the current state: `idle`, `syncing`, `error`. The app bar offline indicator (STORY-014) consumes this provider.
- [ ] AC13: The sync engine never blocks the UI thread. All network and database operations run in a background isolate or async context.
- [ ] AC14: Unit tests cover: batch splitting at 500 events, idempotent re-send of failed entries, pull deduplication by UUID.

## Technical Notes
### Flutter
- `SyncEngine` service class in `lib/core/sync/sync_engine.dart`.
- Connectivity detection: `connectivity_plus` package. Listen to `ConnectivityResult` stream; trigger sync on transition to a non-`none` result.
- Push logic:
  1. `SyncQueueDao.getPendingBatch(limit: 500)` — returns up to 500 PENDING queue rows.
  2. Mark them `IN_FLIGHT` in Drift.
  3. Call `ApiClient.postSyncEvents(events)`.
  4. On success: update status to `SYNCED`, write `server_timestamp` to Events rows.
  5. On failure: update status to `FAILED`, increment `retry_count`.
  6. Repeat until no more PENDING rows.
- Pull logic:
  1. Read `last_sync_at` from local `Shops` table (use as `since` cursor).
  2. Call `ApiClient.getSyncEvents(since: cursor, limit: 500)`.
  3. For each returned event: if UUID exists locally, update `server_timestamp`; else insert new event row.
  4. If `has_more=true`, repeat with `latest_server_timestamp` as new cursor.
  5. Update `Shops.last_sync_at`.
- `SyncStatusNotifier` (Riverpod `StateNotifier`) with states `SyncIdle`, `SyncInProgress`, `SyncError(message)`.
- Use `Isolate.run` or a `compute` wrapper for the batch processing logic to keep the UI responsive.

### Django
- `POST /api/sync/events` — batch event upload, idempotent by UUID (defined in API_CONTRACTS.md).
- `GET /api/sync/events?since=&limit=` — pull sync (defined in API_CONTRACTS.md).
- Both endpoints must be implemented and tested in this story.
- Django view tests: (1) upload 3 events, receive `accepted=3`; (2) re-upload same events, receive `duplicates=3, accepted=0`; (3) upload event with wrong shop_id → 403; (4) upload batch > 500 → 413; (5) pull since timestamp returns only events after that timestamp.
- Ensure the `Event` model's append-only constraint (no UPDATE/DELETE) is enforced in the Django layer.

## Offline Behaviour
The sync engine only activates when connectivity is detected. All core features (transaction entry, balance display, reminder dispatch) are fully functional with the sync engine idle or absent. When offline, SyncQueue entries accumulate in PENDING state. When connectivity returns, the engine flushes them. The app must never prevent a user action because sync is in progress or has failed.

## Dependencies
- STORY-006 (Drift SyncQueue table and EventsDao)
- STORY-004 (OTP auth — session token required for all sync API calls)
- STORY-014 (offline indicator consumes SyncStatus from this story — can be developed in parallel but depends on the provider interface being defined here)

## Definition of Done
- [ ] All ACs passing
- [ ] flutter test passing
- [ ] flutter analyze clean
- [ ] python -m pytest passing
- [ ] Offline behaviour verified manually
