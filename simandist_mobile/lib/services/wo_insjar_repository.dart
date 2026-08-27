import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/wo_insjar.dart';
import 'api_service.dart';
import 'sqlite_service.dart';

class WoSyncResult {
  final int total;
  final int diproses;
  final String? pesan;
  const WoSyncResult({required this.total, required this.diproses, this.pesan});
}

class WoInsjarRepository {
  WoInsjarRepository({SqliteService? database})
      : _db = database ?? SqliteService.instance;

  final SqliteService _db;
  static const table = 'wo_insjar';

  Future<List<WoInsjar>> semua() async {
    final db = await _db.database;
    final rows = await db.query(
      table,
      orderBy:
          "CASE status_wo WHEN '${WoInsjar.statusMulai}' THEN 0 WHEN '${WoInsjar.statusDalam}' THEN 1 ELSE 2 END, tanggal DESC, kode_wo DESC",
    );
    return rows.map(WoInsjar.fromMap).toList();
  }

  Future<List<WoInsjar>> belumTersinkron() async {
    final db = await _db.database;
    final rows = await db.query(table, where: 'is_dirty = 1');
    return rows.map(WoInsjar.fromMap).toList();
  }

  Future<WoInsjar?> cariKode(String kodeWo) async {
    final db = await _db.database;
    final rows = await db.query(
      table,
      where: 'kode_wo = ?',
      whereArgs: [kodeWo],
      limit: 1,
    );
    return rows.isEmpty ? null : WoInsjar.fromMap(rows.first);
  }

  Future<void> simpan(WoInsjar wo, {bool tandaiDirty = true}) async {
    final db = await _db.database;
    final values = wo.copyWith(isDirty: tandaiDirty).toMap()
      ..['synced_at'] = DateTime.now().toUtc().toIso8601String();
    await db.insert(
      table,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> mulaiPengerjaan(String kodeWo) async {
    final db = await _db.database;
    await db.update(
      table,
      {'status_wo': WoInsjar.statusDalam, 'is_dirty': 1},
      where: 'kode_wo = ? AND status_wo = ?',
      whereArgs: [kodeWo, WoInsjar.statusMulai],
    );
  }

  /// Membuka database sebelum request API memastikan tabel wo_insjar selalu
  /// dibangun ketika pengguna menekan Download WO, termasuk pada unduhan pertama.
  Future<WoSyncResult> download(String token) async {
    final db = await _db.database;
    final response = await ApiService.getWoInsjar(token);
    if (response['success'] != true || response['rows'] is! List) {
      return WoSyncResult(
        total: 0,
        diproses: 0,
        pesan: (response['message'] ?? 'Data WO tidak valid.').toString(),
      );
    }

    final rows = response['rows'] as List;
    var ditambahkan = 0;
    final syncTime = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      for (final row in rows) {
        if (row is! Map) continue;
        final remote = WoInsjar.fromRemote(Map<String, dynamic>.from(row));
        if (remote.kodeWo.isEmpty) continue;

        final ada = await txn.query(
          table,
          columns: ['kode_wo'],
          where: 'kode_wo = ?',
          whereArgs: [remote.kodeWo],
          limit: 1,
        );
        if (ada.isNotEmpty) continue;

        final values = remote
            .copyWith(statusWo: WoInsjar.normalisasiStatus(remote.statusWo))
            .toMap()
          ..['synced_at'] = syncTime
          ..['is_dirty'] = 0;
        await txn.insert(table, values);
        ditambahkan++;
      }

      await txn.insert(
        'sync_metadata',
        {
          'key': 'WO_Ins_Jar',
          'synced_at': syncTime,
          'row_count': rows.length,
          'status': 'success',
          'error_message': '',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    return WoSyncResult(total: rows.length, diproses: ditambahkan);
  }

  Future<WoSyncResult> sinkron(String token) async {
    final pending = await belumTersinkron();
    if (pending.isEmpty) {
      return const WoSyncResult(total: 0, diproses: 0);
    }

    final response = await ApiService.syncWoInsjar(
      token,
      pending.map((wo) => wo.toRemote()).toList(),
    );
    if (response['success'] != true) {
      return WoSyncResult(
        total: pending.length,
        diproses: 0,
        pesan: (response['message'] ?? 'Sinkronisasi WO gagal.').toString(),
      );
    }

    final db = await _db.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      for (final wo in pending) {
        await txn.update(
          table,
          {'is_dirty': 0, 'synced_at': now},
          where: 'kode_wo = ?',
          whereArgs: [wo.kodeWo],
        );
      }
    });

    final terkirim = (response['diproses'] as num?)?.toInt() ?? pending.length;
    return WoSyncResult(total: pending.length, diproses: terkirim);
  }

  Future<List<String>> daftarPenyulang() async {
    final db = await _db.database;
    final rows = await db.query(
      'master_data_rows',
      columns: ['payload_json'],
      where: 'dataset = ?',
      whereArgs: ['Master_Penyulang'],
    );
    final hasil = <String>{};
    for (final row in rows) {
      try {
        final payload = jsonDecode('${row['payload_json']}');
        if (payload is! Map) continue;
        for (final key in ['Nama Penyulang', 'Penyulang', 'nama_penyulang']) {
          final value = '${payload[key] ?? ''}'.trim();
          if (value.isNotEmpty) {
            hasil.add(value);
            break;
          }
        }
      } catch (_) {}
    }
    return hasil.toList()..sort();
  }
}
