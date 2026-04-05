# Django API Contracts — Dukaan Dost

> Maintained by architect and django-dev agents.
> flutter-dev reads this as the source of truth for all response schemas.
> Any change here must be communicated to flutter-dev immediately.
> Last updated: 2026-04-05

Base URL: `/api/`
Auth: All endpoints except OTP request/verify require a valid session token in the `Authorization: Token {session_token}` header.
All monetary amounts: integer paisa (PKR x 100).

---

### POST /api/auth/otp/request
**Purpose:** Send a 6-digit OTP to the given phone number via SMS gateway.
**Auth:** None required
**Request:**
```json
{
  "phone": "+923001234567"  // string, E.164 format, required
}
```
**Response:**
```json
{
  "message": "OTP sent",
  "expires_in_seconds": 300
}
```
**Offline behaviour:** Cannot work offline. Flutter shows "Internet connection required for login" message.
**Error codes:**
- `400` — Invalid phone number format
- `429` — Rate limited (max 5 OTP requests per phone per hour)
- `500` — SMS gateway failure

---

### POST /api/auth/otp/verify
**Purpose:** Verify OTP code and return a session token. Creates Shop record on first login.
**Auth:** None required
**Request:**
```json
{
  "phone": "+923001234567",  // string, E.164 format, required
  "otp": "123456"            // string, 6 digits, required
}
```
**Response:**
```json
{
  "token": "abc123...",           // string, session token
  "shop_id": "uuid-here",        // string, UUID
  "is_new_shop": true,           // boolean, true if this is first login
  "shop": {                      // object, null if is_new_shop=true
    "name": "Kareem Store",
    "locality": "Orangi Town",
    "phone": "+923001234567"
  }
}
```
**Offline behaviour:** Cannot work offline. Flutter shows "Internet connection required for login" message.
**Error codes:**
- `400` — Invalid OTP format
- `401` — Incorrect OTP or OTP expired
- `429` — Too many verification attempts (max 3 per OTP)

---

### GET /api/shop/profile
**Purpose:** Retrieve the authenticated shop's profile.
**Auth:** OTP session token required
**Request:** None (shop_id extracted from session)
**Response:**
```json
{
  "id": "uuid-here",
  "phone": "+923001234567",
  "name": "Kareem Store",
  "locality": "Orangi Town",
  "created_at": "2026-04-05T10:00:00Z"
}
```
**Offline behaviour:** Flutter serves from local Shops table. Syncs on reconnect.
**Error codes:**
- `401` — Invalid or expired session token

---

### PUT /api/shop/profile
**Purpose:** Update the authenticated shop's name and/or locality.
**Auth:** OTP session token required
**Request:**
```json
{
  "name": "Kareem General Store",  // string, optional
  "locality": "North Nazimabad"    // string, optional
}
```
**Response:**
```json
{
  "id": "uuid-here",
  "phone": "+923001234567",
  "name": "Kareem General Store",
  "locality": "North Nazimabad",
  "updated_at": "2026-04-05T12:00:00Z"
}
```
**Offline behaviour:** Flutter updates local Shops table immediately. Queues profile update for sync on reconnect.
**Error codes:**
- `400` — Validation error (name too long, etc.)
- `401` — Invalid or expired session token

---

### POST /api/sync/events
**Purpose:** Batch upload events from the device to the server. Idempotent — duplicate UUIDs are ignored.
**Auth:** OTP session token required
**Request:**
```json
{
  "events": [
    {
      "id": "uuid-event-1",
      "event_type": "CREDIT",
      "party_type": "CUSTOMER",
      "party_id": "uuid-customer-1",
      "amount_paisa": 50000,
      "note": "Chai aur cheeni",
      "device_id": "device-abc",
      "actor_label": "Main phone",
      "device_timestamp": "2026-04-05T09:30:00Z"
    }
  ]  // array, max 500 events per request
}
```
**Response:**
```json
{
  "accepted": 5,       // int, number of new events accepted
  "duplicates": 2,     // int, number of events already on server (ignored)
  "server_timestamp": "2026-04-05T12:00:00Z"  // string, latest server_timestamp for client to store as sync cursor
}
```
**Offline behaviour:** Events accumulate in SyncQueue with status PENDING. Flushed automatically on reconnect.
**Error codes:**
- `400` — Malformed event data, missing required fields, invalid event_type
- `401` — Invalid or expired session token
- `403` — Event contains a shop_id that does not match the authenticated session
- `413` — Batch exceeds 500 events

---

### GET /api/sync/events
**Purpose:** Pull events for this shop since a given server timestamp. Used to fetch events created on other devices.
**Auth:** OTP session token required
**Request:**
```
GET /api/sync/events?since=2026-04-05T10:00:00Z&limit=500
```
| Param | Type | Required | Comment |
|---|---|---|---|
| `since` | ISO 8601 datetime | Yes | Return events with server_timestamp > this value |
| `limit` | int | No, default 500 | Max events to return |

