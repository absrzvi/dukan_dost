# Product Requirements Document — Dukaan Dost
Status: Approved

> Set Status to APPROVED to unblock the architect agent.
> Last updated: 2026-04-05

---

## Problem Statement

Pakistan has 5 million+ kiryana stores. Every store operates on a dual informal credit system — customer-facing udhaar (credit extended to buyers) and supplier-facing credit (goods received on 7–30 day terms from FMCG distributors). Both are tracked on paper.

This creates three acute problems:
1. **Disputes** — when paper records conflict or go missing, relationships are damaged
2. **Slow collection** — manual WhatsApp follow-up takes minutes per customer; store owners avoid it
3. **No real-time position** — store owners have no instant view of net cash owed vs owed to them

Existing solutions (Khatabook, BizBook, Hisaab) address only the customer-facing ledger, are English-heavy, built on Indian behavioral defaults, and do not cover supplier-side credit. No app has true offline-first architecture or delivers WhatsApp-native Urdu reminders.

---

## User Personas

### Primary — Kareem bhai (Kiryana Store Owner)
- Age 35–50, urban/semi-urban Karachi (Orangi Town, North Nazimabad, SITE-adjacent)
- Device: Tecno Spark or Samsung Galaxy A-entry; 2–3GB RAM; Android 10–12
- Language: Urdu/Roman Urdu; limited English
- WhatsApp-comfortable; paper-first for business; no prior app habit
- Monthly turnover PKR 200,000–1,000,000; 50–200 regular credit customers; 3–5 FMCG suppliers

### Secondary — Grahak (Customer, passive)
- Receives WhatsApp messages from store owner's number
- Never installs an app
- MVP touchpoint: WhatsApp notification only
- Phase 2 touchpoint: web confirmation link

### B2B — FMCG Distributor (Phase 2)
- 50–200 retailer accounts; tracks AR in Excel or paper
- Read-only web dashboard showing retailer credit health scores
- Health score: green/amber/red based on overdue days and outstanding amount
- Sortable by health score for DSR pre-beat-visit planning

---

## Design Principles

These principles are non-negotiable and must guide every architecture, UI, and UX decision.

**1. Speed over completeness** — Every core interaction must complete in under 10 seconds. The window between serving customers is 8–12 seconds. If it takes longer, the store owner reverts to paper. No mandatory fields beyond amount and customer.

**2. The ledger is a conversation** — WhatsApp has trained Pakistani users to read relationships as chat threads. Each customer's transaction history renders as a chat-like chronological thread — not a table with rows and columns. Debit on one side, credit on the other, running balance pinned at top.

**3. Numbers are sacred, text is optional** — Financial amounts must be the most visually dominant element on every screen. Large font, high contrast, never buried in a line of text. Notes and descriptions are secondary and always optional.

**4. WhatsApp is the notification layer** — Do not build an in-app notification system. Every reminder, confirmation, and history share routes through WhatsApp (with SMS fallback). Users already live there.

**5. Offline is the default state** — Every screen is designed assuming no connection. A loading spinner on transaction entry is an architecture failure, not a UX inconvenience. Connection triggers sync — it never gates action.

**6. Match the paper ledger mental model** — The paper register is the reference point, not a Western fintech app. The home screen is a list of names with balances — exactly what the physical book shows. The transition from paper to digital must feel like an upgrade, not a replacement.

---

## Functional Requirements

### Onboarding (First-Time Setup)
1. Store owner registers using phone number + OTP only. No email, no social login.
2. OTP codes are single-use and expire after 5 minutes.
3. Session token returned on OTP verify, stored in Flutter secure storage.
4. Every Django API endpoint requires a valid session token.
5. After OTP verification, store owner enters shop name and locality.
6. Store owner is prompted to optionally import phone contacts to bootstrap the customer list. Imported contacts become customer records with name + phone number.
7. App immediately guides the store owner through recording their first transaction (guided walkthrough) as the onboarding climax — this is the first value moment.
8. Total time from app download to first recorded transaction: under 3 minutes.

