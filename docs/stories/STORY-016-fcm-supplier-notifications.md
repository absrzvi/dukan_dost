# STORY-016: FCM Push Notifications for Supplier Payment Due Dates
Status: TODO
Sprint: 5
Points: 5

## User Story
As a kiryana store owner, I want to receive a push notification on my phone 2 days before a supplier payment is due, so that I can prepare the payment in advance and avoid overdue penalties with my FMCG distributors.

## Acceptance Criteria
- [ ] AC1: When a supplier record with a due date is created or updated, the FCM token for the device is registered (or refreshed) on the server via the `Device` model.
- [ ] AC2: A Django management command (or Celery beat task) runs daily to identify supplier records where `due_date = today + 2 days` and `is_paid = false`. For each match, an FCM push notification is sent to all active devices registered to that shop.
- [ ] AC3: The FCM notification payload includes: title "Supplier payment jald aane wali hai", body "[Supplier Name] ko PKR [amount] ki payment [due_date] tak karni hai.", and a `data` field with `supplier_id` and `shop_id`.
- [ ] AC4: Tapping the FCM notification opens the app and navigates directly to the Suppliers tab.
- [ ] AC5: The FCM token is stored in the `Device.fcm_token` field on the server. The Flutter app registers/refreshes the FCM token on each app launch and on FCM token refresh callbacks.
- [ ] AC6: If the FCM notification cannot be delivered (invalid token, device offline), the failure is logged server-side but does not raise an exception that breaks the daily job.
- [ ] AC7: The in-app supplier list (STORY-012) continues to show due-date highlights independently of FCM — push notifications are supplementary, not the sole alert mechanism.
- [ ] AC8: A device that has FCM disabled or no FCM token still receives the in-app due-date highlight; the notification is simply not sent.
- [ ] AC9: Unit tests cover: notification is triggered for a supplier due in exactly 2 days; notification is NOT triggered for a supplier due in 1 day or 3 days; notification is NOT triggered for a paid supplier; notification is NOT triggered for a deleted supplier.

## Technical Notes
### Flutter
- `FirebaseMessaging.instance.getToken()` called at app startup in `main.dart` after OTP auth is confirmed. Token sent to `PUT /api/shop/device` (or a new `POST /api/devices/register` endpoint — django-dev and flutter-dev must agree and update API_CONTRACTS.md).
- `FirebaseMessaging.onTokenRefresh` listener: re-sends updated token to the server.
- `FirebaseMessaging.onMessageOpenedApp` listener: if notification `data.supplier_id` is present, navigate to the Suppliers tab. Use `GoRouter` or `Navigator` with the `supplier_id` for deep link routing.
- `FirebaseMessaging.onMessage` (foreground): show a local notification using `flutter_local_notifications` package so the alert is visible when the app is in the foreground.
- Add `google-services.json` to `android/app/`. Firebase project must be configured with the app's package name (`com.dukaandost`).

### Django
- New management command: `backend/apps/suppliers/management/commands/send_due_date_notifications.py`.
- Logic: `Supplier.objects.filter(due_date=date.today() + timedelta(days=2), is_paid=False, is_deleted=False)`. For each result, get all active `Device` records for `supplier.shop` where `fcm_token` is not null and `is_active=True`. Call Firebase Admin SDK `messaging.send()` for each token.
- Firebase Admin SDK: `firebase-admin` Python package. Credentials via `FIREBASE_SERVICE_ACCOUNT_JSON` environment variable (path to service account JSON).
- Handle `messaging.UnregisteredError` and `messaging.InvalidArgumentError`: set `device.fcm_token=None` and `device.is_active=False` on these errors to keep the token list clean.
- Schedule via `cron` on the server (or `django-celery-beat` if Celery is already in the stack). Run at 09:00 PKT daily.
- Add `FIREBASE_SERVICE_ACCOUNT_JSON` to `.env.example`.
- New endpoint for device FCM token registration: `PUT /api/devices/{device_id}/fcm-token` — request body `{"fcm_token": "..."}`. Update or create the `Device` record for `(shop, device_id)`.
- Tests: mock Firebase Admin SDK `messaging.send`; assert correct suppliers selected; assert paid/deleted suppliers skipped; assert `UnregisteredError` deactivates the device.

## Offline Behaviour
FCM push notifications are delivered by Firebase infrastructure — they queue on Google's servers and are delivered when the device comes online. The in-app due-date highlight (STORY-012) works fully offline and is the primary visual indicator; FCM is supplementary. The FCM token registration requires connectivity at app launch (it is a Firebase SDK call) — if the token cannot be registered, the app continues normally and retries on next launch. No core feature depends on FCM being available.

## Dependencies
- STORY-004 (OTP auth — shop and device context required to register FCM token)
- STORY-012 (supplier ledger — supplier records must exist on the server for the daily notification job to query)
- STORY-013 (sync engine — supplier records must be synced to the server before the notification job can find them)

## Definition of Done
- [ ] All ACs passing
- [ ] flutter test passing
- [ ] flutter analyze clean
- [ ] python -m pytest passing
- [ ] Offline behaviour verified manually
