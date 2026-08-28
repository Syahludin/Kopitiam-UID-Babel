import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/temuan_inspeksi.dart';
import '../models/wo_insjar.dart';
import '../services/high_accuracy_location_service.dart';
import '../services/temuan_repository.dart';
import 'landscape_camera_screen.dart';

class TemuanTab extends StatefulWidget {
  final WoInsjar wo;
  final Map<String, dynamic> sesi;

  const TemuanTab({super.key, required this.wo, required this.sesi});

  @override
  State<TemuanTab> createState() => _TemuanTabState();
}

class _TemuanTabState extends State<TemuanTab> {
  static const blue = Color(0xFF004D8C);
  static const navy = Color(0xFF071B30);
  static const amber = Color(0xFFFFB800);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);

  final repo = TemuanRepository();
  List<TemuanInspeksi> items = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load(remote: true);
  }

  Future<void> _load({bool remote = false}) async {
    if (remote) {
      await repo.unduh('${widget.sesi['token'] ?? ''}', widget.wo.kodeWo);
    }
    items = await repo.untukWo(widget.wo.kodeWo);
    if (mounted) setState(() {});
  }

  Future<void> _add() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TemuanFormScreen(wo: widget.wo, sesi: widget.sesi),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _sync() async {
    setState(() => busy = true);
    try {
      await repo.sinkron('${widget.sesi['token'] ?? ''}');
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Temuan berhasil disinkronkan.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
          children: [
            Row(
              children: [
                Text(
                  '${items.length} Temuan',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: navy,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: busy ? null : _sync,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Sinkron'),
                ),
              ],
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Column(
                  children: [
                    Icon(Icons.fact_check_outlined, size: 48, color: blue),
                    SizedBox(height: 12),
                    Text(
                      'Belum ada temuan',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Tambahkan temuan hasil inspeksi.',
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              )
            else
              ...items.map(_card),
          ],
        ),
        Positioned(
          right: 18,
          bottom: 20,
          child: FloatingActionButton.extended(
            onPressed: _add,
            backgroundColor: amber,
            foregroundColor: navy,
            icon: const Icon(Icons.add),
            label: const Text(
              'Temuan',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(TemuanInspeksi item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.kodeTemuan,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: blue,
                  ),
                ),
              ),
              Text(
                item.prioritas,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.temuan,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${item.tier} • ${item.segmen}',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class TemuanFormScreen extends StatefulWidget {
  final WoInsjar wo;
  final Map<String, dynamic> sesi;

  const TemuanFormScreen({super.key, required this.wo, required this.sesi});

  @override
  State<TemuanFormScreen> createState() => _TemuanFormScreenState();
}

class _TemuanFormScreenState extends State<TemuanFormScreen> {
  static const blue = Color(0xFF0A3E74);
  static const amber = Color(0xFFFFAE00);
  static const navy = Color(0xFF071B30);
  static const line = Color(0xFFE2E8F0);

  final repo = TemuanRepository();
  final segmenCtrl = TextEditingController();
  final jarakCtrl = TextEditingController();
  final tinggiCtrl = TextEditingController();

  List<Map<String, dynamic>> listMaster = [];
  List<Map<String, dynamic>> pohonMaster = [];
  String kode = '';
  String object = 'Jaringan';
  String? tier;
  String? temuan;
  String? pohon;
  LocationFix? gps;
  String foto = '';
  String lingkungan = '';
  bool saving = false;
  bool mengambilGps = false;

  bool get isVegetasi {
    final value = (temuan ?? '').toLowerCase();
    return value.contains('rabas') ||
        value.contains('pangkas') ||
        value.contains('tebang');
  }

  String _cleanKey(String key) =>
      key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  String _findValue(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = '${row[key] ?? ''}'.trim();
      if (value.isNotEmpty) return value;
    }
    final normalized = keys.map(_cleanKey).toSet();
    for (final entry in row.entries) {
      final value = '${entry.value ?? ''}'.trim();
      if (normalized.contains(_cleanKey(entry.key)) && value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  List<String> get temuanOptions {
    if (tier == null || tier!.isEmpty) return [];
    final options = listMaster
        .where((row) {
          final rowObject = _findValue(
            row,
            const ['Objek Inspeksi', 'Jenis Object', 'Object'],
          );
          final rowTier = _findValue(row, const ['Tier']);
          final matchObject = rowObject.isEmpty ||
              rowObject.toLowerCase().contains(object.toLowerCase());
          final matchTier =
              rowTier.isEmpty || rowTier.toLowerCase() == tier!.toLowerCase();
          return matchObject && matchTier;
        })
        .map((row) => _findValue(row, const ['Temuan', 'Nama Temuan']))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    return options;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    segmenCtrl.dispose();
    jarakCtrl.dispose();
    tinggiCtrl.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    kode = await repo.kodeBaru(widget.wo.kodeWo);
    final determined = repo.jenisObject(widget.sesi);
    object = determined.isNotEmpty ? determined : 'Jaringan';
    listMaster = await repo.master('List_Temuan');
    pohonMaster = await repo.master('Jenis Pohon');
    if (mounted) setState(() {});
  }

  Future<void> _ambilGps() async {
    setState(() => mengambilGps = true);
    try {
      final fix = await HighAccuracyLocationService.acquire(
        onSample: (_, __) {},
      );
      if (mounted) {
        setState(() {
          gps = fix;
          mengambilGps = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => mengambilGps = false);
        _message('Gagal mengambil koordinat: $error');
      }
    }
  }

  Future<String> _ambilFoto(String label) async {
    final capturedPath = await LandscapeCameraScreen.capture(
      context,
      title: label,
    );
    if (capturedPath == null || capturedPath.isEmpty) return '';
    final source = File(capturedPath);
    if (!await source.exists() || await source.length() <= 0) {
      throw StateError('Foto kamera tidak tersimpan. Ambil ulang foto.');
    }
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final name =
        '$kode.$label.${two(now.hour)}${two(now.minute)}${two(now.second)}.jpg';
    return (await source.copy(p.join(p.dirname(source.path), name))).path;
  }

  String _pick(Map<String, dynamic> row, List<String> keys) =>
      _findValue(row, keys);

  String get calculatedPriority {
    if (temuan == null || temuan!.isEmpty) return '';
    return repo.prioritas(
      temuan!,
      double.tryParse(jarakCtrl.text.replaceAll(',', '.')),
      double.tryParse(tinggiCtrl.text.replaceAll(',', '.')),
      listMaster,
    );
  }

  Future<void> _save() async {
    if (tier == null || tier!.isEmpty) {
      _message('Pilih Tier terlebih dahulu.');
      return;
    }
    if (segmenCtrl.text.trim().isEmpty ||
        gps == null ||
        object.isEmpty ||
        temuan == null ||
        temuan!.isEmpty ||
        foto.isEmpty ||
        lingkungan.isEmpty) {
      _message('Lengkapi Segmen, Temuan, GPS, dan kedua foto.');
      return;
    }
    if (isVegetasi &&
        (jarakCtrl.text.trim().isEmpty ||
            pohon == null ||
            pohon!.isEmpty ||
            tinggiCtrl.text.trim().isEmpty)) {
      _message('Jarak, jenis pohon, dan tinggi pohon wajib diisi.');
      return;
    }
    setState(() => saving = true);
    try {
      final now = DateTime.now();
      final coordinate = gps!.coordinate.split(',');
      final distance = double.tryParse(jarakCtrl.text.replaceAll(',', '.'));
      final height = double.tryParse(tinggiCtrl.text.replaceAll(',', '.'));
      final item = TemuanInspeksi(
        kodeTemuan: kode,
        kodeWo: widget.wo.kodeWo,
        kodeUiw: widget.wo.kodeUiw,
        kodeUp3: widget.wo.kodeUp3,
        kodeUlp: widget.wo.kodeUlp,
        ulp: widget.wo.ulp,
        hari: WoInsjar.hariIndonesia[now.weekday - 1],
        tanggal: WoInsjar.formatTanggal(now),
        penyulang: widget.wo.penyulang,
        sectionAwal: widget.wo.sectionAwal,
        sectionAkhir: widget.wo.sectionAkhir,
        section: widget.wo.section,
        segmen: segmenCtrl.text.trim(),
        koordinat: gps!.coordinate,
        lat: coordinate.first.trim(),
        long: coordinate.length > 1 ? coordinate[1].trim() : '',
        jenisObject: object,
        tier: tier!,
        temuan: temuan!,
        jarak: isVegetasi ? distance : null,
        jenisPohon: isVegetasi ? (pohon ?? '') : '',
        tinggiPohon: isVegetasi ? height : null,
        prioritas: calculatedPriority,
        fotoTemuan: foto,
        fotoLingkungan: lingkungan,
        waktuInput: WoInsjar.stampLengkap(now),
        userInput: '${widget.sesi['username'] ?? ''}',
        folderPath: TemuanRepository.folder(
          widget.wo,
          object,
          kode,
          now,
        ),
      );
      await repo.simpan(item);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trees = pohonMaster
        .map((row) => _pick(row, const ['Jenis Pohon', 'Pohon', 'Nama']))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Tambah Temuan Baru',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _header(),
                const SizedBox(height: 14),
                _identity(),
                const SizedBox(height: 14),
                _classification(trees),
                const SizedBox(height: 14),
                _gpsCard(),
                const SizedBox(height: 14),
                _photos(),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: amber,
                  foregroundColor: navy,
                ),
                child: Text(
                  saving ? 'Menyimpan...' : 'Simpan Temuan ke Server Lokal',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _box() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      );

  Widget _header() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: blue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Konteks Work Order',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 5),
            Text(
              widget.wo.kodeWo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(widget.wo.ulp, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      );

  Widget _identity() => Container(
        padding: const EdgeInsets.all(16),
        decoration: _box(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📌 Identitas Temuan',
              style: TextStyle(color: blue, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _read('Kode Temuan', kode)),
                const SizedBox(width: 10),
                Expanded(child: _read('Jenis Object', object)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _read('Penyulang', widget.wo.penyulang)),
                const SizedBox(width: 10),
                Expanded(child: _read('Section', widget.wo.section)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: segmenCtrl,
              decoration: const InputDecoration(
                labelText: 'Segmen *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      );

  Widget _classification(List<String> trees) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _box(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔍 Klasifikasi Temuan',
              style: TextStyle(color: blue, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: tier,
                    hint: const Text('--Pilih Tier--'),
                    items: const [
                      DropdownMenuItem(value: 'Tier 1', child: Text('Tier 1')),
                      DropdownMenuItem(value: 'Tier 2', child: Text('Tier 2')),
                    ],
                    onChanged: (value) => setState(() {
                      tier = value;
                      temuan = null;
                    }),
                    decoration: const InputDecoration(
                      labelText: 'Tier *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _read('Prioritas', calculatedPriority)),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: temuanOptions.contains(temuan) ? temuan : null,
              hint: Text(tier == null ? 'Pilih Tier dahulu' : 'Pilih Temuan'),
              items: temuanOptions
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged:
                  tier == null ? null : (value) => setState(() => temuan = value),
              decoration: const InputDecoration(
                labelText: 'Nama Temuan *',
                border: OutlineInputBorder(),
              ),
            ),
            if (isVegetasi) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: jarakCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Jarak (m) *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: tinggiCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Tinggi (m) *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: trees.contains(pohon) ? pohon : null,
                items: trees
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => pohon = value),
                decoration: const InputDecoration(
                  labelText: 'Jenis Pohon *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _gpsCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: _box(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '📍 Koordinat Temuan',
                    style: TextStyle(color: blue, fontWeight: FontWeight.w800),
                  ),
                ),
                if (gps != null)
                  Text(
                    'Akurasi ${gps!.accuracyLabel}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              gps?.coordinate ?? '-',
              style: const TextStyle(color: blue, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: mengambilGps ? null : _ambilGps,
                icon: const Icon(Icons.my_location),
                label: Text(
                  mengambilGps
                      ? 'Mencari akurasi...'
                      : 'Ambil Koordinat Temuan',
                ),
              ),
            ),
          ],
        ),
      );

  Widget _photos() => Container(
        padding: const EdgeInsets.all(16),
        decoration: _box(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📷 Foto Temuan',
              style: TextStyle(color: blue, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _photo('Foto Temuan *', foto, () async {
                    try {
                      final value = await _ambilFoto('Foto Temuan');
                      if (mounted) setState(() => foto = value);
                    } catch (error) {
                      _message('$error');
                    }
                  }),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _photo('Foto Sekitar Tiang *', lingkungan, () async {
                    try {
                      final value = await _ambilFoto('Foto Lingkungan');
                      if (mounted) setState(() => lingkungan = value);
                    } catch (error) {
                      _message('$error');
                    }
                  }),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _photo(String label, String path, VoidCallback onTap) {
    final exists = path.isNotEmpty && File(path).existsSync();
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: exists ? blue : line),
        ),
        child: exists
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.file(File(path), fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.screen_rotation_rounded, color: blue),
                  const SizedBox(height: 7),
                  Text(label, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  const Text(
                    'Landscape wajib',
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _read(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
}
