# Data Model — Dukaan Dost

> Maintained by architect, flutter-dev (Drift schemas), and django-dev (Django models).
> Last updated: 2026-04-05

---

## Drift Tables (Mobile — SQLite)

All monetary amounts are stored as `int` (integer paisa, PKR x 100). No floating point.

### Events

The append-only transaction log. This is the source of truth for all balances.

| Field | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `TEXT (UUID)` | PRIMARY KEY | Client-generated UUIDv4 |
| `shop_id` | `TEXT (UUID)` | NOT NULL | Shop this event belongs to |
| `event_type` | `TEXT` | NOT NULL, CHECK IN ('CREDIT','PAYMENT','REVERSAL','REMINDER_SENT') | Type of ledger event |
| `party_type` | `TEXT` | NOT NULL, CHECK IN ('CUSTOMER','SUPPLIER') | Whether this involves a customer or supplier |
| `party_id` | `TEXT (UUID)` | NOT NULL | FK to Customers or Suppliers |
| `amount_paisa` | `INTEGER` | NOT NULL, >= 0 | Amount in paisa (always positive; direction implied by event_type) |
| `note` | `TEXT` | NULLABLE | Optional text note |
| `voice_note_path` | `TEXT` | NULLABLE | Local file path to voice recording |
| `device_id` | `TEXT` | NOT NULL | Device that created this event |
| `actor_label` | `TEXT` | NULLABLE | Human label for the device/actor (e.g. "Main phone") |
| `device_timestamp` | `INTEGER` | NOT NULL | Unix epoch millis when event was created on device |
| `server_timestamp` | `INTEGER` | NULLABLE | Unix epoch millis assigned by server on sync; NULL if unsynced |
| `created_at` | `INTEGER` | NOT NULL, DEFAULT current_timestamp | Row creation time |

**Indexes:**
- `idx_events_party` on (`party_type`, `party_id`) — for balance computation queries
- `idx_events_shop` on (`shop_id`) — for shop-scoped queries
- `idx_events_device_ts` on (`device_timestamp`) — for chronological display
- `idx_events_server_ts` on (`server_timestamp`) — for sync pull deduplication

---

### Customers

| Field | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `TEXT (UUID)` | PRIMARY KEY | Client-generated UUIDv4 |
| `shop_id` | `TEXT (UUID)` | NOT NULL | Owning shop |
| `name` | `TEXT` | NOT NULL | Customer name (required) |
| `phone` | `TEXT` | NULLABLE | Phone number (optional); used for WhatsApp deep links |
| `is_flagged` | `INTEGER` | NOT NULL, DEFAULT 0 | 1 if flagged for follow-up tomorrow |
| `last_reminder_at` | `INTEGER` | NULLABLE | Unix epoch millis of last reminder sent |
| `created_at` | `INTEGER` | NOT NULL | Row creation time |
| `updated_at` | `INTEGER` | NOT NULL | Last modification time |
| `is_deleted` | `INTEGER` | NOT NULL, DEFAULT 0 | Soft delete flag |

**Indexes:**
- `idx_customers_shop` on (`shop_id`) — for shop-scoped list queries
- `idx_customers_phone` on (`shop_id`, `phone`) — for contact import dedup

---

### Suppliers

| Field | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `TEXT (UUID)` | PRIMARY KEY | Client-generated UUIDv4 |
| `shop_id` | `TEXT (UUID)` | NOT NULL | Owning shop |
| `name` | `TEXT` | NOT NULL | Supplier name |
| `phone` | `TEXT` | NULLABLE | Contact phone |
| `invoice_amount_paisa` | `INTEGER` | NOT NULL | Invoice total in paisa |
| `due_date` | `INTEGER` | NULLABLE | Unix epoch millis of payment due date |
| `is_paid` | `INTEGER` | NOT NULL, DEFAULT 0 | 1 if invoice is marked paid |
| `created_at` | `INTEGER` | NOT NULL | Row creation time |
| `updated_at` | `INTEGER` | NOT NULL | Last modification time |
| `is_deleted` | `INTEGER` | NOT NULL, DEFAULT 0 | Soft delete flag |

**Indexes:**
- `idx_suppliers_shop` on (`shop_id`) — for shop-scoped list queries
- `idx_suppliers_due` on (`shop_id`, `due_date`) WHERE `is_paid = 0` — for upcoming due date queries

---

### SyncQueue

Tracks events pending upload to the server.

| Field | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `INTEGER` | PRIMARY KEY AUTOINCREMENT | Queue order |
| `event_id` | `TEXT (UUID)` | NOT NULL, UNIQUE | FK to Events.id |
| `status` | `TEXT` | NOT NULL, DEFAULT 'PENDING', CHECK IN ('PENDING','IN_FLIGHT','SYNCED','FAILED') | Sync status |
| `retry_count` | `INTEGER` | NOT NULL, DEFAULT 0 | Number of failed attempts |
| `last_attempt_at` | `INTEGER` | NULLABLE | Unix epoch millis of last sync attempt |
| `created_at` | `INTEGER` | NOT NULL | When queued |

