/// Cascade offline berbasis master existing, bukan sumber otorisasi baru.
class C4aSelection {
  static const up3Labels = {'161': 'UP3 Bangka', '163': 'UP3 Belitung'};
  static const ulpLabels = {
    '16100': 'ULP Pangkalpinang',
    '16110': 'ULP Sungailiat',
    '16120': 'ULP Mentok',
    '16130': 'ULP Toboali',
    '16140': 'ULP Koba',
    '16300': 'ULP Tanjung Pandan',
    '16310': 'ULP Manggar',
  };
  final Map<String, dynamic> sesi;
  final List<Map<String, dynamic>> units;
  String? up3, ulp;

  C4aSelection(this.sesi, this.units) {
    if (!isUid) {
      up3 = value(sesi, ['kodeUp3']);
      if (isUlp) ulp = value(sesi, ['kodeUlp']);
    }
  }

  static String value(Map<String, dynamic> row, List<String> keys) {
    String normal(String key) =>
        key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (final key in keys) {
      for (final entry in row.entries) {
        if (normal(key) == normal(entry.key) &&
            '${entry.value ?? ''}'.trim().isNotEmpty) {
          return '${entry.value}'.trim();
        }
      }
    }
    return '';
  }

  bool get isUid =>
      value(sesi, ['role']).toLowerCase().replaceAll(' ', '') == 'superuser' ||
      (value(sesi, ['kodeUp3']).isEmpty && value(sesi, ['kodeUlp']).isEmpty);
  bool get isUlp => !isUid && value(sesi, ['kodeUlp']).isNotEmpty;
  List<Map<String, dynamic>> get _unitRows {
    // getMasterData hanya memuat akun login, bukan akun unit lainnya.
    // Referensi publik PRD §8.7 melengkapi unit tanpa membuka data akun lain.
    final own = units.where(
      (r) =>
          value(r, ['Username']).toLowerCase() ==
          value(sesi, ['username']).toLowerCase(),
    );
    final uiw = value(sesi, ['kodeUiw']).isNotEmpty
        ? value(sesi, ['kodeUiw'])
        : (own.isEmpty ? '' : value(own.first, ['Kode UIW']));
    final rows = <Map<String, dynamic>>[...units, if (isUlp) sesi];
    return [
      ...rows,
      for (final entry in ulpLabels.entries)
        if (!rows.any((r) => value(r, ['kodeUlp']) == entry.key))
          {
            'Kode UIW': uiw,
            'Kode UP3': entry.key.substring(0, 3),
            'Kode ULP': entry.key,
            'ULP': entry.value,
          },
    ];
  }

  List<String> get up3Options =>
      _unitRows
          .map((r) => value(r, ['kodeUp3']))
          .where(up3Labels.containsKey)
          .toSet()
          .toList()
        ..sort();
  List<String> get ulpOptions =>
      _unitRows
          .where((r) => value(r, ['kodeUp3']) == up3)
          .map((r) => value(r, ['kodeUlp']))
          .where(ulpLabels.containsKey)
          .toSet()
          .toList()
        ..sort();

  void selectUp3(String? code) {
    if (!isUid || !up3Options.contains(code)) return;
    up3 = code;
    ulp = null;
  }

  void selectUlp(String? code) {
    if (isUlp || !ulpOptions.contains(code)) return;
    ulp = code;
  }

  bool get ready => up3Labels.containsKey(up3) && ulpOptions.contains(ulp);

  Map<String, String> get identity {
    if (!ready) return {};
    final matches = _unitRows.where(
      (r) => value(r, ['kodeUp3']) == up3 && value(r, ['kodeUlp']) == ulp,
    );
    final uiws = matches
        .map((r) => value(r, ['kodeUiw']))
        .where((v) => v.isNotEmpty)
        .toSet();
    final names = matches
        .map((r) => value(r, ['ULP']))
        .where((v) => v.isNotEmpty)
        .toSet();
    if (uiws.length != 1 ||
        names.length != 1 ||
        !RegExp(r'^\d+$').hasMatch(uiws.single)) {
      return {};
    }
    return {
      'kode_uiw': uiws.single,
      'kode_up3': up3!,
      'kode_ulp': ulp!,
      'ulp': names.single,
    };
  }

  static String _normal(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  bool belongs(Map<String, dynamic> row) {
    if (!ready) return false;
    final code = value(row, ['Kode ULP']);
    if (code.isNotEmpty) return code == ulp;
    final name = _normal(value(row, ['ULP']));
    final label = _normal(ulpLabels[ulp] ?? '');
    return name == ulp ||
        name == label ||
        name == label.replaceFirst('ulp ', '');
  }

  List<String> penyulangOptions(List<Map<String, dynamic>> rows) =>
      rows
          .where(belongs)
          .map((r) => value(r, ['Nama Penyulang']))
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  List<String> sectionOptions(
    List<Map<String, dynamic>> rows,
    String? penyulang,
  ) =>
      rows
          .where(
            (r) =>
                belongs(r) &&
                penyulang != null &&
                _normal(value(r, ['Penyulang'])) == _normal(penyulang),
          )
          .map((r) => value(r, ['Nama Keypoint']))
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  static String section(String? awal, String? akhir) =>
      awal == null || akhir == null || awal == akhir ? '' : '$awal - $akhir';

  List<String> garduOptions(List<Map<String, dynamic>> rows) =>
      rows
          .where(belongs)
          .map((r) => value(r, ['GARDU']))
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  Map<String, dynamic>? gardu(List<Map<String, dynamic>> rows, String? nomor) {
    final matches = rows
        .where((r) => belongs(r) && value(r, ['GARDU']) == nomor)
        .toList();
    // Master ambigu tidak boleh mengisi koordinat dari baris sembarang.
    return matches.length == 1 ? matches.single : null;
  }

  static String latitude(Map<String, dynamic> row) =>
      value(row, ['KOORDINAT LAT', 'Latitude', 'X']);
  static String longitude(Map<String, dynamic> row) =>
      value(row, ['KOORDINAT LONG', 'Longitude', 'Y']);
  static bool validCoordinate(String latitude, String longitude) {
    final lat = double.tryParse(latitude), long = double.tryParse(longitude);
    return lat != null &&
        long != null &&
        lat.isFinite &&
        long.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        long >= -180 &&
        long <= 180 &&
        !(lat == 0 && long == 0);
  }

  static List<Map<String, dynamic>> temuanForObject(
    List<Map<String, dynamic>> rows,
    String object,
  ) => ['Jaringan', 'Gardu'].contains(object)
      ? rows
            .where(
              (r) =>
                  _normal(
                    value(r, [
                      'Objek Inspeksi',
                      'Object Inspeksi',
                      'Jenis Object',
                    ]),
                  ) ==
                  _normal(object),
            )
            .toList()
      : [];

  static List<Map<String, dynamic>> temuanForTier(
    List<Map<String, dynamic>> rows,
    String object,
    String? tier,
  ) => ['Tier 1', 'Tier 2'].contains(tier)
      ? temuanForObject(
          rows,
          object,
        ).where((r) => _normal(value(r, ['Tier'])) == _normal(tier!)).toList()
      : [];
}
