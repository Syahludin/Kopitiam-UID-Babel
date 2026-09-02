import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/temuan_inspeksi.dart';
import '../models/wo_insjar.dart';
import 'api_service.dart';
import 'photo_watermark_service.dart';
import 'sqlite_service.dart';

class TemuanRepository {
  static const int maxPhotoBytes = 5 * 1024 * 1024;
  final _db = SqliteService.instance;

  Future<Database> _database() async {
    final db = await _db.database;
    await db.execute('''CREATE TABLE IF NOT EXISTS temuan_inspeksi (
      kode_temuan TEXT PRIMARY KEY,
      kode_wo TEXT NOT NULL,
      kode_uiw TEXT DEFAULT '',
      kode_up3 TEXT DEFAULT '',
      kode_ulp TEXT DEFAULT '',
      ulp TEXT DEFAULT '',
      hari TEXT DEFAULT '',
      tanggal TEXT DEFAULT '',
      penyulang TEXT DEFAULT '',
      section_awal TEXT DEFAULT '',
      section_akhir TEXT DEFAULT '',
      section TEXT DEFAULT '',
      segmen TEXT DEFAULT '',
      nomor_gardu TEXT DEFAULT '',
      koordinat TEXT DEFAULT '',
      lat TEXT DEFAULT '',
      long TEXT DEFAULT '',
      jenis_object TEXT DEFAULT '',
      tier TEXT DEFAULT '',
      temuan TEXT DEFAULT '',
      jarak REAL,
      jenis_pohon TEXT DEFAULT '',
      tinggi_pohon REAL,
      prioritas TEXT DEFAULT '',
      pekerjaan TEXT DEFAULT '',
      jenis_wo TEXT DEFAULT '',
      foto_temuan TEXT DEFAULT '',
      foto_lingkungan TEXT DEFAULT '',
      link_foto TEXT DEFAULT '',
      link_lingkungan TEXT DEFAULT '',
      waktu_input TEXT DEFAULT '',
      user_input TEXT DEFAULT '',
      folder_path TEXT DEFAULT '',
      is_dirty INTEGER DEFAULT 1
    )''');
    return db;
  }

  Future<List<TemuanInspeksi>> untukWo(String kodeWo) async {
    final db = await _database();
    final rows = await db.query(
      'temuan_inspeksi',
      where: 'kode_wo = ?',
      whereArgs: [kodeWo],
      orderBy: 'kode_temuan',
    );
    return rows.map(TemuanInspeksi.fromMap).toList();
  }

  Future<String> kodeBaru(String kodeWo) async {
    final db = await _database();
    final rows = await db.rawQuery(
      'SELECT kode_temuan FROM temuan_inspeksi WHERE kode_wo = ? '
      'ORDER BY kode_temuan DESC LIMIT 1',
      [kodeWo],
    );
    var number = 0;
    if (rows.isNotEmpty) {
      number = int.tryParse('${rows.first['kode_temuan']}'.split('.TO-').last) ?? 0;
    }
    return '$kodeWo.TO-${(number + 1).toString().padLeft(3, '0')}';
  }

