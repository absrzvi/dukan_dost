# Architecture Decision Records — Dukaan Dost
Status: Approved

> This file is maintained by the architect agent via /architect.
> Set Status to APPROVED to unblock the scrum-master agent.
> Last updated: 2026-04-05

---

### ADR-001: Offline-First Architecture and Append-Only Event Log
Date: 2026-04-05
Status: APPROVED

#### Context
Dukaan Dost targets kiryana store owners in Pakistan where electricity load-shedding (4-14 hours/day) and unreliable 2G/3G connectivity are the norm. The app must never gate a core action on network availability. The anchor user story — recording a transaction in under 10 seconds — must work identically whether the device is online or offline.

Additionally, financial ledger data demands an immutable audit trail. Paper ledgers are never "edited" — mistakes are crossed out and corrected with a new line. The digital system must preserve this property.

#### Decision
1. **Local-first writes:** Every transaction write goes to SQLite (via Drift) FIRST. The network is never on the critical path for any data entry operation.
2. **Append-only event log:** The Events table is immutable. No UPDATE or DELETE on transaction records. Corrections are modelled as reversal entries (a new event that negates the original).
3. **Computed balances:** Balances are never stored as mutable fields. They are always computed by replaying the event log filtered by party. This guarantees consistency and eliminates state synchronisation bugs.
4. **Sync queue:** Every local write creates an entry in the SyncQueue table. A background process flushes the queue when connectivity is detected (event-triggered, not polling, to preserve battery).
5. **Offline indicator:** A subtle indicator in the app bar shows when the device is offline. No features are disabled — only sync is deferred.

#### Consequences
- **Positive:** 100% of core features work offline. Transaction entry is sub-second (local SQLite write). No data loss from connectivity interruptions.
- **Negative:** Balances require a full event replay per party. For MVP scale (50-200 customers, <10K events per shop), this is negligible (<50ms). If scale increases, a materialised balance cache with event-log-driven invalidation can be introduced later.
- **Negative:** Unsynced events since last backup are irrecoverable if the device is lost. This is communicated to users during onboarding.

#### Rejected Alternatives
- **Online-first with offline cache:** Rejected because it inverts the reliability model. Any network dependency on the write path is an architecture failure for this user context.
- **CRDT-based state:** Rejected as over-engineered for MVP. Append-only logs with server-side ordering are simpler and sufficient. CRDTs add complexity without clear benefit when the conflict model is "all writes are valid, just order them."
- **Mutable balance fields with sync:** Rejected because mutable state synchronisation across devices is a known source of bugs and data corruption. Append-only + recompute is simpler and provably correct.

---

### ADR-002: Flutter + Drift/SQLite as Mobile Stack
Date: 2026-04-05
Status: APPROVED

#### Context
The primary target device is a low-end Android phone (Tecno Spark, Samsung Galaxy A-entry, 2-3GB RAM, Android 10-12). The app must launch in under 3 seconds, scroll 500 transactions at 60fps, and keep total footprint under 150MB. iOS is a Phase 3 concern but should come at near-zero marginal cost.

#### Decision
1. **Flutter** as the cross-platform mobile framework. Single Dart codebase for Android (MVP) and iOS (Phase 3).
2. **Drift** (formerly Moor) as the typed SQLite ORM for local storage. Drift provides compile-time SQL verification, type-safe queries, and reactive streams — reducing runtime errors in financial data handling.
3. **SQLite** as the local database engine via Drift. Battle-tested, zero-configuration, embedded, and performant on low-end hardware.

#### Consequences
- **Positive:** Single codebase for Android and future iOS. Dart's AOT compilation produces performant native code. Drift's type safety catches schema errors at compile time rather than runtime.
- **Positive:** Flutter's widget-level rendering means chat-thread transaction history can be built with standard ListView without native platform dependencies.
- **Negative:** Flutter adds ~15-20MB to APK size. Acceptable given the 150MB budget.
- **Negative:** Team must learn Dart if not already proficient. Dart's ecosystem is smaller than Kotlin/Swift but adequate for this use case.

