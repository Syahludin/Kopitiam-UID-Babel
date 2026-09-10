import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/models/wo_insdu.dart';
import 'package:kopitiam_mobile/screens/wo_insdu_form_screen.dart';

Finder field(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is DropdownButtonFormField<String> &&
      widget.decoration.labelText == label,
);

List<String?> options(WidgetTester tester, String label) {
  final button = find.descendant(
    of: field(label),
    matching: find.byType(DropdownButton<String>),
  );
  return tester
      .widget<DropdownButton<String>>(button)
      .items!
      .map((item) => item.value)
      .toList();
}

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

    final scrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    ).first;
    await tester.scrollUntilVisible(field('Cover FCO Atas'), 400, scrollable: scrollable);
    expect(options(tester, 'Cover FCO Atas'), [
      'Lengkap',
      'Tidak Lengkap',
      'Rusak',
      'Tidak ada',
    ]);

    await tester.scrollUntilVisible(field('Jumperan Atas'), 250, scrollable: scrollable);
    expect(options(tester, 'Jumperan Atas'), [
      'A3C',
      'A3CS (Lengkap)',
      'A3CS (Tidak Lengkap)',
      'Protective Sleeve (Lengkap)',
      'Protective Sleeve (Tidak Lengkap)',
    ]);
  });
}
