import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/temuan_inspeksi.dart';
import '../models/wo_har_jar.dart';
import '../models/wo_material_har_jar.dart';
import '../models/wo_insjar.dart';
import '../services/high_accuracy_location_service.dart';
import '../services/photo_watermark_service.dart';
import '../services/wo_har_jar_repository.dart';
import '../widgets/material_input_section.dart';
import 'landscape_camera_screen.dart';

class FormTindakLanjutHarJarScreen extends StatefulWidget {
  final WoHarJar existing;
  final Map<String, dynamic> sesi;

  const FormTindakLanjutHarJarScreen({
    super.key,
    required this.existing,
    required this.sesi,
  });

  @override
  State<FormTindakLanjutHarJarScreen> createState() =>
      _FormTindakLanjutHarJarScreenState();
}

class _FormTindakLanjutHarJarScreenState
    extends State<FormTindakLanjutHarJarScreen> {
  static const blue = Color(0xFF0A3E74);
  static const navy = Color(0xFF071B30);
  static const amber = Color(0xFFFFAE00);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);
  static const green = Color(0xFF16A34A);

  final _repo = WoHarJarRepository();
  final _catatanCtrl = TextEditingController();

  late String _status;
  String _fotoSesudah = '';
  String _koordinat = '';
  double? _lat;
  double? _long;
  List<WoMaterialHarJar> _materials = const [];
  List<String> _masterMaterials = const [];
  bool _saving = false;
  bool _takingPhoto = false;
  bool _locating = false;
  String? _locAccuracy;

  WoHarJar get _wo => widget.existing;
  bool get _readOnly =>
      WoHarJar.normalisasiStatus(_status) == WoHarJar.statusSelesai;
  bool get _editable =>
      !_readOnly &&
      WoHarJar.normalisasiStatus(_status) == WoHarJar.statusSedang;

  @override
  void initState() {
    super.initState();
    _status = WoHarJar.normalisasiStatus(_wo.statusWo);
    _fotoSesudah = _wo.fotoSesudah;
    _koordinat = _wo.koordinat;
    _lat = _wo.lat;
    _long = _wo.long;
    _catatanCtrl.text = _wo.catatanPetugas;
    _loadMaterials();
    _loadMaster();
  }

  Future<void> _loadMaterials() async {
    final list = await _repo.materialUntukWo(_wo.kodeWo);
    if (mounted) setState(() => _materials = list);
  }

  Future<void> _loadMaster() async {
    final list = await _repo.daftarMaterialMaster();
    if (mounted) setState(() => _masterMaterials = list);
  }

  @override
  void dispose() {
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _ambilFoto() async {
    if (!_editable || _takingPhoto) return;
    setState(() => _takingPhoto = true);
    try {
      final value = await LandscapeCameraScreen.capture(
        context,
        title: 'Foto Sesudah',
      );
      if (value == null || value.isEmpty) return;
      final now = DateTime.now();
      final item = TemuanInspeksi(
        kodeTemuan: _wo.kodeTemuan,
        kodeWo: _wo.kodeWo,
        temuan: _wo.temuan,
        jenisObject: _wo.jenisObject,
        koordinat: _koordinat.isEmpty ? _wo.koordinat : _koordinat,
        ulp: _wo.ulp,
        penyulang: _wo.penyulang,
        section: _wo.section,
        segmen: _wo.segmen,
        hari: _wo.hari.isEmpty
            ? WoInsjar.hariIndonesia[now.weekday - 1]
            : _wo.hari,
        tanggal: _wo.tanggal.isEmpty
            ? WoInsjar.formatTanggal(now)
            : _wo.tanggal,
        waktuInput: _wo.waktuInput.isEmpty
            ? WoInsjar.stampLengkap(now)
            : _wo.waktuInput,
      );
      final watermarked = await PhotoWatermarkService.render(
        sourcePath: value,
        item: item,
        photoLabel: 'Foto Sesudah',
      );
      if (mounted) setState(() => _fotoSesudah = watermarked);
    } catch (error) {
      if (mounted) _message('$error', error: true);
    } finally {
      if (mounted) setState(() => _takingPhoto = false);
    }
  }

  Future<void> _ambilGps() async {
    if (!_editable || _locating) return;
    setState(() {
      _locating = true;
      _locAccuracy = null;
    });
    try {
      final fix = await HighAccuracyLocationService.acquire(
        onSample: (_, accuracy) {
          if (mounted) setState(() => _locAccuracy = fixAccuracyLabel(accuracy));
        },
      );
      if (mounted) {
        setState(() {
          _lat = fix.latitude;
          _long = fix.longitude;
          _koordinat = fix.coordinate;
          _locAccuracy = fix.accuracyLabel;
        });
      }
    } catch (error) {
      if (mounted) _message('$error', error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  String fixAccuracyLabel(double accuracy) =>
      '${accuracy.toStringAsFixed(1)} m';

  void _tambahMaterial(WoMaterialHarJar draft) {
    final item = WoMaterialHarJar(
      kodePenggunaanMaterial: _repo.generateKodeMaterial(_wo.kodeWo),
      kodeWo: _wo.kodeWo,
      material: draft.material,
      jumlah: draft.jumlah,
      satuan: draft.satuan,
      kepemilikan: draft.kepemilikan,
      keterangan: draft.keterangan,
      userInput: '${widget.sesi['username'] ?? ''}',
      waktuInput: WoInsjar.stampLengkap(DateTime.now()),
    );
    setState(() => _materials = [..._materials, item]);
  }

  void _hapusMaterial(String kode) {
    setState(
      () => _materials = _materials
          .where((item) => item.kodePenggunaanMaterial != kode)
          .toList(),
    );
  }

  Future<void> _simpanSelesai() async {
    if (_saving || _readOnly) return;
    if (_fotoSesudah.isEmpty) {
      _message('Foto Sesudah wajib diambil.');
      return;
    }
    if (_koordinat.isEmpty || _lat == null || _long == null) {
      _message('Ambil koordinat GPS realisasi terlebih dahulu.');
      return;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final updated = _wo.copyWith(
        koordinat: _koordinat,
        lat: _lat,
        long: _long,
        fotoSesudah: _fotoSesudah,
        catatanPetugas: _catatanCtrl.text.trim(),
        statusWo: WoHarJar.statusSelesai,
        userInput: '${widget.sesi['username'] ?? ''}',
        waktuInput: _wo.waktuInput.isNotEmpty
            ? _wo.waktuInput
            : WoInsjar.stampLengkap(now),
        waktuRealisasi: WoInsjar.stampLengkap(now),
        isSynced: false,
      );
      await _repo.simpanSelesai(updated, _materials);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        _message(
          error.toString().replaceFirst('StateError: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _bukaMaps(String koordinat) {
    final clean = koordinat.trim();
    if (clean.isEmpty) {
      _message('Koordinat belum tersedia.');
      return;
    }
    launchUrl(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination='
        '${Uri.encodeComponent(clean)}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? const Color(0xFFDC2626) : green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wo = _wo;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Tindak Lanjut Har Jar',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: blue,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _header(wo),
                const SizedBox(height: 14),
                _temuanCard(wo),
                const SizedBox(height: 14),
                _fotoSesudahCard(),
                const SizedBox(height: 14),
                _koordinatCard(),
                const SizedBox(height: 14),
                _catatanCard(),
                const SizedBox(height: 14),
                MaterialInputSection(
                  materials: _materials,
                  masterMaterials: _masterMaterials,
                  editable: _editable,
                  onAdd: _tambahMaterial,
                  onDelete: _hapusMaterial,
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A0F172A),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _readOnly || _saving ? null : _simpanSelesai,
                style: FilledButton.styleFrom(
                  backgroundColor: _readOnly ? navy : amber,
                  foregroundColor: navy,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: navy,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Menyimpan...',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      )
                    : Text(
                        _readOnly ? 'WO Selesai' : 'Simpan Selesai',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(WoHarJar wo) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF004D8C), Color(0xFF071B30)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.engineering_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Kode WO',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                _statusChip(_status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              wo.kodeWo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${wo.ulp} • ${wo.timEksekusi}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );

  Widget _statusChip(String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _temuanCard(WoHarJar wo) => _card(
        'Review Temuan',
        [
          _readRow('Temuan', wo.temuan),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _readRow('Tier', wo.tier)),
              const SizedBox(width: 8),
              Expanded(child: _readRow('Prioritas', wo.prioritas)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _readRow('Section', wo.section)),
              const SizedBox(width: 8),
              Expanded(child: _readRow('Penyulang', wo.penyulang)),
            ],
          ),
          if (wo.linkFotoTemuan.isNotEmpty ||
              wo.linkFotoTiangSekitar.isNotEmpty) ...[
            const SizedBox(height: 10),
            if (wo.linkFotoTemuan.isNotEmpty)
              _linkFotoRow('Foto Temuan', wo.linkFotoTemuan),
            if (wo.linkFotoTiangSekitar.isNotEmpty) ...[
              const SizedBox(height: 8),
              _linkFotoRow('Foto Tiang Sekitar', wo.linkFotoTiangSekitar),
            ],
          ],
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _bukaMaps(wo.koordinat),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.map_rounded, size: 18, color: blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      wo.koordinat.isEmpty
                          ? 'Koordinat temuan belum tersedia'
                          : wo.koordinat,
                      style: const TextStyle(
                        color: blue,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _linkFotoRow(String label, String url) => Row(
        children: [
          const Icon(Icons.photo_rounded, size: 14, color: blue),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('Buka'),
          ),
        ],
      );

  Widget _fotoSesudahCard() => _card(
        'Foto Sesudah',
        [
          InkWell(
            onTap: _editable ? _ambilFoto : null,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _fotoSesudah.isNotEmpty ? blue : line,
                ),
              ),
              child: _fotoSesudah.isNotEmpty && File(_fotoSesudah).existsSync()
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.file(File(_fotoSesudah), fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.photo_camera_back_rounded,
                            color: blue, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          _takingPhoto
                              ? 'Membuka kamera...'
                              : 'Ambil Foto Sesudah',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      );

  Widget _koordinatCard() => _card(
        'Koordinat Realisasi',
        [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _koordinat.isEmpty ? 'Belum diambil' : _koordinat,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _editable && !_locating ? _ambilGps : null,
              icon: _locating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded, size: 18),
              label: Text(
                _locating
                    ? 'Mengambil GPS...'
                    : 'Ambil Koordinat GPS',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (_locAccuracy != null) ...[
            const SizedBox(height: 6),
            Text(
              'Akurasi: $_locAccuracy',
              style: const TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ],
      );

  Widget _catatanCard() => _card(
        'Catatan Petugas',
        [
          TextField(
            controller: _catatanCtrl,
            enabled: _editable,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Catatan pengerjaan lapangan...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: line),
              ),
            ),
          ),
        ],
      );

  Widget _card(String title, List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: blue,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      );

  Widget _readRow(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: muted)),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
}
