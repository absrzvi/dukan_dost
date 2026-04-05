# STORY-007: Customer List Screen (Computed Balances, Search, Sort)
Status: TODO
Sprint: 2
Points: 5

## User Story
As a kiryana store owner, I want to see a list of all my customers with their current outstanding balances sorted by highest balance first, and be able to search and sort the list, so that I always know at a glance who owes me the most and can quickly find any customer.

## Acceptance Criteria
- [ ] AC1: The home screen renders a scrollable list of all customers belonging to the authenticated shop, showing name, balance in PKR (formatted from paisa), and a "no phone" indicator icon for customers without a phone number.
- [ ] AC2: Balances are computed locally from the Drift event log (STORY-006) — no network call is required to display the list.
- [ ] AC3: The list is sorted by balance descending by default; the store owner can switch to sort by name (A–Z) or last activity date via a sort control.
- [ ] AC4: A search bar at the top filters the customer list by name (case-insensitive, Roman Urdu and Urdu script both supported).
- [ ] AC5: Customers with a balance older than 7 days are highlighted in red with a "X din baad" overdue count displayed on the list item.
- [ ] AC6: Flagged customers (is_flagged=true) appear at the top of the list with a distinct follow-up indicator, above the sort order.
- [ ] AC7: A summary panel at the top of the screen shows three numbers: "Mujhe milna hai" (total owed to me), "Mujhe dena hai" (total owed to suppliers), and "Net position" — all computed locally.
- [ ] AC8: Tapping a customer navigates to the Customer Detail screen (STORY-010 stub is acceptable at this stage).
- [ ] AC9: A floating action button or prominent button allows creating a new customer with name (required) and optional phone number.
- [ ] AC10: Creating a new customer writes to the local Drift `Customers` table immediately and queues a sync entry; the list updates reactively without a pull-to-refresh.
- [ ] AC11: The list renders 200 customers with no jank (lazy rendering via `ListView.builder`).
- [ ] AC12: All user-facing labels are in Urdu.

## Technical Notes
### Flutter
- Screen: `HomeScreen` with a `CustomerListView` widget.
- Use `StreamProvider` wrapping a Drift `watchCustomers(shopId)` query that joins with a balance subquery.
- Balance per customer: compute inline in the Drift query using a correlated subquery or a separate `computeBalance` call per customer. For MVP scale (<200 customers) a per-customer query is acceptable.
- Overdue logic: `days_overdue = (now - last_credit_event_timestamp).inDays` for customers with balance > 0.
- Summary panel: three `Riverpod` derived providers summing balances from the customer stream + a separate supplier stream.
- New customer form: a `BottomSheet` with name and phone fields. On save: generate client UUID, write to Drift, enqueue sync.
- `ListView.builder` with `AutomaticKeepAliveClientMixin` disabled (no keep-alive needed; items are cheap to rebuild).
- Sort state: managed by a `StateProvider<SortOrder>`.

### Django
- `GET /api/customers` is already specified in API_CONTRACTS.md. The Flutter app should call this on reconnect to cross-check balances, but the screen never waits for it.
- `POST /api/customers` handles new customer sync (via SyncQueue flush in STORY-013).

## Offline Behaviour
The entire screen works offline. All customer data and balances come from the local Drift database. The summary panel totals are computed locally. Creating a new customer writes locally and queues for sync. If offline, the sync queue entry sits in PENDING state until STORY-013 engine detects connectivity.

## Dependencies
- STORY-005 (shop onboarding must be complete so shop name and shop_id are available locally)
- STORY-006 (Drift event log and balance computation must be in place)

## Definition of Done
- [ ] All ACs passing
- [ ] flutter test passing
- [ ] flutter analyze clean
- [ ] python -m pytest passing
- [ ] Offline behaviour verified manually
