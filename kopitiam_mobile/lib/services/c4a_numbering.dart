import '../models/temuan_inspeksi.dart';

/// Nomor ditetapkan saat simpan, bukan saat membuka form/memotret.
class C4aNumbering {
  static int nextTo(Iterable<TemuanInspeksi> rows, String ulp) {
    final pattern = RegExp('^PEG-$ulp[0-9]{9}\\.TO-([0-9]{3})\$');
    var maximum = 0;
    for (final row in rows) {
      if (row.kodeWo.isNotEmpty || row.kodeUlp != ulp) continue;
      final match = pattern.firstMatch(row.kodeTemuan);
      if (match != null) {
        final number = int.parse(match.group(1)!);
        if (number > maximum) maximum = number;
      }
    }
    return maximum + 1;
  }

  static String normalizePenyulang(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static int nextDaily(
    Iterable<TemuanInspeksi> rows,
    String ulp,
    String penyulang,
    DateTime now,
  ) {
    if (penyulang.trim().isEmpty) throw StateError('Penyulang wajib dipilih.');
    final pattern = RegExp('^PEG-$ulp${day(now)}([0-9]{3})\\.TO-[0-9]{3}\$');
    var maximum = 0;
    for (final row in rows) {
      if (row.kodeWo.isNotEmpty ||
          row.kodeUlp != ulp ||
          normalizePenyulang(row.penyulang) != normalizePenyulang(penyulang)) {
        continue;
      }
      final match = pattern.firstMatch(row.kodeTemuan);
      if (match != null) {
        final number = int.parse(match.group(1)!);
        if (number > maximum) maximum = number;
      }
    }
    return maximum + 1;
  }

  static String day(DateTime now) =>
      '${(now.year % 100).toString().padLeft(2, '0')}'
      '${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

  static String code(String ulp, DateTime now, int daily, int to) {
    if (!RegExp(r'^\d{5}$').hasMatch(ulp)) {
      throw StateError('Kode ULP harus 5 digit numerik.');
    }
    if (daily < 1 || daily > 999 || to < 1 || to > 999) {
      throw StateError(
        'Counter C4A di luar rentang 001–999. Nomor tidak boleh diputar ulang.',
      );
    }
    return 'PEG-$ulp${day(now)}${daily.toString().padLeft(3, '0')}.TO-${to.toString().padLeft(3, '0')}';
  }
}
