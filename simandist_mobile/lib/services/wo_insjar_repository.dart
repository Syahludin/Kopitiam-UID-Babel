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
    final rows = await db.query(table, orderBy: 'tanggal DESC, kode_wo DESC');
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
    await db.insert(table, values,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Nomor urut 3 digit per Kode ULP per tanggal.
  Future<String> buatKodeWo({
    required String kodeUlp,
    required DateTime tanggal,
  }) async {
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${two(tanggal.year % 100)}${two(tanggal.month)}${two(tanggal.day)}';
    final prefix = 'INSJAR-$kodeUlp$stamp';
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT kode_wo FROM $table WHERE kode_wo LIKE ? ORDER BY kode_wo DESC',
      ['$prefix%'],
    );
    var urutan = 0;
    for (final row in rows) {
      final kode = '${row['kode_wo'] ?? ''}';
      if (kode.length < prefix.length + 3) continue;
      final angka = int.tryParse(kode.substring(prefix.length)) ?? 0;
      if (angka > urutan) urutan = angka;
    }
    return '$prefix${(urutan + 1).toString().padLeft(3, '0')}';
  }

  /// Download WO dari spreadsheet. Kode WO yang sudah ada di lokal dilewati.
  Future<WoSyncResult> download(String token) async {
    final response = await ApiService.getWoInsjar(token);
    if (response['success'] != true || response['rows'] is! List) {
      return WoSyncResult(
        total: 0,
        diproses: 0,
        pesan: (response['message'] ?? 'Data WO tidak valid.').toString(),
      );
    }

    final rows = response['rows'] as List;
    final db = await _db.database;
    var ditambahkan = 0;

    await db.transaction((txn) async {
      for (final row in rows) {
        if (row is! Map) continue;
        final wo = WoInsjar.fromRemote(Map<String, dynamic>.from(row));
        if (wo.kodeWo.isEmpty) continue;

        final ada = await txn.query(
          table,
          columns: ['kode_wo'],
          where: 'kode_wo = ?',
          whereArgs: [wo.kodeWo],
          limit: 1,
        );
        if (ada.isNotEmpty) continue;

        await txn.insert(table, wo.toMap()..['synced_at'] = DateTime.now().toUtc().toIso8601String());
        ditambahkan++;
      }
    });

    return WoSyncResult(total: rows.length, diproses: ditambahkan);
  }

  /// Kirim WO lokal yang berubah ke spreadsheet, dicocokkan lewat Kode WO.
  Future<WoSyncResult> sinkron(String token) async {
    final pending = await belumTersinkron();
    if (pending.isEmpty) {
      return const WoSyncResult(total: 0, diproses: 0);
    }

    final payload = pending.map((wo) => wo.toRemote()).toList();
    final response = await ApiService.syncWoInsjar(token, payload);
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

  /// Daftar penyulang dari master data lokal.
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
      } catch (_) {
        continue;
      }
    }
    final list = hasil.toList()..sort();
    return list;
  }
}
