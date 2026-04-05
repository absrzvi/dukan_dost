# STORY-015: Backup (Local SQLite Export + Optional Google Drive)
Status: TODO
Sprint: 5
Points: 5

## User Story
As a kiryana store owner, I want the app to automatically save a backup of all my transaction data to my phone storage — and optionally to Google Drive — so that if I lose my phone I can restore my full ledger history on a new device.

## Acceptance Criteria
- [ ] AC1: The app performs a local backup daily when the app is open and the device is charging. The backup is a copy of the SQLite database file exported to the device's external storage directory (e.g. `Downloads/DukaanDost/backup_{date}.db`).
- [ ] AC2: A "Backup" settings screen is accessible from the main menu. It shows: last local backup time, last Google Drive backup time (if enabled), backup file size, and a "Backup Now" manual trigger button.
- [ ] AC3: Each backup operation writes a row to the local Drift `Backups` table with `backup_type`, `file_path` or `gdrive_file_id`, `file_size_bytes`, `status`, and `completed_at`.
- [ ] AC4: On completion of a backup, `POST /api/backup/metadata` is called to record the backup on the server (for restore flow on new devices). If offline, this is queued for sync.
- [ ] AC5: Google Drive backup is opt-in. Enabling it triggers Google Sign-In (using the Google Drive API scoped to the app-specific folder only — not full Drive access). Once authenticated, backups are automatically uploaded to Google Drive after each local backup.
- [ ] AC6: The backup settings screen clearly displays the message: "Agar phone gum ho jaye aur aakhri backup ke baad transactions sync nahi hue, toh woh transactions wapas nahi aayenge." (shown in Urdu; also shown during onboarding).
- [ ] AC7: On new device setup (after OTP verification), if the server has backup metadata on record, the app offers a "Restore from Google Drive" option that downloads and restores the latest backup file.
- [ ] AC8: The restore flow clearly states what data will be restored and warns that events since the last backup that were not synced are irrecoverable.
- [ ] AC9: Backup runs in the background without blocking the UI; a non-intrusive snackbar or app bar indicator shows when a backup is in progress.
- [ ] AC10: Local backup files older than 7 days are automatically pruned to manage device storage.
- [ ] AC11: All user-facing strings in the backup flow are in Urdu.

## Technical Notes
### Flutter
- `BackupService` in `lib/core/backup/backup_service.dart`.
- Local backup: use `sqflite` path + `dart:io` `File.copy()` to copy the Drift DB file to `getExternalStorageDirectory()`. Use `path_provider` package.
- Charging detection: `battery_plus` package — check `BatteryState.charging` before triggering automatic backup.
- Daily trigger: use `WorkManager` (via `workmanager` Flutter package) to register a periodic background task. Runs when app is open and charging. Do NOT use a polling `Timer` — use WorkManager constraints (`requiresCharging: true`, `frequency: Duration(days: 1)`).
- Google Drive: `google_sign_in` + `googleapis` packages. Scope: `DriveApi.driveAppdataScope` (app-specific folder, not visible to user in Drive UI — prevents clutter). Upload file as multipart upload.
- `BackupsDao` in Drift: `insertBackup(...)`, `getLatestBackup(shopId, type)`, `pruneOldLocalBackups(shopId, keepCount: 7)`.
- Restore flow: shown in `OnboardingScreen` after OTP verify if `is_new_shop=false` and server has backup metadata. Download the Google Drive file by `gdrive_file_id`, replace the Drift DB file, restart the database connection.
- Backup metadata sync: `POST /api/backup/metadata` call wrapped in the sync engine (STORY-013) flow — or called directly after backup completes if online.

### Django
- `POST /api/backup/metadata` is defined in API_CONTRACTS.md. Implement the view and serializer. Store `BackupMetadata` model (shop, backup_type, gdrive_file_id, file_size_bytes, device_id, created_at).
- Add a `GET /api/backup/metadata/latest` endpoint (not in current API_CONTRACTS.md — flutter-dev and django-dev must agree and update API_CONTRACTS.md) that returns the most recent backup metadata for the authenticated shop, to support the new-device restore prompt.
- Tests: create backup metadata, retrieve latest, confirm shop isolation (one shop cannot see another's metadata).

## Offline Behaviour
Local backup runs entirely on-device and requires no network. Google Drive upload requires connectivity — if offline when a backup completes, the Drive upload is deferred and retried on next connectivity. The `POST /api/backup/metadata` call is queued via the sync engine if offline. The restore flow requires connectivity (to retrieve backup metadata from server and download from Google Drive) — this is the only flow in the app that is legitimately gated on network, and it is part of the new-device setup where connectivity is expected.

## Dependencies
- STORY-004 (session token required for `POST /api/backup/metadata`)
- STORY-013 (sync engine for queuing backup metadata POST when offline)

## Definition of Done
- [ ] All ACs passing
- [ ] flutter test passing
- [ ] flutter analyze clean
- [ ] python -m pytest passing
- [ ] Offline behaviour verified manually