### Customer Management
9. Store owner can create a customer record with name only (phone number is optional).
10. Store owner can add or update a phone number on an existing customer record at any time.
11. Customer records without a phone number display a "no phone" indicator throughout the app.
12. Store owner can import additional phone contacts at any time from the customer list screen.

### Transaction Entry (Udhaar Dena / Wapsi)
13. Store owner can record a credit transaction (udhaar) in under 10 seconds: tap customer → tap large + button → enter amount on keypad → save.
14. Store owner can record a payment received (wapsi) in under 10 seconds: tap customer → tap large − button → enter amount → save.
15. Partial payments are supported from day one — remaining balance shown immediately after entry.
16. When a customer's balance reaches exactly zero, the app displays a "Hisaab saaf" (account clear) celebration state — a rewarding visual confirmation that the account is settled.
17. Store owner can attach an optional voice note to any transaction (audio recording only — no transcription in MVP).
18. After recording a transaction, store owner is optionally prompted to notify the customer immediately via WhatsApp (pre-filled message with updated balance) or SMS fallback.
19. After recording a payment (wapsi), store owner is optionally prompted to send a WhatsApp receipt to the customer confirming the payment and showing the new remaining balance.
20. Every transaction saves to local SQLite (Drift) instantly with no network dependency. Network is never on the critical path for entry.
21. Each transaction event carries: UUID, shop ID, event type, party type, party ID, amount in paisa, device timestamp, device ID, actor label, optional note.
22. The event log is append-only and immutable. No edit or delete. Corrections are reversal entries.
23. Balances are computed by replaying the event log — never stored as a mutable field.
24. All monetary amounts stored as integer paisa (PKR × 100). No floating point.

### WhatsApp Reminder (Takaza Bhejna)
25. Home screen shows all customers with outstanding balances, sorted by balance descending.
26. Customers overdue by 7+ days are highlighted red with days-overdue count and a one-tap remind button directly on the list item.
27. Store owner can send a one-tap WhatsApp reminder directly from the customer list item (no drill-down required).
28. Reminder opens a pre-filled Urdu WhatsApp message via `wa.me/` deep link using the store owner's own number.
29. Three Urdu reminder templates available:
    - **Gentle (7+ days):** "Assalamualaikum [Name] bhai, umeed hai khairiyat se honge. [Shop Name] ka PKR [X] baaki hai. Thoda waqt mile toh ada kar dein. Shukriya."
    - **Firm (14+ days):** "Assalamualaikum [Name] bhai, [Shop Name] ka PKR [X] kaafi dino se baaki hai. Guzarish hai jaldi ada kar dein. Shukriya."
    - **Final notice (21+ days):** "Assalamualaikum [Name] bhai, [Shop Name] ka PKR [X] bohot din se baaki hai. Aaj hi ada kar dein toh meherbani hogi. Shukriya."
30. Store owner can preview and edit the pre-filled message before sending (WhatsApp opens with the template — the store owner taps send or edits first).
31. App logs a REMINDER_SENT event to the local event log when a reminder is dispatched.
32. Last reminder sent date is visible on the customer detail screen to prevent double-messaging on the same day.
33. For customers without WhatsApp (no phone number or SMS-only), the reminder button triggers an SMS fallback instead of a WhatsApp deep link.

### Transaction History & Dispute Resolution (Jhagra Khatam Karna)
34. Each customer has a full chronological transaction history rendered as a chat-thread layout (debit on one side, credit on the other, running balance pinned at top).
35. Store owner can turn the screen toward the customer during a dispute to show the history directly.
36. If still disputed, store owner taps "History share karein" — formatted history sent to customer via WhatsApp as plain text (no app required for customer to read it).
37. Every transaction is timestamped to the second.
38. Voice note attachments are playable inline in the transaction history.

### Supplier Credit Tracking (Mujhe Dena Hai)
39. Separate Suppliers tab (distinct mental model from customer ledger: "money I owe" vs "money owed to me").
40. Store owner can add a supplier with supplier name, invoice amount, and payment due date.
41. App sends a push notification (FCM) 2 days before a supplier payment is due.
42. Store owner can mark a supplier invoice as paid.
43. Supplier list shows total owed and per-supplier breakdown with days until due.

