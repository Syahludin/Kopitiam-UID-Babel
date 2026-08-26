import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/local_user.dart';

/// Database SQLite lokal untuk profil User_App_Mobile dan metadata sinkronisasi.
/// Password asli tidak pernah masuk database ini.
class SqliteService {
  SqliteService._();
  static final SqliteService instance = SqliteService._();

  static const _databaseName = 'simandist_local.db';
  static const _databaseVersion = 1;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final root = await getDatabasesPath();
    _database = await openDatabase(
      p.join(root, _databaseName),
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Tambahkan migrasi bernomor di sini saat schema berubah.
      },
    );
    return _database!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE user_app_mobile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_no TEXT NOT NULL,
        kode_uiw TEXT NOT NULL DEFAULT '',
        kode_up3 TEXT NOT NULL DEFAULT '',
        kode_ulp TEXT NOT NULL DEFAULT '',
        ulp TEXT NOT NULL DEFAULT '',
        username TEXT NOT NULL COLLATE NOCASE UNIQUE,
        password_hash TEXT NOT NULL,
        password_salt TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT '',
        bidang TEXT NOT NULL DEFAULT '',
        tim TEXT NOT NULL DEFAULT '',
        sub_tim TEXT NOT NULL DEFAULT '',
        akses_menu TEXT NOT NULL DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1,
        source_updated_at TEXT,
        synced_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_user_username ON user_app_mobile(username COLLATE NOCASE)');
    await db.execute('CREATE INDEX idx_user_unit ON user_app_mobile(kode_ulp, ulp)');
    await db.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        remote_revision TEXT NOT NULL DEFAULT '',
        synced_at TEXT,
        row_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'idle',
        error_message TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.insert('sync_metadata', {'key': 'User_App_Mobile', 'status': 'idle'});
  }

  Future<void> upsertUsers(Iterable<LocalUser> users) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final user in users) {
        final values = user.toMap();
        values.remove('id');
        values['updated_at'] = now;
        values['created_at'] = now;
        batch.insert(
          'user_app_mobile',
          values,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      await txn.insert(
        'sync_metadata',
        {
          'key': 'User_App_Mobile',
          'synced_at': now,
          'row_count': users.length,
          'status': 'success',
          'error_message': '',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<LocalUser?> findUser(String username) async {
    final db = await database;
    final rows = await db.query(
      'user_app_mobile',
      where: 'username = ? AND is_active = 1',
      whereArgs: [username.trim().toLowerCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromMap(rows.first);
  }

  Future<List<LocalUser>> allUsers() async {
    final db = await database;
    final rows = await db.query('user_app_mobile', orderBy: 'username COLLATE NOCASE');
    return rows.map(_fromMap).toList();
  }

  Future<bool> hasUsers() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM user_app_mobile');
    return ((result.first['total'] as int?) ?? 0) > 0;
  }

  Future<Map<String, Object?>?> syncInfo(String key) async {
    final db = await database;
    final rows = await db.query('sync_metadata', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> markSyncError(String key, Object error) async {
    final db = await database;
    await db.insert(
      'sync_metadata',
      {'key': key, 'status': 'error', 'error_message': error.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  LocalUser _fromMap(Map<String, Object?> row) => LocalUser(
        id: row['id'] as int?,
        remoteNo: '${row['remote_no'] ?? ''}',
        kodeUiw: '${row['kode_uiw'] ?? ''}',
        kodeUp3: '${row['kode_up3'] ?? ''}',
        kodeUlp: '${row['kode_ulp'] ?? ''}',
        ulp: '${row['ulp'] ?? ''}',
        username: '${row['username'] ?? ''}',
        passwordHash: '${row['password_hash'] ?? ''}',
        passwordSalt: '${row['password_salt'] ?? ''}',
        role: '${row['role'] ?? ''}',
        bidang: '${row['bidang'] ?? ''}',
        tim: '${row['tim'] ?? ''}',
        subTim: '${row['sub_tim'] ?? ''}',
        aksesMenu: '${row['akses_menu'] ?? ''}',
        isActive: row['is_active'] == 1,
        sourceUpdatedAt: row['source_updated_at']?.toString(),
        syncedAt: '${row['synced_at'] ?? ''}',
      );
}
