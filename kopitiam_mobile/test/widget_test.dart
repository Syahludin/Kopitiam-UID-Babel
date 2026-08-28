import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/main.dart';
import 'package:kopitiam_mobile/screens/login_screen.dart';

/// Beberapa frame singkat supaya StartupScreen selesai memutuskan tujuan
/// tanpa memakai pumpAndSettle, yang tidak pernah tenang karena aplikasi
/// menjalankan Timer.periodic untuk pemeriksaan keamanan.
Future<void> _bootstrap(WidgetTester tester) async {
  await tester.pumpWidget(const SiManDistApp());
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
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