**Indexes:**
- `idx_syncqueue_status` on (`status`) — for batch flush queries (WHERE status = 'PENDING')

---

### Shops

Local shop profile. One row per device (the authenticated shop).

| Field | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `TEXT (UUID)` | PRIMARY KEY | Shop UUID from server |
| `phone` | `TEXT` | NOT NULL | Registered phone number |
| `name` | `TEXT` | NOT NULL | Shop name (entered during onboarding) |
| `locality` | `TEXT` | NULLABLE | Locality / area |
| `device_id` | `TEXT` | NOT NULL | This device's unique ID |
| `actor_label` | `TEXT` | NULLABLE | Human label for this device |
| `session_token` | `TEXT` | NOT NULL | Auth session token (stored in secure storage, cached here) |
| `last_sync_at` | `INTEGER` | NULLABLE | Unix epoch millis of last successful sync |
| `created_at` | `INTEGER` | NOT NULL | Row creation time |
| `updated_at` | `INTEGER` | NOT NULL | Last modification time |

**Indexes:** None beyond primary key (single row table).

---

### Backups

Tracks backup history and metadata.

| Field | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `INTEGER` | PRIMARY KEY AUTOINCREMENT | Auto ID |
| `shop_id` | `TEXT (UUID)` | NOT NULL | Shop this backup belongs to |
| `backup_type` | `TEXT` | NOT NULL, CHECK IN ('LOCAL','GDRIVE') | Destination type |
| `file_path` | `TEXT` | NULLABLE | Local file path (for LOCAL type) |
| `gdrive_file_id` | `TEXT` | NULLABLE | Google Drive file ID (for GDRIVE type) |
| `file_size_bytes` | `INTEGER` | NOT NULL | Backup file size |
| `status` | `TEXT` | NOT NULL, CHECK IN ('IN_PROGRESS','COMPLETED','FAILED') | Backup status |
| `created_at` | `INTEGER` | NOT NULL | When backup was initiated |
| `completed_at` | `INTEGER` | NULLABLE | When backup finished |

**Indexes:**
- `idx_backups_shop_type` on (`shop_id`, `backup_type`, `created_at` DESC) — for finding latest backup

---

## Django Models (Backend — PostgreSQL)

All monetary amounts are stored as `BigIntegerField` (integer paisa, PKR x 100). No floating point.

### Shop

| Field | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `UUIDField` | PRIMARY KEY, default=uuid4 | Shop identifier |
| `phone` | `CharField(max_length=20)` | UNIQUE, NOT NULL | Registered phone number (E.164 format) |
| `name` | `CharField(max_length=255)` | NOT NULL | Shop name |
| `locality` | `CharField(max_length=255)` | NULLABLE | Area / locality |
| `is_active` | `BooleanField` | DEFAULT True | Soft deactivation flag |
| `created_at` | `DateTimeField` | auto_now_add | Registration time |
| `updated_at` | `DateTimeField` | auto_now | Last profile update |

**Indexes:**
- UNIQUE on `phone`

---

### Event

Append-only event log. Mirrors the Drift Events table. No UPDATE or DELETE allowed (enforced at application layer and DB triggers).

| Field | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `UUIDField` | PRIMARY KEY | Client-generated UUID (same as Drift Events.id) |
| `shop` | `ForeignKey(Shop)` | NOT NULL, on_delete=PROTECT | Owning shop |
| `event_type` | `CharField(max_length=20)` | NOT NULL, choices=['CREDIT','PAYMENT','REVERSAL','REMINDER_SENT'] | Event type |
| `party_type` | `CharField(max_length=20)` | NOT NULL, choices=['CUSTOMER','SUPPLIER'] | Party type |
| `party_id` | `UUIDField` | NOT NULL | FK to Customer or Supplier (not enforced as DB FK due to polymorphism) |
| `amount_paisa` | `BigIntegerField` | NOT NULL, >= 0 | Amount in paisa |
| `note` | `TextField` | NULLABLE | Optional text note |
| `device_id` | `CharField(max_length=255)` | NOT NULL | Device that created the event |
| `actor_label` | `CharField(max_length=255)` | NULLABLE | Human label for the device |
| `device_timestamp` | `DateTimeField` | NOT NULL | Timestamp from client device |
| `server_timestamp` | `DateTimeField` | auto_now_add | Assigned by server on receipt |
| `created_at` | `DateTimeField` | auto_now_add | DB row creation time |

**Indexes:**
- `idx_event_shop_server_ts` on (`shop_id`, `server_timestamp`) — for sync pull queries
- `idx_event_party` on (`shop_id`, `party_type`, `party_id`) — for balance computation
- `idx_event_device_ts` on (`shop_id`, `device_timestamp`) — for chronological queries

