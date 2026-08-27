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
  final bool isDirty;

  const WoInsjar({
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
    this.sectionAwal = '',
    this.sectionAkhir = '',
    this.section = '',
    this.koordinatAwal = '',
    this.koordinatAkhir = '',
    this.realisasiKms,
    this.waktuMulai = '',
    this.waktuSelesai = '',
    this.durasiPekerjaan = '',
    this.statusWo = 'Belum Dikerjakan',
    this.isDirty = false,
  });

  static const hariIndonesia = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

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
        isDirty: map['is_dirty'] == 1,
      );

  factory WoInsjar.fromRemote(Map<String, dynamic> row) {
    double? parseKms(Object? value) {
      final text = '${value ?? ''}'.replaceAll(',', '.').trim();
      return text.isEmpty ? null : double.tryParse(text);
    }

    String pick(List<String> keys) {
      for (final key in keys) {
        final value = '${row[key] ?? ''}'.trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return WoInsjar(
      no: pick(['No', 'no']),
      kodeWo: pick(['Kode WO', 'kodeWo']),
      kodeUiw: pick(['Kode UIW', 'kodeUiw']),
      kodeUp3: pick(['Kode UP3', 'kodeUp3']),
      kodeUlp: pick(['Kode ULP', 'kodeUlp']),
      ulp: pick(['ULP', 'ulp']),
      hari: pick(['Hari', 'hari']),
      tanggal: pick(['Tanggal', 'tanggal']),
      penyulang: pick(['Penyulang', 'penyulang']),
      sectionAwal: pick(['Section Awal', 'sectionAwal']),
      sectionAkhir: pick(['Section Akhir', 'sectionAkhir']),
      section: pick(['Section', 'section']),
      koordinatAwal: pick(['Koordinat Awal', 'koordinatAwal']),
      koordinatAkhir: pick(['Koordinat Akhir', 'koordinatAkhir']),
      realisasiKms: parseKms(row['Realisasi kmS'] ?? row['realisasiKms']),
      waktuMulai: pick(['Waktu Mulai', 'waktuMulai']),
      waktuSelesai: pick(['Waktu Selesai', 'waktuSelesai']),
      durasiPekerjaan: pick(['Durasi Pekerjaan', 'durasiPekerjaan']),
      statusWo: pick(['Status WO', 'statusWo']),
    );
  }

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
        'is_dirty': isDirty ? 1 : 0,
      };

  Map<String, dynamic> toRemote() => {
        'Kode WO': kodeWo,
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
        'Koordinat Awal': koordinatAwal,
        'Koordinat Akhir': koordinatAkhir,
        'Realisasi kmS': realisasiKms?.toStringAsFixed(3) ?? '',
        'Waktu Mulai': waktuMulai,
        'Waktu Selesai': waktuSelesai,
        'Durasi Pekerjaan': durasiPekerjaan,
        'Status WO': statusWo,
      };

  WoInsjar copyWith({
    String? penyulang,
    String? sectionAwal,
    String? sectionAkhir,
    String? section,
    String? koordinatAwal,
    String? koordinatAkhir,
    double? realisasiKms,
    String? waktuMulai,
    String? waktuSelesai,
    String? durasiPekerjaan,
    String? statusWo,
    bool? isDirty,
  }) {
    return WoInsjar(
      id: id,
      no: no,
      kodeWo: kodeWo,
      kodeUiw: kodeUiw,
      kodeUp3: kodeUp3,
      kodeUlp: kodeUlp,
      ulp: ulp,
      hari: hari,
      tanggal: tanggal,
      penyulang: penyulang ?? this.penyulang,
      sectionAwal: sectionAwal ?? this.sectionAwal,
      sectionAkhir: sectionAkhir ?? this.sectionAkhir,
      section: section ?? this.section,
      koordinatAwal: koordinatAwal ?? this.koordinatAwal,
      koordinatAkhir: koordinatAkhir ?? this.koordinatAkhir,
      realisasiKms: realisasiKms ?? this.realisasiKms,
      waktuMulai: waktuMulai ?? this.waktuMulai,
      waktuSelesai: waktuSelesai ?? this.waktuSelesai,
      durasiPekerjaan: durasiPekerjaan ?? this.durasiPekerjaan,
      statusWo: statusWo ?? this.statusWo,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  /// Format lengkap tanggal dan waktu: 27/08/2026 14:35:07
  static String stampLengkap(DateTime value) {
    String two(int input) => input.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  /// Format durasi HH:mm:ss dari selisih dua stempel waktu.
  static String hitungDurasi(DateTime mulai, DateTime selesai) {
    final diff = selesai.difference(mulai);
    if (diff.isNegative) return '00:00:00';
    String two(int input) => input.toString().padLeft(2, '0');
    return '${two(diff.inHours)}:${two(diff.inMinutes % 60)}:${two(diff.inSeconds % 60)}';
  }

  static DateTime? parseStamp(String value) {
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})\s+(\d{2}):(\d{2}):(\d{2})$')
        .firstMatch(value.trim());
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }
}
