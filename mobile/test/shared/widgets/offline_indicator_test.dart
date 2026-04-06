// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/sync/sync_provider.dart';
import '../../../lib/core/sync/sync_service.dart';
import '../../../lib/shared/widgets/offline_indicator.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wrap the [child] widget inside a ProviderScope with controlled overrides.
Widget _wrap(
  Widget child, {
  SyncStatus syncStatus = SyncStatus.idle,
  bool isOnline = true,
}) {
  return ProviderScope(
    overrides: [
      syncStatusProvider.overrideWith(
        (_) => SyncStatusNotifier.forTesting(syncStatus),
      ),
      isOnlineProvider.overrideWith((_) => Stream.value(isOnline)),
    ],
    child: MaterialApp(home: Scaffold(appBar: AppBar(actions: [child]))),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets('shows offline badge when isOnline = false', (tester) async {
    await tester.pumpWidget(
      _wrap(const OfflineIndicator(), isOnline: false),
    );
    // One pump to build, one to let the StreamProvider emit.
    await tester.pump();

    expect(find.textContaining('آف لائن'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
  });

  testWidgets('shows syncing indicator when SyncStatus = syncing',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const OfflineIndicator(),
        syncStatus: SyncStatus.syncing,
        isOnline: true,
      ),
    );
    await tester.pump();

    expect(find.textContaining('مطابقت ہو رہی ہے'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('hides indicator when online and idle', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const OfflineIndicator(),
        syncStatus: SyncStatus.idle,
        isOnline: true,
      ),
    );
    await tester.pump();

    expect(find.textContaining('آف لائن'), findsNothing);
    expect(find.textContaining('مطابقت ہو رہی ہے'), findsNothing);
    expect(find.byIcon(Icons.wifi_off), findsNothing);
  });
}
