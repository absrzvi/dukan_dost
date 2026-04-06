import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/event_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/events_dao.dart';
import '../../../core/database/daos/suppliers_dao.dart';
import '../models/supplier_with_balance.dart';

/// Repository for Suppliers — CRUD + balance enrichment.
///
/// Iron Rules:
///   - Balances are computed by replaying the event log, never stored.
///   - All monetary amounts are integer paisa.
///   - Every create/update/delete also queues a SyncQueue entry atomically.
class SuppliersRepository {
  SuppliersRepository({
    required AppDatabase db,
    required SuppliersDao suppliersDao,
    required EventsDao eventsDao,
  })  : _db = db,
        _suppliersDao = suppliersDao,
        _eventsDao = eventsDao;

  final AppDatabase _db;
  final SuppliersDao _suppliersDao;
  final EventsDao _eventsDao;
  final _uuid = const Uuid();

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  /// Stream of all active suppliers enriched with computed balances.
  /// Auto-updates when either the Suppliers table or the Events table changes.
  Stream<List<SupplierWithBalance>> watchSuppliersWithBalances(String shopId) {
    final suppliersStream = _suppliersDao.watchSuppliers(shopId);
    final eventsStream = _eventsDao.watchShopEvents(shopId);

    return Rx.combineLatest2(
      suppliersStream,
      eventsStream,
      (List<Supplier> suppliers, List<Event> _) => suppliers,
    ).asyncMap((supplierList) async {
      final enriched = <SupplierWithBalance>[];
      for (final supplier in supplierList) {
        final balance = await _eventsDao.computeBalance(
          supplier.id,
          PartyType.supplier,
        );

        DateTime? dueDateAt;
        if (supplier.dueDate != null) {
          dueDateAt =
              DateTime.fromMillisecondsSinceEpoch(supplier.dueDate!);
        }

        enriched.add(SupplierWithBalance(
          supplier: supplier,
          balancePaisa: balance,
          dueDateAt: dueDateAt,
        ));
      }
      return enriched;
    });
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Create a new supplier locally and queue for sync.
  /// If [initialDebtPaisa] > 0, also writes a CREDIT event atomically.
  /// [deviceId] must be passed from the real device ID provider — never hardcode.
  Future<Supplier> createSupplier({
    required String shopId,
    required String name,
    required String deviceId,
    String? phone,
    DateTime? dueDate,
    int? initialDebtPaisa,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    final companion = SuppliersCompanion.insert(
      id: id,
      shopId: shopId,
      name: name,
      phone: Value(phone),
      invoiceAmountPaisa: initialDebtPaisa ?? 0,
      dueDate: Value(dueDate?.millisecondsSinceEpoch),
      isPaid: const Value(0),
      isDeleted: const Value(0),
      createdAt: now,
      updatedAt: now,
    );

    await _db.transaction(() async {
      await _suppliersDao.upsertSupplier(companion);

      // Queue supplier creation for sync
      await _db.into(_db.syncQueue).insert(SyncQueueCompanion.insert(
            eventId: id,
            status: const Value('PENDING'),
            payload: Value(jsonEncode({
              'action': 'CREATE_SUPPLIER',
              'id': id,
              'name': name,
              'phone': phone,
              'shop_id': shopId,
              'invoice_amount_paisa': initialDebtPaisa ?? 0,
              if (dueDate != null)
                'due_date': dueDate.toIso8601String(),
            })),
            createdAt: now,
          ));

      // If initial debt provided, write a CREDIT event atomically
      if (initialDebtPaisa != null && initialDebtPaisa > 0) {
        final eventId = _uuid.v4();
        final payloadMap = <String, dynamic>{
          'id': eventId,
          'shop_id': shopId,
          'event_type': EventType.credit,
          'party_type': PartyType.supplier,
          'party_id': id,
          'amount_paisa': initialDebtPaisa,
          'device_id': deviceId,
          'device_timestamp':
              DateTime.fromMillisecondsSinceEpoch(now, isUtc: true)
                  .toIso8601String(),
        };

        await _db.into(_db.events).insert(EventsCompanion.insert(
              id: eventId,
              shopId: shopId,
              eventType: EventType.credit,
              partyType: PartyType.supplier,
              partyId: id,
              amountPaisa: initialDebtPaisa,
              deviceId: deviceId,
              deviceTimestamp: now,
              serverTimestamp: const Value(null),
              createdAt: now,
            ));

        await _db.into(_db.syncQueue).insert(SyncQueueCompanion.insert(
              eventId: eventId,
              status: const Value('PENDING'),
              payload: Value(jsonEncode(payloadMap)),
              createdAt: now,
            ));
      }
    });

    final created = await _suppliersDao.getSupplier(id);
    if (created == null) {
      throw StateError('createSupplier: row not found after insert (id=$id)');
    }
    return created;
  }

  /// Mark a supplier as paid and queue for sync.
  Future<void> markPaid(String supplierId, String shopId) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Get the current supplier to find the invoice amount
    final supplier = await _suppliersDao.getSupplier(supplierId);
    if (supplier == null) return;

    await _db.transaction(() async {
      await _suppliersDao.markPaidSupplier(supplierId);
      await _db.into(_db.syncQueue).insert(SyncQueueCompanion.insert(
            eventId: _uuid.v4(), // proper UUID — synthetic keys rejected by server
            status: const Value('PENDING'),
            payload: Value(jsonEncode({
              'action': 'MARK_SUPPLIER_PAID',
              'id': supplierId,
              'shop_id': shopId,
              'is_paid': true,
            })),
            createdAt: now,
          ));
    });
  }

  /// Soft-delete a supplier locally and queue for sync.
  Future<void> deleteSupplier(String supplierId, String shopId) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      await _suppliersDao.softDeleteSupplier(supplierId);
      await _db.into(_db.syncQueue).insert(SyncQueueCompanion.insert(
            eventId: _uuid.v4(), // proper UUID — synthetic keys rejected by server
            status: const Value('PENDING'),
            payload: Value(jsonEncode({
              'action': 'DELETE_SUPPLIER',
              'id': supplierId,
              'shop_id': shopId,
              'soft_delete': true,
            })),
            createdAt: now,
          ));
    });
  }

  /// Get a single supplier by id.
  Future<Supplier?> getSupplier(String supplierId) {
    return _suppliersDao.getSupplier(supplierId);
  }
}
