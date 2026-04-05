# STORY-002 — Flutter Project Scaffold

## Metadata
| Field | Value |
|---|---|
| Story ID | STORY-002 |
| Title | Flutter Project Scaffold |
| Status | DONE |
| Created | 2026-04-05 |
| Last Updated | 2026-04-05 |
| Agent | flutter-dev |

## Goal
Scaffold the complete Flutter project structure including all dependencies, folder structure, Drift table definitions, core utilities, and stub screens ready for feature development in STORY-004 (OTP auth).

## Scope
- pubspec.yaml dependencies (Drift, Riverpod, Dio, connectivity_plus, etc.)
- Full lib/ folder structure with feature modules
- Drift table definitions matching DATA_MODEL.md
- Core constants, utilities, shared widgets
- Stub screens for all features
- main.dart wired to ProviderScope + MaterialApp

## Definition of Done
- [ ] `flutter analyze` passes with zero errors
- [ ] `flutter test` passes with zero failures
- [ ] Offline scenario tested: transaction recorded with no network, syncs correctly on reconnect
- [ ] Urdu strings present for all user-facing text in the story scope
- [ ] QA score >= 85/100
- [ ] Code Reviewer agent approved (no Critical issues)
- [ ] Security Sentinel agent approved (no Critical issues)
- [ ] `docs/API_CONTRACTS.md` updated if any endpoints changed
- [ ] Story file Status set to DONE
