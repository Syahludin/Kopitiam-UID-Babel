import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/screens/temuan_form_screen.dart';
import 'package:kopitiam_mobile/models/wo_insjar.dart';
import 'package:kopitiam_mobile/services/temuan_repository.dart';
import 'package:kopitiam_mobile/services/high_accuracy_location_service.dart';

class MemoryMasterRepository extends TemuanRepository {
  @override
  Future<String> kodeBaru(String kodeWo) async => '$kodeWo.TO-001';
  @override
  Future<List<Map<String, dynamic>>> master(String dataset) async => [];
}

void main() {
  testWidgets('form WO existing tetap memakai WO dan kunci subTim', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TemuanFormScreen(
          wo: const WoInsjar(
            kodeWo: 'INSJAR-16140260908001',
            ulp: 'ULP Koba',
            penyulang: 'A',
            section: 'K1 - K2',
          ),
          sesi: const {'subTim': 'insjar'},
          repository: MemoryMasterRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Work Order'), findsOneWidget);
    expect(find.text('INSJAR-16140260908001'), findsOneWidget);
    expect(find.text('Jaringan'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.decoration.labelText == 'Jenis Object *',
      ),
      findsNothing,
    );
    expect(find.text('Unit C4A'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'GPS jaringan hanya diambil saat diklik, menolak fix tidak presisi',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: TemuanFormScreen.c4a(
            sesi: const {'kodeUp3': '161', 'kodeUlp': '16140'},
            repository: MemoryMasterRepository(),
            acquireLocation: () async {
              calls++;
              return LocationFix(
                latitude: -2,
                longitude: 106,
                accuracy: calls == 1 ? 20 : 3,
                capturedAt: DateTime.now(),
                samples: 1,
                locked: calls > 1,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      final object = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.decoration.labelText == 'Jenis Object *',
      );
      await tester.ensureVisible(object);
      await tester.pumpAndSettle();
      await tester.tap(object);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jaringan'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ambil Koordinat Temuan'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Ambil Koordinat Temuan'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.textContaining('GPS belum presisi'), findsOneWidget);
      await tester.tap(find.text('Ambil Koordinat Temuan'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('-2.0000000,106.0000000'), findsOneWidget);
    },
  );
  testWidgets(
    'satu form scroll saja; tidak membangun beranda atau sinkronisasi',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TemuanFormScreen.c4a(
            sesi: const {'kodeUp3': '161', 'kodeUlp': '16140'},
            repository: MemoryMasterRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Sinkron'), findsNothing);
      expect(find.text('Tambah Temuan C4A'), findsOneWidget);
      expect(find.text('Simpan Lokal'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Aset yang Dinilai'), 200);
      expect(find.byKey(const ValueKey('c4a-asset-row')), findsNothing);
      await tester.scrollUntilVisible(find.text('Foto Dokumentasi'), 300);
      expect(find.text('Foto Dokumentasi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'C4A memilih object eksplisit, tidak terkunci subTim dan tanpa WO',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TemuanFormScreen.c4a(
            sesi: const {
              'subTim': 'insjar',
              'kodeUp3': '161',
              'kodeUlp': '16140',
            },
            repository: MemoryMasterRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Work Order'), findsNothing);
      final object = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.decoration.labelText == 'Jenis Object *',
      );
      expect(object, findsOneWidget);
      await tester.ensureVisible(object);
      await tester.pumpAndSettle();
      await tester.tap(object);
      await tester.pumpAndSettle();
      expect(find.text('Jaringan'), findsOneWidget);
      expect(find.text('Gardu'), findsOneWidget);
      await tester.tap(find.text('Gardu'));
      await tester.pumpAndSettle();
      expect(find.text('Nomor Gardu *'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
