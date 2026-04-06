import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/customers_dao.dart';
import '../../../core/database/daos/events_dao.dart';
import '../models/customer_with_balance.dart';

/// Repository for Customers — CRUD + balance enrichment.
///
/// Iron Rules:
///   - Balances are computed by replaying the event log, never stored.
///   - All monetary amounts are integer paisa.
///   - Every create/update/delete also queues a SyncQueue entry (future STORY-013).
class CustomersRepository {
  CustomersRepository({
    required AppDatabase db,
    required CustomersDao customersDao,
    required EventsDao eventsDao,
  })  : _db = db,
        _customersDao = customersDao,
        _eventsDao = eventsDao;

  final AppDatabase _db;
  final CustomersDao _customersDao;
  final EventsDao _eventsDao;
  final _uuid = const Uuid();

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  /// Stream of all customers enriched with their computed balances.
  /// Auto-updates when either the Customers table or the Events table changes,
  /// using [Rx.combineLatest2] so a new CREDIT/PAYMENT immediately triggers
  /// a re-computation of all balances.
  Stream<List<CustomerWithBalance>> watchCustomersWithBalances(String shopId) {
    final customersStream = _customersDao.watchCustomers(shopId);
    final eventsStream = _eventsDao.watchShopEvents(shopId);

    return Rx.combineLatest2(
      customersStream,
      eventsStream,
      (List<Customer> customers, List<Event> _) => customers,
    ).asyncMap((customerList) async {
      final enriched = <CustomerWithBalance>[];
      for (final customer in customerList) {
        final balance = await _eventsDao.computeBalance(
          customer.id,
          'CUSTOMER',
        );
        final lastCreditTs = await _eventsDao.lastCreditTimestamp(
          customer.id,
          'CUSTOMER',
        );
        final lastActivityTs = await _eventsDao.lastActivityTimestamp(
          customer.id,
          'CUSTOMER',
        );

        int? daysOverdue;
        if (balance > 0 && lastCreditTs != null) {
          final lastCredit =
              DateTime.fromMillisecondsSinceEpoch(lastCreditTs);
          daysOverdue = DateTime.now().difference(lastCredit).inDays;
        }

        DateTime? lastActivityAt;
        if (lastActivityTs != null) {
          lastActivityAt =
              DateTime.fromMillisecondsSinceEpoch(lastActivityTs);
        }

        enriched.add(CustomerWithBalance(
          customer: customer,
          balancePaisa: balance,
          daysOverdue: daysOverdue,
          lastActivityAt: lastActivityAt,
        ));
      }
      return enriched;
    });
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Create a new customer locally and queue for sync.
  /// Atomic: inserts the customer row and SyncQueue entry in one transaction.
  Future<Customer> createCustomer({
    required String shopId,
    required String name,
    String? phone,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    final companion = CustomersCompanion.insert(
      id: id,
      shopId: shopId,
      name: name,
      phone: Value(phone),
      isFlagged: const Value(0),
      lastReminderAt: const Value(null),
      createdAt: now,
      updatedAt: now,
      isDeleted: const Value(0),
    );

    await _db.transaction(() async {
      await _customersDao.upsertCustomer(companion);
      await _db.into(_db.syncQueue).insert(SyncQueueCompanion.insert(
            eventId: id,
            status: const Value('PENDING'),
            payload: Value(jsonEncode({
              'action': 'CREATE_CUSTOMER',
              'id': id,
              'name': name,
              'phone': phone,
              'shop_id': shopId,
            })),
            createdAt: now,
          ));
    });

    // Read back the inserted row to return the full Customer object.
    // companion.build() gives us the typed row without a second DB roundtrip
    // risk — but getCustomer is safe here because the transaction above has
    // already committed, so the row is guaranteed to exist.
    final created = await _customersDao.getCustomer(id);
    if (created == null) {
      throw StateError('createCustomer: row not found after insert (id=$id)');
    }
    return created;
  }

  /// Update an existing customer locally and queue for sync.
  /// Atomic: updates the customer row and SyncQueue entry in one transaction.
  Future<void> updateCustomer({
    required String customerId,
    String? name,
    String? phone,
    int? isFlagged,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final companion = CustomersCompanion(
      id: Value(customerId),
      name: name != null ? Value(name) : const Value.absent(),
      phone: phone != null ? Value(phone) : const Value.absent(),
      isFlagged: isFlagged != null ? Value(isFlagged) : const Value.absent(),
      updatedAt: Value(now),
    );

    await _db.transaction(() async {
      await _customersDao.upsertCustomer(companion);
      await _db.into(_db.syncQueue).insert(SyncQueueCompanion.insert(
            eventId: _uuid.v4(), // proper UUID — synthetic keys rejected by server
            status: const Value('PENDING'),
            payload: Value(jsonEncode({
              'action': 'UPDATE_CUSTOMER',
              'id': customerId,
              if (name != null) 'name': name,
              if (phone != null) 'phone': phone,
              if (isFlagged != null) 'is_flagged': isFlagged,
            })),
            createdAt: now,
          ));
    });
  }

  /// Soft-delete a customer locally and queue for sync.
  /// Atomic: soft-deletes the customer row and SyncQueue entry in one transaction.
  Future<void> deleteCustomer(String customerId) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      await _customersDao.softDeleteCustomer(customerId);
      await _db.into(_db.syncQueue).insert(SyncQueueCompanion.insert(
            eventId: _uuid.v4(), // proper UUID — synthetic keys rejected by server
            status: const Value('PENDING'),
            payload: Value(jsonEncode({
              'action': 'DELETE_CUSTOMER',
              'id': customerId,
              'soft_delete': true,
            })),
            createdAt: now,
          ));
    });
  }

  /// Update the last-reminder timestamp for a customer to now.
  Future<void> updateLastReminderAt(String customerId) async {
    await _customersDao.updateLastReminderAt(
        customerId, DateTime.now().millisecondsSinceEpoch);
  }

  /// Get a single customer by id.
  Future<Customer?> getCustomer(String customerId) {
    return _customersDao.getCustomer(customerId);
  }
}
