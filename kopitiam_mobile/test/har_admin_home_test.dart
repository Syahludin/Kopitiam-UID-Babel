import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/models/har_execution.dart';
import 'package:kopitiam_mobile/screens/har_execution_screen.dart';
import 'package:kopitiam_mobile/services/har_execution_repository.dart';
import 'package:kopitiam_mobile/theme/kopitiam_theme.dart';

class HarHomeRepository extends HarExecutionRepository {
  HarHomeRepository(super.session);

  @override
  Future<List<HarExecution>> listAll() async => [];

  @override
  Future<HarMasterState> masterState() async =>
      const HarMasterState(false, null);

  @override
  Future<String> syncAll() async => 'Tidak ada WO.';

  @override
  Future<HarDownloadResult> downloadAssigned() async =>
      const HarDownloadResult(0, 0, [HarExecution.jar]);
}

void main() {
  testWidgets('beranda Admin tidak menampilkan bagian Work Order', (
    tester,
  ) async {
    const session = {
      'username': '16.BBL',
      'role': 'Admin',
      'subTim': 'Pegawai',
      'kodeUlp': '16',
      'ulp': 'UID Babel',
    };
    final repository = HarHomeRepository(session);

    await tester.pumpWidget(
      MaterialApp(
        theme: KopitiamTheme.light,
        home: HarExecutionScreen(
          sesi: session,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ringkasan Work Order'), findsNothing);
    expect(find.text('Data Work Order'), findsNothing);
    expect(find.text('Download WO'), findsNothing);
    expect(find.text('Sinkron WO'), findsNothing);
    expect(find.text('16.BBL'), findsOneWidget);
  });

  testWidgets('beranda Har memakai card aksi ROW dengan dua tombol satu baris', (
    tester,
  ) async {
    const session = {
      'username': '16130.Har',
      'role': 'Petugas',
      'subTim': 'Har',
      'kodeUlp': '16130',
      'ulp': 'ULP Toboali',
    };
    final repository = HarHomeRepository(session);

    await tester.pumpWidget(
      MaterialApp(
        theme: KopitiamTheme.light,
        home: HarExecutionScreen(
          sesi: session,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Data Work Order'), findsOneWidget);
    final download = tester.getTopLeft(find.text('Download WO'));
    final sync = tester.getTopLeft(find.text('Sinkron WO'));
    expect((download.dy - sync.dy).abs(), lessThan(1));
    expect(download.dx, lessThan(sync.dx));
  });
}
