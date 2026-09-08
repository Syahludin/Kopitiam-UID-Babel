class TemuanInspeksi {
  static const statusDraft = 'draft';
  static const statusQueued = 'queued';
  static const statusSending = 'sending';
  static const statusSynced = 'synced';
  static const statusFailed = 'failed';

  final String kodeTemuan, kodeWo, kodeUiw, kodeUp3, kodeUlp, ulp;
  final String hari, tanggal, penyulang, sectionAwal, sectionAkhir, section;
  final String segmen, nomorGardu, koordinat, lat, long, jenisObject, tier, temuan;
  final double? jarak, tinggiPohon;
  final String jenisPohon, prioritas, pekerjaan, jenisWo;
  final String fotoTemuan, fotoLingkungan, linkFoto, linkLingkungan;
  final String waktuInput, userInput, folderPath;
  final bool dirty;
  final String syncStatus, syncError, lastAttemptAt;
  final int retryCount;

  const TemuanInspeksi({
    required this.kodeTemuan,
    required this.kodeWo,
    this.kodeUiw = '', this.kodeUp3 = '', this.kodeUlp = '', this.ulp = '',
    this.hari = '', this.tanggal = '', this.penyulang = '',
    this.sectionAwal = '', this.sectionAkhir = '', this.section = '',
    this.segmen = '', this.nomorGardu = '', this.koordinat = '',
    this.lat = '', this.long = '', this.jenisObject = '', this.tier = '',
    this.temuan = '', this.jarak, this.jenisPohon = '', this.tinggiPohon,
    this.prioritas = '', this.pekerjaan = '', this.jenisWo = '',
    this.fotoTemuan = '', this.fotoLingkungan = '', this.linkFoto = '',
    this.linkLingkungan = '', this.waktuInput = '', this.userInput = '',
    this.folderPath = '', this.dirty = true,
    this.syncStatus = statusDraft, this.syncError = '', this.retryCount = 0,
    this.lastAttemptAt = '',
  });

  static String normalizeSyncStatus(Object? value, {required bool dirty}) {
    final status = '${value ?? ''}'.trim().toLowerCase();
    if (!dirty) return statusSynced;
    if ({statusDraft, statusQueued, statusSending, statusFailed}.contains(status)) {
      return status == statusSending ? statusQueued : status;
    }
    return statusQueued;
  }

  factory TemuanInspeksi.fromMap(Map<String, Object?> m) {
    final dirty = m['is_dirty'] == 1;
    return TemuanInspeksi(
      kodeTemuan: '${m['kode_temuan'] ?? ''}', kodeWo: '${m['kode_wo'] ?? ''}',
      kodeUiw: '${m['kode_uiw'] ?? ''}', kodeUp3: '${m['kode_up3'] ?? ''}',
      kodeUlp: '${m['kode_ulp'] ?? ''}', ulp: '${m['ulp'] ?? ''}',
      hari: '${m['hari'] ?? ''}', tanggal: '${m['tanggal'] ?? ''}',
      penyulang: '${m['penyulang'] ?? ''}', sectionAwal: '${m['section_awal'] ?? ''}',
      sectionAkhir: '${m['section_akhir'] ?? ''}', section: '${m['section'] ?? ''}',
      segmen: '${m['segmen'] ?? ''}', nomorGardu: '${m['nomor_gardu'] ?? ''}',
      koordinat: '${m['koordinat'] ?? ''}', lat: '${m['lat'] ?? ''}', long: '${m['long'] ?? ''}',
      jenisObject: '${m['jenis_object'] ?? ''}', tier: '${m['tier'] ?? ''}',
      temuan: '${m['temuan'] ?? ''}', jarak: (m['jarak'] as num?)?.toDouble(),
      jenisPohon: '${m['jenis_pohon'] ?? ''}', tinggiPohon: (m['tinggi_pohon'] as num?)?.toDouble(),
      prioritas: '${m['prioritas'] ?? ''}', pekerjaan: '${m['pekerjaan'] ?? ''}',
      jenisWo: '${m['jenis_wo'] ?? ''}', fotoTemuan: '${m['foto_temuan'] ?? ''}',
      fotoLingkungan: '${m['foto_lingkungan'] ?? ''}', linkFoto: '${m['link_foto'] ?? ''}',
      linkLingkungan: '${m['link_lingkungan'] ?? ''}', waktuInput: '${m['waktu_input'] ?? ''}',
      userInput: '${m['user_input'] ?? ''}', folderPath: '${m['folder_path'] ?? ''}', dirty: dirty,
      syncStatus: normalizeSyncStatus(m['sync_status'], dirty: dirty),
      syncError: '${m['sync_error'] ?? ''}', retryCount: (m['retry_count'] as num?)?.toInt() ?? 0,
      lastAttemptAt: '${m['last_attempt_at'] ?? ''}',
    );
  }

  factory TemuanInspeksi.fromRemote(Map<String, dynamic> r) => TemuanInspeksi(
    kodeTemuan: '${r['Kode Temuan'] ?? ''}', kodeWo: '${r['Kode WO'] ?? ''}',
    kodeUiw: '${r['Kode UIW'] ?? ''}', kodeUp3: '${r['Kode UP3'] ?? ''}',
    kodeUlp: '${r['Kode ULP'] ?? ''}', ulp: '${r['ULP'] ?? ''}', hari: '${r['Hari'] ?? ''}',
    tanggal: '${r['Tanggal'] ?? ''}', penyulang: '${r['Penyulang'] ?? ''}',
    sectionAwal: '${r['Section Awal'] ?? ''}', sectionAkhir: '${r['Section Akhir'] ?? ''}',
    section: '${r['Section'] ?? ''}', segmen: '${r['Segmen'] ?? ''}',
    nomorGardu: '${r['Nomor Gardu'] ?? ''}', koordinat: '${r['Koordinat Temuan'] ?? ''}',
    lat: '${r['Lat Temuan'] ?? ''}', long: '${r['Long Temuan'] ?? ''}',
    jenisObject: '${r['Jenis Object'] ?? ''}', tier: '${r['Tier'] ?? ''}', temuan: '${r['Temuan'] ?? ''}',
    jarak: double.tryParse('${r['Jarak Terhadap Jaringan'] ?? ''}'.replaceAll(',', '.')),
    jenisPohon: '${r['Jenis Pohon'] ?? ''}',
    tinggiPohon: double.tryParse('${r['Tinggi Pohon'] ?? ''}'.replaceAll(',', '.')),
    prioritas: '${r['Prioritas'] ?? ''}', pekerjaan: '${r['Pekerjaan (Padam / Tanpa Padam)'] ?? ''}',
    jenisWo: '${r['Jenis WO'] ?? ''}', linkFoto: '${r['Link Foto'] ?? ''}',
    linkLingkungan: '${r['Link Foto Sekitaran Tiang'] ?? ''}', waktuInput: '${r['Waktu Input'] ?? ''}',
    userInput: '${r['User Input'] ?? ''}', folderPath: '${r['Folder Path'] ?? ''}', dirty: false,
    syncStatus: statusSynced,
  );

  Map<String, Object?> toMap() => {
    'kode_temuan': kodeTemuan, 'kode_wo': kodeWo, 'kode_uiw': kodeUiw,
    'kode_up3': kodeUp3, 'kode_ulp': kodeUlp, 'ulp': ulp, 'hari': hari,
    'tanggal': tanggal, 'penyulang': penyulang, 'section_awal': sectionAwal,
    'section_akhir': sectionAkhir, 'section': section, 'segmen': segmen,
    'nomor_gardu': nomorGardu, 'koordinat': koordinat, 'lat': lat, 'long': long,
    'jenis_object': jenisObject, 'tier': tier, 'temuan': temuan, 'jarak': jarak,
    'jenis_pohon': jenisPohon, 'tinggi_pohon': tinggiPohon, 'prioritas': prioritas,
    'pekerjaan': pekerjaan, 'jenis_wo': jenisWo, 'foto_temuan': fotoTemuan,
    'foto_lingkungan': fotoLingkungan, 'link_foto': linkFoto,
    'link_lingkungan': linkLingkungan, 'waktu_input': waktuInput,
    'user_input': userInput, 'folder_path': folderPath, 'is_dirty': dirty ? 1 : 0,
    'sync_status': normalizeSyncStatus(syncStatus, dirty: dirty),
    'sync_error': syncError, 'retry_count': retryCount, 'last_attempt_at': lastAttemptAt,
  };

  Map<String, dynamic> toRemote() => {
    'Kode UIW': kodeUiw, 'Kode UP3': kodeUp3, 'Kode ULP': kodeUlp, 'ULP': ulp,
    'Kode WO': kodeWo, 'Kode Temuan': kodeTemuan, 'Hari': hari, 'Tanggal': tanggal,
    'Penyulang': penyulang, 'Section Awal': sectionAwal, 'Section Akhir': sectionAkhir,
    'Section': section, 'Segmen': segmen, 'Nomor Gardu': nomorGardu,
    'Koordinat Temuan': koordinat, 'Lat Temuan': lat, 'Long Temuan': long,
    'Jenis Object': jenisObject, 'Tier': tier, 'Temuan': temuan,
    'Jarak Terhadap Jaringan': jarak, 'Jenis Pohon': jenisPohon,
    'Tinggi Pohon': tinggiPohon, 'Prioritas': prioritas,
    'Pekerjaan (Padam / Tanpa Padam)': pekerjaan, 'Foto Temuan': fotoTemuan,
    'Link Foto': linkFoto, 'Foto Lingkungan Sekitaran Tiang': fotoLingkungan,
    'Link Foto Sekitaran Tiang': linkLingkungan, 'Jenis WO': jenisWo,
    'Waktu Input': waktuInput, 'User Input': userInput, 'Folder Path': folderPath,
  };
}
