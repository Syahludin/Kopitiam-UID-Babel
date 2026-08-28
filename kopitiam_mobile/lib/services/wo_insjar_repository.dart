import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/wo_insjar.dart';
import 'api_service.dart';
import 'sqlite_service.dart';

class WoSyncResult {
  final int total;
  final int diproses;
  final String? pesan;

  const WoSyncResult({
    required this.total,
    required this.diproses,
    this.pesan,
  });
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

  /// Hanya WO selesai yang boleh dikirim ke server.
  Future<List<WoInsjar>> belumTersinkron() async {
    final db = await _db.database;
    final rows = await db.query(
      table,
      where: 'is_dirty = 1 AND status_wo = ?',
      whereArgs: [WoInsjar.statusSelesai],
    );
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
    final selesai =
        WoInsjar.normalisasiStatus(wo.statusWo) == WoInsjar.statusSelesai;
    final values = wo.copyWith(isDirty: tandaiDirty && selesai).toMap()
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
      {'status_wo': WoInsjar.statusDalam, 'is_dirty': 0},
      where: 'kode_wo = ? AND status_wo = ?',
      whereArgs: [kodeWo, WoInsjar.statusMulai],
    );
  }

  /// Membentuk INSJAR-<Kode ULP><YYMMDD><NNN>.
  Future<String> buatKodeWo({
    required String kodeUlp,
    required DateTime tanggal,
  }) async {
    String two(int value) => value.toString().padLeft(2, '0');
    final datePart =
        '${two(tanggal.year % 100)}${two(tanggal.month)}${two(tanggal.day)}';
    final prefix = 'INSJAR-$kodeUlp$datePart';
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT kode_wo FROM $table WHERE kode_wo LIKE ? ORDER BY kode_wo DESC',
      ['$prefix%'],
    );

    var highest = 0;
    for (final row in rows) {
      final code = '${row['kode_wo'] ?? ''}';
      if (!code.startsWith(prefix)) continue;
      final sequence = int.tryParse(code.substring(prefix.length)) ?? 0;
      if (sequence > highest) highest = sequence;
    }
    return '$prefix${(highest + 1).toString().padLeft(3, '0')}';
  }

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
    var tersedia = 0;
    final syncTime = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      for (final row in rows) {
        if (row is! Map) continue;
        final remote = WoInsjar.fromRemote(Map<String, dynamic>.from(row));
        if (remote.kodeWo.isEmpty) continue;

        // WO yang sudah selesai di server tidak diunduh kembali setelah salinan
        // lokalnya dihapus oleh sinkronisasi sukses.
        if (WoInsjar.normalisasiStatus(remote.statusWo) ==
            WoInsjar.statusSelesai) {
          continue;
        }
        tersedia++;

        final existing = await txn.query(
          table,
          columns: ['kode_wo'],
          where: 'kode_wo = ?',
          whereArgs: [remote.kodeWo],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;

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
          'row_count': tersedia,
          'status': 'success',
          'error_message': '',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    return WoSyncResult(total: tersedia, diproses: ditambahkan);
  }

  Future<WoSyncResult> sinkron(String token) async {
    final pending = await belumTersinkron();
    if (pending.isEmpty) {
      return const WoSyncResult(
        total: 0,
        diproses: 0,
        pesan: 'Belum ada WO selesai yang siap disinkronkan.',
      );
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

    final processed =
        (response['diproses'] as num?)?.toInt() ?? pending.length;
    if (processed != pending.length) {
      return WoSyncResult(
        total: pending.length,
        diproses: processed,
        pesan:
            'Konfirmasi server tidak lengkap. Data lokal dipertahankan agar aman.',
      );
    }

    // Penghapusan hanya dilakukan setelah seluruh WO dikonfirmasi server.
    final db = await _db.database;
    await db.transaction((txn) async {
      for (final wo in pending) {
        await txn.delete(
          table,
          where: 'kode_wo = ? AND status_wo = ?',
          whereArgs: [wo.kodeWo, WoInsjar.statusSelesai],
        );
      }
    });

    return WoSyncResult(total: pending.length, diproses: processed);
  }

  Future<List<String>> daftarPenyulang() async {
    final db = await _db.database;
    final rows = await db.query(
      'master_data_rows',
      columns: ['payload_json'],
      where: 'dataset = ?',
      whereArgs: ['Master_Penyulang'],
    );
    final result = <String>{};
    for (final row in rows) {
      try {
        final payload = jsonDecode('${row['payload_json']}');
        if (payload is! Map) continue;
        for (final key in ['Nama Penyulang', 'Penyulang', 'nama_penyulang']) {
          final value = '${payload[key] ?? ''}'.trim();
          if (value.isNotEmpty) {
            result.add(value);
            break;
          }
        }
      } catch (_) {
        continue;
      }
    }
    return result.toList()..sort();
  }
}
