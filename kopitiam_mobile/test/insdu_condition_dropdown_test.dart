import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/models/wo_insdu.dart';
import 'package:kopitiam_mobile/screens/wo_insdu_form_screen.dart';

Finder dropdown(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is DropdownButtonFormField<String> &&
      widget.decoration.labelText == label,
);

void main() {
  testWidgets('cover dan jumper memakai kriteria dropdown yang ditetapkan', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WoInsduFormScreen(
          existing: WoInsdu(
            kodeWo: 'INSDU-001',
            statusWo: WoInsdu.statusDalam,
          ),
          sesi: {'subTim': 'Inspeksi Gardu'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pengukuran'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      dropdown('Cover FCO Atas'),
      400,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.tap(dropdown('Cover FCO Atas'));
    await tester.pumpAndSettle();
    for (final option in [
      'Lengkap',
      'Tidak Lengkap',
      'Rusak',
      'Tidak ada',
    ]) {
      expect(find.text(option), findsWidgets);
    }
    await tester.tap(find.text('Lengkap').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(dropdown('Jumperan Atas'));
    await tester.tap(dropdown('Jumperan Atas'));
    await tester.pumpAndSettle();
    for (final option in [
      'A3C',
      'A3CS (Lengkap)',
      'A3CS (Tidak Lengkap)',
      'Protective Sleeve (Lengkap)',
      'Protective Sleeve (Tidak Lengkap)',
    ]) {
      expect(find.text(option), findsWidgets);
    }
  });
}