**Response:**
```json
{
  "events": [
    {
      "id": "uuid-event-1",
      "event_type": "CREDIT",
      "party_type": "CUSTOMER",
      "party_id": "uuid-customer-1",
      "amount_paisa": 50000,
      "note": "Chai aur cheeni",
      "device_id": "device-abc",
      "actor_label": "Main phone",
      "device_timestamp": "2026-04-05T09:30:00Z",
      "server_timestamp": "2026-04-05T12:00:00Z"
    }
  ],
  "has_more": false,                          // boolean, true if more events exist beyond limit
  "latest_server_timestamp": "2026-04-05T12:00:00Z"  // string, cursor for next pull
}
```
**Offline behaviour:** Pull sync is skipped when offline. Triggered automatically on reconnect after push sync completes.
**Error codes:**
- `400` — Invalid `since` format
- `401` — Invalid or expired session token

---

### GET /api/customers
**Purpose:** List all customers for the authenticated shop with computed balances.
**Auth:** OTP session token required
**Request:**
```
GET /api/customers?search=kareem&sort=balance_desc
```
| Param | Type | Required | Comment |
|---|---|---|---|
| `search` | string | No | Filter by name (case-insensitive contains) |
| `sort` | string | No, default `balance_desc` | Sort: `balance_desc`, `balance_asc`, `name_asc`, `last_activity` |

**Response:**
```json
{
  "customers": [
    {
      "id": "uuid-customer-1",
      "name": "Ahmed bhai",
      "phone": "+923009876543",
      "balance_paisa": 150000,
      "is_flagged": false,
      "last_reminder_at": null,
      "last_activity_at": "2026-04-03T14:00:00Z",
      "days_overdue": 12
    }
  ],
  "total_owed_paisa": 750000
}
```
**Offline behaviour:** Flutter computes balances locally from the event log. Server response is used only to cross-check after sync.
**Error codes:**
- `401` — Invalid or expired session token

---

### POST /api/customers
**Purpose:** Create a new customer record for the authenticated shop.
**Auth:** OTP session token required
**Request:**
```json
{
  "id": "uuid-customer-new",    // string UUID, client-generated
  "name": "Bilal bhai",         // string, required
  "phone": "+923001112233"      // string, optional
}
```
**Response:**
```json
{
  "id": "uuid-customer-new",
  "name": "Bilal bhai",
  "phone": "+923001112233",
  "balance_paisa": 0,
  "created_at": "2026-04-05T12:00:00Z"
}
```
**Offline behaviour:** Customer created in local Drift table immediately. Queued for sync on reconnect.
**Error codes:**
- `400` — Validation error (name missing, duplicate phone for this shop)
- `401` — Invalid or expired session token
- `409` — Customer with this UUID already exists

---

### PUT /api/customers/{id}
**Purpose:** Update a customer's name, phone, or flagged status.
**Auth:** OTP session token required
**Request:**
```json
{
  "name": "Bilal Ahmed bhai",     // string, optional
  "phone": "+923001112234",       // string, optional
  "is_flagged": true              // boolean, optional
}
```
**Response:**
```json
{
  "id": "uuid-customer-1",
  "name": "Bilal Ahmed bhai",
  "phone": "+923001112234",
  "is_flagged": true,
  "balance_paisa": 150000,
  "updated_at": "2026-04-05T13:00:00Z"
}
```
**Offline behaviour:** Updated in local Drift table immediately. Queued for sync on reconnect.
**Error codes:**
- `400` — Validation error
- `401` — Invalid or expired session token
- `403` — Customer does not belong to authenticated shop
- `404` — Customer not found

---

### GET /api/customers/{id}/events
**Purpose:** Full event history for one customer, for chat-thread display and dispute resolution.
**Auth:** OTP session token required
**Request:**
```
GET /api/customers/{id}/events?limit=100&offset=0
```
| Param | Type | Required | Comment |
|---|---|---|---|
| `limit` | int | No, default 100 | Max events to return |
| `offset` | int | No, default 0 | Pagination offset |

**Response:**
```json
{
  "customer": {
    "id": "uuid-customer-1",
    "name": "Ahmed bhai",
    "balance_paisa": 150000
  },
  "events": [
    {
      "id": "uuid-event-1",
      "event_type": "CREDIT",
      "amount_paisa": 50000,
      "note": "Chai aur cheeni",
      "device_timestamp": "2026-04-05T09:30:00Z",
      "server_timestamp": "2026-04-05T12:00:00Z",
      "actor_label": "Main phone"
    }
  ],
  "total_events": 42,
  "has_more": true
}
```
**Offline behaviour:** Flutter serves from local event log. Full history always available offline.
**Error codes:**
- `401` — Invalid or expired session token
- `403` — Customer does not belong to authenticated shop
- `404` — Customer not found

---

### GET /api/suppliers
**Purpose:** List all suppliers for the authenticated shop with balances and due dates.
**Auth:** OTP session token required
**Request:**
```
GET /api/suppliers?sort=due_date_asc
```
| Param | Type | Required | Comment |
|---|---|---|---|
| `sort` | string | No, default `due_date_asc` | Sort: `due_date_asc`, `amount_desc`, `name_asc` |

