import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kopitiam_mobile/models/temuan_inspeksi.dart';
import 'package:kopitiam_mobile/screens/temuan_form_screen.dart';
import 'package:kopitiam_mobile/services/high_accuracy_location_service.dart';
import 'package:kopitiam_mobile/services/temuan_repository.dart';

class FlowRepository extends TemuanRepository {
  final saved = <TemuanInspeksi>[];
  bool failSave = false;
  @override
  Future<TemuanInspeksi> simpanC4a(
    TemuanInspeksi draft, {
    DateTime? savedAt,
  }) async {
    if (failSave) throw StateError('Disk penuh');
    saved.add(draft);
    return draft;
  }

  @override
  Future<List<Map<String, dynamic>>> master(String dataset) async =>
      switch (dataset) {
        'Master_Penyulang' => [
          {'ULP': '16140', 'Nama Penyulang': 'A'},
          {'ULP': '16310', 'Nama Penyulang': 'B'},
        ],
        'Master_Keypoint' => [
          {'ULP': '16140', 'Penyulang': 'A', 'NAMA KEYPOINT': 'K1'},
          {'ULP': '16140', 'Penyulang': 'A', 'NAMA KEYPOINT': 'K2'},
        ],
        'Master_Gardu' => [
          {
            'ULP': '16140',
            'GARDU': 'G1',
            'PENYULANG': 'A',
            'PTS/LBS': 'K1',
            'KOORDINAT LAT': '-2.123456789',
            'KOORDINAT LONG': '106.123456789',
          },
          {
            'ULP': '16310',
            'GARDU': 'G2',
            'PENYULANG': 'B',
            'PTS/LBS': 'K3',
            'X': '-2',
            'Y': '107',
          },
        ],
        'Master_Temuan' => [
          {
            'Objek Inspeksi': 'Jaringan',
            'Tier': 'Tier 1',
            'Temuan': 'Isolator',
            'Prioritas': 'Sedang',
          },
          {
            'Objek Inspeksi': 'Jaringan',
            'Tier': 'Tier 2',
            'Temuan': 'Kabel',
            'Prioritas': 'Minor',
          },
          {
            'Objek Inspeksi': 'Gardu',
            'Tier': 'Tier 1',
            'Temuan': 'Bushing',
            'Prioritas': 'Mayor',
          },
        ],
        _ => [],
      };
}

