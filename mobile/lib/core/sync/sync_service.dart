/// Background sync service stub.
/// Full implementation in STORY-005 (sync engine).
///
/// Responsibilities:
/// - Flush SyncQueue entries (status = PENDING) to the Django API when online
/// - Pull events from server since last sync timestamp
/// - Update server_timestamp on local events after successful sync
/// - Handle retry logic with exponential back-off (max 3 retries)
class SyncService {
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  /// Trigger a sync cycle. No-op if already syncing or offline.
  Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      // TODO(STORY-005): Implement sync flush and pull
    } finally {
      _isSyncing = false;
    }
  }
}
