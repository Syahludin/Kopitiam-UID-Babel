class WoYandalP0 {
  static const statusMenunggu = 'Menunggu';
  static const statusSedang = 'Sedang Dikerjakan';
  static const statusSelesai = 'Selesai';
  static const statusTersinkron = 'Tersinkron';

  final int? id;
  final String no;
  final String kodeWo;
  final String kodeTemuan;
  final String kodeUiw;
  final String kodeUp3;
  final String up3;
  final String kodeUlp;
  final String ulp;
  final String hari;
  final String tanggal;
  final String jenisP0;
  final String penyulang;
  final String section;
  final String segmen;
  final String nomorGardu;
  final String jenisObject;
  final String tier;
  final String temuan;
  final String prioritas;
  final String koordinat;
  final double? lat;
  final double? long;
  final String fotoTemuan;
  final String linkFoto;
  final String fotoLingkungan;
  final String linkLingkungan;
  final String fotoTindakLanjut;
  final String linkFotoTindakLanjut;
  final String tindakLanjut;
  final String reguYantek;
  final String nomorHp;
  final String catatan;
  final String statusWo;
  final String dibuatOleh;
  final String diteruskanOleh;
  final String waktuMulai;
  final String waktuSelesai;
  final String durasi;
  final String folderPath;
  final bool isSynced;

  const WoYandalP0({
    this.id,
    this.no = '',
    required this.kodeWo,
    this.kodeTemuan = '',
    this.kodeUiw = '',
    this.kodeUp3 = '',
    this.up3 = '',
    this.kodeUlp = '',
    this.ulp = '',
    this.hari = '',
    this.tanggal = '',
    this.jenisP0 = '',
    this.penyulang = '',
    this.section = '',
    this.segmen = '',
    this.nomorGardu = '',
    this.jenisObject = '',
    this.tier = '',
    this.temuan = '',
    this.prioritas = '',
    this.koordinat = '',
    this.lat,
    this.long,
    this.fotoTemuan = '',
    this.linkFoto = '',
    this.fotoLingkungan = '',
    this.linkLingkungan = '',
    this.fotoTindakLanjut = '',
    this.linkFotoTindakLanjut = '',
    this.tindakLanjut = '',
    this.reguYantek = '',
    this.nomorHp = '',
    this.catatan = '',
    this.statusWo = statusMenunggu,
    this.dibuatOleh = '',
    this.diteruskanOleh = '',
    this.waktuMulai = '',
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
        status == 'dalam pengerjaan' ||
        status == 'sedang dikerjakan') {
      return statusSedang;
    }
    return statusMenunggu;
  }

  static double? _tryDouble(Object? value) {
    final text = '${value ?? ''}'.replaceAll(',', '.').trim();
    return text.isEmpty ? null : double.tryParse(text);
  }

  factory WoYandalP0.fromMap(Map<String, Object?> m) => WoYandalP0(
        id: m['id'] as int?,
        no: '${m['no'] ?? ''}',
        kodeWo: '${m['kode_wo'] ?? ''}',
        kodeTemuan: '${m['kode_temuan'] ?? ''}',
        kodeUiw: '${m['kode_uiw'] ?? ''}',
        kodeUp3: '${m['kode_up3'] ?? ''}',
        up3: '${m['up3'] ?? ''}',
        kodeUlp: '${m['kode_ulp'] ?? ''}',
        ulp: '${m['ulp'] ?? ''}',
        hari: '${m['hari'] ?? ''}',
        tanggal: '${m['tanggal'] ?? ''}',
        jenisP0: '${m['jenis_p0'] ?? ''}',
        penyulang: '${m['penyulang'] ?? ''}',
        section: '${m['section'] ?? ''}',
        segmen: '${m['segmen'] ?? ''}',
        nomorGardu: '${m['nomor_gardu'] ?? ''}',
        jenisObject: '${m['jenis_object'] ?? ''}',
        tier: '${m['tier'] ?? ''}',
        temuan: '${m['temuan'] ?? ''}',
        prioritas: '${m['prioritas'] ?? ''}',
        koordinat: '${m['koordinat'] ?? ''}',
        lat: (m['lat'] as num?)?.toDouble(),
        long: (m['long'] as num?)?.toDouble(),
        fotoTemuan: '${m['foto_temuan'] ?? ''}',
        linkFoto: '${m['link_foto'] ?? ''}',
        fotoLingkungan: '${m['foto_lingkungan'] ?? ''}',
        linkLingkungan: '${m['link_lingkungan'] ?? ''}',
        fotoTindakLanjut: '${m['foto_tindak_lanjut'] ?? ''}',
        linkFotoTindakLanjut: '${m['link_foto_tindak_lanjut'] ?? ''}',
        tindakLanjut: '${m['tindak_lanjut'] ?? ''}',
        reguYantek: '${m['regu_yantek'] ?? ''}',
        nomorHp: '${m['nomor_hp'] ?? ''}',
        catatan: '${m['catatan'] ?? ''}',
        statusWo: normalisasiStatus(m['status_wo']),
        dibuatOleh: '${m['dibuat_oleh'] ?? ''}',
        diteruskanOleh: '${m['diteruskan_oleh'] ?? ''}',
        waktuMulai: '${m['waktu_mulai'] ?? ''}',
        waktuSelesai: '${m['waktu_selesai'] ?? ''}',
        durasi: '${m['durasi'] ?? ''}',
        folderPath: '${m['folder_path'] ?? ''}',
        isSynced: m['is_synced'] == 1,
      );

  factory WoYandalP0.fromRemote(Map<String, dynamic> r) => WoYandalP0(
        no: '${r['No'] ?? ''}',
        kodeWo: '${r['Kode WO'] ?? ''}',
        kodeTemuan: '${r['Kode Temuan'] ?? ''}',
        kodeUiw: '${r['Kode UIW'] ?? ''}',
        kodeUp3: '${r['Kode UP3'] ?? ''}',
        up3: '${r['UP3'] ?? ''}',
        kodeUlp: '${r['Kode ULP'] ?? ''}',
        ulp: '${r['ULP'] ?? ''}',
        hari: '${r['Hari'] ?? ''}',
        tanggal: '${r['Tanggal'] ?? ''}',
        jenisP0: '${r['Jenis P0'] ?? ''}',
        penyulang: '${r['Penyulang'] ?? ''}',
        section: '${r['Section'] ?? ''}',
        segmen: '${r['Segmen'] ?? ''}',
        nomorGardu: '${r['Nomor Gardu'] ?? r['Gardu'] ?? ''}',
        jenisObject: '${r['Jenis Object'] ?? ''}',
        tier: '${r['Tier'] ?? ''}',
        temuan: '${r['Temuan'] ?? ''}',
        prioritas: '${r['Prioritas'] ?? ''}',
        koordinat: '${r['Koordinat'] ?? ''}',
        lat: _tryDouble(r['Lat']),
        long: _tryDouble(r['Long']),
        fotoTemuan: '${r['Foto Temuan'] ?? ''}',
        linkFoto: '${r['Link Foto'] ?? ''}',
        fotoLingkungan: '${r['Foto Lingkungan Sekitaran Tiang'] ?? ''}',
        linkLingkungan: '${r['Link Foto Sekitaran Tiang'] ?? ''}',
        fotoTindakLanjut: '${r['Foto Tindak Lanjut'] ?? ''}',
        linkFotoTindakLanjut: '${r['Link Foto Tindak Lanjut'] ?? ''}',
        tindakLanjut: '${r['Tindak Lanjut'] ?? ''}',
        reguYantek: '${r['Regu Yantek'] ?? ''}',
        nomorHp: '${r['Nomor HP'] ?? ''}',
        catatan: '${r['Catatan'] ?? ''}',
        statusWo: normalisasiStatus(r['Status WO']),
        dibuatOleh: '${r['Dibuat Oleh'] ?? ''}',
        diteruskanOleh: '${r['Diteruskan Oleh'] ?? ''}',
        waktuMulai: '${r['Waktu Mulai'] ?? ''}',
        waktuSelesai: '${r['Waktu Selesai'] ?? ''}',
        durasi: '${r['Durasi'] ?? ''}',
        folderPath: '${r['Folder Path'] ?? ''}',
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'no': no,
        'kode_wo': kodeWo,
        'kode_temuan': kodeTemuan,
        'kode_uiw': kodeUiw,
        'kode_up3': kodeUp3,
        'up3': up3,
        'kode_ulp': kodeUlp,
        'ulp': ulp,
        'hari': hari,
        'tanggal': tanggal,
        'jenis_p0': jenisP0,
        'penyulang': penyulang,
        'section': section,
        'segmen': segmen,
        'nomor_gardu': nomorGardu,
        'jenis_object': jenisObject,
        'tier': tier,
        'temuan': temuan,
        'prioritas': prioritas,
        'koordinat': koordinat,
        'lat': lat,
        'long': long,
        'foto_temuan': fotoTemuan,
        'link_foto': linkFoto,
        'foto_lingkungan': fotoLingkungan,
        'link_lingkungan': linkLingkungan,
        'foto_tindak_lanjut': fotoTindakLanjut,
        'link_foto_tindak_lanjut': linkFotoTindakLanjut,
        'tindak_lanjut': tindakLanjut,
        'regu_yantek': reguYantek,
        'nomor_hp': nomorHp,
        'catatan': catatan,
        'status_wo': normalisasiStatus(statusWo),
        'dibuat_oleh': dibuatOleh,
        'diteruskan_oleh': diteruskanOleh,
        'waktu_mulai': waktuMulai,
        'waktu_selesai': waktuSelesai,
        'durasi': durasi,
        'folder_path': folderPath,
        'is_synced': isSynced ? 1 : 0,
      };

  Map<String, dynamic> toRemote() => {
        'No': no,
        'Kode WO': kodeWo,
        'Kode Temuan': kodeTemuan,
        'Kode UIW': kodeUiw,
        'Kode UP3': kodeUp3,
        'UP3': up3,
        'Kode ULP': kodeUlp,
        'ULP': ulp,
        'Hari': hari,
        'Tanggal': tanggal,
        'Jenis P0': jenisP0,
        'Penyulang': penyulang,
        'Section': section,
        'Segmen': segmen,
        'Nomor Gardu': nomorGardu,
        'Jenis Object': jenisObject,
        'Tier': tier,
        'Temuan': temuan,
        'Prioritas': prioritas,
        'Koordinat': koordinat,
        'Lat': lat,
        'Long': long,
        'Foto Tindak Lanjut': fotoTindakLanjut,
        'Link Foto Tindak Lanjut': linkFotoTindakLanjut,
        'Tindak Lanjut': tindakLanjut,
        'Regu Yantek': reguYantek,
        'Nomor HP': nomorHp,
        'Catatan': catatan,
        'Status WO': normalisasiStatus(statusWo),
        'Waktu Mulai': waktuMulai,
        'Waktu Selesai': waktuSelesai,
        'Durasi': durasi,
        'Folder Path': folderPath,
      };
}
