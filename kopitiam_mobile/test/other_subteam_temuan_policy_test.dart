import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/screens/temuan_form_screen.dart';
import 'package:kopitiam_mobile/services/temuan_repository.dart';

class MixedTemuanRepository extends TemuanRepository {
  @override
  Future<List<Map<String, dynamic>>> master(String dataset) async {
    if (dataset == 'Master_Temuan') {
      return const [
        {
          'Objek Inspeksi': 'Jaringan',
          'Tier': 'Tier 1',
          'Temuan': 'Kabel Geser',
        },
        {
          'Objek Inspeksi': 'Jaringan',
          'Tier': 'Tier 2',
          'Temuan': 'Andongan Rendah',
        },
        {
          'Objek Inspeksi': 'Gardu',
          'Tier': 'Tier 1',
          'Temuan': 'Trafo Bocor',
        },
        {
          'Objek Inspeksi': 'Gardu',
          'Tier': 'Tier 2',
          'Temuan': 'Bushing Rusak',
        },
      ];
    }
    return const [];
  }
}

Finder fieldFinder(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is DropdownButtonFormField<String> &&
      widget.decoration.labelText == label,
);

DropdownButtonFormField<String> field(
  WidgetTester tester,
  String label,
) => tester.widget<DropdownButtonFormField<String>>(fieldFinder(label));

void main() {
  testWidgets(
    'other sub-team selects object then tier before finding',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TemuanFormScreen.c4a(
            sesi: const {
              'subTim': 'Har Jaringan',
              'kodeUp3': '161',
              'kodeUlp': '16140',
              'username': 'petugas.har',
            },
            repository: MixedTemuanRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final object = field(tester, 'Jenis Object *');
      expect(object.initialValue, isNull);

      await tester.scrollUntilVisible(
        fieldFinder('Tier *'),
        250,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ).first,
      );
      expect(field(tester, 'Tier *').onChanged, isNull);
      expect(field(tester, 'Nama Temuan *').onChanged, isNull);

      object.onChanged!('Gardu');
      await tester.pumpAndSettle();
      await tester.ensureVisible(fieldFinder('Tier *'));
      final tier = field(tester, 'Tier *');
      expect(tier.onChanged, isNotNull);

      tier.onChanged!('Tier 1');
      await tester.pumpAndSettle();
      await tester.ensureVisible(fieldFinder('Nama Temuan *'));
      expect(field(tester, 'Nama Temuan *').onChanged, isNotNull);

      await tester.tap(fieldFinder('Nama Temuan *'));
      await tester.pumpAndSettle();

      expect(find.text('Trafo Bocor'), findsOneWidget);
      expect(find.text('Kabel Geser'), findsNothing);
      expect(find.text('Andongan Rendah'), findsNothing);
      expect(find.text('Bushing Rusak'), findsNothing);
    },
  );
}
