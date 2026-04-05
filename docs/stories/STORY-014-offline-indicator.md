# STORY-014: Offline Indicator (Subtle Connectivity Status in App Bar)
Status: TODO
Sprint: 4
Points: 2

## User Story
As a kiryana store owner, I want a subtle indicator in the app bar that tells me when my phone has no internet connection (and when it is syncing), so that I know my recent transactions are queued and will sync later — without the app ever preventing me from recording transactions.

## Acceptance Criteria
- [ ] AC1: When the device has no network connectivity, a subtle indicator appears in the app bar — a small icon or label ("Offline" / "آف لائن") in a muted colour (grey or amber, not red to avoid alarm).
- [ ] AC2: When the sync engine (STORY-013) is actively syncing, the indicator changes to show a sync-in-progress state (e.g. a small spinning icon with "Sync..." label).
- [ ] AC3: When the device is online and sync is idle (no pending items), the indicator is hidden — normal state is no indicator visible.
- [ ] AC4: No core feature (transaction entry, customer list, balance display) is disabled or gated when the device is offline.
- [ ] AC5: The offline indicator does not use a full-width banner or modal that obscures content. It is constrained to the app bar area.
- [ ] AC6: The indicator transitions between states smoothly (animated crossfade or fade-in/out, not a jarring snap).
- [ ] AC7: When connectivity is restored and sync completes, the indicator disappears automatically with a brief "Synced" / "مکمل" confirmation for 2 seconds before fading out.
- [ ] AC8: Widget tests cover: offline state shows indicator, sync-in-progress state shows spinner, online-idle state hides indicator.

## Technical Notes
### Flutter
- `ConnectivityStatusWidget` — a small widget placed in the `AppBar.actions` or `AppBar.title` suffix area.
- Consumes two Riverpod providers:
  1. `connectivityProvider` — `StreamProvider` wrapping `connectivity_plus` stream, returns `bool isOnline`.
  2. `syncStatusProvider` — `StateNotifierProvider<SyncStatusNotifier, SyncStatus>` from STORY-013.
- Render logic:
  - `SyncStatus.syncing` → small `SizedBox(width:16, height:16)` `CircularProgressIndicator` + "Sync..." text.
  - `!isOnline` (and not syncing) → grey wifi-off icon + "آف لائن" text.
  - `isOnline && SyncStatus.idle` → hidden (return `SizedBox.shrink()`).
  - After sync completes: show "مکمل" for 2 seconds using a `Timer`, then fade out.
- Use `AnimatedSwitcher` for the crossfade between states.
- Indicator text size: 11sp, muted grey (#9E9E9E for offline, primary colour for syncing).

### Django
- No Django work required for this story.

## Offline Behaviour
This story is itself a description of how the app communicates the offline state. No feature is degraded. The indicator is purely informational. The app continues to function identically whether the indicator is showing or hidden.

## Dependencies
- STORY-013 (SyncStatusNotifier provider must be defined before the indicator can consume it)

## Definition of Done
- [ ] All ACs passing
- [ ] flutter test passing
- [ ] flutter analyze clean
- [ ] python -m pytest passing
- [ ] Offline behaviour verified manually
