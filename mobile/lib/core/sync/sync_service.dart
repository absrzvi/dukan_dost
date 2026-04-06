import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../database/app_database.dart';

// ---------------------------------------------------------------------------
// SyncStatus enum
// ---------------------------------------------------------------------------

enum SyncStatus { idle, syncing, synced, error }

// ---------------------------------------------------------------------------
// SyncResult value object
// ---------------------------------------------------------------------------

class SyncResult {
  const SyncResult({
    required this.pushed,
    required this.pulled,
    required this.hasErrors,
  });

  final int pushed;
  final int pulled;
  final bool hasErrors;

  @override
  String toString() =>
      'SyncResult(pushed: $pushed, pulled: $pulled, hasErrors: $hasErrors)';
}

// ---------------------------------------------------------------------------
// SyncService
// ---------------------------------------------------------------------------

/// Background sync service.
///
/// Responsibilities:
/// - Flush SyncQueue entries (status = PENDING) to the Django API when online
/// - Pull events from server since last sync timestamp
/// - Update server_timestamp on local events after successful sync
/// - Handle retry logic (max 3 retries per entry; dead-letter after that)
///
/// Iron Rule: All sync errors are swallowed — never surface to user as
/// blocking errors. The UI only sees the [SyncStatus] state.
class SyncService {
  SyncService({required AppDatabase database, required Dio dio})
      : _db = database,
        _dio = dio;

  final AppDatabase _db;
  final Dio _dio;

  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _currentStatus = SyncStatus.idle;

  SyncStatus get currentStatus => _currentStatus;

  Stream<SyncStatus> get statusStream => _statusController.stream;

  void _setStatus(SyncStatus s) {
    _currentStatus = s;
    _statusController.add(s);
  }

  // ---------------------------------------------------------------------------
  // Push
  // ---------------------------------------------------------------------------

  /// Push all PENDING SyncQueue entries to server in batches of 500.
  /// Returns the total number of events successfully pushed.
  Future<int> pushPending(String shopId, String authToken) async {
    final dao = _db.eventsDao;
    var totalPushed = 0;

    while (true) {
      final batch = await dao.getPendingSyncBatch(limit: 500);
      if (batch.isEmpty) break;

      final eventIds = batch.map((e) => e.eventId).toList();

      // Decode JSON payloads stored in the SyncQueue rows.
      final payloads = batch
          .where((e) => e.payload != null)
          .map((e) => jsonDecode(e.payload!) as Map<String, dynamic>)
          .toList();

      if (payloads.isEmpty) {
        // All entries in this batch have null payloads — data corruption.
        // Mark FAILED so they are visible for investigation rather than silently
        // disappearing as SYNCED without ever reaching the server.
        await dao.markFailed(eventIds);
        break;
      }

      try {
        await _dio.post<dynamic>(
          '/api/sync/events',
          data: {'events': payloads},
          options: Options(
            headers: {'Authorization': 'Token $authToken'},
          ),
        );
        await dao.markSynced(eventIds);
        totalPushed += eventIds.length;
      } on DioException {
        await dao.markFailed(eventIds);
        break; // Stop on network error; retry next cycle
      } catch (_) {
        await dao.markFailed(eventIds);
        break;
      }
    }

    return totalPushed;
  }

  // ---------------------------------------------------------------------------
  // Pull
  // ---------------------------------------------------------------------------

  /// Pull events from server since the last known pull timestamp.
  /// Writes new events to local DB, deduplicating by UUID via upsert.
  /// Returns the total number of event rows processed (including deduped).
  Future<int> pullNew(String shopId, String authToken) async {
    final dao = _db.eventsDao;
    var cursor = await dao.getLastPullTimestamp(shopId);
    var totalPulled = 0;

    while (true) {
      try {
        // Convert epoch-millis cursor to ISO 8601 string for Django parse_datetime.
        // On first sync (cursor == null) use epoch zero so the server returns all events.
        final sinceIso = cursor != null && cursor > 0
            ? DateTime.fromMillisecondsSinceEpoch(cursor, isUtc: true).toIso8601String()
            : '1970-01-01T00:00:00.000Z';

        final response = await _dio.get<Map<String, dynamic>>(
          '/api/sync/events',
          queryParameters: {
            'since': sinceIso,
            'limit': 500,
          },
          options: Options(
            headers: {'Authorization': 'Token $authToken'},
          ),
        );

        final data = response.data;
        if (data == null) break;

        final List<dynamic> eventList =
            (data['events'] as List<dynamic>?) ?? [];

        for (final raw in eventList) {
          final e = raw as Map<String, dynamic>;
          await dao.upsertEventFromServer(
            id: e['id'] as String,
            shopId: e['shop_id'] as String,
            eventType: e['event_type'] as String,
            partyType: e['party_type'] as String,
            partyId: e['party_id'] as String,
            amountPaisa: (e['amount_paisa'] as num).toInt(),
            note: e['note'] as String?,
            deviceId: e['device_id'] as String? ?? '',
            actorLabel: e['actor_label'] as String?,
            deviceTimestamp: _parseTimestamp(e['device_timestamp']),
            serverTimestamp: _parseTimestamp(e['server_timestamp']),
          );
          totalPulled++;
        }

        final hasMore = (data['has_more'] as bool?) ?? false;
        final latestTs = data['latest_server_timestamp'];
        final newCursor =
            latestTs != null ? _parseTimestamp(latestTs) : null;

        if (newCursor != null && newCursor > 0) {
          await dao.updateLastPullTimestamp(shopId, newCursor);
          cursor = newCursor;
        }

        if (!hasMore) break;
      } on DioException {
        break; // Swallow pull error; retry next cycle
      } catch (_) {
        break;
      }
    }

    return totalPulled;
  }

  // ---------------------------------------------------------------------------
  // Full sync cycle
  // ---------------------------------------------------------------------------

  /// Full sync cycle: push then pull.
  /// Updates [currentStatus] and [statusStream] throughout.
  Future<SyncResult> sync(String shopId, String authToken) async {
    if (_currentStatus == SyncStatus.syncing) {
      return const SyncResult(pushed: 0, pulled: 0, hasErrors: false);
    }

    _setStatus(SyncStatus.syncing);

    var pushed = 0;
    var pulled = 0;
    var hasErrors = false;

    try {
      pushed = await pushPending(shopId, authToken);
      pulled = await pullNew(shopId, authToken);
      _setStatus(SyncStatus.synced);
    } catch (_) {
      hasErrors = true;
      _setStatus(SyncStatus.error);
    }

    return SyncResult(pushed: pushed, pulled: pulled, hasErrors: hasErrors);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static int _parseTimestamp(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return DateTime.parse(value).millisecondsSinceEpoch;
    }
    return 0;
  }

  void dispose() {
    _statusController.close();
  }
}