#### Rejected Alternatives
- **React Native:** Rejected due to worse performance on low-end devices (JavaScript bridge overhead), larger bundle size, and less predictable scroll performance for the 500-transaction benchmark.
- **Kotlin (native Android):** Rejected because it locks out iOS without a full rewrite. Flutter provides iOS at near-zero marginal cost.
- **PWA / Web app:** Rejected because offline storage limits in browsers are unreliable, service worker APIs are inconsistent on low-end Android WebViews, and the app needs native contact import and file system access for backups.

---

### ADR-003: Django REST Framework + PostgreSQL + Redis as Backend Stack
Date: 2026-04-05
Status: APPROVED

#### Context
The backend serves three functions: (1) store the authoritative copy of the event log, (2) authenticate users via OTP, and (3) serve API endpoints for sync and data retrieval. The backend is not on the critical path for any user-facing action — it is a sync target and auth provider.

#### Decision
1. **Django REST Framework (DRF)** as the API layer. Python ecosystem provides rapid development, strong ORM, and mature auth libraries.
2. **PostgreSQL** as the primary database. ACID-compliant, supports append-only patterns naturally, excellent indexing for time-series event queries.
3. **Redis** for: (a) OTP code storage with TTL-based expiry (5 minutes), (b) sync queue caching, (c) rate limiting on auth endpoints.

#### Consequences
- **Positive:** Django's ORM, migration system, and admin panel accelerate development. DRF serializers provide request validation out of the box.
- **Positive:** PostgreSQL's JSONB support allows flexible event metadata without schema migrations for every new field.
- **Positive:** Redis TTL handles OTP expiry without cron jobs or manual cleanup.
- **Negative:** Python is slower than Go/Rust for raw throughput. Acceptable because the backend is not latency-critical (sync happens in background) and MVP scale is <10K shops.

#### Rejected Alternatives
- **Firebase / Supabase (BaaS):** Rejected because (a) event-log append-only semantics need custom enforcement not easily expressed in BaaS rules, (b) vendor lock-in on a Pakistani-market product is risky, (c) offline sync logic in Flutter would still need custom code.
- **Node.js / Express:** Rejected due to weaker ORM ecosystem and less mature migration tooling compared to Django. TypeScript adds safety but Django + DRF provides more out of the box.
- **Go:** Rejected because development speed is more important than raw performance at MVP scale. Django's batteries-included approach wins here.

---

### ADR-004: WhatsApp Deep Links as Notification Layer (with SMS Fallback)
Date: 2026-04-05
Status: APPROVED

#### Context
Pakistani kiryana store owners live on WhatsApp. It is the universal communication tool across all socioeconomic levels. Building an in-app notification system would be redundant — users already check WhatsApp constantly. The MVP needs reminders (takaza), transaction notifications, and history sharing.

#### Decision
1. **WhatsApp deep links** (`wa.me/{phone}?text={encoded_message}`) as the primary notification channel. The Flutter app constructs the deep link and opens it — WhatsApp handles delivery.
2. **No WhatsApp Business API in MVP.** Deep links use the store owner's personal WhatsApp number, making messages feel personal rather than institutional.
3. **SMS fallback** for customers without WhatsApp (no phone number or feature phone). SMS sent via local Pakistani gateway (Infobip / Avanza / TeleCom).
4. **FCM push notifications** only for supplier payment due date reminders (2 days before due).
5. **Three pre-filled Urdu reminder templates** (gentle/firm/final) based on days overdue (7+/14+/21+). Store owner can edit before sending.

#### Consequences
- **Positive:** Zero infrastructure cost for WhatsApp reminders (deep links are free). No WhatsApp Business API approval process or per-message fees.
- **Positive:** Messages come from the store owner's number — preserving the personal relationship dynamic that is culturally critical.
- **Negative:** No delivery confirmation or read receipt data available to the app (deep link just opens WhatsApp — we cannot confirm the message was actually sent). The REMINDER_SENT event logs intent, not confirmed delivery.
- **Negative:** SMS fallback incurs per-message cost via the gateway.

#### Rejected Alternatives
- **WhatsApp Business API:** Rejected for MVP due to approval lead time, per-message cost, and the institutional feel of business messages (which undermines the personal relationship model).
- **In-app push notifications:** Rejected per iron rule — WhatsApp is the only notification channel in MVP.
- **Email notifications:** Rejected because the target user persona does not use email for business communication.

---

### ADR-005: Phone Number + OTP Authentication (No Email, No Social Login)
Date: 2026-04-05
Status: APPROVED

