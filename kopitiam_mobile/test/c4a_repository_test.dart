import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sqflite/sqflite.dart';
import 'package:kopitiam_mobile/models/temuan_inspeksi.dart';
import 'package:kopitiam_mobile/services/temuan_repository.dart';

/// Double transaksi: menjalankan repository asli dan file foto sesungguhnya.
class MemoryDatabase implements Database, Transaction {
  final rows = <Map<String, Object?>>[];
  Future<void> _tail = Future.value();
  bool rejectInsert = false;
  String? lastWhere;
  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {}
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    lastWhere = where;
    return rows
        .where(
          (r) => whereArgs != null
              ? r['kode_wo'] == '' && r['kode_ulp'] == whereArgs.first
              : r['is_dirty'] == 1 && r['kode_wo'] != '',
        )
        .map((r) => {...r})
        .toList();
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (rejectInsert) throw StateError('Disk penuh');
    expect(conflictAlgorithm, ConflictAlgorithm.abort);
    if (rows.any((r) => r['kode_temuan'] == values['kode_temuan'])) {
      throw StateError('Duplicate key');
    }
    rows.add({...values});
    return rows.length;
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) {
    final result = _tail.then((_) async {
      final snapshot = rows.map((r) => {...r}).toList();
      try {
        return await action(this);
      } catch (_) {
        rows
          ..clear()
          ..addAll(snapshot);
        rethrow;
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TemuanInspeksi completeDraft(
  String photo,
  String environment, {
  String penyulang = 'A',
}) => TemuanInspeksi(
  kodeWo: '',
  kodeTemuan: '',
  kodeUiw: '16',
  kodeUp3: '161',
  kodeUlp: '16140',
  ulp: 'ULP Koba',
  penyulang: penyulang,
  sectionAwal: 'K1',
  sectionAkhir: 'K2',
  section: 'K1 - K2',
  segmen: 'S1',
  jenisObject: 'Jaringan',
  tier: 'Tier 1',
  temuan: 'Isolator',
  prioritas: 'Sedang',
  lat: '-2.123456789',
  long: '106.123456789',
  koordinat: '-2.123456789, 106.123456789',
  fotoTemuan: photo,
  fotoLingkungan: environment,
  userInput: 'pegawai',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late String photo, environment;
  late MemoryDatabase db;
  late TemuanRepository repo;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('c4a-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => root.path,
        );
    final image = img.Image(width: 800, height: 600);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    photo = '${root.path}/primary.jpg';
    environment = '${root.path}/environment.jpg';
    await File(photo).writeAsBytes(img.encodeJpg(image));
    await File(environment).writeAsBytes(img.encodeJpg(image));
    db = MemoryDatabase();
    repo = TemuanRepository(database: db);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await root.delete(recursive: true);
  });

  test('simpan atomik, watermark final, restart repository, ganti penyulang/hari', () async {
    final now = DateTime(2026, 9, 8, 23, 59);
    final first = await repo.simpanC4a(
      completeDraft(photo, environment),
      savedAt: now,
    );
    expect(first.kodeTemuan, 'PEG-16140260908001.TO-001');
    expect(first.kodeWo, '');
    expect(first.jenisWo, '');
    expect(first.dirty, true);
    expect(first.waktuInput, '08 September 2026, 23:59:00');
    expect(
      first.folderPath,
      'Kopitiam/Rekap Temuan Inspeksi/16140/Jaringan/2026/09. September/08/${first.kodeTemuan}/',
    );
    expect(first.toRemote()['Kode WO'], '');
    expect(first.toRemote()['Jenis WO'], '');
    expect(first.linkFoto, '');
    expect(first.linkLingkungan, '');
    expect(File(first.fotoTemuan).existsSync(), true);
    expect(File(first.fotoLingkungan).existsSync(), true);
    final decoded = img.decodeJpg(File(first.fotoTemuan).readAsBytesSync())!;
    final panel = decoded.getPixel(70, 470);
    expect(panel.r + panel.g + panel.b, lessThan(680));
    final restarted = TemuanRepository(database: db);
    final items = await Future.wait([
      restarted.simpanC4a(completeDraft(photo, environment), savedAt: now),
      repo.simpanC4a(
        completeDraft(photo, environment, penyulang: 'B'),
        savedAt: now,
      ),
    ]);
    expect(items.map((i) => i.kodeTemuan), [
      'PEG-16140260908002.TO-002',
      'PEG-16140260908001.TO-003',
    ]);
    final tomorrow = await restarted.simpanC4a(
      completeDraft(photo, environment),
      savedAt: now.add(const Duration(minutes: 2)),
    );
    expect(tomorrow.kodeTemuan, 'PEG-16140260909001.TO-004');
    expect(db.rows, hasLength(4));
    await repo.sinkron('unused');
    expect(db.lastWhere, "is_dirty = 1 AND kode_wo <> ''");
    expect(db.rows.every((r) => r['is_dirty'] == 1), true);
  });

  test('validasi metadata, foto hilang/rusak, dan gagal insert tidak memakan nomor', () async {
    final draft = completeDraft(photo, environment);
    for (final mutation in <Map<String, Object?>>[
      {'kode_wo': 'DUMMY'},
      {'jenis_wo': 'DUMMY'},
      {'kode_ulp': 'ULP Koba'},
      {'user_input': ''},
      {'prioritas': ''},
      {'section_akhir': 'K1'},
      {'tier': 'Tier 3'},
      {'lat': 'NaN'},
      {'foto_lingkungan': photo},
    ]) {
      await expectLater(
        repo.simpanC4a(TemuanInspeksi.fromMap({...draft.toMap(), ...mutation})),
        throwsStateError,
      );
    }
    await expectLater(
      repo.simpanC4a(completeDraft('${root.path}/missing.jpg', environment)),
      throwsStateError,
    );
    final corrupt = '${root.path}/corrupt.jpg';
    await File(corrupt).writeAsString('not JPEG');
    await expectLater(
      repo.simpanC4a(completeDraft(corrupt, environment)),
      throwsStateError,
    );
    db.rejectInsert = true;
    await expectLater(repo.simpanC4a(draft), throwsStateError);
    expect(db.rows, isEmpty);
    db.rejectInsert = false;
    final saved = await repo.simpanC4a(draft, savedAt: DateTime(2026, 9, 8));
    expect(saved.kodeTemuan, 'PEG-16140260908001.TO-001');
  });

  test(
    'gardu mempertahankan lat/long penuh, tanpa WO dan section awal/akhir',
    () async {
      final draft = TemuanInspeksi.fromMap({
        ...completeDraft(photo, environment).toMap(),
        'jenis_object': 'Gardu',
        'nomor_gardu': 'G1',
        'section_awal': '',
        'section_akhir': '',
        'section': 'LBS Koba',
      });
      final saved = await repo.simpanC4a(draft);
      expect(saved.lat, '-2.123456789');
      expect(saved.long, '106.123456789');
      expect(saved.section, 'LBS Koba');
      expect(saved.nomorGardu, 'G1');
    },
  );

  test('foto portrait/terlalu besar dan ROW numerik invalid ditolak', () async {
    final portrait = '${root.path}/portrait.jpg';
    await File(portrait)
        .writeAsBytes(img.encodeJpg(img.Image(width: 600, height: 800)));
    await expectLater(
      repo.simpanC4a(completeDraft(portrait, environment)),
      throwsStateError,
    );
    final large = '${root.path}/large.jpg';
    await File(large)
        .writeAsBytes(List.filled(TemuanRepository.maxPhotoBytes + 1, 0));
    await expectLater(
      repo.simpanC4a(completeDraft(large, environment)),
      throwsStateError,
    );
    for (final jarak in [null, -1.0, double.nan, double.infinity]) {
      final row = TemuanInspeksi.fromMap({
        ...completeDraft(photo, environment).toMap(),
        'temuan': 'Tebang Besar',
        'jarak': jarak,
        'tinggi_pohon': 10.0,
        'jenis_pohon': 'Sengon',
        'prioritas': 'Mayor',
      });
      await expectLater(repo.simpanC4a(row), throwsStateError);
    }
    expect(db.rows, isEmpty);
  });
}