**Response:**
```json
{
  "suppliers": [
    {
      "id": "uuid-supplier-1",
      "name": "Tapal Tea Distributor",
      "phone": "+923005551234",
      "invoice_amount_paisa": 250000,
      "due_date": "2026-04-10",
      "is_paid": false,
      "days_until_due": 5
    }
  ],
  "total_owed_paisa": 500000
}
```
**Offline behaviour:** Flutter serves from local Suppliers table.
**Error codes:**
- `401` — Invalid or expired session token

---

### POST /api/suppliers
**Purpose:** Create a new supplier record.
**Auth:** OTP session token required
**Request:**
```json
{
  "id": "uuid-supplier-new",         // string UUID, client-generated
  "name": "National Foods",          // string, required
  "phone": "+923005559876",          // string, optional
  "invoice_amount_paisa": 300000,    // int, required
  "due_date": "2026-04-15"           // string ISO date, optional
}
```
**Response:**
```json
{
  "id": "uuid-supplier-new",
  "name": "National Foods",
  "phone": "+923005559876",
  "invoice_amount_paisa": 300000,
  "due_date": "2026-04-15",
  "is_paid": false,
  "created_at": "2026-04-05T12:00:00Z"
}
```
**Offline behaviour:** Created in local Drift table immediately. Queued for sync on reconnect.
**Error codes:**
- `400` — Validation error (name missing, invalid amount)
- `401` — Invalid or expired session token
- `409` — Supplier with this UUID already exists

---

### PUT /api/suppliers/{id}
**Purpose:** Update a supplier's details or mark as paid.
**Auth:** OTP session token required
**Request:**
```json
{
  "name": "National Foods Dist.",     // string, optional
  "phone": "+923005559877",           // string, optional
  "invoice_amount_paisa": 310000,     // int, optional
  "due_date": "2026-04-20",           // string ISO date, optional
  "is_paid": true                     // boolean, optional
}
```
**Response:**
```json
{
  "id": "uuid-supplier-1",
  "name": "National Foods Dist.",
  "phone": "+923005559877",
  "invoice_amount_paisa": 310000,
  "due_date": "2026-04-20",
  "is_paid": true,
  "updated_at": "2026-04-05T14:00:00Z"
}
```
**Offline behaviour:** Updated in local Drift table immediately. Queued for sync on reconnect.
**Error codes:**
- `400` — Validation error
- `401` — Invalid or expired session token
- `403` — Supplier does not belong to authenticated shop
- `404` — Supplier not found

---

### DELETE /api/suppliers/{id}
**Purpose:** Soft-delete a supplier (sets is_deleted=true). Data is preserved for audit trail.
**Auth:** OTP session token required
**Request:** None
**Response:**
```json
{
  "id": "uuid-supplier-1",
  "is_deleted": true,
  "deleted_at": "2026-04-05T15:00:00Z"
}
```
**Offline behaviour:** Marked as deleted in local Drift table immediately. Queued for sync on reconnect.
**Error codes:**
- `401` — Invalid or expired session token
- `403` — Supplier does not belong to authenticated shop
- `404` — Supplier not found

---

### POST /api/reminders/log
**Purpose:** Log that a WhatsApp or SMS reminder was sent to a customer. This is an audit record — the actual message is sent via WhatsApp deep link on the device.
**Auth:** OTP session token required
**Request:**
```json
{
  "customer_id": "uuid-customer-1",   // string UUID, required
  "reminder_type": "GENTLE",          // string, required: GENTLE | FIRM | FINAL
  "channel": "WHATSAPP",              // string, required: WHATSAPP | SMS
  "balance_paisa": 150000,            // int, required: balance at time of reminder
  "device_timestamp": "2026-04-05T16:00:00Z"  // string ISO datetime, required
}
```
**Response:**
```json
{
  "logged": true,
  "event_id": "uuid-event-reminder",
  "server_timestamp": "2026-04-05T16:00:01Z"
}
```
**Offline behaviour:** REMINDER_SENT event is written to local event log immediately. Synced to server on reconnect via normal event sync.
**Error codes:**
- `400` — Validation error (invalid reminder_type, missing customer_id)
- `401` — Invalid or expired session token
- `403` — Customer does not belong to authenticated shop
- `404` — Customer not found

---

### POST /api/backup/metadata
**Purpose:** Record backup metadata on the server for restore flow on new devices.
**Auth:** OTP session token required
**Request:**
```json
{
  "backup_type": "GDRIVE",            // string, required: LOCAL | GDRIVE
  "gdrive_file_id": "1abc2def3...",   // string, required if backup_type=GDRIVE
  "file_size_bytes": 2048576,         // int, required
  "device_id": "device-abc",          // string, required
  "created_at": "2026-04-05T02:00:00Z"  // string ISO datetime, required
}
```
**Response:**
```json
{
  "id": "uuid-backup-record",
  "backup_type": "GDRIVE",
  "file_size_bytes": 2048576,
  "created_at": "2026-04-05T02:00:00Z",
  "server_received_at": "2026-04-05T02:00:05Z"
}
```
**Offline behaviour:** Backup metadata is stored in local Backups table. Synced to server on reconnect.
**Error codes:**
- `400` — Validation error (missing required fields)
- `401` — Invalid or expired session token