#### Context
Target users (kiryana store owners, age 35-50, Karachi) universally have a phone number but may not have an email address or Google/Facebook accounts configured for OAuth. The authentication method must match the user's existing digital identity — which is their phone number.

#### Decision
1. **Phone number + OTP** as the sole authentication method.
2. OTP delivered via SMS through a local Pakistani gateway (Infobip / Avanza / TeleCom).
3. OTP codes are **6-digit numeric**, single-use, and expire after **5 minutes**.
4. On successful OTP verification, the server returns a **session token** (opaque, long-lived) stored in Flutter secure storage.
5. Every Django API endpoint validates the session token. No unprotected routes.
6. Rate limiting: max 5 OTP requests per phone number per hour (Redis-backed).
7. `user_id` / `shop_id` is extracted from the authenticated session only — never from request body or query params.

#### Consequences
- **Positive:** Lowest friction onboarding possible. Phone number is the one identifier every user has.
- **Positive:** No password management, no password reset flow, no email verification.
- **Negative:** SMS delivery is not 100% reliable (network delays, gateway issues). Mitigated by retry logic and clear error messaging.
- **Negative:** SIM swap attacks are a theoretical risk. Acceptable for MVP — no high-value financial transactions are processed through the app (it is a ledger, not a payment system).

#### Rejected Alternatives
- **Email + password:** Rejected because target users do not reliably have email accounts.
- **Social login (Google/Facebook):** Rejected because it adds friction (which account? what permissions?) and many target users do not have these configured.
- **Biometric auth:** Rejected as primary auth (low-end devices have inconsistent fingerprint sensor quality). Can be added as session unlock in Phase 2.

---

### ADR-006: Sync Protocol Design (Batch Event Upload, Conflict Resolution)
Date: 2026-04-05
Status: APPROVED

#### Context
The app operates offline-first. Events accumulate locally and must sync to the server when connectivity is available. The sync protocol must handle: (a) batch uploads of potentially hundreds of events after extended offline periods, (b) pulling events from other devices for the same shop, (c) conflict resolution — though the append-only model largely eliminates traditional conflicts.

