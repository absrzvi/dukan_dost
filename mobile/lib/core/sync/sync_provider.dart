import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/connectivity_service.dart';
import '../providers/database_provider.dart';
import 'sync_service.dart';

// ---------------------------------------------------------------------------
// ConnectivityService provider
// ---------------------------------------------------------------------------

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

// ---------------------------------------------------------------------------
// isOnline StreamProvider
// Emits true whenever the device has a non-Bluetooth, non-none connection.
// ---------------------------------------------------------------------------

final isOnlineProvider = StreamProvider<bool>((ref) {
  final svc = ref.watch(connectivityServiceProvider);
  return svc.isOnlineStream;
});

// ---------------------------------------------------------------------------
// SyncService provider
// ---------------------------------------------------------------------------

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dio = ref.watch(dioProvider);
  final svc = SyncService(database: db, dio: dio);
  ref.onDispose(svc.dispose);
  return svc;
});

// ---------------------------------------------------------------------------
// SyncStatus StateNotifier
// ---------------------------------------------------------------------------

class SyncStatusNotifier extends StateNotifier<SyncStatus> {
  SyncStatusNotifier(SyncService syncService) : super(SyncStatus.idle) {
    _statusSubscription = syncService.statusStream.listen((s) {
      state = s;
    });
  }

  /// Testing constructor — starts with a fixed [initialState] and does not
  /// subscribe to any stream.
  SyncStatusNotifier.forTesting(super.initialState)
      : _statusSubscription = null;

  StreamSubscription<SyncStatus>? _statusSubscription;

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
}

final syncStatusProvider =
    StateNotifierProvider<SyncStatusNotifier, SyncStatus>((ref) {
  final svc = ref.watch(syncServiceProvider);
  return SyncStatusNotifier(svc);
});

// ---------------------------------------------------------------------------
// Auto-sync: trigger when connectivity transitions from false → true
// ---------------------------------------------------------------------------

/// Watches [isOnlineProvider] and fires a sync cycle whenever the device
/// comes back online. The sync result is discarded — errors are swallowed.
///
/// Wire this provider once at app startup by calling:
///   ref.watch(autoSyncProvider);
/// in a high-level widget (e.g. HomeScreen).
final autoSyncProvider = Provider<void>((ref) {
  var wasOnline = false;

  ref.listen<AsyncValue<bool>>(isOnlineProvider, (previous, next) {
    final isOnline = next.valueOrNull ?? false;
    if (isOnline && !wasOnline) {
      // Transitioned offline → online: start sync in background
      _triggerSync(ref);
    }
    wasOnline = isOnline;
  });
});

Future<void> _triggerSync(Ref ref) async {
  final syncService = ref.read(syncServiceProvider);
  final db = ref.read(appDatabaseProvider);

  try {
    final shops = await db.select(db.shops).get();
    if (shops.isEmpty) return;
    final shop = shops.first;
    final token = shop.sessionToken;
    await syncService.sync(shop.id, token);
  } catch (_) {
    // Swallow — sync is best-effort background task
  }
}
