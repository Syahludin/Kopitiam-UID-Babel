import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/temuan_inspeksi.dart';
import '../models/wo_insjar.dart';
import '../services/high_accuracy_location_service.dart';
import '../services/photo_watermark_service.dart';
import '../services/temuan_repository.dart';
import 'landscape_camera_screen.dart';

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
  static const muted = Color(0xFF64748B);
  static const green = Color(0xFF16A34A);

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
    return value.contains('rabas') || value.contains('pangkas') || value.contains('tebang');
  }

  bool get objectLocked => repo.jenisObject(widget.sesi).isNotEmpty;
  List<String> get objectOptions => const ['Jaringan', 'Gardu'];

  String _cleanKey(String key) => key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  String _findValue(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = '${row[key] ?? ''}'.trim();
      if (value.isNotEmpty) return value;
    }
    final normalized = keys.map(_cleanKey).toSet();
    for (final entry in row.entries) {
      final value = '${entry.value ?? ''}'.trim();
      if (normalized.contains(_cleanKey(entry.key)) && value.isNotEmpty) return value;
    }
    return '';
  }

  List<String> get temuanOptions {
    if (tier == null || tier!.isEmpty) return [];
    final targetObject = object.toLowerCase().trim();
    return listMaster.where((row) {
      final rowObject = _findValue(row, const ['Objek Inspeksi', 'Jenis Object', 'Object']).trim().toLowerCase();
      if (rowObject.isEmpty) return false;
      final matchObject = rowObject.split(RegExp(r'[/,;]')).map((e) => e.trim()).where((e) => e.isNotEmpty).any((e) => e == targetObject);
      if (!matchObject) return false;
      final rowTier = _findValue(row, const ['Tier']);
      return rowTier.trim().isEmpty || rowTier.trim().toLowerCase() == tier!.toLowerCase();
    }).map((row) => _findValue(row, const ['Temuan', 'Nama Temuan'])).where((v) => v.isNotEmpty).toSet().toList();
  }

  @override
  void initState() { super.initState(); _initialize(); }

  @override
  void dispose() { segmenCtrl.dispose(); jarakCtrl.dispose(); tinggiCtrl.dispose(); super.dispose(); }

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
      final fix = await HighAccuracyLocationService.acquire(onSample: (_, __) {});
      if (mounted) setState(() { gps = fix; mengambilGps = false; });
    } catch (error) {
      if (mounted) { setState(() => mengambilGps = false); _message('Gagal mengambil koordinat: $error'); }
    }
  }

  Future<String> _ambilFoto(String label) async {
    final capturedPath = await LandscapeCameraScreen.capture(context, title: label);
    if (capturedPath == null || capturedPath.isEmpty) return '';
    final source = File(capturedPath);
    if (!await source.exists() || await source.length() <= 0) throw StateError('Foto kamera tidak tersimpan.');
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final name = '$kode.$label.${two(now.hour)}${two(now.minute)}${two(now.second)}.jpg';
    final copied = await source.copy(p.join(p.dirname(source.path), name));
    final item = TemuanInspeksi(kodeTemuan: kode, kodeWo: widget.wo.kodeWo, temuan: temuan ?? '', jenisObject: object, koordinat: gps?.coordinate ?? '', ulp: widget.wo.ulp, penyulang: widget.wo.penyulang, section: widget.wo.section, segmen: segmenCtrl.text.trim(), hari: WoInsjar.hariIndonesia[now.weekday - 1], tanggal: WoInsjar.formatTanggal(now), waktuInput: WoInsjar.stampLengkap(now));
    return PhotoWatermarkService.render(sourcePath: copied.path, item: item, photoLabel: label);
  }

  String get calculatedPriority {
    if (temuan == null || temuan!.isEmpty) return '';
    return repo.prioritas(temuan!, double.tryParse(jarakCtrl.text.replaceAll(',', '.')), double.tryParse(tinggiCtrl.text.replaceAll(',', '.')), listMaster);
  }

  Future<void> _save() async {
    if (tier == null || tier!.isEmpty) { _message('Pilih Tier terlebih dahulu.'); return; }
    if (segmenCtrl.text.trim().isEmpty || gps == null || object.isEmpty || temuan == null || temuan!.isEmpty || foto.isEmpty || lingkungan.isEmpty) { _message('Lengkapi Segmen, Temuan, GPS, dan kedua foto.'); return; }
    if (isVegetasi && (jarakCtrl.text.trim().isEmpty || pohon == null || pohon!.isEmpty || tinggiCtrl.text.trim().isEmpty)) { _message('Jarak, jenis pohon, dan tinggi pohon wajib diisi.'); return; }
    setState(() => saving = true);
    try {
      final now = DateTime.now();
      final coordinate = gps!.coordinate.split(',');
      final item = TemuanInspeksi(
        kodeTemuan: kode, kodeWo: widget.wo.kodeWo, kodeUiw: widget.wo.kodeUiw, kodeUp3: widget.wo.kodeUp3, kodeUlp: widget.wo.kodeUlp, ulp: widget.wo.ulp,
        hari: WoInsjar.hariIndonesia[now.weekday - 1], tanggal: WoInsjar.formatTanggal(now), penyulang: widget.wo.penyulang, sectionAwal: widget.wo.sectionAwal, sectionAkhir: widget.wo.sectionAkhir, section: widget.wo.section, segmen: segmenCtrl.text.trim(),
        koordinat: gps!.coordinate, lat: coordinate.first.trim(), long: coordinate.length > 1 ? coordinate[1].trim() : '', jenisObject: object, tier: tier!, temuan: temuan!,
        jarak: isVegetasi ? double.tryParse(jarakCtrl.text.replaceAll(',', '.')) : null, jenisPohon: isVegetasi ? (pohon ?? '') : '', tinggiPohon: isVegetasi ? double.tryParse(tinggiCtrl.text.replaceAll(',', '.')) : null,
        prioritas: calculatedPriority, fotoTemuan: foto, fotoLingkungan: lingkungan, waktuInput: WoInsjar.stampLengkap(now), userInput: '${widget.sesi['username'] ?? ''}',
        folderPath: TemuanRepository.folder(widget.wo, object, kode, now),
      );
      await repo.simpan(item);
      if (mounted) Navigator.pop(context, true);
    } finally { if (mounted) setState(() => saving = false); }
  }

  void _message(String text) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }

  @override
  Widget build(BuildContext context) {
    final trees = pohonMaster.map((row) => _findValue(row, const ['Jenis Pohon', 'Pohon', 'Nama'])).where((v) => v.isNotEmpty).toSet().toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(title: const Text('Tambah Temuan Baru', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)), backgroundColor: blue, foregroundColor: Colors.white, elevation: 0, titleSpacing: 16),
      body: Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [_header(), const SizedBox(height: 14), _identity(), const SizedBox(height: 14), _classification(trees), const SizedBox(height: 14), _gpsCard(), const SizedBox(height: 14), _photos()])),
        Container(
          decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x1A0F172A), blurRadius: 10, offset: Offset(0, -2))]),
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Temuan disimpan di server lokal, lalu disinkronkan.', style: TextStyle(fontSize: 11, color: muted)),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
              onPressed: saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: amber, foregroundColor: navy, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: saving ? const Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: navy)), SizedBox(width: 10), Text('Menyimpan...', style: TextStyle(fontWeight: FontWeight.w800))]) : const Text('Simpan Temuan ke Server Lokal', style: TextStyle(fontWeight: FontWeight.w800)),
            )),
          ]),
        ),
      ]),
    );
  }

  BoxDecoration _box() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: line));
  InputDecoration _inputDecoration(String label) => InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: blue, width: 1.5)));

  Widget _sectionCard(String badge, IconData icon, String title, List<Widget> children) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16), decoration: _box(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 26, height: 26, decoration: BoxDecoration(color: blue, borderRadius: BorderRadius.circular(8)), child: Center(child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)))),
        const SizedBox(width: 10), Icon(icon, size: 18, color: blue), const SizedBox(width: 6),
        Expanded(child: Text(title, style: const TextStyle(color: blue, fontSize: 15, fontWeight: FontWeight.w800))),
      ]),
      const SizedBox(height: 14), ...children,
    ]),
  );

  Widget _header() => Container(
    width: double.infinity, padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF004D8C), Color(0xFF071B30)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x26004D8C), blurRadius: 14, offset: Offset(0, 6))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.assignment_turned_in_rounded, color: Colors.white, size: 20)),
        const SizedBox(width: 10), const Expanded(child: Text('Work Order', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: amber, borderRadius: BorderRadius.circular(100)), child: const Text('Temuan', style: TextStyle(color: navy, fontSize: 10, fontWeight: FontWeight.w800))),
      ]),
      const SizedBox(height: 12),
      Text(widget.wo.kodeWo, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Row(children: [const Icon(Icons.location_city_rounded, size: 15, color: Colors.white70), const SizedBox(width: 6), Expanded(child: Text(widget.wo.ulp, style: const TextStyle(color: Colors.white70, fontSize: 13)))]),
    ]),
  );

  Widget _identity() => _sectionCard('1', Icons.tag_rounded, 'Identitas Temuan', [
    Row(children: [Expanded(child: _read('Kode Temuan', kode)), const SizedBox(width: 10), Expanded(child: _objectField())]),
    const SizedBox(height: 12),
    Row(children: [Expanded(child: _read('Penyulang', widget.wo.penyulang)), const SizedBox(width: 10), Expanded(child: _read('Section', widget.wo.section))]),
    const SizedBox(height: 12),
    TextField(controller: segmenCtrl, decoration: _inputDecoration('Segmen *')),
  ]);

  Widget _objectField() {
    if (objectLocked) return _read('Jenis Object', object);
    return DropdownButtonFormField<String>(value: objectOptions.contains(object) ? object : null, hint: const Text('--Pilih Object--'), items: objectOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) {
      if (v == null || v == object) return;
      // Ganti Object: reset tier, temuan, dan seluruh state vegetasi karena
      // Tier/Temuan sebelumnya mungkin tidak relevan untuk object yang baru.
      setState(() {
        object = v;
        tier = null;
        temuan = null;
        pohon = null;
        jarakCtrl.clear();
        tinggiCtrl.clear();
      });
    }, decoration: _inputDecoration('Jenis Object *'));
  }

  Widget _classification(List<String> trees) => _sectionCard('2', Icons.tune_rounded, 'Klasifikasi Temuan', [
    Row(children: [
      Expanded(child: DropdownButtonFormField<String>(value: tier, hint: const Text('--Pilih Tier--'), items: const [DropdownMenuItem(value: 'Tier 1', child: Text('Tier 1')), DropdownMenuItem(value: 'Tier 2', child: Text('Tier 2'))], onChanged: (v) {
        if (v == null || v == tier) return;
        // Ganti Tier: reset temuan dan seluruh state vegetasi karena
        // Temuan lama mungkin tidak tersedia di Tier baru, dan field
        // vegetasi lama (jarak/tinggi/pohon) bisa tertinggal.
        setState(() {
          tier = v;
          temuan = null;
          pohon = null;
          jarakCtrl.clear();
          tinggiCtrl.clear();
        });
      }, decoration: _inputDecoration('Tier *'))),
      const SizedBox(width: 10), Expanded(child: _read('Prioritas', calculatedPriority)),
    ]),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(isExpanded: true, value: temuanOptions.contains(temuan) ? temuan : null, hint: Text(tier == null ? 'Pilih Tier dahulu' : 'Pilih Temuan'), items: temuanOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: tier == null ? null : (v) {
      if (v == temuan) return;
      // Ganti Temuan: jika temuan lama vegetasi dan temuan baru bukan
      // vegetasi (atau sebaliknya), bersihkan field vegetasi agar data
      // tidak tertinggal/tidak valid.
      final wasVegetasi = isVegetasi;
      setState(() {
        temuan = v;
        if (wasVegetasi) {
          pohon = null;
          jarakCtrl.clear();
          tinggiCtrl.clear();
        }
      });
    }, decoration: _inputDecoration('Nama Temuan *')),
    if (isVegetasi) ...[
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: jarakCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: _inputDecoration('Jarak Thd\nJaringan (m) *'))),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: tinggiCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: _inputDecoration('Tinggi\nBatang (m) *'))),
      ]),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(isExpanded: true, value: trees.contains(pohon) ? pohon : null, items: trees.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => pohon = v), decoration: _inputDecoration('Jenis Pohon *')),
    ],
  ]);

  Widget _gpsCard() => _sectionCard('3', Icons.my_location_rounded, 'Koordinat Temuan', [
    Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(Icons.place_rounded, size: 20, color: gps == null ? muted : green), const SizedBox(width: 10),
        Expanded(child: Text(gps?.coordinate ?? 'Belum diambil', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: gps == null ? muted : navy))),
        if (gps != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(100)), child: Text('Akurasi ${gps!.accuracyLabel}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: green))),
      ]),
    ),
    const SizedBox(height: 12),
    SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: mengambilGps ? null : _ambilGps, style: OutlinedButton.styleFrom(foregroundColor: blue, side: const BorderSide(color: blue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(Icons.my_location), label: Text(mengambilGps ? 'Mencari akurasi...' : 'Ambil Koordinat Temuan'))),
  ]);

  Widget _photos() => _sectionCard('4', Icons.photo_camera_back_rounded, 'Foto Dokumentasi', [
    Row(children: [
      Expanded(child: _photo('Foto Temuan *', foto, () async { try { final v = await _ambilFoto('Foto Temuan'); if (mounted) setState(() => foto = v); } catch (e) { _message('$e'); } })),
      const SizedBox(width: 10),
      Expanded(child: _photo('Foto Sekitar Tiang *', lingkungan, () async { try { final v = await _ambilFoto('Foto Lingkungan'); if (mounted) setState(() => lingkungan = v); } catch (e) { _message('$e'); } })),
    ]),
    const SizedBox(height: 8),
    const Row(children: [Icon(Icons.gpp_good_rounded, size: 14, color: green), SizedBox(width: 6), Expanded(child: Text('Foto diambil landscape', style: TextStyle(fontSize: 11, color: muted)))]),
  ]);

  /// Menangani ketukan pada kolom kamera untuk verifikasi foto.
  /// - Jika foto belum ada: langsung membuka kamera.
  /// - Jika foto sudah ada: menampilkan 2 pilihan (Lihat Hasil / Ambil Ulang)
  ///   agar petugas dapat memverifikasi apakah foto sudah sesuai.
  void _onPhotoTap(String label, String path, VoidCallback onCapture) {
    if (path.isEmpty || !File(path).existsSync()) {
      onCapture();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(label.replaceAll(' *', '')),
        content: const Text(
          'Foto telah tersimpan. Verifikasi apakah foto sudah sesuai.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _lihatFoto(path);
            },
            icon: const Icon(Icons.visibility_rounded),
            label: const Text('Lihat Hasil Foto'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              onCapture();
            },
            style: FilledButton.styleFrom(
              backgroundColor: amber,
              foregroundColor: navy,
            ),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Ambil Ulang Foto'),
          ),
        ],
      ),
    );
  }

  void _lihatFoto(String path) {
    if (path.isEmpty || !File(path).existsSync()) return;
    showDialog<void>(
      context: context,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Dialog.fullscreen(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: Image.file(File(path), fit: BoxFit.contain),
                ),
              ),
              const Positioned(
                top: 48,
                right: 16,
                child: Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photo(String label, String path, VoidCallback onCapture) {
    final exists = path.isNotEmpty && File(path).existsSync();
    return InkWell(onTap: () => _onPhotoTap(label, path, onCapture), borderRadius: BorderRadius.circular(14), child: Container(
      height: 150,
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: exists ? blue : line, width: exists ? 1.4 : 1)),
      child: exists
          ? Stack(fit: StackFit.expand, children: [
              ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.file(File(path), fit: BoxFit.cover)),
              Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xCC071B30), borderRadius: BorderRadius.circular(100)), child: Text(label.replaceAll(' *', ''), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)))),
            ])
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 46, height: 46, decoration: const BoxDecoration(color: Color(0xFFE8F1FA), shape: BoxShape.circle), child: const Icon(Icons.screen_rotation_rounded, color: blue)),
              const SizedBox(height: 8), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
              const SizedBox(height: 3), const Text('Landscape wajib', style: TextStyle(fontSize: 10, color: muted)),
            ]),
    ));
  }

  Widget _read(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 10, color: muted, fontWeight: FontWeight.w600, letterSpacing: .3)),
    const SizedBox(height: 5),
    Container(width: double.infinity, padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)), child: Text(value.isEmpty ? '-' : value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
  ]);
}
