// ignore_for_file: avoid_relative_lib_imports

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/config/env.dart';
import '../../../lib/core/database/app_database.dart';
import '../../../lib/core/sync/sync_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase _makeTestDatabase() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

/// Build a Dio instance with a mock adapter.
///
/// [postResponseBody] — JSON object returned for POST requests.
/// [getResponseBody]  — JSON object returned for GET requests.
/// [failRequests]     — if true, all requests throw a DioException.
Dio _makeMockDio({
  Map<String, dynamic>? postResponseBody,
  Map<String, dynamic>? getResponseBody,
  bool failRequests = false,
}) {
  final dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
  dio.httpClientAdapter = _MockAdapter(
    postBody: postResponseBody ?? {'accepted': 0},
    getBody: getResponseBody ?? {'events': [], 'has_more': false},
    fail: failRequests,
  );
  return dio;
}

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter({
    required this.postBody,
    required this.getBody,
    required this.fail,
  });

  final Map<String, dynamic> postBody;
  final Map<String, dynamic> getBody;
  final bool fail;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    if (fail) {
      throw DioException(requestOptions: options);
    }
    final body =
        options.method == 'POST' ? postBody : getBody;
    final encoded = utf8.encode(jsonEncode(body));
    return ResponseBody.fromBytes(encoded, 200,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

// ---------------------------------------------------------------------------
// Seed helpers
// ---------------------------------------------------------------------------

Future<void> _seedShop(AppDatabase db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.into(db.shops).insert(
        ShopsCompanion.insert(
          id: 'shop-001',
          phone: '03001234567',
          name: 'Test Shop',
          deviceId: 'dev-001',
          sessionToken: 'tok-001',
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<void> _seedPendingEvent(
  AppDatabase db, {
  required String eventId,
}) async {
  await db.eventsDao.insertEvent(
    id: eventId,
    shopId: 'shop-001',
    eventType: 'CREDIT',
    partyType: 'CUSTOMER',
    partyId: 'cust-001',
    amountPaisa: 5000,
    deviceId: 'dev-001',
    deviceTimestamp: DateTime.now().millisecondsSinceEpoch,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;

  setUp(() async {
    db = _makeTestDatabase();
    await _seedShop(db);
  });

  tearDown(() async {
    await db.close();
  });

  // -----------------------------------------------------------------------
  // pushPending — no pending entries
  // -----------------------------------------------------------------------

  test('pushPending returns 0 when no pending entries', () async {
    final svc = SyncService(database: db, dio: _makeMockDio());
    final result = await svc.pushPending('shop-001', 'tok-001');
    expect(result, 0);
  });

  // -----------------------------------------------------------------------
  // pushPending — marks entries as SYNCED after successful push
  // -----------------------------------------------------------------------

  test(
      'pushPending marks entries as SYNCED after successful POST to server',
      () async {
    await _seedPendingEvent(db, eventId: 'evt-001');
    await _seedPendingEvent(db, eventId: 'evt-002');

    final svc = SyncService(
      database: db,
      dio: _makeMockDio(postResponseBody: {'accepted': 2}),
    );

    final pushed = await svc.pushPending('shop-001', 'tok-001');

    expect(pushed, 2);

    // Verify both entries are now SYNCED — no pending left
    final pending = await db.eventsDao.getPendingSyncBatch();
    expect(pending, isEmpty);
  });

  // -----------------------------------------------------------------------
  // pushPending — marks entries as FAILED on network error
  // -----------------------------------------------------------------------

  test('pushPending marks entries as FAILED when POST throws DioException',
      () async {
    await _seedPendingEvent(db, eventId: 'evt-fail-001');

    final svc = SyncService(
      database: db,
      dio: _makeMockDio(failRequests: true),
    );
    final pushed = await svc.pushPending('shop-001', 'tok-001');

    expect(pushed, 0);

    // Entry should now be FAILED with retryCount = 1
    final all = await (db.select(db.syncQueue)
          ..where((sq) => sq.eventId.equals('evt-fail-001')))
        .get();
    expect(all.first.status, 'FAILED');
    expect(all.first.retryCount, 1);
  });

  // -----------------------------------------------------------------------
  // pullNew — writes new events from server to local DB
  // -----------------------------------------------------------------------

  test('pullNew inserts new events from server into local DB', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final serverEvent = {
      'id': 'srv-evt-001',
      'shop_id': 'shop-001',
      'event_type': 'CREDIT',
      'party_type': 'CUSTOMER',
      'party_id': 'cust-srv-001',
      'amount_paisa': 10000,
      'device_id': 'dev-other',
      'device_timestamp': now - 60000,
      'server_timestamp': now,
    };

    final svc = SyncService(
      database: db,
      dio: _makeMockDio(
        getResponseBody: {
          'events': [serverEvent],
          'has_more': false,
          'latest_server_timestamp': now,
        },
      ),
    );

    final pulled = await svc.pullNew('shop-001', 'tok-001');

    expect(pulled, 1);

    final rows = await (db.select(db.events)
          ..where((e) => e.id.equals('srv-evt-001')))
        .get();
    expect(rows, hasLength(1));
    expect(rows.first.amountPaisa, 10000);
    expect(rows.first.serverTimestamp, now);
  });

  // -----------------------------------------------------------------------
  // pullNew — duplicate UUID does NOT create duplicate event rows
  // -----------------------------------------------------------------------

  test('pullNew with duplicate UUID does not create duplicate event rows',
      () async {
    // Pre-seed event locally
    await _seedPendingEvent(db, eventId: 'dup-evt-001');

    final now = DateTime.now().millisecondsSinceEpoch;
    final serverEvent = {
      'id': 'dup-evt-001',
      'shop_id': 'shop-001',
      'event_type': 'CREDIT',
      'party_type': 'CUSTOMER',
      'party_id': 'cust-001',
      'amount_paisa': 5000,
      'device_id': 'dev-001',
      'device_timestamp': now - 60000,
      'server_timestamp': now,
    };

    final svc = SyncService(
      database: db,
      dio: _makeMockDio(
        getResponseBody: {
          'events': [serverEvent],
          'has_more': false,
          'latest_server_timestamp': now,
        },
      ),
    );

    await svc.pullNew('shop-001', 'tok-001');

    // Still only 1 row for that ID
    final rows = await (db.select(db.events)
          ..where((e) => e.id.equals('dup-evt-001')))
        .get();
    expect(rows, hasLength(1));
    // server_timestamp should be updated from server response
    expect(rows.first.serverTimestamp, now);
  });
}
