import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class ShopRepository {
  final Dio _dio;
  final AppDatabase _db;

  ShopRepository(this._dio, this._db);

  /// Writes shop name and locality to local Drift table (offline-first).
  /// Returns after the local write. The caller should fire [syncProfileUpdate]
  /// separately without awaiting to keep navigation unblocked.
  Future<void> updateShopProfileLocal({
    required String shopId,
    required String name,
    String? locality,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await (_db.update(_db.shops)..where((s) => s.id.equals(shopId))).write(
      ShopsCompanion(
        name: Value(name),
        locality: Value(locality),
        updatedAt: Value(now),
      ),
    );
  }

  /// Attempts the network call; on failure enqueues a SyncQueue entry.
  /// Fire this with [unawaited] after [updateShopProfileLocal].
  Future<void> syncProfileUpdate({
    required String shopId,
    required String name,
    String? locality,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _dio.put('/api/shop/profile', data: {
        'name': name,
        if (locality != null) 'locality': locality,
      });
    } on DioException {
      await _enqueueProfileUpdate(
          shopId: shopId, name: name, locality: locality, now: now);
    } catch (_) {
      await _enqueueProfileUpdate(
          shopId: shopId, name: name, locality: locality, now: now);
    }
  }

  Future<void> _enqueueProfileUpdate({
    required String shopId,
    required String name,
    String? locality,
    required int now,
  }) async {
    final syntheticId = 'SHOP_PROFILE_UPDATE_$shopId';
    final payload = jsonEncode({
      'event_type': 'SHOP_PROFILE_UPDATE',
      'shop_id': shopId,
      'name': name,
      'locality': locality,
    });

    await _db.into(_db.syncQueue).insertOnConflictUpdate(SyncQueueCompanion(
          eventId: Value(syntheticId),
          status: const Value('PENDING'),
          retryCount: const Value(0),
          payload: Value(payload),
          createdAt: Value(now),
        ));
  }

  /// Mark shop onboarding as complete using the dedicated column.
  Future<void> markOnboardingComplete(String shopId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.shops)..where((s) => s.id.equals(shopId))).write(
      ShopsCompanion(
        hasCompletedOnboarding: const Value(1),
        updatedAt: Value(now),
      ),
    );
  }

  /// Returns true if onboarding has been completed for this shop.
  Future<bool> hasCompletedOnboarding(String shopId) async {
    final shop = await (_db.select(_db.shops)
          ..where((s) => s.id.equals(shopId)))
        .getSingleOrNull();
    return (shop?.hasCompletedOnboarding ?? 0) == 1;
  }
}
