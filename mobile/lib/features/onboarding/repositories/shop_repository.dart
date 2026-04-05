import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class ShopRepository {
  final Dio _dio;
  final AppDatabase _db;

  ShopRepository(this._dio, this._db);

  /// Updates shop name and locality.
  /// - Writes to local Shops table immediately (offline-first).
  /// - Attempts PUT /api/shop/profile; on failure enqueues a SyncQueue entry.
  Future<void> updateShopProfile({
    required String shopId,
    required String name,
    String? locality,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Write to local Shops table first (offline-first)
    // Only update name/locality; preserve existing row data.
    await (_db.update(_db.shops)..where((s) => s.id.equals(shopId))).write(
      ShopsCompanion(
        name: Value(name),
        locality: Value(locality),
        updatedAt: Value(now),
      ),
    );

    // 2. Attempt network call
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
    // Use a deterministic synthetic event ID so repeated failures don't create duplicates.
    final syntheticId = 'SHOP_PROFILE_UPDATE_$shopId';
    // Payload stored implicitly; sync worker identifies by eventId prefix.
    // ignore: unused_local_variable
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
          createdAt: Value(now),
        ));
  }

  /// Mark shop onboarding as complete.
  /// Stores a sentinel value in actorLabel = 'ONBOARDING_COMPLETE'.
  Future<void> markOnboardingComplete(String shopId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.shops)..where((s) => s.id.equals(shopId))).write(
      ShopsCompanion(
        actorLabel: const Value('ONBOARDING_COMPLETE'),
        updatedAt: Value(now),
      ),
    );
  }

  /// Returns true if onboarding has been completed for this shop.
  Future<bool> hasCompletedOnboarding(String shopId) async {
    final shop = await (_db.select(_db.shops)
          ..where((s) => s.id.equals(shopId)))
        .getSingleOrNull();
    return shop?.actorLabel == 'ONBOARDING_COMPLETE';
  }
}