### End-of-Day Summary
44. Home screen summary panel shows three numbers: Total owed to me / Total I owe suppliers / Net position.
45. Store owner can flag customers for follow-up tomorrow.
46. Flagged customers appear at the top of the list the next day with a follow-up indicator.

### Sync & Offline
47. Sync queue: every local write creates a queue entry. Background flush when connectivity is available.
48. Offline indicator shown subtly in the app bar when device has no connectivity. Core features remain fully functional offline — never disable core features due to connectivity.
49. On reconnect, sync queue flushes in background with status shown in app bar.
50. App performs a periodic backup of the local SQLite database to device storage and optionally Google Drive.
51. If device is lost/replaced, unsynced data since last backup is irrecoverable. This limitation is clearly communicated to the user during onboarding and backup setup.
52. Sync is event-triggered (on connectivity change), never polling — to preserve battery on low-end devices with 4–14 hours daily load shedding.

### Device & Multi-User Preparation
53. Each device has a device ID set at first launch.
54. Store owner sets an optional actor label per device during setup (e.g. "Main phone", "Ahmed's phone"). This label is stored on every event record for future multi-user audit trail.

---

## Non-Functional Requirements

| Requirement | Target |
|---|---|
| Transaction entry time | Under 10 seconds end-to-end |
| App launch time (cold) | Under 3 seconds on target device |
| Target device | Tecno Spark / Samsung Galaxy A-entry; 2–3GB RAM; Android 10–12 |
| Offline capability | 100% of core features work with no network |
| Language | Urdu script + Roman Urdu; all user-facing strings have both variants |
| Connectivity | Designed for 3G/2G; no feature gated on network speed |
| Battery | No background processes that drain battery; sync is event-triggered not polling |
| Data size | App + local DB must stay under 150MB on device |
| Monetary precision | Integer paisa only; no float arithmetic anywhere in the stack |

---

## MVP Scope

### In MVP
- Phone number + OTP registration
- Onboarding: shop name + locality + optional contact import + guided first transaction (under 3 minutes)
- Customer management (phone optional, name required, contact import)
- Offline-first transaction recording (credit + payment)
- "Hisaab saaf" celebration state when balance reaches zero
- Optional WhatsApp notification to customer on every transaction
- Optional WhatsApp receipt on payment received
- Append-only event log with full history + voice note attachments
- WhatsApp reminder (one-tap, 3 Urdu templates with actual Urdu text)
- SMS fallback for customers without WhatsApp
- Share transaction history via WhatsApp (plain text)
- Home screen overdue indicators (7+ day red highlight, inline remind button)
- End-of-day net position summary
- Follow-up flagging (persists to next day)
- Supplier credit tracking (separate tab with due dates)
- Offline sync queue (event-triggered, not polling)
- Periodic local backup (device storage + optional Google Drive)
- Device ID + actor label per device

### Explicitly Out of MVP
- Two-sided customer confirmation (Phase 2)
- Distributor dashboard (Phase 2)
- Urdu speech-to-text transcription (Phase 2)
- Custom reminder message templates (Phase 2)
- Multi-user / family shop UI (Phase 2 — data model supports it from day one)
- In-app payment collection (Phase 2)
- Analytics / reporting dashboard (Phase 2)
- JazzCash/Easypaisa payment integration (Phase 2)
- iOS version (Phase 3)

---

## Phase 2 Scope (for data model awareness)

### Two-Sided Customer Confirmation
- Customer receives WhatsApp link → opens mobile web page (no app install) → sees transaction list + balance → taps "Theek hai" (Confirm) or "Mujhe ikhtilaf hai" (I disagree)
- Opt-in per customer (not default-on) — field research in Week 1 informs exact UX
- Store owner sees confirmation state on next sync

### Distributor Dashboard
- Read-only web view per distributor showing all retailer accounts
- Health score per retailer: green (current), amber (7–14 days overdue), red (14+ days overdue)
- Sortable by health score for DSR pre-beat-visit planning
- No login required for retailer; distributor has separate credentials

