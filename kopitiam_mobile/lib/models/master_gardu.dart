class MasterGardu {
  final String no;
  final String ulp;
  final String gardu;
  final String alamat;
  final String penyulang;
  final String ptsLbs;
  final String lokasiKelasGardu;
  final String linePrimerGardu;
  final String koordinatGps;
  final String jenisGardu;
  final String koordinatX;
  final String koordinatY;

  const MasterGardu({
    this.no = '',
    this.ulp = '',
    this.gardu = '',
    this.alamat = '',
    this.penyulang = '',
    this.ptsLbs = '',
    this.lokasiKelasGardu = '',
    this.linePrimerGardu = '',
    this.koordinatGps = '',
    this.jenisGardu = '',
    this.koordinatX = '',
    this.koordinatY = '',
  });

  factory MasterGardu.fromMap(Map<String, dynamic> map) {
    String find(List<String> keys) {
      for (final key in keys) {
        if (map.containsKey(key) && '${map[key]}'.trim().isNotEmpty) {
          return '${map[key]}'.trim();
        }
      }
      final normalized = keys.map((k) => k.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')).toSet();
      for (final entry in map.entries) {
        final k = entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (normalized.contains(k) && '${entry.value}'.trim().isNotEmpty) {
          return '${entry.value}'.trim();
        }
      }
      return '';
    }

    return MasterGardu(
      no: find(['NO', 'No', 'no']),
      ulp: find(['ULP', 'Ulp', 'ulp']),
      gardu: find(['GARDU', 'Gardu', 'Nama Gardu', 'gardu']),
      alamat: find(['ALAMAT', 'Alamat', 'alamat']),
      penyulang: find(['PENYULANG', 'Penyulang', 'penyulang']),
      ptsLbs: find(['PTS/LBS', 'PTS / LBS', 'Pts/Lbs', 'pts_lbs']),
      lokasiKelasGardu: find(['LOKASI KELAS GARDU', 'Lokasi Kelas Gardu', 'Kelas Gardu']),
      linePrimerGardu: find(['LINE PRIMER GARDU', 'Line Primer Gardu', 'Line Primer']),
      koordinatGps: find(['KOORDINAT GPS', 'Koordinat GPS', 'Koordinat']),
      jenisGardu: find(['JENIS GARDU', 'Jenis Gardu', 'jenis_gardu']),
      koordinatX: find(['KOORDINAT X', 'Koordinat X', 'Long', 'Longitude', 'X']),
      koordinatY: find(['KOORDINAT Y', 'Koordinat Y', 'Lat', 'Latitude', 'Y']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'NO': no,
      'ULP': ulp,
      'GARDU': gardu,
      'ALAMAT': alamat,
      'PENYULANG': penyulang,
      'PTS/LBS': ptsLbs,
      'LOKASI KELAS GARDU': lokasiKelasGardu,
      'LINE PRIMER GARDU': linePrimerGardu,
      'KOORDINAT GPS': koordinatGps,
      'JENIS GARDU': jenisGardu,
      'KOORDINAT X': koordinatX,
      'KOORDINAT Y': koordinatY,
    };
  }
}
