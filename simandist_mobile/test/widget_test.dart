import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simandist_mobile/main.dart';

void main() {
  testWidgets('menampilkan halaman login SiManDist', (tester) async {
    await tester.pumpWidget(const SiManDistApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('PLN UID BABEL'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
