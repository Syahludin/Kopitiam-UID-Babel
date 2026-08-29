import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/temuan_inspeksi.dart';
import '../models/wo_insjar.dart';
import '../models/wo_row.dart';
import '../services/photo_watermark_service.dart';
import '../services/wo_row_repository.dart';
import 'landscape_camera_screen.dart';

class WoRowFormScreen extends StatefulWidget {
  final WoRow existing;
  final Map<String, dynamic> sesi;

  const WoRowFormScreen({
    super.key,
    required this.existing,
    required this.sesi,
  });

  @override
  State<WoRowFormScreen> createState() => _WoRowFormScreenState();
}

class _WoRowFormScreenState extends State<WoRowFormScreen> {
  static const blue = Color(0xFF0A3E74);
  static const navy = Color(0xFF071B30);
  static const amber = Color(0xFFFFAE00);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);
  static const green = Color(0xFF16A34A);

  final _repo = WoRowRepository();
  final _diameterCtrl = TextEditingController();

  late String _status;
  String? _tindakLanjut;
  String _fotoSesudah = '';
  bool _saving = false;
  bool _takingPhoto = false;

  WoRow get _row => widget.existing;
  bool get _readOnly => _status == WoRow.statusSelesai;
  bool get _editable =>
      !_readOnly &&
      WoRow.normalisasiStatus(_status) == WoRow.statusProgress;
  bool get _isTebang => _tindakLanjut == 'Tebang';

  int? get _diameterValue =>
      double.tryParse(_diameterCtrl.text.replaceAll(',', '.'))?.round();

  String get _jenisTebangan => _isTebang
      ? WoRow.jenisTebanganDariDiameter(_diameterValue)
      : _row.jenisTebangan;

  @override
  void initState() {
    super.initState();
    _status = WoRow.normalisasiStatus(_row.statusWo);
    _tindakLanjut = _row.tindakLanjut.isEmpty ? null : _row.tindakLanjut;
    _fotoSesudah = _row.fotoSesudah;
    if (_row.ukuranDiameterBatang != null) {
      _diameterCtrl.text = '${_row.ukuranDiameterBatang}';
    }
  }

  @override
  void dispose() {
    _diameterCtrl.dispose();
    super.dispose();
  }

  Future<void> _mulai() async {
    if (_readOnly || _saving) return;
    await _repo.mulaiPekerjaan(_row.kodeWo);
    if (mounted) setState(() => _status = WoRow.statusProgress);
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
        kodeTemuan: _row.kodeTemuan,
        kodeWo: _row.kodeWo,
        temuan: _row.temuan,
        jenisObject: _row.jenisObject,
        koordinat: _row.koordinat,
        ulp: _row.ulp,
        penyulang: _row.penyulang,
        section: _row.section,
        segmen: _row.segmen,
        hari: _row.hari.isEmpty
            ? WoInsjar.hariIndonesia[now.weekday - 1]
            : _row.hari,
        tanggal: _row.tanggal.isEmpty
            ? WoInsjar.formatTanggal(now)
            : _row.tanggal,
        waktuInput: _row.waktuInput.isEmpty
            ? WoInsjar.stampLengkap(now)
            : _row.waktuInput,
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

  Future<void> _simpanRealisasi() async {
    if (_saving) return;
    if (_tindakLanjut == null || _tindakLanjut!.isEmpty) {
      _message('Pilih Tindak Lanjut terlebih dahulu.');
      return;
    }
    if (_isTebang && _diameterValue == null) {
      _message('Isi Ukuran Diameter Batang (cm) bernilai angka.');
      return;
    }
    if (_fotoSesudah.isEmpty) {
      _message('Foto Sesudah wajib diambil.');
      return;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final updated = _row.copyWith(
        tindakLanjut: _tindakLanjut,
        ukuranDiameterBatang: _isTebang ? _diameterValue : null,
        jenisTebangan: _isTebang ? _jenisTebangan : _row.jenisTebangan,
        fotoSesudah: _fotoSesudah,
        statusWo: WoRow.statusSelesai,
        userInput: '${widget.sesi['username'] ?? ''}',
        waktuInput: WoInsjar.stampLengkap(now),
        waktuRealisasi: WoInsjar.stampLengkap(now),
        isDirty: true,
      );
      await _repo.simpan(updated);
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

  void _bukaMaps() {
    final clean = _row.koordinat.trim();
    if (clean.isEmpty) {
      _message('Koordinat temuan belum tersedia.');
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination='
      '${Uri.encodeComponent(clean)}',
    );
    launchUrl(uri, mode: LaunchMode.externalApplication);
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
    final row = _row;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Tindak Lanjut ROW',
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
                _header(row),
                const SizedBox(height: 14),
                _temuanCard(row),
                const SizedBox(height: 14),
                _realisasiCard(),
                const SizedBox(height: 14),
                _fotoCard(),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _readOnly || _saving ? null : _simpanRealisasi,
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
                            _readOnly
                                ? 'ROW Selesai'
                                : 'Simpan Realisasi',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(WoRow row) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF004D8C), Color(0xFF071B30)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26004D8C),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_turned_in_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Kode Temuan',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                _statusChip(_status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              row.kodeWo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              row.kodeTemuan,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_city_rounded,
                    size: 15, color: Colors.white70),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${row.ulp} • ${row.kodeUlp}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                if (!_readOnly && _status == WoRow.statusPenugasan)
                  TextButton.icon(
                    onPressed: _saving ? null : _mulai,
                    style: TextButton.styleFrom(
                      backgroundColor: amber,
                      foregroundColor: navy,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text(
                      'Mulai Pekerjaan',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _statusChip(String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _readOnly ? green : Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: _readOnly ? Colors.white : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _temuanCard(WoRow row) => _card(
        'Info Temuan',
        [
          _readRow('Temuan', row.temuan),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [_readRow('Jenis Object', row.jenisObject)],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [_readRow('Tier', row.tier)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _readRow('Prioritas', row.prioritas),
          const SizedBox(height: 10),
          _readRow('Segmen', row.segmen),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Column(children: [_readRow('Section', row.section)])),
              const SizedBox(width: 8),
              Expanded(
                child: Column(children: [_readRow('Penyulang', row.penyulang)]),
              ),
            ],
          ),
          if (row.jenisPohon.isNotEmpty) ...[
            const SizedBox(height: 10),
            _readRow('Jenis Pohon', row.jenisPohon),
          ],
          const SizedBox(height: 10),
          InkWell(
            onTap: _bukaMaps,
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
                      row.koordinat.isEmpty ? 'Koordinat belum tersedia' : row.koordinat,
                      style: const TextStyle(
                        color: blue,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 18, color: blue),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _realisasiCard() => _card(
        'Tindak Lanjut & Realisasi',
        [
          DropdownButtonFormField<String>(
            initialValue: WoRow.tindakLanjutOptions.contains(_tindakLanjut)
                ? _tindakLanjut
                : null,
            hint: const Text('--Pilih Tindak Lanjut--'),
            items: WoRow.tindakLanjutOptions
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged:
                _editable ? (value) => setState(() => _tindakLanjut = value) : null,
            decoration: _inputDecoration('Tindak Lanjut *'),
          ),
          if (_isTebang) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _diameterCtrl,
              enabled: _editable,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration('Ukuran Diamter Batan (cm) *'),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text(
                    'Jenis Tebangan',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                  const Spacer(),
                  Text(
                    _jenisTebangan,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: navy,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );

  Widget _fotoCard() => _card(
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
                  width: _fotoSesudah.isNotEmpty ? 1.4 : 1,
                ),
              ),
              child: _fotoSesudah.isNotEmpty && File(_fotoSesudah).existsSync()
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.file(
                            File(_fotoSesudah),
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xCC071B30),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Text(
                              'Foto Sesudah',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.photo_camera_back_rounded,
                          color: blue,
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        _takingPhoto
                            ? const Text(
                                'Membuka kamera...',
                                style: TextStyle(color: muted),
                              )
                            : const Text(
                                'Ambil Foto Sesudah',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155),
                                ),
                              ),
                        const SizedBox(height: 4),
                        const Text(
                          'Landscape wajib • Di-zoom otomatis',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.gpp_good_rounded, size: 14, color: green),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Foto diberi tanda air otomatis dan disimpan ke folder temuan.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ),
            ],
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: muted,
              fontWeight: FontWeight.w600,
              letterSpacing: .3,
            ),
          ),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      );

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: blue, width: 1.5),
        ),
      );
}
