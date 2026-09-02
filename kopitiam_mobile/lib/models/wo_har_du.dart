class WoHarDu {
  static const statusMenunggu = 'Menunggu';
  static const statusSedang = 'Sedang Dikerjakan';
  static const statusSelesai = 'Selesai';
  static const statusTersinkron = 'Tersinkron';

  final int? id;
  final String no;
  final String kodeWo;
  final String kodeUiw;
  final String kodeUp3;
  final String kodeUlp;
  final String ulp;
  final String hari;
  final String tanggal;
  final String penyulang;
  final String section;
  final String nomorGardu;
  final String kodeTemuan;
  final String kodeWoInspeksi;
  final String jenisObject;
  final String tier;
  final String temuan;
  final String prioritas;
  final String pekerjaan;
  final String jenisWo;
  final String koordinat;
  final double? lat;
  final double? long;
  final String fotoTemuan;
  final String linkFotoTemuan;
  final String fotoTiangSekitar;
  final String linkFotoTiangSekitar;
  final String fotoSesudah;
  final String linkFotoSesudah;
  final String catatanPetugas;
  final String timEksekusi;
  final String tanggalPenugasan;
  final String catatanKoordinator;
  final String namaKoordinator;
  final String statusWo;
  final String userInput;
  final String waktuInput;
  final String waktuSelesai;
  final String durasi;
  final String folderPath;
  final bool isSynced;

  const WoHarDu({
    this.id,
    this.no = '',
    required this.kodeWo,
    this.kodeUiw = '',
    this.kodeUp3 = '',
    this.kodeUlp = '',
    this.ulp = '',
    this.hari = '',
    this.tanggal = '',
    this.penyulang = '',
    this.section = '',
    this.nomorGardu = '',
    this.kodeTemuan = '',
    this.kodeWoInspeksi = '',
    this.jenisObject = '',
    this.tier = '',
    this.temuan = '',
    this.prioritas = '',
    this.pekerjaan = '',
    this.jenisWo = '',
    this.koordinat = '',
    this.lat,
    this.long,
    this.fotoTemuan = '',
    this.linkFotoTemuan = '',
    this.fotoTiangSekitar = '',
    this.linkFotoTiangSekitar = '',
    this.fotoSesudah = '',
    this.linkFotoSesudah = '',
    this.catatanPetugas = '',
    this.timEksekusi = '',
    this.tanggalPenugasan = '',
    this.catatanKoordinator = '',
    this.namaKoordinator = '',
    this.statusWo = statusMenunggu,
    this.userInput = '',
    this.waktuInput = '',
    this.waktuSelesai = '',
    this.durasi = '',
    this.folderPath = '',
    this.isSynced = false,
  });

  static String normalisasiStatus(Object? value) {
    final status = '${value ?? ''}'.trim().toLowerCase();
    if (status == statusSelesai.toLowerCase()) return statusSelesai;
    if (status == statusTersinkron.toLowerCase()) return statusTersinkron;
    if (status == statusSedang.toLowerCase() ||
        status == 'progress' ||
        status == 'dalam pengerjaan') {
      return statusSedang;
    }
    return statusMenunggu;
  }

  static double? _tryDouble(Object? value) {
    final text = '${value ?? ''}'.replaceAll(',', '.').trim();
    return text.isEmpty ? null : double.tryParse(text);
  }

  factory WoHarDu.fromMap(Map<String, Object?> m) => WoHarDu(
        id: m['id'] as int?,
        no: '${m['no'] ?? ''}',
        kodeWo: '${m['kode_wo'] ?? ''}',
        kodeUiw: '${m['kode_uiw'] ?? ''}',
        kodeUp3: '${m['kode_up3'] ?? ''}',
        kodeUlp: '${m['kode_ulp'] ?? ''}',
        ulp: '${m['ulp'] ?? ''}',
        hari: '${m['hari'] ?? ''}',
        tanggal: '${m['tanggal'] ?? ''}',
        penyulang: '${m['penyulang'] ?? ''}',
        section: '${m['section'] ?? ''}',
        nomorGardu: '${m['nomor_gardu'] ?? ''}',
        kodeTemuan: '${m['kode_temuan'] ?? ''}',
        kodeWoInspeksi: '${m['kode_wo_inspeksi'] ?? ''}',
        jenisObject: '${m['jenis_object'] ?? ''}',
        tier: '${m['tier'] ?? ''}',
        temuan: '${m['temuan'] ?? ''}',
        prioritas: '${m['prioritas'] ?? ''}',
        pekerjaan: '${m['pekerjaan'] ?? ''}',
        jenisWo: '${m['jenis_wo'] ?? ''}',
        koordinat: '${m['koordinat'] ?? ''}',
        lat: (m['lat'] as num?)?.toDouble(),
        long: (m['long'] as num?)?.toDouble(),
        fotoTemuan: '${m['foto_temuan'] ?? ''}',
        linkFotoTemuan: '${m['link_foto_temuan'] ?? ''}',
        fotoTiangSekitar: '${m['foto_tiang_sekitar'] ?? ''}',
        linkFotoTiangSekitar: '${m['link_foto_tiang_sekitar'] ?? ''}',
        fotoSesudah: '${m['foto_sesudah'] ?? ''}',
        linkFotoSesudah: '${m['link_foto_sesudah'] ?? ''}',
        catatanPetugas: '${m['catatan_petugas'] ?? ''}',
        timEksekusi: '${m['tim_eksekusi'] ?? ''}',
        tanggalPenugasan: '${m['tanggal_penugasan'] ?? ''}',
        catatanKoordinator: '${m['catatan_koordinator'] ?? ''}',
        namaKoordinator: '${m['nama_koordinator'] ?? ''}',
        statusWo: normalisasiStatus(m['status_wo']),
        userInput: '${m['user_input'] ?? ''}',
        waktuInput: '${m['waktu_input'] ?? ''}',
        waktuSelesai: '${m['waktu_selesai'] ?? ''}',
        durasi: '${m['durasi'] ?? ''}',
        folderPath: '${m['folder_path'] ?? ''}',
        isSynced: m['is_synced'] == 1,
      );

  factory WoHarDu.fromRemote(Map<String, dynamic> r) => WoHarDu(
        no: '${r['No'] ?? ''}',
        kodeWo: '${r['Kode WO'] ?? ''}',
        kodeUiw: '${r['Kode UIW'] ?? ''}',
        kodeUp3: '${r['Kode UP3'] ?? ''}',
        kodeUlp: '${r['Kode ULP'] ?? ''}',
        ulp: '${r['ULP'] ?? ''}',
        hari: '${r['Hari'] ?? ''}',
        tanggal: '${r['Tanggal'] ?? ''}',
        penyulang: '${r['Penyulang'] ?? ''}',
        section: '${r['Section'] ?? ''}',
        nomorGardu: '${r['Nomor Gardu'] ?? r['Gardu'] ?? ''}',
        kodeTemuan: '${r['Kode Temuan'] ?? ''}',
        kodeWoInspeksi: '${r['Kode WO Inspeksi'] ?? ''}',
        jenisObject: '${r['Jenis Object'] ?? ''}',
        tier: '${r['Tier'] ?? ''}',
        temuan: '${r['Temuan'] ?? ''}',
        prioritas: '${r['Prioritas'] ?? ''}',
        pekerjaan: '${r['Pekerjaan (Padam / Tanpa Padam)'] ?? r['Pekerjaan'] ?? ''}',
        jenisWo: '${r['Jenis WO'] ?? ''}',
        koordinat: '${r['Koordinat'] ?? ''}',
        lat: _tryDouble(r['Lat']),
        long: _tryDouble(r['Long']),
        linkFotoTemuan: '${r['Link Foto Temuan'] ?? ''}',
        linkFotoTiangSekitar: '${r['Link Foto Tiang Sekitar'] ?? ''}',
        linkFotoSesudah: '${r['Link Foto Sesudah'] ?? ''}',
        catatanPetugas: '${r['Catatan Petugas'] ?? ''}',
        timEksekusi: '${r['Tim Eksekusi'] ?? ''}',
        tanggalPenugasan: '${r['Tanggal Penugasan'] ?? ''}',
        catatanKoordinator: '${r['Catatan Koordinator / TL'] ?? r['Catatan Koordinator'] ?? ''}',
        namaKoordinator: '${r['Nama Koordinator'] ?? ''}',
        statusWo: normalisasiStatus(r['Status WO']),
        userInput: '${r['User Input'] ?? ''}',
        waktuInput: '${r['Waktu Input'] ?? ''}',
        waktuSelesai: '${r['Waktu Selesai'] ?? ''}',
        durasi: '${r['Durasi'] ?? ''}',
        folderPath: '${r['Folder Path'] ?? ''}',
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'no': no,
        'kode_wo': kodeWo,
        'kode_uiw': kodeUiw,
        'kode_up3': kodeUp3,
        'kode_ulp': kodeUlp,
        'ulp': ulp,
        'hari': hari,
        'tanggal': tanggal,
        'penyulang': penyulang,
        'section': section,
        'nomor_gardu': nomorGardu,
        'kode_temuan': kodeTemuan,
        'kode_wo_inspeksi': kodeWoInspeksi,
        'jenis_object': jenisObject,
        'tier': tier,
        'temuan': temuan,
        'prioritas': prioritas,
        'pekerjaan': pekerjaan,
        'jenis_wo': jenisWo,
        'koordinat': koordinat,
        'lat': lat,
        'long': long,
        'foto_temuan': fotoTemuan,
        'link_foto_temuan': linkFotoTemuan,
        'foto_tiang_sekitar': fotoTiangSekitar,
        'link_foto_tiang_sekitar': linkFotoTiangSekitar,
        'foto_sesudah': fotoSesudah,
        'link_foto_sesudah': linkFotoSesudah,
        'catatan_petugas': catatanPetugas,
        'tim_eksekusi': timEksekusi,
        'tanggal_penugasan': tanggalPenugasan,
        'catatan_koordinator': catatanKoordinator,
        'nama_koordinator': namaKoordinator,
        'status_wo': normalisasiStatus(statusWo),
        'user_input': userInput,
        'waktu_input': waktuInput,
        'waktu_selesai': waktuSelesai,
        'durasi': durasi,
        'folder_path': folderPath,
        'is_synced': isSynced ? 1 : 0,
      };

  Map<String, dynamic> toRemote() => {
        'No': no,
        'Kode WO': kodeWo,
        'Kode UIW': kodeUiw,
        'Kode UP3': kodeUp3,
        'Kode ULP': kodeUlp,
        'ULP': ulp,
        'Hari': hari,
        'Tanggal': tanggal,
        'Penyulang': penyulang,
        'Section': section,
        'Nomor Gardu': nomorGardu,
        'Kode Temuan': kodeTemuan,
        'Kode WO Inspeksi': kodeWoInspeksi,
        'Jenis Object': jenisObject,
        'Tier': tier,
        'Temuan': temuan,
        'Prioritas': prioritas,
        'Pekerjaan (Padam / Tanpa Padam)': pekerjaan,
        'Jenis WO': jenisWo,
        'Koordinat': koordinat,
        'Lat': lat,
        'Long': long,
        'Foto Sesudah': fotoSesudah,
        'Link Foto Sesudah': linkFotoSesudah,
        'Catatan Petugas': catatanPetugas,
        'Tim Eksekusi': timEksekusi,
        'Tanggal Penugasan': tanggalPenugasan,
        'Catatan Koordinator / TL': catatanKoordinator,
        'Nama Koordinator': namaKoordinator,
        'Status WO': normalisasiStatus(statusWo),
        'User Input': userInput,
        'Waktu Input': waktuInput,
        'Waktu Selesai': waktuSelesai,
        'Durasi': durasi,
        'Folder Path': folderPath,
      };
}
