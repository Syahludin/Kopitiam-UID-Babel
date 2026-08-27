class WoInsjar {
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
  final String sectionAwal;
  final String sectionAkhir;
  final String section;
  final String koordinatAwal;
  final String koordinatAkhir;
  final double? realisasiKms;
  final String waktuMulai;
  final String waktuSelesai;
  final String durasiPekerjaan;
  final String statusWo;

  const WoInsjar({
    this.id,
    required this.no,
    required this.kodeWo,
    required this.kodeUiw,
    required this.kodeUp3,
    required this.kodeUlp,
    required this.ulp,
    required this.hari,
    required this.tanggal,
    required this.penyulang,
    required this.sectionAwal,
    required this.sectionAkhir,
    required this.section,
    required this.koordinatAwal,
    required this.koordinatAkhir,
    this.realisasiKms,
    required this.waktuMulai,
    required this.waktuSelesai,
    required this.durasiPekerjaan,
    required this.statusWo,
  });

  factory WoInsjar.fromMap(Map<String, Object?> map) => WoInsjar(
        id: map['id'] as int?,
        no: '${map['no'] ?? ''}',
        kodeWo: '${map['kode_wo'] ?? ''}',
        kodeUiw: '${map['kode_uiw'] ?? ''}',
        kodeUp3: '${map['kode_up3'] ?? ''}',
        kodeUlp: '${map['kode_ulp'] ?? ''}',
        ulp: '${map['ulp'] ?? ''}',
        hari: '${map['hari'] ?? ''}',
        tanggal: '${map['tanggal'] ?? ''}',
        penyulang: '${map['penyulang'] ?? ''}',
        sectionAwal: '${map['section_awal'] ?? ''}',
        sectionAkhir: '${map['section_akhir'] ?? ''}',
        section: '${map['section'] ?? ''}',
        koordinatAwal: '${map['koordinat_awal'] ?? ''}',
        koordinatAkhir: '${map['koordinat_akhir'] ?? ''}',
        realisasiKms: (map['realisasi_kms'] as num?)?.toDouble(),
        waktuMulai: '${map['waktu_mulai'] ?? ''}',
        waktuSelesai: '${map['waktu_selesai'] ?? ''}',
        durasiPekerjaan: '${map['durasi_pekerjaan'] ?? ''}',
        statusWo: '${map['status_wo'] ?? ''}',
      );

  factory WoInsjar.fromRemote(Map<String, dynamic> row) => WoInsjar(
        no: '${row['No'] ?? row['no'] ?? ''}',
        kodeWo: '${row['Kode WO'] ?? row['kodeWo'] ?? ''}',
        kodeUiw: '${row['Kode UIW'] ?? row['kodeUiw'] ?? ''}',
        kodeUp3: '${row['Kode UP3'] ?? row['kodeUp3'] ?? ''}',
        kodeUlp: '${row['Kode ULP'] ?? row['kodeUlp'] ?? ''}',
        ulp: '${row['ULP'] ?? row['ulp'] ?? ''}',
        hari: '${row['Hari'] ?? row['hari'] ?? ''}',
        tanggal: '${row['Tanggal'] ?? row['tanggal'] ?? ''}',
        penyulang: '${row['Penyulang'] ?? row['penyulang'] ?? ''}',
        sectionAwal: '${row['Section Awal'] ?? row['sectionAwal'] ?? ''}',
        sectionAkhir: '${row['Section Akhir'] ?? row['sectionAkhir'] ?? ''}',
        section: '${row['Section'] ?? row['section'] ?? ''}',
        koordinatAwal: '${row['Koordinat Awal'] ?? row['koordinatAwal'] ?? ''}',
        koordinatAkhir: '${row['Koordinat Akhir'] ?? row['koordinatAkhir'] ?? ''}',
        realisasiKms: double.tryParse('${row['Realisasi kmS'] ?? row['realisasiKms'] ?? ''}'),
        waktuMulai: '${row['Waktu Mulai'] ?? row['waktuMulai'] ?? ''}',
        waktuSelesai: '${row['Waktu Selesai'] ?? row['waktuSelesai'] ?? ''}',
        durasiPekerjaan: '${row['Durasi Pekerjaan'] ?? row['durasiPekerjaan'] ?? ''}',
        statusWo: '${row['Status WO'] ?? row['statusWo'] ?? ''}',
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'no': no,
        'kode_wo': kodeWo,
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
        'koordinat_awal': koordinatAwal,
        'koordinat_akhir': koordinatAkhir,
        'realisasi_kms': realisasiKms,
        'waktu_mulai': waktuMulai,
        'waktu_selesai': waktuSelesai,
        'durasi_pekerjaan': durasiPekerjaan,
        'status_wo': statusWo,
      };
}