#### Decision
1. **Batch upload:** `POST /api/sync/events` accepts an array of events. Each event carries a client-generated UUID, device_id, and device_timestamp. The server assigns a server_timestamp on receipt.
2. **Idempotent uploads:** The server uses the event UUID as a deduplication key. Re-uploading the same event (e.g., after a network timeout where the client didn't receive the 200) is a no-op.
3. **Pull sync:** `GET /api/sync/events?since={server_timestamp}` returns all events for the shop since the given timestamp. This allows a device to pull events created on other devices.
4. **No conflict resolution needed:** Because the event log is append-only, there are no conflicts in the traditional sense. Two devices recording events for the same customer simply produce two events — both are valid. The balance is recomputed from the full log.
5. **Sync trigger:** Event-triggered on connectivity change (not polling). When the device detects network availability, it flushes the SyncQueue.
6. **Ordering:** Events are ordered by server_timestamp for the authoritative timeline. Device_timestamp is preserved for audit purposes but is not used for ordering (device clocks may be wrong).
7. **Batch size limit:** Max 500 events per upload request. If the queue exceeds 500, multiple batches are sent sequentially.

#### Consequences
- **Positive:** Idempotent uploads mean the client can safely retry without risk of duplicate events on the server.
- **Positive:** No complex conflict resolution logic. Append-only eliminates merge conflicts entirely.
- **Positive:** Event-triggered sync preserves battery (critical for load-shedding environments).
- **Negative:** Device clock skew means device_timestamp may not reflect true event order. Mitigated by using server_timestamp as the authoritative ordering.
- **Negative:** Pull sync returns all events since a timestamp, which may include events the device already has locally. The client deduplicates by UUID.

#### Rejected Alternatives
- **Polling-based sync:** Rejected because it drains battery on low-end devices during the 4-14 hours of daily load-shedding when users need their phone for other purposes.
- **WebSocket real-time sync:** Rejected as over-engineered for MVP. The use case does not require real-time sync — background batch sync is sufficient.
- **Operational Transform / CRDT:** Rejected because append-only event logs do not have conflicts that require transformation. These are solutions for collaborative editing, not ledger recording.

---

### ADR-007: Backup Strategy (Local Device Storage + Optional Google Drive)
Date: 2026-04-05
Status: APPROVED

#### Context
If a store owner loses their device, unsynced events since the last successful sync are lost. The server has the authoritative copy of all synced events, but events recorded after the last sync are only on the device. Additionally, users may want a local backup independent of the server.

#### Decision
1. **Periodic local backup:** The app periodically exports the SQLite database file to device storage (external storage directory). Frequency: daily when the app is open and the device is charging.
2. **Optional Google Drive backup:** Users can opt in to upload the SQLite backup to Google Drive. This uses the Google Drive API with the app-specific folder scope (not full Drive access).
3. **Backup metadata:** A Backups table tracks backup timestamp, file size, destination (local/gdrive), and status.
4. **Restore flow:** On new device setup, after OTP verification, the user is offered: (a) restore from server (synced events only), (b) restore from Google Drive backup (includes unsynced events up to last backup).
5. **Clear communication:** During onboarding and backup settings, the app explicitly states: "Events recorded after your last backup and before your last sync cannot be recovered if the device is lost."

#### Consequences
- **Positive:** Google Drive backup provides recovery of unsynced events (up to last backup point).
- **Positive:** Local backup provides fast restore without network dependency.
- **Negative:** Google Drive requires a Google account, which some users may not have. This is why it is optional.
- **Negative:** Backup frequency (daily) means up to 24 hours of unsynced events could be lost. Acceptable given the alternative (no backup at all).

#### Rejected Alternatives
- **Continuous backup:** Rejected because writing to external storage or uploading to cloud on every transaction would drain battery and consume data.
- **Server-only restore:** Rejected because it does not recover unsynced events. The server only has events that have been successfully synced.
- **Custom cloud backup service:** Rejected because Google Drive is already on most Android devices and requires no additional infrastructure.

---

### ADR-008: Flutter State Management Choice — Riverpod
Date: 2026-04-05
Status: APPROVED

#### Context
Flutter requires an explicit state management solution. The app has several state domains: (a) local database state (Drift streams), (b) sync queue status, (c) auth session, (d) UI state (selected customer, current screen). The solution must work well with Drift's reactive streams, be testable, and perform well on low-end devices.

#### Decision
**Riverpod** (v2+) as the state management solution.

Rationale:
1. **Drift integration:** Riverpod's `StreamProvider` natively wraps Drift's reactive query streams. When the local database changes (new transaction recorded), the UI rebuilds automatically without manual plumbing.
2. **Compile-time safety:** Riverpod providers are resolved at compile time (no runtime `BuildContext` lookups). This eliminates the "ProviderNotFoundException" class of bugs that plague Provider.
3. **Testability:** Riverpod's `ProviderContainer` allows complete provider overriding in tests without widget tree setup. Unit testing business logic requires no Flutter test harness.
4. **Scoping:** Riverpod's `family` and `autoDispose` modifiers allow per-customer and per-screen state that cleans up automatically — critical for the customer detail screens that load event histories.
5. **No BuildContext dependency:** Providers can be read from anywhere (services, background sync), not just the widget tree. This is essential for the sync engine which runs outside the UI.

#### Consequences
- **Positive:** Type-safe, compile-time verified, excellent Drift integration, testable without widget tree.
- **Positive:** `autoDispose` prevents memory leaks on low-end devices — state for screens the user has navigated away from is automatically freed.
- **Negative:** Riverpod has a steeper learning curve than Provider. The `ref.watch` / `ref.read` / `ref.listen` distinction requires initial ramp-up.
- **Negative:** Code generation (riverpod_generator) is recommended for v2+ but adds a build step. Acceptable trade-off for type safety.

#### Rejected Alternatives
- **Provider:** Rejected because it depends on BuildContext for all reads (cannot access from sync engine), lacks compile-time safety, and the Flutter team has signalled Riverpod as the successor.
- **Bloc:** Rejected because its event/state boilerplate is excessive for this app's complexity level. Bloc excels in large teams with strict patterns — this MVP prioritises development speed. Additionally, Bloc's stream-based model adds unnecessary indirection when Drift already provides streams.
- **GetX:** Rejected due to poor testability, implicit global state, and lack of compile-time safety. Not suitable for financial data handling.
