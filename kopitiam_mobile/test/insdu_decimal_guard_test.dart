import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/models/wo_insdu.dart';
import 'package:kopitiam_mobile/screens/wo_insdu_form_screen.dart';

void main() {
  testWidgets('semua input pengukuran memakai koma sebagai pemisah desimal', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WoInsduFormScreen(
          existing: WoInsdu(
            kodeWo: 'INSDU-001',
            statusWo: WoInsdu.statusDalam,
            bebanUtamaRWbp: 12.5,
          ),
          sesi: {'subTim': 'Inspeksi Gardu'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pengukuran'));
    await tester.pumpAndSettle();

    final firstField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Beban Utama R (A) WBP',
    );
    expect(firstField, findsOneWidget);
    expect(find.text('12,5'), findsOneWidget);

    await tester.enterText(firstField, '12.5');
    await tester.pump();
    expect(find.text('Gunakan (,) sebagai pemisah'), findsOneWidget);

    await tester.enterText(firstField, '12,5');
    await tester.pump();
    expect(find.text('Gunakan (,) sebagai pemisah'), findsNothing);
  });
}