Finder get scrollable => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;
Finder dropdown(String label) => find.byWidgetPredicate(
  (w) =>
      w is DropdownButtonFormField<String> && w.decoration.labelText == label,
);
Future<void> reveal(WidgetTester tester, Finder target) async {
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(target, 200, scrollable: scrollable);
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String label, String value) async {
  await reveal(tester, dropdown(label));
  await tester.tap(dropdown(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

void main() {
  late Directory root;
  late String primary, environment;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('c4a-flow-');
    final bytes = img.encodeJpg(img.Image(width: 800, height: 600));
    primary = '${root.path}/primary.jpg';
    environment = '${root.path}/environment.jpg';
    await File(primary).writeAsBytes(bytes);
    await File(environment).writeAsBytes(bytes);
  });
  tearDown(() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await root.delete(recursive: true);
  });

  Future<void> open(WidgetTester tester, FlowRepository repo) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Hanya harness tes FAB, bukan implementasi beranda Fase 2.
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<bool>(
                  builder: (_) => TemuanFormScreen.c4a(
                    sesi: const {'kodeUiw': '16', 'username': 'pegawai'},
                    repository: repo,
                    acquireLocation: () async => LocationFix(
                      latitude: -2.12,
                      longitude: 106.12,
                      accuracy: 3,
                      capturedAt: DateTime.now(),
                      samples: 1,
                      locked: true,
                    ),
                    capturePhoto: (label) async =>
                        label == 'Foto Temuan' ? primary : environment,
                  ),
                ),
              ),
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byType(Scaffold));
      await precacheImage(FileImage(File(primary)), context);
      if (!context.mounted) return;
      await precacheImage(FileImage(File(environment)), context);
    });
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await choose(tester, 'UP3', 'UP3 Bangka');
    await choose(tester, 'ULP', 'ULP Koba');
  }

  Future<void> takePhotos(WidgetTester tester) async {
    for (final label in ['Foto Temuan *', 'Foto Sekitar Tiang *']) {
      await reveal(tester, find.text(label));
      await tester.runAsync(() async {
        await tester.tap(find.text(label));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
    }
  }

  testWidgets('FAB → gardu → satu ringkasan → foto → simpan lokal tanpa WO', (
    tester,
  ) async {
    final repo = FlowRepository();
    await open(tester, repo);
    await choose(tester, 'Jenis Object *', 'Gardu');
    await choose(tester, 'Nomor Gardu *', 'G1');
    await reveal(tester, find.byKey(const ValueKey('c4a-asset-row')));
    expect(find.byKey(const ValueKey('c4a-asset-row')), findsOneWidget);
    expect(
      find.textContaining('ULP Koba • Gardu • G1 • A • K1'),
      findsOneWidget,
    );
    await choose(tester, 'Tier *', 'Tier 1');
    await choose(tester, 'Nama Temuan *', 'Bushing');
    await reveal(tester, find.text('Koordinat Master Gardu (lat, long)'));
    expect(find.text('-2.123456789, 106.123456789'), findsOneWidget);
    expect(find.text('Ambil Koordinat Temuan'), findsNothing);
    await tester.tap(find.text('Simpan Lokal'));
    await tester.pumpAndSettle();
    expect(repo.saved, isEmpty);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await takePhotos(tester);
    repo.failSave = true;
    await tester.tap(find.text('Simpan Lokal'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Disk penuh'), findsOneWidget);
    expect(find.byType(TemuanFormScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    repo.failSave = false;
    await tester.tap(find.text('Simpan Lokal'));
    await tester.pumpAndSettle();
    final item = repo.saved.single;
    expect(item.kodeWo, '');
    expect(item.jenisWo, '');
    expect(item.kodeUlp, '16140');
    expect(item.nomorGardu, 'G1');
    expect(item.penyulang, 'A');
    expect(item.section, 'K1');
    expect(item.lat, '-2.123456789');
    expect(item.long, '106.123456789');
    expect(item.userInput, 'pegawai');
    expect(item.prioritas, 'Mayor');
    expect(find.byType(TemuanFormScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('jaringan cascade section, Tier reset, GPS manual dan simpan', (
    tester,
  ) async {
    final repo = FlowRepository();
    await open(tester, repo);
    await choose(tester, 'Jenis Object *', 'Jaringan');
    await choose(tester, 'Penyulang *', 'A');
    await choose(tester, 'Section Awal *', 'K1');
    await reveal(tester, dropdown('Section Akhir *'));
    final akhir = tester.widget<DropdownButtonFormField<String>>(
      dropdown('Section Akhir *'),
    );
    expect(akhir.initialValue, isNull);
    await tester.tap(dropdown('Section Akhir *'));
    await tester.pumpAndSettle();
    expect(find.text('K2'), findsOneWidget);
    await tester.tap(find.text('K2'));
    await tester.pumpAndSettle();
    final segmen = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Segmen *',
    );
    await reveal(tester, segmen);
    await tester.enterText(segmen, 'S1');
    await choose(tester, 'Tier *', 'Tier 2');
    await choose(tester, 'Nama Temuan *', 'Kabel');
    await choose(tester, 'Tier *', 'Tier 1');
    await reveal(tester, dropdown('Nama Temuan *'));
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(dropdown('Nama Temuan *'))
          .initialValue,
      isNull,
    );
    await choose(tester, 'Nama Temuan *', 'Isolator');
    await reveal(tester, find.text('Ambil Koordinat Temuan'));
    await tester.tap(find.text('Ambil Koordinat Temuan'));
    await tester.pumpAndSettle();
    await takePhotos(tester);
    await tester.tap(find.text('Simpan Lokal'));
    await tester.pumpAndSettle();
    final item = repo.saved.single;
    expect(item.section, 'K1 - K2');
    expect(item.segmen, 'S1');
    expect(item.nomorGardu, '');
    expect(item.koordinat, '-2.1200000,106.1200000');
    expect(item.temuan, 'Isolator');
    expect(tester.takeException(), isNull);
  });

  testWidgets('ganti UP3 menghapus aset, ringkasan, koordinat dan kedua foto', (
    tester,
  ) async {
    final repo = FlowRepository();
    await open(tester, repo);
    await choose(tester, 'Jenis Object *', 'Gardu');
    await choose(tester, 'Nomor Gardu *', 'G1');
    await choose(tester, 'Tier *', 'Tier 1');
    await choose(tester, 'Nama Temuan *', 'Bushing');
    await takePhotos(tester);
    await choose(tester, 'UP3', 'UP3 Belitung');
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(dropdown('ULP'))
          .initialValue,
      isNull,
    );
    await choose(tester, 'ULP', 'ULP Manggar');
    await choose(tester, 'Jenis Object *', 'Gardu');
    await reveal(tester, dropdown('Nomor Gardu *'));
    await tester.tap(dropdown('Nomor Gardu *'));
    await tester.pumpAndSettle();
    expect(find.text('G1'), findsNothing);
    await tester.tap(find.text('G2'));
    await tester.pumpAndSettle();
    await reveal(tester, dropdown('Tier *'));
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(dropdown('Tier *'))
          .initialValue,
      isNull,
    );
    await reveal(tester, find.text('Foto Temuan *'));
    expect(find.text('Foto Sekitar Tiang *'), findsOneWidget);
    await tester.tap(find.text('Simpan Lokal'));
    await tester.pumpAndSettle();
    expect(repo.saved, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
