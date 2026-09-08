import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/models/har_execution.dart';
import 'package:kopitiam_mobile/screens/har_execution_screen.dart';
import 'package:kopitiam_mobile/services/har_execution_repository.dart';
import 'package:kopitiam_mobile/theme/kopitiam_theme.dart';

class AdminHarRepository extends HarExecutionRepository {
  AdminHarRepository(super.session);

  @override
  Future<List<HarExecution>> listAll() async => [];

  @override
  Future<HarMasterState> masterState() async =>
      const HarMasterState(false, null);

  @override
  Future<String> syncAll() async => 'Tidak ada WO.';
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
    final repository = AdminHarRepository(session);

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
    expect(find.text('Download WO'), findsNothing);
    expect(find.text('Sinkron WO'), findsNothing);
    expect(find.text('16.BBL'), findsOneWidget);
  });
}