---

## Pre-Development Gate

Before any production code is written:
- **Flutter benchmark:** Run a list-scroll performance test on a Tecno Spark (or equivalent 2–3GB RAM Android device) with 500 mock transactions. Flutter is the decided stack; this benchmark must confirm it before stories are written.
- Pass criteria: smooth 60fps scroll on the customer transaction list with 500 events loaded.
- If benchmark fails: reassess React Native as alternative before proceeding.

---

## Go-to-Market (context for product decisions)

- **Karachi-first pilot** across both residential neighbourhood stores and commercial area stores
- **Distributor-led distribution:** FMCG regional distributors push app to retailer networks; DSR demonstrates during weekly beat visit
- **Priority FMCG targets:** Tapal Tea, National Foods, Shan Foods
- **Priority distributors:** Asif Distributions, Sigma Distributors
- **Week 1 field research gates Phase 2:** Two-sided ledger assumption validated by asking store owners: "Agar aapka customer WhatsApp pe apna balance dekh sake, toh kya aapko koi masla hoga?"

---

## Downstream Dependencies

| Dependency | Used for | MVP? |
|---|---|---|
| Local Pakistani SMS gateway (Infobip / Avanza / TeleCom) | OTP delivery + SMS reminder fallback | Yes |
| WhatsApp deep link (`wa.me/` scheme) | Reminder + history share | Yes |
| Firebase Cloud Messaging (FCM) | Supplier payment due reminders | Yes |
| Google Drive API | Optional backup destination | Yes |
| Drift / SQLite | Local event log | Yes |
| PostgreSQL | Server-side event log | Yes |
| Redis | Sync queue + OTP TTL cache | Yes |
| Next.js / server-rendered HTML | Customer confirmation web view | Phase 2 |

---

## Key Risks & Mitigations

### Risk 1 — Cold-Start Behaviour Change (Highest Priority)
**Risk:** Getting store owners to adopt a digital habit when paper already works. Paper is faster for in-the-moment entry. The pain is episodic (collection time, disputes), not daily.
**Mitigation:** Lead with the collection reminder workflow (end of the credit cycle), not the daily ledger. The store owner must have data in the app to send reminders — this creates the incentive to maintain it. The guided first transaction during onboarding seeds the first data point.
**Validation:** Week 1 field research — gauge reaction intensity to "one-tap WhatsApp reminder" pitch.

### Risk 2 — Two-Sided Ledger Cultural Resistance
**Risk:** Store owners may resist sharing formal digital records with customers (shifts power dynamic).
**Mitigation:** Two-sided confirmation is Phase 2, opt-in per customer. MVP only sends messages from the store owner's number — it feels like a personal message, not an institutional notification.
**Validation:** Week 1 field research question: "Agar aapka customer WhatsApp pe apna balance dekh sake, toh kya aapko koi masla hoga?"

### Risk 3 — Distributor GTM Activation
**Risk:** Distributors agree in principle but don't actively push to retailers. DSR beat visit is the activation mechanism.
**Mitigation:** Include a DSR incentive (leaderboard or bonus for retailers onboarded). Don't rely on goodwill alone.

### Risk 4 — Khatabook Competition
**Risk:** Khatabook has funding and brand; they will respond to traction.
**Mitigation:** Defensible differentiation is the supplier-side B2B ledger and the distributor dashboard. Do not compete on the basic customer ledger — compete on the layers above it.

### Risk 5 — Urdu Voice Input Accuracy
**Risk:** Voice notes may be in Punjabi or Sindhi when system expects Urdu.
**Mitigation:** MVP voice notes are audio recordings only, not transcribed. Transcription requires validated Urdu ASR and is Phase 2.

---

## Acceptance Criteria

### Onboarding
- [ ] Given a new user, when they download and open the app, then they can reach their first recorded transaction in under 3 minutes
- [ ] Given a user has 200 phone contacts, when they opt to import contacts, then matching contacts appear as customer records with name and phone number
- [ ] Given a user during onboarding, when they enter shop name and locality, then this information persists to their profile and appears on all outgoing WhatsApp messages

