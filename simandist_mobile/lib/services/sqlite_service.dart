import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/local_user.dart';

class SqliteService {
  SqliteService._();
  static final SqliteService instance = SqliteService._();
  static const _databaseName = 'simandist_local.db';
  static const _databaseVersion = 2;
  static const masterDatasets = ['User_App_Mobile', 'Master_Penyulang', 'Master_Keypoint', 'Listr_Temuan', 'Jenis Pohon'];
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final root = await getDatabasesPath();
    _database = await openDatabase(p.join(root, _databaseName), version: _databaseVersion, onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'), onCreate: (db, version) async => _createSchema(db), onUpgrade: (db, oldVersion, newVersion) async { if (oldVersion < 2) await _createMasterSchema(db); });
    return _database!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''CREATE TABLE user_app_mobile (id INTEGER PRIMARY KEY AUTOINCREMENT, remote_no TEXT NOT NULL, kode_uiw TEXT NOT NULL DEFAULT '', kode_up3 TEXT NOT NULL DEFAULT '', kode_ulp TEXT NOT NULL DEFAULT '', ulp TEXT NOT NULL DEFAULT '', username TEXT NOT NULL COLLATE NOCASE UNIQUE, password_hash TEXT NOT NULL, password_salt TEXT NOT NULL, role TEXT NOT NULL DEFAULT '', bidang TEXT NOT NULL DEFAULT '', tim TEXT NOT NULL DEFAULT '', sub_tim TEXT NOT NULL DEFAULT '', akses_menu TEXT NOT NULL DEFAULT '', is_active INTEGER NOT NULL DEFAULT 1, source_updated_at TEXT, synced_at TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE sync_metadata (key TEXT PRIMARY KEY, remote_revision TEXT NOT NULL DEFAULT '', synced_at TEXT, row_count INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'idle', error_message TEXT NOT NULL DEFAULT '')''');
    await _createMasterSchema(db);
  }

  Future<void> _createMasterSchema(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS master_data_rows (id INTEGER PRIMARY KEY AUTOINCREMENT, dataset TEXT NOT NULL, row_key TEXT NOT NULL, payload_json TEXT NOT NULL, synced_at TEXT NOT NULL, UNIQUE(dataset,row_key))''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_master_dataset ON master_data_rows(dataset)');
  }

  Future<void> replaceMasterData(Map<String, dynamic> datasets) async {
    for (final name in masterDatasets) {
      if (!datasets.containsKey(name) || datasets[name] is! List) throw StateError('Dataset tidak lengkap: $name');
    }
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      for (final name in masterDatasets) {
        final rows = datasets[name] as List;
        await txn.delete('master_data_rows', where: 'dataset = ?', whereArgs: [name]);
        final batch = txn.batch();
        for (var index = 0; index < rows.length; index++) {
          final row = rows[index];
          if (row is! Map) continue;
          final payload = Map<String, dynamic>.from(row);
          batch.insert('master_data_rows', {'dataset': name, 'row_key': _rowKey(payload, index), 'payload_json': jsonEncode(payload), 'synced_at': now}, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
        await txn.insert('sync_metadata', {'key': name, 'synced_at': now, 'row_count': rows.length, 'status': 'success', 'error_message': ''}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  String _rowKey(Map<String, dynamic> row, int index) {
    for (final key in ['No', 'ID', 'Kode', 'Username', 'username', 'Kode Penyulang', 'Kode Keypoint']) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return index.toString();
  }

  Future<bool> hasMasterData() async {
    final db = await database;
    final placeholders = List.filled(masterDatasets.length, '?').join(',');
    final rows = await db.rawQuery("SELECT COUNT(*) AS total FROM sync_metadata WHERE status = 'success' AND key IN ($placeholders)", masterDatasets);
    return ((rows.first['total'] as int?) ?? 0) == masterDatasets.length;
  }

  Future<DateTime?> lastMasterSync() async {
    final db = await database;
    final placeholders = List.filled(masterDatasets.length, '?').join(',');
    final rows = await db.rawQuery("SELECT MAX(synced_at) AS value FROM sync_metadata WHERE status = 'success' AND key IN ($placeholders)", masterDatasets);
    final value = rows.first['value']?.toString();
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }

  Future<void> upsertUsers(Iterable<LocalUser> users) async { final list=users.toList(growable:false),db=await database,now=DateTime.now().toUtc().toIso8601String();await db.transaction((txn)async{final batch=txn.batch();for(final user in list){final values=user.toMap()..remove('id');values['updated_at']=now;values['created_at']=now;batch.insert('user_app_mobile',values,conflictAlgorithm:ConflictAlgorithm.replace);}await batch.commit(noResult:true);}); }
  Future<LocalUser?> findUser(String username) async { final db=await database;final rows=await db.query('user_app_mobile',where:'username = ? AND is_active = 1',whereArgs:[username.trim().toLowerCase()],limit:1);return rows.isEmpty?null:_fromMap(rows.first); }
  Future<bool> hasUsers() async { final db=await database;final result=await db.rawQuery('SELECT COUNT(*) AS total FROM user_app_mobile');return ((result.first['total'] as int?)??0)>0; }
  Future<void> close() async { await _database?.close();_database=null; }
  LocalUser _fromMap(Map<String,Object?> row)=>LocalUser(id:row['id'] as int?,remoteNo:'${row['remote_no']??''}',kodeUiw:'${row['kode_uiw']??''}',kodeUp3:'${row['kode_up3']??''}',kodeUlp:'${row['kode_ulp']??''}',ulp:'${row['ulp']??''}',username:'${row['username']??''}',passwordHash:'${row['password_hash']??''}',passwordSalt:'${row['password_salt']??''}',role:'${row['role']??''}',bidang:'${row['bidang']??''}',tim:'${row['tim']??''}',subTim:'${row['sub_tim']??''}',aksesMenu:'${row['akses_menu']??''}',isActive:row['is_active']==1,sourceUpdatedAt:row['source_updated_at']?.toString(),syncedAt:'${row['synced_at']??''}');
}