  Future<void> simpan(TemuanInspeksi item) async {
    if (item.fotoTemuan.isEmpty || item.fotoLingkungan.isEmpty) {
      throw StateError('Foto Temuan dan Foto Sekitar Tiang wajib diambil.');
    }
    final watermarkedPrimary = _sudahWatermark(item.fotoTemuan)
        ? item.fotoTemuan
        : await PhotoWatermarkService.render(
            sourcePath: item.fotoTemuan,
            item: item,
            photoLabel: 'Foto Temuan',
          );
    final watermarkedEnvironment = _sudahWatermark(item.fotoLingkungan)
        ? item.fotoLingkungan
        : await PhotoWatermarkService.render(
            sourcePath: item.fotoLingkungan,
            item: item,
            photoLabel: 'Foto Lingkungan',
          );
    final primary = await _persistPhoto(
      watermarkedPrimary,
      item.kodeTemuan,
      'Foto Temuan',
    );
    final environment = await _persistPhoto(
      watermarkedEnvironment,
      item.kodeTemuan,
      'Foto Lingkungan',
    );
    final stored = _withPhotos(item, primary.path, environment.path);
    final db = await _database();
    await db.insert(
      'temuan_inspeksi',
      stored.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<File> _persistPhoto(
    String sourcePath,
    String findingCode,
    String label,
  ) async {
    final source = File(sourcePath);
    await _validatePhoto(source);
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory(
      p.join(root.path, 'temuan_photos', _safeName(findingCode)),
    );
    await folder.create(recursive: true);

    final originalName = p.basename(source.path);
    final timestampMatch = RegExp(r'(\d{6})(?=\.jpe?g$)', caseSensitive: false)
        .firstMatch(originalName);
    final stamp = timestampMatch?.group(1) ??
        DateTime.now()
            .toIso8601String()
            .replaceAll(RegExp(r'[^0-9]'), '')
            .substring(8, 14);
    final filename = '${_safeName(findingCode)}.$label.$stamp.jpg';
    final destination = File(p.join(folder.path, filename));
    if (p.equals(source.path, destination.path)) return source;
    return source.copy(destination.path);
  }

  Future<void> _validatePhoto(File file) async {
    if (!await file.exists()) {
      throw StateError('File foto tidak ditemukan. Ambil ulang foto.');
    }
    final length = await file.length();
    if (length <= 0 || length > maxPhotoBytes) {
      throw StateError('Ukuran foto harus lebih kecil dari 5 MB.');
    }
    final header = await file.openRead(0, 3).fold<List<int>>(
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
  }

  String _safeName(String value) => value.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]'),
        '_',
      );

  bool _sudahWatermark(String path) => path.endsWith('_wm.jpg');

  TemuanInspeksi _withPhotos(
    TemuanInspeksi item,
    String primary,
    String environment,
  ) {
    return TemuanInspeksi(
      kodeTemuan: item.kodeTemuan,
      kodeWo: item.kodeWo,
      kodeUiw: item.kodeUiw,
      kodeUp3: item.kodeUp3,
      kodeUlp: item.kodeUlp,
      ulp: item.ulp,
      hari: item.hari,
      tanggal: item.tanggal,
      penyulang: item.penyulang,
      sectionAwal: item.sectionAwal,
      sectionAkhir: item.sectionAkhir,
      section: item.section,
      segmen: item.segmen,
      nomorGardu: item.nomorGardu,
      koordinat: item.koordinat,
      lat: item.lat,
      long: item.long,
      jenisObject: item.jenisObject,
      tier: item.tier,
      temuan: item.temuan,
      jarak: item.jarak,
      jenisPohon: item.jenisPohon,
      tinggiPohon: item.tinggiPohon,
      prioritas: item.prioritas,
      pekerjaan: item.pekerjaan,
      jenisWo: item.jenisWo,
      fotoTemuan: primary,
      fotoLingkungan: environment,
      linkFoto: item.linkFoto,
      linkLingkungan: item.linkLingkungan,
      waktuInput: item.waktuInput,
      userInput: item.userInput,
      folderPath: item.folderPath,
      dirty: true,
    );
  }

  Future<void> unduh(String token, String kodeWo) async {
    final response = await ApiService.getTemuan(token, kodeWo);
    if (response['success'] != true || response['rows'] is! List) return;
    final db = await _database();
    for (final row in response['rows'] as List) {
      if (row is Map) {
        await db.insert(
          'temuan_inspeksi',
          TemuanInspeksi.fromRemote(Map<String, dynamic>.from(row)).toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }

  Future<void> sinkron(String token) async {
    final db = await _database();
    final rows = await db.query('temuan_inspeksi', where: 'is_dirty = 1');
    for (final row in rows) {
      final item = TemuanInspeksi.fromMap(row);
      if (item.fotoTemuan.isEmpty || item.fotoLingkungan.isEmpty) {
        throw StateError(
          '${item.kodeTemuan}: kedua foto wajib tersedia sebelum sinkron.',
        );
      }
      final primary = File(item.fotoTemuan);
      final environment = File(item.fotoLingkungan);
      await _validatePhoto(primary);
      await _validatePhoto(environment);

      final payload = item.toRemote()
        ..['Foto Temuan'] = p.basename(primary.path)
        ..['Foto Lingkungan Sekitaran Tiang'] = p.basename(environment.path)
        ..['fotoTemuanBase64'] = base64Encode(await primary.readAsBytes())
        ..['fotoLingkunganBase64'] =
            base64Encode(await environment.readAsBytes());
      final response = await ApiService.syncTemuan(token, payload);
      if (response['success'] == true) {
        await db.update(
          'temuan_inspeksi',
          {
            'is_dirty': 0,
            'link_foto': '${response['linkFoto'] ?? ''}',
            'link_lingkungan': '${response['linkLingkungan'] ?? ''}',
            'folder_path': '${response['folderPath'] ?? item.folderPath}',
          },
          where: 'kode_temuan = ?',
          whereArgs: [item.kodeTemuan],
        );
      } else {
        final kode = '${response['kode'] ?? ''}';
        final message =
            (response['message'] ?? 'Sinkronisasi foto gagal.').toString();
        if (kode.startsWith('SESSION_')) {
          throw StateError(
            'Sesi tidak valid atau sudah berakhir. Silakan login ulang. [$kode]',
          );
        }
        throw StateError(
          message.isEmpty
              ? 'Sinkronisasi foto gagal. [$kode]'
              : '$message [$kode]',
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> master(String dataset) async {
    final db = await _database();
    final rows = await db.query(
      'master_data_rows',
      columns: ['payload_json'],
      where: 'dataset = ?',
      whereArgs: [dataset],
    );
    return rows
        .map(
          (row) => Map<String, dynamic>.from(
            jsonDecode('${row['payload_json']}'),
          ),
        )
        .toList();
  }

  String jenisObject(Map<String, dynamic> sesi) {
    final value = '${sesi['subTim'] ?? sesi['tim'] ?? ''}'.toLowerCase();
    if (value.contains('inspeksi jaringan') || value.contains('insjar')) {
      return 'Jaringan';
    }
    if (value.contains('inspeksi gardu') || value.contains('insdu')) {
      return 'Gardu';
    }
    return '';
  }

  static final _vegetasiPatterns = [
    RegExp(r'^(Rabas|Pangkas).*?\s*/\s*(Rabas|Pangkas)$', caseSensitive: false),
    RegExp(r'^Tebang\s+Sedang$', caseSensitive: false),
    RegExp(r'^Tebang\s+Besar$', caseSensitive: false),
  ];

  bool _isVegetasi(String temuan) => _vegetasiPatterns
      .any((pattern) => pattern.hasMatch(temuan.trim()));

  String prioritas(
    String temuan,
    double? jarak,
    double? tinggi,
    List<Map<String, dynamic>> master,
  ) {
    if (_isVegetasi(temuan)) {
      final distance = jarak ?? 0;
      final height = tinggi ?? 0;
      if (height < 9) return distance > 5 ? 'Minor' : 'Mayor';
      if (distance < 3) return 'Mayor';
      if (distance < 6) return 'Sedang';
      return 'Minor';
    }
    for (final row in master) {
      final nama = _cari(row, const ['Temuan', 'Nama Temuan']);
      if (nama.isNotEmpty && _sama(nama, temuan)) {
        return _cari(row, const ['Prioritas']);
      }
    }
    return '';
  }

  static String _cari(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = '${row[key] ?? ''}'.trim();
      if (value.isNotEmpty) return value;
    }
    String normal(String key) =>
        key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final normalized = keys.map(normal).toSet();
    for (final entry in row.entries) {
      if (normalized.contains(normal(entry.key)) &&
          '${entry.value ?? ''}'.trim().isNotEmpty) {
        return '${entry.value ?? ''}'.trim();
      }
    }
    return '';
  }

  static bool _sama(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  static String folder(
    WoInsjar wo,
    String object,
    String code,
    DateTime now,
  ) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return 'Kopitiam/Rekap Temuan Inspeksi/${wo.kodeUlp}/$object/'
        '${now.year}/${now.month.toString().padLeft(2, '0')}. '
        '${months[now.month - 1]}/${now.day.toString().padLeft(2, '0')}/'
        '${wo.kodeWo}/$code/';
  }
}
