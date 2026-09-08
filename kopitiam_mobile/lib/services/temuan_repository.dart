import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/temuan_inspeksi.dart';
import '../models/c4a_selection.dart';
import '../models/wo_insjar.dart';
import 'api_service.dart';
import 'c4a_numbering.dart';
import 'photo_watermark_service.dart';
import 'sqlite_service.dart';

class TemuanRepository {
  static const int maxPhotoBytes = 5 * 1024 * 1024;
  final _db = SqliteService.instance;
  final Database? database;
  TemuanRepository({this.database});

  Future<Database> _database() async {
    final db = database ?? await _db.database;
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
      number =
          int.tryParse('${rows.first['kode_temuan']}'.split('.TO-').last) ?? 0;
    }
    return '$kodeWo.TO-${(number + 1).toString().padLeft(3, '0')}';
  }

  Future<void> simpan(TemuanInspeksi item) async {
    if (item.kodeWo.isEmpty) {
      throw StateError('Gunakan simpanC4a untuk temuan tanpa WO.');
    }
    final stored = await _preparePhotos(item);
    final db = await _database();
    await db.insert(
      'temuan_inspeksi',
      stored.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Atomik pada SQLite perangkat: satu simpan berhasil = satu nomor harian + TO.
  /// Tidak mengalokasikan WO dan tidak mengirim data ke pusat.
  Future<TemuanInspeksi> simpanC4a(
    TemuanInspeksi draft, {
    DateTime? savedAt,
  }) async {
    validateC4a(draft);
    await _validatePhoto(File(draft.fotoTemuan));
    await _validatePhoto(File(draft.fotoLingkungan));
    for (final path in [draft.fotoTemuan, draft.fotoLingkungan]) {
      final decoded = img.decodeJpg(await File(path).readAsBytes());
      if (decoded == null || decoded.width <= decoded.height) {
        throw StateError('Foto C4A harus JPEG landscape dari kamera aplikasi.');
      }
    }
    final db = await _database();
    return db.transaction((txn) async {
      final now = savedAt ?? DateTime.now();
      final rows = (await txn.query(
        'temuan_inspeksi',
        where: "kode_wo = '' AND kode_ulp = ?",
        whereArgs: [draft.kodeUlp],
      )).map(TemuanInspeksi.fromMap).toList();
      final code = C4aNumbering.code(
        draft.kodeUlp,
        now,
        C4aNumbering.nextDaily(rows, draft.kodeUlp, draft.penyulang, now),
        C4aNumbering.nextTo(rows, draft.kodeUlp),
      );
      final item = TemuanInspeksi.fromMap({
        ...draft.toMap(),
        'kode_temuan': code,
        'hari': WoInsjar.hariIndonesia[now.weekday - 1],
        'tanggal': WoInsjar.formatTanggal(now),
        'waktu_input': WoInsjar.stampLengkap(now),
        'folder_path': folderC4a(draft.kodeUlp, draft.jenisObject, code, now),
        'is_dirty': 1,
        'link_foto': '',
        'link_lingkungan': '',
      });
      final stored = await _preparePhotos(item);
      await txn.insert(
        'temuan_inspeksi',
        stored.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return stored;
    });
  }

  Future<TemuanInspeksi> _preparePhotos(TemuanInspeksi item) async {
    if (item.fotoTemuan.isEmpty || item.fotoLingkungan.isEmpty) {
      throw StateError('Foto Temuan dan Foto Sekitar Tiang wajib diambil.');
    }
    final watermarkedPrimary =
        item.kodeWo.isNotEmpty && _sudahWatermark(item.fotoTemuan)
        ? item.fotoTemuan
        : await PhotoWatermarkService.render(
            sourcePath: item.fotoTemuan,
            item: item,
            photoLabel: 'Foto Temuan',
          );
    final watermarkedEnvironment =
        item.kodeWo.isNotEmpty && _sudahWatermark(item.fotoLingkungan)
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
    return _withPhotos(item, primary.path, environment.path);
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
    final timestampMatch = RegExp(
      r'(\d{6})(?=\.jpe?g$)',
      caseSensitive: false,
    ).firstMatch(originalName);
    final stamp =
        timestampMatch?.group(1) ??
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
    final header = await file
        .openRead(0, 3)
        .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
    final isJpeg =
        header.length >= 3 &&
        header[0] == 0xFF &&
        header[1] == 0xD8 &&
        header[2] == 0xFF;
    if (!isJpeg) {
      throw StateError('Format foto tidak valid. Gunakan kamera aplikasi.');
    }
  }

  String _safeName(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

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
    // C4A tetap lokal pada Fase 1; jangan masuk endpoint WO existing.
    final rows = await db.query(
      'temuan_inspeksi',
      where: "is_dirty = 1 AND kode_wo <> ''",
    );
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
        ..['fotoLingkunganBase64'] = base64Encode(
          await environment.readAsBytes(),
        );
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
        final message = (response['message'] ?? 'Sinkronisasi foto gagal.')
            .toString();
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
          (row) =>
              Map<String, dynamic>.from(jsonDecode('${row['payload_json']}')),
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

  bool _isVegetasi(String temuan) =>
      _vegetasiPatterns.any((pattern) => pattern.hasMatch(temuan.trim()));

  bool isRowC4a(String temuan) =>
      const {'rabas / pangkas', 'tebang sedang', 'tebang besar'}.contains(
        temuan
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'\s*/\s*'), ' / ')
            .replaceAll(RegExp(r'\s+'), ' '),
      );

  void validateC4a(TemuanInspeksi item) {
    if (item.kodeWo.isNotEmpty || item.jenisWo.isNotEmpty) {
      throw StateError('C4A harus tanpa WO.');
    }
    if (!RegExp(r'^\d+$').hasMatch(item.kodeUiw) ||
        !C4aSelection.up3Labels.containsKey(item.kodeUp3) ||
        !C4aSelection.ulpLabels.containsKey(item.kodeUlp) ||
        !item.kodeUlp.startsWith(item.kodeUp3) ||
        [
          item.ulp,
          item.userInput,
          item.penyulang,
          item.section,
          item.temuan,
          item.prioritas,
        ].any((s) => s.trim().isEmpty) ||
        !['Jaringan', 'Gardu'].contains(item.jenisObject) ||
        !['Tier 1', 'Tier 2'].contains(item.tier)) {
      throw StateError(
        'Lengkapi unit, aset, Tier, Temuan, Prioritas, dan akun login.',
      );
    }
    if (!C4aSelection.validCoordinate(item.lat, item.long) ||
        item.koordinat.replaceAll(' ', '') !=
            '${item.lat},${item.long}'.replaceAll(' ', '')) {
      throw StateError('Koordinat Temuan tidak valid.');
    }
    if (item.jenisObject == 'Jaringan' &&
        (item.segmen.trim().isEmpty ||
            item.sectionAwal.isEmpty ||
            item.sectionAkhir.isEmpty ||
            item.sectionAwal == item.sectionAkhir ||
            item.section !=
                C4aSelection.section(item.sectionAwal, item.sectionAkhir) ||
            item.nomorGardu.isNotEmpty)) {
      throw StateError('Lengkapi Section berbeda dan Segmen jaringan.');
    }
    if (item.jenisObject == 'Gardu' &&
        (item.nomorGardu.isEmpty ||
            item.sectionAwal.isNotEmpty ||
            item.sectionAkhir.isNotEmpty)) {
      throw StateError('Pilih Nomor Gardu dari master.');
    }
    if (isRowC4a(item.temuan) &&
        (item.jenisPohon.trim().isEmpty ||
            prioritasC4a(
              item.temuan,
              item.jarak,
              item.tinggiPohon,
              [],
            ).isEmpty ||
            item.prioritas !=
                prioritasC4a(item.temuan, item.jarak, item.tinggiPohon, []))) {
      throw StateError(
        'Jarak, tinggi, jenis pohon dan prioritas ROW harus valid.',
      );
    }
    if (item.fotoTemuan.isEmpty ||
        item.fotoLingkungan.isEmpty ||
        item.fotoTemuan == item.fotoLingkungan) {
      throw StateError('Kedua foto bukti berbeda wajib diambil.');
    }
  }

  String prioritasC4a(
    String temuan,
    double? jarak,
    double? tinggi,
    List<Map<String, dynamic>> master,
  ) {
    if (isRowC4a(temuan)) {
      if (jarak == null ||
          tinggi == null ||
          !jarak.isFinite ||
          !tinggi.isFinite ||
          jarak < 0 ||
          tinggi <= 0) {
        return '';
      }
      if (tinggi >= jarak * math.sqrt(2)) return 'Mayor';
      return prioritas(temuan, jarak, tinggi, master);
    }
    // Master_Temuan adalah sumber prioritas existing; tidak menambah sheet lookup.
    final values = master
        .where((r) => _sama(_cari(r, ['Temuan']), temuan))
        .map((r) => _cari(r, ['Prioritas']))
        .where((v) => v.isNotEmpty)
        .toSet();
    return values.length == 1 ? values.single : '';
  }

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

  static String folder(WoInsjar wo, String object, String code, DateTime now) =>
      _folder(wo.kodeUlp, object, '${wo.kodeWo}/$code', now);

  static String folderC4a(
    String ulp,
    String object,
    String code,
    DateTime now,
  ) => _folder(ulp, object, code, now);

  static String _folder(String ulp, String object, String leaf, DateTime now) {
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
    return 'Kopitiam/Rekap Temuan Inspeksi/$ulp/$object/'
        '${now.year}/${now.month.toString().padLeft(2, '0')}. '
        '${months[now.month - 1]}/${now.day.toString().padLeft(2, '0')}/'
        '$leaf/';
  }
}