### Transaction Entry
- [ ] Given a store owner is offline, when they record a credit transaction, then it saves to local storage in under 10 seconds and a sync queue entry is created
- [ ] Given a store owner records a partial payment, when the entry is saved, then the remaining balance is shown immediately without a network call
- [ ] Given a customer's balance reaches zero after a payment, when the entry is saved, then a "Hisaab saaf" celebration animation/state is displayed
- [ ] Given a store owner records a credit transaction, when they are prompted to notify the customer, then WhatsApp opens with a pre-filled balance update message
- [ ] Given a store owner records a payment received, when they are prompted to send a receipt, then WhatsApp opens with a pre-filled receipt message showing the new remaining balance
- [ ] Given a store owner attaches a voice note, when they view the transaction later, then the voice note is playable inline
- [ ] Given a store owner loses their device, when they reinstall on a new device and restore from backup, then all previously backed-up transactions are available

### Reminders
- [ ] Given a customer is 7+ days overdue, when the store owner views the home screen, then that customer is highlighted red with days-overdue count and an inline remind button
- [ ] Given a customer has WhatsApp, when the store owner taps remind, then WhatsApp opens with a pre-filled Urdu message containing the customer's name, shop name, and balance in the gentle template
- [ ] Given a customer has been reminded today, when the store owner views the customer detail, then "last reminder sent" shows today's date — preventing accidental double-messaging
- [ ] Given a customer has no phone number, when the store owner taps remind, then an SMS is sent via the fallback gateway
- [ ] Given the store owner previews a reminder, when they edit the pre-filled text in WhatsApp, then the REMINDER_SENT event is still logged (because the intent was sent, even if edited)

### Dispute Resolution
- [ ] Given a customer disputes a balance at the counter, when the store owner opens the customer's history, then a chat-thread view with all timestamped transactions is shown within 2 seconds
- [ ] Given the store owner taps "History share karein", then a plain-text formatted transaction history is sent to the customer via WhatsApp
- [ ] Given any transaction in the log, when the store owner views it, then a timestamp accurate to the second is displayed

### Supplier Tracking
- [ ] Given a supplier invoice is due in 2 days, when the app checks due dates, then an FCM push notification is sent to the store owner
- [ ] Given a supplier invoice is marked as paid, when the store owner views the summary panel, then the "Total I owe" figure decreases accordingly

### End-of-Day Summary
- [ ] Given the store owner flags a customer for follow-up, when they open the app the next day, then that customer appears at the top of the list with a follow-up indicator

### Sync & Offline
- [ ] Given the device has been offline for 7 days with 100+ pending events, when connectivity is restored, then all events sync without data loss or duplication
- [ ] Given two events are recorded on two different devices for the same shop (future multi-user), when both sync, then both appear in the server-side event log as separate entries (append-only — no conflict)

### Security
- [ ] Given an unauthenticated request, when it hits any Django endpoint, then a 401 is returned
- [ ] Given two shop owners, when one requests customer data, then they cannot see the other shop's records
- [ ] Given a sync payload contains an event with a different shop_id, when it reaches the API, then it is rejected with a 403

---

## Open Questions (resolved)

| Question | Decision |
|---|---|
| Customer without WhatsApp? | Phone optional; SMS fallback for non-WhatsApp customers |
| Reminder logic — manual or app-driven? | Hybrid: sorted list + red highlight at 7+ days + inline one-tap remind |
| Flutter confirmed? | Provisionally confirmed; benchmark on low-end device before first story |
| Device loss / data recovery? | Periodic backup to device storage + optional Google Drive |
| Multi-user data model? | device_id + optional actor label on every event from day one |
| Store owner segments for pilot? | Both residential and commercial; field data decides which converts better |
| Two-sided ledger go/no-go? | Soft signal; field research shapes UX (opt-in per customer), Phase 2 stays on roadmap |
| Distributor dashboard scope? | Read-only health score dashboard (green/amber/red), sortable by score |
