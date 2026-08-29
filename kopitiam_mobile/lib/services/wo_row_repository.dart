import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/temuan_inspeksi.dart';
import '../models/wo_row.dart';
import 'api_service.dart';
import 'photo_watermark_service.dart';
import 'sqlite_service.dart';
import 'wo_insjar_repository.dart' show WoSyncResult;

class WoRowRepository {
  static const int maxPhotoBytes = 5 * 1024 * 1024;
  final _db = SqliteService.instance;

  Future<Database> _database() async => _db.database;

  Future<List<WoRow>> semua() async {
    final db = await _database();
    final rows = await db.rawQuery(
      "SELECT * FROM wo_row "
      "ORDER BY CASE status_wo "
      "WHEN 'Penugasan Tim' THEN 0 "
      "WHEN 'Progress Pekerjaan' THEN 1 "
      "ELSE 2 END, kode_wo DESC",
    );
    return rows.map(WoRow.fromMap).toList();
  }

  Future<int> jumlahDirty() async {
    final db = await _database();
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM wo_row "
      "WHERE is_dirty = 1 AND status_wo = 'Selesai'",
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<WoRow?> cari(String kodeWo) async {
    final db = await _database();
    final rows = await db.query(
      'wo_row',
      where: 'kode_wo = ?',
      whereArgs: [kodeWo],
      limit: 1,
    );
    return rows.isEmpty ? null : WoRow.fromMap(rows.first);
  }

  Future<WoSyncResult> download(String token) async {
    final response = await ApiService.getWoRow(token);
    final pendingList = response['rows'];
    if (response['success'] != true || pendingList is! List) {
      return WoSyncResult(
        total: 0,
        diproses: 0,
        pesan: (response['message'] ?? 'Download ROW gagal.').toString(),
      );
    }
    final db = await _database();
    final now = DateTime.now().toUtc().toIso8601String();
    var added = 0;
    await db.transaction((txn) async {
      for (final row in pendingList) {
        if (row is! Map) continue;
        final item = WoRow.fromRemote(Map<String, dynamic>.from(row));
        if (WoRow.normalisasiStatus(item.statusWo) == WoRow.statusSelesai) {
          continue;
        }
        final inserted = await txn.insert(
          'wo_row',
          item.toMap()..['synced_at'] = now,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (inserted > 0) added++;
      }
      await txn.insert(
        'sync_metadata',
        {
          'key': 'WO_ROW',
          'synced_at': now,
          'row_count': added,
          'status': 'success',
          'error_message': '',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    return WoSyncResult(total: added, diproses: added);
  }

  Future<void> mulaiPekerjaan(String kodeWo) async {
    final db = await _database();
    await db.update(
      'wo_row',
      {'status_wo': WoRow.statusProgress, 'is_dirty': 0},
      where: 'kode_wo = ?',
      whereArgs: [kodeWo],
    );
  }

  Future<void> simpan(WoRow item) async {
    if (item.fotoSesudah.isEmpty) {
      throw StateError('Foto Sesudah wajib diambil.');
    }
    final watermarked = item.fotoSesudah.endsWith('_wm.jpg')
        ? item.fotoSesudah
        : await PhotoWatermarkService.render(
            sourcePath: item.fotoSesudah,
            item: _watermarkItem(item),
            photoLabel: 'Foto Sesudah',
          );
    final photoPath = await _persistPhoto(watermarked, item.kodeWo);
    final stored =
        item.copyWith(fotoSesudah: photoPath.path, isDirty: true);
    final db = await _database();
    await db.insert(
      'wo_row',
      stored.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<File> _persistPhoto(String sourcePath, String kodeWo) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError('File foto tidak ditemukan. Ambil ulang foto.');
    }
    final length = await source.length();
    if (length <= 0 || length > maxPhotoBytes) {
      throw StateError('Ukuran foto harus lebih kecil dari 5 MB.');
    }
    final header = await source.openRead(0, 3).fold<List<int>>(
      <int>[],
      (bytes, chunk) => bytes..addAll(chunk),
    );
    final isJpeg = header.length >= 3 &&
        header[0] == 0xFF &&
        header[1] == 0xD8 &&
        header[2] == 0xFF;
    if (!isJpeg) {
      throw StateError('Format foto tidak valid. Gunakan kamera aplikasi.');
    }
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory(
      p.join(root.path, 'row_photos', _safeName(kodeWo)),
    );
    await folder.create(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(8, 14);
    final filename = '${_safeName(kodeWo)}.Foto Sesudah.$stamp.jpg';
    final destination = File(p.join(folder.path, filename));
    return source.copy(destination.path);
  }

  TemuanInspeksi _watermarkItem(WoRow item) => TemuanInspeksi(
        kodeTemuan: item.kodeTemuan,
        kodeWo: item.kodeWo,
        temuan: item.temuan,
        jenisObject: item.jenisObject,
        koordinat: item.koordinat,
        ulp: item.ulp,
        penyulang: item.penyulang,
        section: item.section,
        segmen: item.segmen,
        hari: item.hari,
        tanggal: item.tanggal,
        waktuInput: item.waktuInput,
      );

  String _safeName(String value) => value.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]'),
        '_',
      );

  Future<WoSyncResult> sinkron(String token) async {
    final db = await _database();
    final rows = await db.query(
      'wo_row',
      where: "is_dirty = 1 AND status_wo = '${WoRow.statusSelesai}'",
    );
    if (rows.isEmpty) {
      return const WoSyncResult(
        total: 0,
        diproses: 0,
        pesan: 'Belum ada ROW selesai yang siap disinkronkan.',
      );
    }
    final payload = <Map<String, dynamic>>[];
    for (final row in rows) {
      final item = WoRow.fromMap(row);
      final photo = File(item.fotoSesudah);
      if (!await photo.exists()) {
        throw StateError(
          '${item.kodeWo}: Foto Sesudah tidak tersedia sebelum sinkron.',
        );
      }
      payload.add(
        item.toRemote()
          ..['Foto Sesudah'] = p.basename(photo.path)
          ..['fotoSesudahBase64'] =
              base64Encode(await photo.readAsBytes()),
        );
    }
    final response = await ApiService.syncWoRow(token, payload);
    if (response['success'] != true) {
      return WoSyncResult(
        total: payload.length,
        diproses: 0,
        pesan: (response['message'] ?? 'Sinkronisasi ROW gagal.').toString(),
      );
    }
    final processed = (response['diproses'] as num?)?.toInt() ?? payload.length;
    if (processed == payload.length) {
      final batch = db.batch();
      for (final row in rows) {
        batch.delete(
          'wo_row',
          where: 'kode_wo = ?',
          whereArgs: [row['kode_wo']],
        );
      }
      await batch.commit(noResult: true);
    }
    return WoSyncResult(total: payload.length, diproses: processed);
  }
}
