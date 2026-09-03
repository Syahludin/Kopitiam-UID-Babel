class MasterGardu {
  final String no;
  final String ulp;
  final String gardu;
  final String alamat;
  final String penyulang;
  final String ptsLbs;
  final String lokasiKelasGardu;
  final String linePrimerGardu;
  final String latLong;
  final String jenisGardu;

  const MasterGardu({
    this.no = '',
    this.ulp = '',
    this.gardu = '',
    this.alamat = '',
    this.penyulang = '',
    this.ptsLbs = '',
    this.lokasiKelasGardu = '',
    this.linePrimerGardu = '',
    this.latLong = '',
    this.jenisGardu = '',
  });

  factory MasterGardu.fromMap(Map<String, dynamic> map) {
    String normalize(String key) =>
        key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    String find(List<String> keys) {
      for (final key in keys) {
        final value = '${map[key] ?? ''}'.trim();
        if (value.isNotEmpty) return value;
      }
      final normalizedKeys = keys.map(normalize).toSet();
      for (final entry in map.entries) {
        final value = '${entry.value ?? ''}'.trim();
        if (normalizedKeys.contains(normalize(entry.key)) && value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    return MasterGardu(
      no: find(const ['NO', 'No', 'no']),
      ulp: find(const ['ULP', 'Ulp', 'ulp']),
      gardu: find(const ['GARDU', 'Gardu', 'Nama Gardu', 'gardu']),
      alamat: find(const ['ALAMAT', 'Alamat', 'alamat']),
      penyulang: find(const ['PENYULANG', 'Penyulang', 'penyulang']),
      ptsLbs: find(const ['PTS/LBS', 'PTS / LBS', 'Pts/Lbs', 'pts_lbs']),
      lokasiKelasGardu: find(
        const ['LOKASI KELAS GARDU', 'Lokasi Kelas Gardu', 'Kelas Gardu'],
      ),
      linePrimerGardu: find(
        const ['LINE PRIMER GARDU', 'Line Primer Gardu', 'Line Primer'],
      ),
      latLong: find(
        const ['LAT LONG', 'Lat Long', 'LAT/LONG', 'Koordinat GPS', 'Koordinat'],
      ),
      jenisGardu: find(const ['JENIS GARDU', 'Jenis Gardu', 'jenis_gardu']),
    );
  }

  Map<String, dynamic> toMap() => {
        'NO': no,
        'ULP': ulp,
        'GARDU': gardu,
        'ALAMAT': alamat,
        'PENYULANG': penyulang,
        'PTS/LBS': ptsLbs,
        'LOKASI KELAS GARDU': lokasiKelasGardu,
        'LINE PRIMER GARDU': linePrimerGardu,
        'LAT LONG': latLong,
        'JENIS GARDU': jenisGardu,
      };
}
