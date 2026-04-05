import 'package:drift/drift.dart';
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
    required CustomersDao customersDao,
    required EventsDao eventsDao,
  })  : _customersDao = customersDao,
        _eventsDao = eventsDao;

  final CustomersDao _customersDao;
  final EventsDao _eventsDao;
  final _uuid = const Uuid();

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  /// Stream of all customers enriched with their computed balances.
  /// Auto-updates when either customers or events tables change.
  Stream<List<CustomerWithBalance>> watchCustomersWithBalances(String shopId) {
    return _customersDao.watchCustomers(shopId).asyncMap((customerList) async {
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

    await _customersDao.upsertCustomer(companion);

    // TODO(STORY-013): enqueue sync entry for customer creation.

    final created = await _customersDao.getCustomer(id);
    return created!;
  }

  /// Update an existing customer locally and queue for sync.
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
    await _customersDao.upsertCustomer(companion);

    // TODO(STORY-013): enqueue sync entry for customer update.
  }

  /// Soft-delete a customer locally and queue for sync.
  Future<void> deleteCustomer(String customerId) async {
    await _customersDao.softDeleteCustomer(customerId);

    // TODO(STORY-013): enqueue sync entry for customer deletion.
  }

  /// Get a single customer by id.
  Future<Customer?> getCustomer(String customerId) {
    return _customersDao.getCustomer(customerId);
  }
}
