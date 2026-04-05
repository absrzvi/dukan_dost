# STORY-012: Supplier Ledger (Supplier List, Add Supplier, Mark Paid)
Status: TODO
Sprint: 4
Points: 5

## User Story
As a kiryana store owner, I want a separate Suppliers tab where I can see all outstanding supplier invoices, add new ones with amounts and due dates, and mark them as paid, so that I always know how much I owe my FMCG suppliers and when payments are due.

## Acceptance Criteria
- [ ] AC1: A "Suppliers" tab (distinct from the customer ledger) is accessible from the main bottom navigation bar.
- [ ] AC2: The suppliers tab shows a list of all active (non-deleted, non-paid) supplier records for the shop, displaying supplier name, invoice amount in PKR, due date, and days until due.
- [ ] AC3: A summary at the top of the suppliers screen shows total owed to all suppliers in PKR (sum of all unpaid invoice amounts).
- [ ] AC4: Suppliers are sorted by due date ascending by default (most urgent first).
- [ ] AC5: Suppliers with a due date within 2 days are highlighted in amber; suppliers with a past due date are highlighted in red.
- [ ] AC6: A "+" button opens an "Add Supplier" bottom sheet with fields: supplier name (required), phone (optional), invoice amount in PKR (required, integer), and due date (optional, date picker).
- [ ] AC7: Saving a new supplier writes to the local Drift `Suppliers` table immediately with a client-generated UUID and queues a SyncQueue entry for `POST /api/suppliers`.
- [ ] AC8: Tapping a supplier record shows an action menu with "Mark as paid" and "Delete" options.
- [ ] AC9: "Mark as paid" sets `is_paid=true` in the local Drift `Suppliers` table, removes the supplier from the active list, and queues a SyncQueue entry for `PUT /api/suppliers/{id}` with `is_paid=true`.
- [ ] AC10: "Delete" sets `is_deleted=true` (soft delete) in the local Drift table and queues a SyncQueue entry for `DELETE /api/suppliers/{id}`.
- [ ] AC11: The home screen summary panel (STORY-007 AC7) "Mujhe dena hai" figure reflects the total unpaid supplier amount computed from the local Drift table.
- [ ] AC12: All monetary amounts are stored as integer paisa; the UI formats them as PKR with no decimal places.
- [ ] AC13: All user-facing strings are in Urdu.

## Technical Notes
### Flutter
- Screen: `SupplierListScreen` in `lib/features/suppliers/screens/`.
- Drift DAO: `SuppliersDao` with `watchActiveSuppliers(shopId)` (WHERE is_paid=0 AND is_deleted=0, ordered by due_date ASC), `insertSupplier()`, `markPaid(id)`, `softDelete(id)`.
- `watchActiveSuppliers` returns a `Stream` consumed by `StreamProvider.autoDispose` in Riverpod.
- Add supplier form: `AddSupplierSheet` bottom sheet with a `DatePicker` for due date. Amount field uses the `AmountKeypad` widget from STORY-008 (or a simpler `TextFormField` with numeric keyboard if keypad reuse is complex — consistency preferred).
- Days until due: computed as `dueDate.difference(DateTime.now()).inDays` at render time.
- Highlight logic: `days_until_due <= 0` → red; `days_until_due <= 2` → amber.
- `SuppliersDao.insertSupplier()` must also insert a SyncQueue row atomically.
- `SuppliersDao.markPaid()` and `softDelete()` must also insert SyncQueue rows for the respective PUT/DELETE API calls.

### Django
- `GET /api/suppliers`, `POST /api/suppliers`, `PUT /api/suppliers/{id}`, `DELETE /api/suppliers/{id}` are all defined in API_CONTRACTS.md.
- Supplier data reaches the server via the sync engine (STORY-013).

## Offline Behaviour
All supplier operations (view, add, mark paid, delete) work fully offline. All reads and writes go directly to the local Drift `Suppliers` table. SyncQueue entries are created atomically with every mutation and will be flushed by the sync engine (STORY-013) on next connectivity. The supplier total on the home screen summary is computed locally. No screen or action is gated on network availability.

## Dependencies
- STORY-006 (Drift tables — SyncQueue for supplier mutations)
- STORY-007 (home screen summary panel to display "Mujhe dena hai" total)

## Definition of Done
- [ ] All ACs passing
- [ ] flutter test passing
- [ ] flutter analyze clean
- [ ] python -m pytest passing
- [ ] Offline behaviour verified manually
