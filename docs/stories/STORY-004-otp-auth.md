# STORY-004 — Phone Number + OTP Authentication

**Status: DONE**
**Sprint:** 1
**Points:** 8

## Goal
Enable a kiryana store owner to log in using their phone number and a 6-digit OTP. On first login, a Shop record is created. On subsequent logins, the session token is refreshed.

## Scope
- Django: OTPRequest model, OTP request and verify views, serializers, tests
- Flutter: PhoneEntryScreen, OtpEntryScreen, AuthRepository, AuthProvider, Dio client

## Acceptance Criteria
1. Owner enters +92XXXXXXXXXX phone number → receives a 6-digit SMS OTP
2. Owner enters OTP → receives session token stored in secure storage
3. First login: `is_new_shop=true` → navigate to onboarding
4. Returning login: `is_new_shop=false` → navigate to home
5. Invalid OTP → show "غلط یا میعاد ختم کوڈ" error
6. Rate limit (5 OTP requests/hour) → 429 → show error
7. Offline → show "انٹرنیٹ ضروری ہے" and disable send button
8. Countdown timer shows 5:00 on OTP screen; resend enabled at 0:00

## Definition of Done
- [ ] `flutter analyze` passes with zero errors
- [ ] `flutter test` passes with zero failures
- [ ] `python -m mypy` passes with zero errors
- [ ] `python -m pytest` passes with zero failures
- [ ] Offline scenario tested: transaction recorded with no network, syncs correctly on reconnect
- [ ] Urdu strings present for all user-facing text in the story scope
- [ ] QA score >= 85/100
- [ ] Code Reviewer agent approved (no Critical issues)
- [ ] Security Sentinel agent approved (no Critical issues)
- [ ] `docs/API_CONTRACTS.md` updated if any endpoints changed
- [ ] Story file Status set to DONE

## Files Changed
### Backend
- `backend/apps/authentication/models.py` — OTPRequest model with hash_otp, create_for_phone, verify
- `backend/apps/authentication/serializers.py` — OTPRequestSerializer, OTPVerifySerializer
- `backend/apps/authentication/views.py` — OTPRequestView, OTPVerifyView
- `backend/apps/authentication/urls.py` — URL patterns
- `backend/apps/authentication/tests.py` — unit + view tests
- `backend/apps/shops/models.py` — Shop and Device models

### Flutter
- `mobile/lib/features/auth/repositories/auth_repository.dart`
- `mobile/lib/features/auth/providers/auth_provider.dart`
- `mobile/lib/features/auth/screens/phone_entry_screen.dart`
- `mobile/lib/features/auth/screens/otp_entry_screen.dart`
- `mobile/lib/core/network/api_client.dart`
