# STORY-001 — Flutter Performance Benchmark

## Metadata
| Field | Value |
|---|---|
| Story ID | STORY-001 |
| Title | Flutter Performance Benchmark |
| Status | DONE |
| Created | 2026-04-05 |
| Last Updated | 2026-04-05 |
| Agent | flutter-dev |

## Goal
Establish a Flutter performance baseline by rendering 500 mock transaction objects in a ListView.builder and verifying smooth rendering with no overflow errors.

## Pass Criteria
- `flutter analyze` passes with zero errors
- `flutter test test/benchmark/transaction_list_benchmark_test.dart` passes with zero failures
- ListView renders 500 transactions without overflow errors
- 60fps validation documented (requires physical device — manual step)

## Definition of Done
- [x] `flutter analyze` passes with zero errors
- [x] `flutter test` passes with zero failures
- [x] Benchmark test renders 500 transactions without overflow errors
- [ ] 60fps manual validation documented (Tecno Spark or equivalent) — PENDING human action
- [x] Story file Status set to DONE

## Implementation Plan
1. Create Flutter project at `mobile/` with org `com.dukaandost`
2. Create benchmark test at `mobile/test/benchmark/transaction_list_benchmark_test.dart`
3. Generate 500 mock transactions (id, customerName, amountPaisa, eventType, timestamp, note)
4. Render in ListView.builder via WidgetTester
5. Measure build time and assert no overflow errors

## Benchmark Test Spec
Each mock transaction:
- `id`: String (sequential, e.g. "txn-001")
- `customerName`: String (e.g. "Ahmed Khan")
- `amountPaisa`: int (e.g. 50000 = PKR 500)
- `eventType`: String — "CREDIT" or "PAYMENT"
- `timestamp`: DateTime
- `note`: String (optional, nullable)

## Notes
- 60fps criterion requires a physical device. Full 60fps validation MUST be done manually on a Tecno Spark or equivalent before STORY-002 begins.
- Amounts are stored as integer paisa per Iron Rule #8 (no floating point for money).

---

## Debug Log

### 2026-04-05 — Attempt 1: Flutter not found on system

**Step attempted:** `flutter --version` and `flutter create mobile --org com.dukaandost --project-name dukaan_dost`

**Result:** BLOCKED — Flutter SDK is not installed on this machine.

**Evidence collected:**
- `flutter --version` in bash shell → `flutter: command not found`
- `where flutter` via cmd.exe → returned no output (not found in PATH)
- `Get-Command flutter` via PowerShell → `CommandNotFoundException`
- Searched `C:\Users\AbbasRizvi` recursively for `flutter.bat` → no results
- Searched `C:\` (5 levels deep) for `flutter.bat` → no results
- Common installation paths checked:
  - `C:\Users\AbbasRizvi\AppData\Local\flutter\bin\` — not found
  - `C:\flutter\bin\` — not found
  - `C:\src\flutter\bin\` — not found

**Blocker:** Flutter SDK must be installed before this story can proceed.

**Resolution required (human action):**
1. Download Flutter SDK from https://docs.flutter.dev/get-started/install/windows
2. Extract to a path WITHOUT spaces (e.g. `C:\flutter`)
3. Add `C:\flutter\bin` to the Windows system PATH environment variable
4. Run `flutter doctor` to verify the installation
5. Ensure Android SDK / Android Studio is also configured (`flutter doctor` will report this)
6. Re-run this story after Flutter is confirmed working

**Commands to verify before re-running:**
```
flutter --version
flutter doctor
```

**Story cannot proceed until Flutter is available in PATH.**

---

### 2026-04-05 — Attempt 2: PASSED

**Flutter version:** Flutter 3.41.6 • channel stable • Dart 3.11.4 • DevTools 2.54.2
**Flutter project found at:** `C:\Users\AbbasRizvi\OneDrive - Nomad Digital Limited\Documents\dukan dost\mobile`
**Flutter SDK location:** `C:\flutter\bin\flutter` (not in bash PATH, but present on system)

**Steps completed:**
1. Flutter SDK found at `C:\flutter` — was installed since Attempt 1.
2. Test file created at `mobile/test/benchmark/transaction_list_benchmark_test.dart`.
3. `flutter analyze` — **No issues found** (ran in 3.1s).
4. `flutter test` — **All 3 tests passed**.

**Fix applied during testing:**
- Initial run failed with `RenderFlex overflowed` errors due to `tester.view.physicalSize = Size(375, 812)` with `devicePixelRatio = 2.0` yielding only 187.5x406 logical pixels — too small for the AppBar layout.
- Fix: changed physicalSize to `Size(750, 1624)` so logical size is correctly 375x812 at 2x ratio.
- Row overflow in AppBar bottom also fixed by wrapping Text widgets in `Flexible`.

## Results

| Metric | Value |
|---|---|
| Flutter version | 3.41.6 (stable) |
| Dart version | 3.11.4 |
| 500-transaction list build time | 376ms |
| `flutter analyze` | PASS — zero issues |
| renders 500 transactions without errors | PASS |
| monetary amounts never displayed as floats | PASS |
| integer paisa type check | PASS |
| Total tests | 3 passed, 0 failed |

**Manual 60fps validation note:**
60fps smoothness has NOT yet been validated on a physical device. This MUST be done manually on a Tecno Spark or equivalent low-end Android device before STORY-002 begins. Connect the device, run `flutter run --profile` and use Flutter DevTools timeline to confirm frame render times stay under 16ms.
