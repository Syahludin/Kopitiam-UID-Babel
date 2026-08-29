class WoRow {
  static const statusPenugasan = 'Penugasan Tim';
  static const statusProgress = 'Progress Pekerjaan';
  static const statusSelesai = 'Selesai';
  static const statusValues = [statusPenugasan, statusProgress, statusSelesai];

  static const tindakLanjutOptions = [
    'Rabas / Pangkas',
    'Rabas',
    'Pangkas',
    'Tebang',
  ];

  final int? id;
  final String no;
  final String kodeWo;
  final String kodeTemuan;
  final String kodeUiw;
  final String kodeUp3;
  final String kodeUlp;
  final String ulp;
  final String hari;
  final String tanggal;
  final String penyulang;
  final String sectionAwal;
  final String sectionAkhir;
  final String section;
  final String segmen;
  final String jenisObject;
  final String tier;
  final String temuan;
  final String prioritas;
  final String pekerjaan;
  final String jenisWo;
  final String koordinat;
  final String lat;
  final String long;
  final double? jarak;
  final String jenisPohon;
  final double? tinggiPohon;
  final String timEksekusi;
  final String tindakLanjut;
  final int? ukuranDiameterBatang;
  final String jenisTebangan;
  final String fotoTemuan;
  final String linkFoto;
  final String fotoLingkungan;
  final String linkLingkungan;
  final String fotoSesudah;
  final String linkFotoSesudah;
  final String statusWo;
  final String userInput;
  final String waktuInput;
  final String waktuRealisasi;
  final String folderPath;
  final bool isDirty;

  const WoRow({
    this.id,
    this.no = '',
    required this.kodeWo,
    this.kodeTemuan = '',
    this.kodeUiw = '',
    this.kodeUp3 = '',
    this.kodeUlp = '',
    this.ulp = '',
    this.hari = '',
    this.tanggal = '',
    this.penyulang = '',
    this.sectionAwal = '',
    this.sectionAkhir = '',
    this.section = '',
    this.segmen = '',
    this.jenisObject = '',
    this.tier = '',
    this.temuan = '',
    this.prioritas = '',
    this.pekerjaan = '',
    this.jenisWo = '',
    this.koordinat = '',
    this.lat = '',
    this.long = '',
    this.jarak,
    this.jenisPohon = '',
    this.tinggiPohon,
    this.timEksekusi = '',
    this.tindakLanjut = '',
    this.ukuranDiameterBatang,
    this.jenisTebangan = '',
    this.fotoTemuan = '',
    this.linkFoto = '',
    this.fotoLingkungan = '',
    this.linkLingkungan = '',
    this.fotoSesudah = '',
    this.linkFotoSesudah = '',
    this.statusWo = statusPenugasan,
    this.userInput = '',
    this.waktuInput = '',
    this.waktuRealisasi = '',
    this.folderPath = '',
    this.isDirty = false,
  });

  static String normalisasiStatus(Object? value) {
    final status = '${value ?? ''}'.trim().toLowerCase();
    if (status == statusSelesai.toLowerCase()) return statusSelesai;
    if (status == statusProgress.toLowerCase() ||
        status == 'dalam pengerjaan' ||
        status == 'berjalan' ||
        status == 'progress') {
      return statusProgress;
    }
    return statusPenugasan;
  }

  static String jenisTebanganDariDiameter(int? diameter) {
    final value = diameter ?? 0;
    if (value <= 0) return 'Rabas / Pangkas';
    if (value <= 50) return 'Tebang Sedang';
    return 'Tebang Besar';
  }

  factory WoRow.fromMap(Map<String, Object?> m) => WoRow(
        id: m['id'] as int?,
        no: '${m['no'] ?? ''}',
        kodeWo: '${m['kode_wo'] ?? ''}',
        kodeTemuan: '${m['kode_temuan'] ?? ''}',
        kodeUiw: '${m['kode_uiw'] ?? ''}',
        kodeUp3: '${m['kode_up3'] ?? ''}',
        kodeUlp: '${m['kode_ulp'] ?? ''}',
        ulp: '${m['ulp'] ?? ''}',
        hari: '${m['hari'] ?? ''}',
        tanggal: '${m['tanggal'] ?? ''}',
        penyulang: '${m['penyulang'] ?? ''}',
        sectionAwal: '${m['section_awal'] ?? ''}',
        sectionAkhir: '${m['section_akhir'] ?? ''}',
        section: '${m['section'] ?? ''}',
        segmen: '${m['segmen'] ?? ''}',
        jenisObject: '${m['jenis_object'] ?? ''}',
        tier: '${m['tier'] ?? ''}',
        temuan: '${m['temuan'] ?? ''}',
        prioritas: '${m['prioritas'] ?? ''}',
        pekerjaan: '${m['pekerjaan'] ?? ''}',
        jenisWo: '${m['jenis_wo'] ?? ''}',
        koordinat: '${m['koordinat'] ?? ''}',
        lat: '${m['lat'] ?? ''}',
        long: '${m['long'] ?? ''}',
        jarak: (m['jarak'] as num?)?.toDouble(),
        jenisPohon: '${m['jenis_pohon'] ?? ''}',
        tinggiPohon: (m['tinggi_pohon'] as num?)?.toDouble(),
        timEksekusi: '${m['tim_eksekusi'] ?? ''}',
        tindakLanjut: '${m['tindak_lanjut'] ?? ''}',
        ukuranDiameterBatang: (m['ukuran_diameter_batang'] as num?)?.toInt(),
        jenisTebangan: '${m['jenis_tebangan'] ?? ''}',
        fotoTemuan: '${m['foto_temuan'] ?? ''}',
        linkFoto: '${m['link_foto'] ?? ''}',
        fotoLingkungan: '${m['foto_lingkungan'] ?? ''}',
        linkLingkungan: '${m['link_lingkungan'] ?? ''}',
        fotoSesudah: '${m['foto_sesudah'] ?? ''}',
        linkFotoSesudah: '${m['link_foto_sesudah'] ?? ''}',
        statusWo: normalisasiStatus(m['status_wo']),
        userInput: '${m['user_input'] ?? ''}',
        waktuInput: '${m['waktu_input'] ?? ''}',
        waktuRealisasi: '${m['waktu_realisasi'] ?? ''}',
        folderPath: '${m['folder_path'] ?? ''}',
        isDirty: m['is_dirty'] == 1,
      );

  factory WoRow.fromRemote(Map<String, dynamic> r) => WoRow(
        no: '${r['No'] ?? ''}',
        kodeWo: '${r['Kode WO'] ?? ''}',
        kodeTemuan: '${r['Kode Temuan'] ?? ''}',
        kodeUiw: '${r['Kode UIW'] ?? ''}',
        kodeUp3: '${r['Kode UP3'] ?? ''}',
        kodeUlp: '${r['Kode ULP'] ?? ''}',
        ulp: '${r['ULP'] ?? ''}',
        hari: '${r['Hari'] ?? ''}',
        tanggal: '${r['Tanggal'] ?? ''}',
        penyulang: '${r['Penyulang'] ?? ''}',
        sectionAwal: '${r['Section Awal'] ?? ''}',
        sectionAkhir: '${r['Section Akhir'] ?? ''}',
        section: '${r['Section'] ?? ''}',
        segmen: '${r['Segmen'] ?? ''}',
        jenisObject: '${r['Jenis Object'] ?? ''}',
        tier: '${r['Tier'] ?? ''}',
        temuan: '${r['Temuan'] ?? ''}',
        prioritas: '${r['Prioritas'] ?? ''}',
        pekerjaan: '${r['Pekerjaan (Padam / Tanpa Padam)'] ?? ''}',
        jenisWo: '${r['Jenis WO'] ?? ''}',
        koordinat: '${r['Koordinat'] ?? ''}',
        lat: '${r['Lat'] ?? ''}',
        long: '${r['Long'] ?? ''}',
        jarak: _tryDouble(r['Jarak Terhadap Jaringan']),
        jenisPohon: '${r['Jenis Pohon'] ?? ''}',
        tinggiPohon: _tryDouble(r['Tinggi Pohon']),
        timEksekusi: '${r['Tim Eksekusi'] ?? ''}',
        tindakLanjut: '${r['Tindak Lanjut'] ?? ''}',
        ukuranDiameterBatang: _tryInt(r['Ukuran Diamter Batan (cm)']),
        jenisTebangan: '${r['Jenis Tebangan'] ?? ''}',
        linkFoto: '${r['Link Foto'] ?? ''}',
        linkLingkungan: '${r['Link Foto Sekitaran Tiang'] ?? ''}',
        linkFotoSesudah: '${r['Link Foto Sesudah'] ?? ''}',
        statusWo: normalisasiStatus(r['Status WO']),
        userInput: '${r['User Input'] ?? ''}',
        waktuInput: '${r['Waktu Input'] ?? ''}',
        waktuRealisasi: '${r['Waktu Realisasi'] ?? ''}',
        folderPath: '${r['Folder Path'] ?? ''}',
      );

  static double? _tryDouble(Object? value) {
    final text = '${value ?? ''}'.replaceAll(',', '.').trim();
    return text.isEmpty ? null : double.tryParse(text);
  }

  static int? _tryInt(Object? value) {
    final text = '${value ?? ''}'.replaceAll(',', '.').trim();
    return text.isEmpty ? null : double.tryParse(text)?.round();
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'no': no,
        'kode_wo': kodeWo,
        'kode_temuan': kodeTemuan,
        'kode_uiw': kodeUiw,
        'kode_up3': kodeUp3,
        'kode_ulp': kodeUlp,
        'ulp': ulp,
        'hari': hari,
        'tanggal': tanggal,
        'penyulang': penyulang,
        'section_awal': sectionAwal,
        'section_akhir': sectionAkhir,
        'section': section,
        'segmen': segmen,
        'jenis_object': jenisObject,
        'tier': tier,
        'temuan': temuan,
        'prioritas': prioritas,
        'pekerjaan': pekerjaan,
        'jenis_wo': jenisWo,
        'koordinat': koordinat,
        'lat': lat,
        'long': long,
        'jarak': jarak,
        'jenis_pohon': jenisPohon,
        'tinggi_pohon': tinggiPohon,
        'tim_eksekusi': timEksekusi,
        'tindak_lanjut': tindakLanjut,
        'ukuran_diameter_batang': ukuranDiameterBatang,
        'jenis_tebangan': jenisTebangan,
        'foto_temuan': fotoTemuan,
        'link_foto': linkFoto,
        'foto_lingkungan': fotoLingkungan,
        'link_lingkungan': linkLingkungan,
        'foto_sesudah': fotoSesudah,
        'link_foto_sesudah': linkFotoSesudah,
        'status_wo': normalisasiStatus(statusWo),
        'user_input': userInput,
        'waktu_input': waktuInput,
        'waktu_realisasi': waktuRealisasi,
        'folder_path': folderPath,
        'is_dirty': isDirty ? 1 : 0,
      };

  Map<String, dynamic> toRemote() => {
        'No': no,
        'Kode WO': kodeWo,
        'Kode Temuan': kodeTemuan,
        'Kode UIW': kodeUiw,
        'Kode UP3': kodeUp3,
        'Kode ULP': kodeUlp,
        'ULP': ulp,
        'Hari': hari,
        'Tanggal': tanggal,
        'Penyulang': penyulang,
        'Section Awal': sectionAwal,
        'Section Akhir': sectionAkhir,
        'Section': section,
        'Segmen': segmen,
        'Jenis Object': jenisObject,
        'Tier': tier,
        'Temuan': temuan,
        'Prioritas': prioritas,
        'Pekerjaan (Padam / Tanpa Padam)': pekerjaan,
        'Jenis WO': jenisWo,
        'Koordinat': koordinat,
        'Lat': lat,
        'Long': long,
        'Jarak Terhadap Jaringan': jarak,
        'Jenis Pohon': jenisPohon,
        'Tinggi Pohon': tinggiPohon,
        'Tim Eksekusi': timEksekusi,
        'Tindak Lanjut': tindakLanjut,
        'Ukuran Diamter Batan (cm)': ukuranDiameterBatang,
        'Jenis Tebangan': jenisTebangan,
        'Foto Sesudah': fotoSesudah,
        'Link Foto Sesudah': linkFotoSesudah,
        'Status WO': normalisasiStatus(statusWo),
        'User Input': userInput,
        'Waktu Input': waktuInput,
        'Waktu Realisasi': waktuRealisasi,
        'Folder Path': folderPath,
      };

  WoRow copyWith({
    String? no,
    String? kodeTemuan,
    String? koordinat,
    String? lat,
    String? long,
    String? timEksekusi,
    String? tindakLanjut,
    int? ukuranDiameterBatang,
    String? jenisTebangan,
    String? fotoSesudah,
    String? linkFotoSesudah,
    String? statusWo,
    String? userInput,
    String? waktuInput,
    String? waktuRealisasi,
    String? folderPath,
    bool? isDirty,
  }) =>
      WoRow(
        id: id,
        no: no ?? this.no,
        kodeWo: kodeWo,
        kodeTemuan: kodeTemuan ?? this.kodeTemuan,
        kodeUiw: kodeUiw,
        kodeUp3: kodeUp3,
        kodeUlp: kodeUlp,
        ulp: ulp,
        hari: hari,
        tanggal: tanggal,
        penyulang: penyulang,
        section: section,
        segmen: segmen,
        jenisObject: jenisObject,
        tier: tier,
        temuan: temuan,
        prioritas: prioritas,
        pekerjaan: pekerjaan,
        jenisWo: jenisWo,
        koordinat: koordinat ?? this.koordinat,
        lat: lat ?? this.lat,
        long: long ?? this.long,
        jarak: jarak,
        jenisPohon: jenisPohon,
        tinggiPohon: tinggiPohon,
        timEksekusi: timEksekusi ?? this.timEksekusi,
        tindakLanjut: tindakLanjut ?? this.tindakLanjut,
        ukuranDiameterBatang:
            ukuranDiameterBatang ?? this.ukuranDiameterBatang,
        jenisTebangan: jenisTebangan ?? this.jenisTebangan,
        fotoTemuan: fotoTemuan,
        linkFoto: linkFoto,
        fotoLingkungan: fotoLingkungan,
        linkLingkungan: linkLingkungan,
        fotoSesudah: fotoSesudah ?? this.fotoSesudah,
        linkFotoSesudah: linkFotoSesudah ?? this.linkFotoSesudah,
        statusWo: statusWo ?? this.statusWo,
        userInput: userInput ?? this.userInput,
        waktuInput: waktuInput ?? this.waktuInput,
        waktuRealisasi: waktuRealisasi ?? this.waktuRealisasi,
        folderPath: folderPath ?? this.folderPath,
        isDirty: isDirty ?? this.isDirty,
      );
}
