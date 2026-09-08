import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/services/temuan_repository.dart';

void main() {
  final repo = TemuanRepository();
  test('ROW Pythagoras inklusif dan fallback formula existing', () {
    expect(repo.prioritasC4a('Tebang Besar', 7, 7 * math.sqrt(2), []), 'Mayor');
    expect(repo.prioritasC4a('Tebang Besar', 7, 9, []), 'Minor');
    expect(repo.prioritasC4a('Rabas / Pangkas', 6, 2.5, []), 'Minor');
    expect(repo.prioritasC4a('Tebang Sedang', 4, 10, []), 'Mayor');
    expect(repo.prioritasC4a('Tebang Sedang', 2, 9, []), 'Mayor');
    // Alur WO tidak diubah oleh aturan C4A.
    expect(repo.prioritas('Tebang Sedang', 4, 10, []), 'Sedang');
    for (final value in [null, double.nan, double.infinity, -1.0]) {
      expect(repo.prioritasC4a('Tebang Besar', value, 9, []), '');
    }
  });
  test('non ROW lookup Master_Temuan; kosong/ambigu ditahan', () {
    expect(
      repo.prioritasC4a('Isolator', null, null, [
        {'Temuan': 'Isolator', 'Prioritas': 'Sedang'},
      ]),
      'Sedang',
    );
    expect(repo.prioritasC4a('Isolator', null, null, []), '');
    expect(
      repo.prioritasC4a('Isolator', null, null, [
        {'Temuan': 'Isolator', 'Prioritas': 'Minor'},
        {'Temuan': 'Isolator', 'Prioritas': 'Mayor'},
      ]),
      '',
    );
  });
}