**Constraints:**
- PostgreSQL trigger to prevent UPDATE and DELETE on this table (append-only enforcement).

---

### Customer

| Field | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `UUIDField` | PRIMARY KEY, default=uuid4 | Customer identifier |
| `shop` | `ForeignKey(Shop)` | NOT NULL, on_delete=CASCADE | Owning shop |
| `name` | `CharField(max_length=255)` | NOT NULL | Customer name |
| `phone` | `CharField(max_length=20)` | NULLABLE | Phone number (optional) |
| `is_flagged` | `BooleanField` | DEFAULT False | Follow-up flag |
| `last_reminder_at` | `DateTimeField` | NULLABLE | Last reminder sent timestamp |
| `is_deleted` | `BooleanField` | DEFAULT False | Soft delete |
| `created_at` | `DateTimeField` | auto_now_add | Creation time |
| `updated_at` | `DateTimeField` | auto_now | Last update time |

**Indexes:**
- `idx_customer_shop` on (`shop_id`) — for shop-scoped queries
- UNIQUE on (`shop_id`, `phone`) WHERE `phone IS NOT NULL` — prevent duplicate phone per shop

---

### Supplier

| Field | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `UUIDField` | PRIMARY KEY, default=uuid4 | Supplier identifier |
| `shop` | `ForeignKey(Shop)` | NOT NULL, on_delete=CASCADE | Owning shop |
| `name` | `CharField(max_length=255)` | NOT NULL | Supplier name |
| `phone` | `CharField(max_length=20)` | NULLABLE | Contact phone |
| `invoice_amount_paisa` | `BigIntegerField` | NOT NULL | Invoice total in paisa |
| `due_date` | `DateField` | NULLABLE | Payment due date |
| `is_paid` | `BooleanField` | DEFAULT False | Paid flag |
| `is_deleted` | `BooleanField` | DEFAULT False | Soft delete |
| `created_at` | `DateTimeField` | auto_now_add | Creation time |
| `updated_at` | `DateTimeField` | auto_now | Last update time |

**Indexes:**
- `idx_supplier_shop` on (`shop_id`) — for shop-scoped queries
- `idx_supplier_due` on (`shop_id`, `due_date`) WHERE `is_paid = False` — upcoming dues

---

### Device

Tracks devices registered to a shop. Supports future multi-user audit trail.

| Field | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `UUIDField` | PRIMARY KEY, default=uuid4 | Device record ID |
| `shop` | `ForeignKey(Shop)` | NOT NULL, on_delete=CASCADE | Owning shop |
| `device_id` | `CharField(max_length=255)` | NOT NULL | Unique device identifier set at first launch |
| `actor_label` | `CharField(max_length=255)` | NULLABLE | Human label (e.g. "Main phone", "Ahmed's phone") |
| `platform` | `CharField(max_length=50)` | NOT NULL, DEFAULT 'android' | Device platform |
| `fcm_token` | `TextField` | NULLABLE | Firebase Cloud Messaging token for push notifications |
| `last_seen_at` | `DateTimeField` | NULLABLE | Last sync timestamp from this device |
| `is_active` | `BooleanField` | DEFAULT True | Whether device is still active |
| `created_at` | `DateTimeField` | auto_now_add | First registration time |
| `updated_at` | `DateTimeField` | auto_now | Last update time |

**Indexes:**
- UNIQUE on (`shop_id`, `device_id`) — one record per device per shop
- `idx_device_fcm` on (`fcm_token`) WHERE `fcm_token IS NOT NULL` — for push notification delivery

---

### OTPRequest

Tracks OTP codes for phone-number authentication. Redis is the primary TTL store; this table provides an audit trail and rate limiting.

| Field | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `UUIDField` | PRIMARY KEY, default=uuid4 | Request ID |
| `phone` | `CharField(max_length=20)` | NOT NULL | Phone number that requested OTP |
| `otp_hash` | `CharField(max_length=128)` | NOT NULL | SHA-256 hash of the OTP code (never store plaintext) |
| `is_verified` | `BooleanField` | DEFAULT False | Whether this OTP was successfully verified |
| `expires_at` | `DateTimeField` | NOT NULL | Expiry time (5 minutes from creation) |
| `ip_address` | `GenericIPAddressField` | NULLABLE | Request origin IP for abuse detection |
| `attempts` | `IntegerField` | DEFAULT 0 | Number of verification attempts (max 3) |
| `created_at` | `DateTimeField` | auto_now_add | Request time |

**Indexes:**
- `idx_otp_phone_created` on (`phone`, `created_at` DESC) — for rate limiting (max 5 per hour per phone)
- `idx_otp_expires` on (`expires_at`) — for cleanup of expired records
