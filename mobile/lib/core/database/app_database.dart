import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'tables/events_table.dart';
import 'tables/customers_table.dart';
import 'tables/suppliers_table.dart';
import 'tables/sync_queue_table.dart';
import 'tables/shops_table.dart';
import 'tables/backups_table.dart';
import 'daos/events_dao.dart';

// Generated file — run: flutter pub run build_runner build
// ignore: uri_has_not_been_generated
part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Events,
    Customers,
    Suppliers,
    SyncQueue,
    Shops,
    Backups,
  ],
  daos: [EventsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Testing constructor — accepts any [QueryExecutor], e.g. NativeDatabase.memory().
  AppDatabase.forTesting(super.executor);

  @override
  // ignore: override_on_non_overriding_member
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'dukaan_dost.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
