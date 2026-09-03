import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/main.dart';
import 'package:kopitiam_mobile/screens/login_screen.dart';

/// Merakit aplikasi lalu menunggu StartupScreen selesai memutuskan tujuan.
///
/// Pemulihan sesi memanggil penyimpanan aman melalui platform channel yang
/// tidak tersedia pada lingkungan pengujian. Panggilan itu baru selesai bila
/// diberi waktu nyata, karena itu memakai runAsync, bukan pumpAndSettle yang
/// tidak pernah tenang akibat Timer.periodic pemeriksaan keamanan.
Future<void> _bootstrap(WidgetTester tester) async {
  await tester.pumpWidget(const KopitiamApp());
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('aplikasi Kopitiam dapat dibangun tanpa exception', (
    tester,
  ) async {
    await _bootstrap(tester);

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tanpa sesi tersimpan, aplikasi berhenti di layar masuk', (
    tester,
  ) async {
    await _bootstrap(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('layar masuk memakai branding KOPITIAM', (tester) async {
    await _bootstrap(tester);

    expect(find.text('KOPITIAM'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
