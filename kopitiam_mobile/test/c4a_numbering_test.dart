import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/services/c4a_numbering.dart';
import 'package:kopitiam_mobile/models/temuan_inspeksi.dart';

void main() {
  test('TO per ULP tidak reset ketika hari/penyulang berubah', () {
    final rows = [
      TemuanInspeksi(
        kodeWo: '',
        kodeUlp: '16140',
        penyulang: 'A',
        kodeTemuan: C4aNumbering.code('16140', DateTime(2025), 1, 5),
      ),
      TemuanInspeksi(
        kodeWo: '',
        kodeUlp: '16140',
        penyulang: 'B',
        kodeTemuan: C4aNumbering.code('16140', DateTime(2026), 1, 7),
      ),
      TemuanInspeksi(
        kodeWo: '',
        kodeUlp: '16310',
        kodeTemuan: C4aNumbering.code('16310', DateTime(2026), 1, 99),
      ),
    ];
    expect(C4aNumbering.nextTo(rows, '16140'), 8);
    expect(C4aNumbering.nextTo(rows, '16310'), 100);
    expect(C4aNumbering.nextTo(rows, '16100'), 1);
  });
  test(
    'counter harian terpisah per ULP+penyulang, maksimum bukan jumlah baris',
    () {
      final date = DateTime(2026, 9, 8);
      final rows = [
        TemuanInspeksi(
          kodeWo: '',
          kodeUlp: '16140',
          penyulang: 'A',
          kodeTemuan: C4aNumbering.code('16140', date, 7, 9),
        ),
        TemuanInspeksi(
          kodeWo: '',
          kodeUlp: '16140',
          penyulang: 'B',
          kodeTemuan: C4aNumbering.code('16140', date, 3, 10),
        ),
      ];
      expect(C4aNumbering.nextDaily(rows, '16140', ' a ', date), 8);
      expect(C4aNumbering.nextDaily(rows, '16140', 'B', date), 4);
      expect(C4aNumbering.nextDaily(rows, '16140', 'C', date), 1);
      expect(C4aNumbering.nextDaily(rows, '16310', 'A', date), 1);
      expect(
        C4aNumbering.nextDaily(
          rows,
          '16140',
          'A',
          date.add(const Duration(days: 1)),
        ),
        1,
      );
    },
  );
  test('kode contoh PRD dan rollover kalender', () {
    expect(
      C4aNumbering.code('16140', DateTime(2025, 4, 17), 1, 5),
      'PEG-16140250417001.TO-005',
    );
    expect(
      C4aNumbering.code('16300', DateTime(2027, 1, 1), 999, 999),
      'PEG-16300270101999.TO-999',
    );
    expect(
      () => C4aNumbering.code('ULP Koba', DateTime.now(), 1, 1),
      throwsStateError,
    );
    expect(
      () => C4aNumbering.code('16140', DateTime.now(), 1000, 1),
      throwsStateError,
    );
    expect(
      () => C4aNumbering.code('16140', DateTime.now(), 1, 1000),
      throwsStateError,
    );
  });
}
