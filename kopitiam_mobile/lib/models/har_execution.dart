import 'dart:convert';
import 'dart:math';

/// New execution contract; legacy WO models remain available to old routes.
class HarExecution {
  static const progress = 'Progress Pekerjaan';
  static const done = 'Selesai';
  static const jar = 'WO Har Jar';
  static const du = 'WO Har Du';
  final Map<String, dynamic> header;
  final List<Map<String, dynamic>> jobs;
  final List<Map<String, dynamic>> materials;
  final String photo;
  final String error;
  final bool dirty;
  final int revision;
  HarExecution({required this.header, this.jobs = const [], this.materials = const [], this.photo = '', this.error = '', this.dirty = false, this.revision = 0});
  String value(String key) => '${header[key] ?? ''}';
  String get code => value('Kode WO');
  String get type => value('Jenis WO');
  String get status => value('Status WO');
  bool get finished => [done.toLowerCase(), 'tersinkron'].contains(status.toLowerCase());
  bool get started => value('Waktu Mulai').isNotEmpty || [progress.toLowerCase(), 'sedang dikerjakan', 'dalam pengerjaan'].contains(status.toLowerCase()) || finished;
  HarExecution change({Map<String, dynamic>? header, List<Map<String, dynamic>>? jobs, List<Map<String, dynamic>>? materials, String? photo, String? error, bool? dirty, int? revision}) => HarExecution(header: header ?? Map.of(this.header), jobs: jobs ?? this.jobs, materials: materials ?? this.materials, photo: photo ?? this.photo, error: error ?? this.error, dirty: dirty ?? this.dirty, revision: revision ?? this.revision);
  Map<String, dynamic> toJson() => {'header': header, 'jobs': jobs, 'materials': materials, 'photo': photo, 'error': error, 'dirty': dirty, 'revision': revision};
  factory HarExecution.decode(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    List<Map<String, dynamic>> rows(String key) => (data[key] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return HarExecution(header: Map<String, dynamic>.from(data['header'] as Map), jobs: rows('jobs'), materials: rows('materials'), photo: '${data['photo'] ?? ''}', error: '${data['error'] ?? ''}', dirty: data['dirty'] == true, revision: (data['revision'] as num?)?.toInt() ?? 0);
  }
  static const inherited = ['Kode Temuan','Kode UIW','Kode UP3','Kode ULP','ULP','Hari','Tanggal','Penyulang','Section','Segmen','Nomor Gardu','Jenis Object','Tier','Temuan','Prioritas','Jenis WO','Koordinat','Lat','Long'];
  Map<String, dynamic> lineage() => {for (final k in inherited) k: header[k] ?? '', 'Kode WO': code};
  static String newId(String prefix) {
    final random = Random.secure();
    return '$prefix-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  }
  static List<String> allowedTypes(Map<String, dynamic> session) {
    final team = '${session['subTim'] ?? session['tim'] ?? ''}'.trim().toLowerCase();
    final userParts = '${session['username'] ?? ''}'.toLowerCase().split(RegExp(r'[.\s_-]+'));
    if (['har', 'hartek', 'har teknik'].contains(team) || userParts.contains('hartek') || userParts.contains('har')) return [jar, du];
    if (['har jar', 'harjar', 'har jaringan'].contains(team) || userParts.contains('harjar')) return [jar];
    if (['har du', 'hardu', 'har gardu'].contains(team) || userParts.contains('hardu')) return [du];
    return [];
  }
}

class HarMaterial {
  final String code, name, unit, rowStatus;
  const HarMaterial(this.code, this.name, this.unit, this.rowStatus);
  factory HarMaterial.fromMap(Map<String, dynamic> row) => HarMaterial('${row['Kode Material'] ?? ''}'.trim(), '${row['Nama Material'] ?? ''}'.trim(), '${row['Satuan Material'] ?? ''}'.trim(), '${row['Status Baris'] ?? ''}'.trim());
  // Preserve unspecified status semantics; explicitly inactive/deleted rows are excluded.
  bool get available => code.isNotEmpty && name.isNotEmpty && unit.isNotEmpty && !['nonaktif','tidak aktif','inactive','deleted','hapus','0','false'].contains(rowStatus.toLowerCase());
  static const ownership = ['PLN','Mitra','Bongkaran'];
}
