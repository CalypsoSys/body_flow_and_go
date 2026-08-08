import 'package:path/path.dart' as path_package;
import 'package:sqflite/sqflite.dart' as sqlite;

import 'database_migrations.dart';

/// Lazily opens Body Flow & Go's private local SQLite database.
///
/// Tests can inject an FFI [sqlite.DatabaseFactory] and an in-memory or
/// temporary [path]. Production callers normally use the default constructor.
final class AppDatabase {
  AppDatabase({sqlite.DatabaseFactory? databaseFactory, String? path})
    : _databaseFactory = databaseFactory ?? sqlite.databaseFactory,
      _configuredPath = path;

  static const fileName = 'golog.sqlite';
  static const schemaVersion = AppDatabaseMigrations.currentVersion;

  final sqlite.DatabaseFactory _databaseFactory;
  final String? _configuredPath;
  Future<sqlite.Database>? _databaseFuture;

  Future<sqlite.Database> get database {
    return _databaseFuture ??= _open();
  }

  Future<String> get resolvedPath async {
    if (_configuredPath case final configuredPath?) {
      return configuredPath;
    }
    final databasesPath = await _databaseFactory.getDatabasesPath();
    return path_package.join(databasesPath, fileName);
  }

  Future<sqlite.Database> _open() async {
    final databasePath = await resolvedPath;
    return _databaseFactory.openDatabase(
      databasePath,
      options: sqlite.OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (database, version) {
          return AppDatabaseMigrations.migrate(
            database,
            fromVersion: 0,
            toVersion: version,
          );
        },
        onUpgrade: (database, oldVersion, newVersion) {
          return AppDatabaseMigrations.migrate(
            database,
            fromVersion: oldVersion,
            toVersion: newVersion,
          );
        },
      ),
    );
  }

  /// Closes an opened database. Calling close before open is harmless.
  Future<void> close() async {
    final databaseFuture = _databaseFuture;
    _databaseFuture = null;
    if (databaseFuture != null) {
      final openedDatabase = await databaseFuture;
      await openedDatabase.close();
    }
  }
}
