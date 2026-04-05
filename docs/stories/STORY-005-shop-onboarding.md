# STORY-005: Shop Onboarding (Name, Locality, Contact Import, First Transaction)
Status: PARTIAL - AC6/AC7 deferred to STORY-008
Sprint: 2
Points: 5

## User Story
As a kiryana store owner who has just verified my OTP for the first time, I want to set up my shop name and locality, optionally import my phone contacts as customers, and be guided through recording my first transaction, so that the app is personalised to my shop and I reach my first value moment in under 3 minutes.

## Acceptance Criteria
- [ ] AC1: After OTP verification where `is_new_shop=true`, the app navigates to a shop setup screen requesting shop name (required) and locality (optional).
- [ ] AC2: Submitting the shop setup screen calls `PUT /api/shop/profile` and persists name and locality to the local Shops table immediately; if offline the update is queued and the app proceeds without blocking.
- [ ] AC3: After shop setup, the app prompts to optionally import phone contacts; accepting shows the device contacts picker with search.
- [ ] AC4: Imported contacts become Customer records (name + phone) in the local Drift Customers table; duplicates (matching phone number for this shop) are silently skipped.
- [ ] AC5: Contact import creates a SyncQueue entry for each new customer so they sync on reconnect.
- [ ] AC6: After contact import (or skipping), the app launches a guided walkthrough prompting the owner to record their first credit transaction: tap a customer (or create one inline), tap the credit button, enter an amount, and save.
- [ ] AC7: The guided walkthrough completes and navigates to the home screen once the first transaction is saved.
- [ ] AC8: Total elapsed time from app download to first recorded transaction is under 3 minutes (manual timing criterion).
- [ ] AC9: Shop name and locality appear correctly in all outgoing WhatsApp message templates.
- [ ] AC10: All user-facing strings on onboarding screens are present in Urdu.

## Technical Notes
### Flutter
- Navigate to `ShopSetupScreen` when `AuthProvider` detects `is_new_shop=true` from OTP verify response.
- `ShopSetupScreen` uses a `TextFormField` for shop name (required, max 255 chars) and locality (optional).
- On submit: write to local `Shops` table via Drift, then call `ShopRepository.updateProfile()` which enqueues a profile sync if online call fails.
- Contact import: use `contacts_service` or `flutter_contacts` package; request `READ_CONTACTS` permission with rationale dialog in Urdu. Map each contact to a `Customer` row (client-generated UUID v4, `shop_id` from session).
- Guided walkthrough: a simple `PageView`-style overlay with 3 steps. Each step highlights the relevant UI element. On step 3 completion (first transaction saved), dismiss walkthrough.
- Store a `has_completed_onboarding` flag in the local `Shops` table to prevent re-triggering on subsequent logins.

### Django
- `PUT /api/shop/profile` (already defined in API_CONTRACTS.md) handles name + locality update.
- No new endpoints required for onboarding.
- `POST /api/customers` (batch-capable via sync) handles contact import — individual customer records are created via the normal sync path.

## Offline Behaviour
Shop name and locality are written to the local Drift `Shops` table immediately on submit — the `PUT /api/shop/profile` call is attempted but failure does not block progress. The profile update is added to a sync queue entry so it reaches the server on next reconnect. Contact import creates local Customer rows instantly; those rows queue for sync. The guided walkthrough and first transaction recording are fully local — no network required.

## Dependencies
- STORY-004 (OTP auth must be complete; `is_new_shop` flag drives navigation into onboarding)

## Known Deferrals
- AC6/AC7: The walkthrough currently shows informational slides only (3 steps describing credit entry flow). A guided, interactive transaction walkthrough requiring a real credit transaction save is deferred to STORY-008 once the credit entry feature is built.

## Definition of Done
- [ ] All ACs passing
- [ ] flutter test passing
- [ ] flutter analyze clean
- [ ] python -m pytest passing
- [ ] Offline behaviour verified manually
