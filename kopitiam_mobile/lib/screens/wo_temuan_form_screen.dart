import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/temuan_inspeksi.dart';
import '../models/wo_insjar.dart';
import '../services/high_accuracy_location_service.dart';
import '../services/photo_watermark_service.dart';
import '../services/temuan_repository.dart';
import '../theme/kopitiam_theme.dart';
import 'landscape_camera_screen.dart';

class WoTemuanFormScreen extends StatefulWidget {
  final WoInsjar wo;
  final Map<String, dynamic> sesi;

  const WoTemuanFormScreen({
    super.key,
    required this.wo,
    required this.sesi,
  });

  @override
  State<WoTemuanFormScreen> createState() => _WoTemuanFormScreenState();
}

class _WoTemuanFormScreenState extends State<WoTemuanFormScreen> {
  final _repo = TemuanRepository();
  final _segmenController = TextEditingController();
  final _jarakController = TextEditingController();
  final _tinggiController = TextEditingController();

  List<Map<String, dynamic>> _masterTemuan = const [];
  List<Map<String, dynamic>> _masterPohon = const [];
  String _kode = '';
  String _object = 'Jaringan';
  String? _tier;
  String? _temuan;
  String? _pohon;
  LocationFix? _gps;
  String _fotoTemuan = '';
  String _fotoSekitar = '';
  bool _loading = true;
  bool _gettingGps = false;
  bool _capturing = false;
  bool _saving = false;
  double? _searchAccuracy;
  String? _loadError;

  bool get _isRow => _repo.isRowC4a(_temuan ?? '');

  String _cleanKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

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

  List<String> get _temuanOptions {
    final tier = _tier;
    if (tier == null || tier.isEmpty) return const [];
    final target = _object.toLowerCase();
    return _masterTemuan.where((row) {
      final rowObject = _findValue(row, const [
        'Object Inspeksi',
        'Objek Inspeksi',
        'Object',
        'Objek',
        'Jenis Object',
        'Jenis Objek',
        'Objektif',
        'Kategori',
      ]).toLowerCase().trim();
      if (rowObject.isEmpty) return false;
      if (target == 'jaringan') {
        if (rowObject.contains('gardu') && !rowObject.contains('jaringan')) {
          return false;
        }
        if (!rowObject.contains('jaringan') &&
            !rowObject.contains('jar') &&
            !rowObject.contains('line') &&
            !rowObject.contains('saluran')) {
          return false;
        }
      } else if (target == 'gardu' &&
          !rowObject.contains('gardu') &&
          !rowObject.contains('trafo')) {
        return false;
      }
      final rowTier = _findValue(row, const ['Tier']);
      return rowTier.isEmpty || rowTier.toLowerCase() == tier.toLowerCase();
    }).map((row) {
      return _findValue(row, const ['Temuan', 'Nama Temuan']);
    }).where((value) => value.isNotEmpty).toSet().toList();
  }

  List<String> get _pohonOptions => _masterPohon
      .map((row) => _findValue(row, const ['Jenis Pohon', 'Pohon', 'Nama']))
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();

  String get _priority {
    final temuan = _temuan;
    if (temuan == null || temuan.isEmpty) return '';
    return _repo.prioritas(
      temuan,
      double.tryParse(_jarakController.text.replaceAll(',', '.')),
      double.tryParse(_tinggiController.text.replaceAll(',', '.')),
      _masterTemuan,
    );
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _segmenController.dispose();
    _jarakController.dispose();
    _tinggiController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final determined = _repo.jenisObject(widget.sesi);
      if (determined.isEmpty) {
        throw StateError('Object inspeksi untuk user ini tidak dikenali.');
      }
      final values = await Future.wait([
        _repo.kodeBaru(widget.wo.kodeWo),
        _repo.master('Master_Temuan'),
        _repo.master('Jenis Pohon'),
      ]);
      _kode = values[0] as String;
      _masterTemuan = values[1] as List<Map<String, dynamic>>;
      _masterPohon = values[2] as List<Map<String, dynamic>>;
      _object = determined;
    } catch (error) {
      _loadError = error.toString().replaceFirst('Bad state: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _getGps() async {
    if (_gettingGps || _capturing || _saving) return;
    setState(() {
      _gettingGps = true;
      _searchAccuracy = null;
    });
    try {
      final fix = await HighAccuracyLocationService.acquire(
        onSample: (_, accuracy) {
          if (mounted) setState(() => _searchAccuracy = accuracy);
        },
      );
      if (mounted) setState(() => _gps = fix);
    } catch (error) {
      if (mounted) _message('Gagal mengambil koordinat: $error');
    } finally {
      if (mounted) setState(() => _gettingGps = false);
    }
  }

  Future<String> _capturePhoto(String label) async {
    final captured = await LandscapeCameraScreen.capture(context, title: label);
    if (captured == null || captured.isEmpty) return '';
    final source = File(captured);
    if (!await source.exists() || await source.length() <= 0) {
      throw StateError('Foto kamera tidak tersimpan.');
    }
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final name =
        '$_kode.$label.${two(now.hour)}${two(now.minute)}${two(now.second)}.jpg';
    final copied = await source.copy(p.join(p.dirname(source.path), name));
    final item = TemuanInspeksi(
      kodeTemuan: _kode,
      kodeWo: widget.wo.kodeWo,
      ulp: widget.wo.ulp,
      penyulang: widget.wo.penyulang,
      section: widget.wo.section,
      segmen: _segmenController.text.trim(),
      jenisObject: _object,
      tier: _tier ?? '',
      temuan: _temuan ?? '',
      koordinat: _gps?.coordinate ?? '',
      hari: WoInsjar.hariIndonesia[now.weekday - 1],
      tanggal: WoInsjar.formatTanggal(now),
      waktuInput: WoInsjar.stampLengkap(now),
    );
    return PhotoWatermarkService.render(
      sourcePath: copied.path,
      item: item,
      photoLabel: label,
    );
  }

  Future<void> _capture(bool primary) async {
    if (_capturing || _saving || _gettingGps) return;
    if (_gps == null) {
      _message('Ambil koordinat temuan terlebih dahulu.');
      return;
    }
    setState(() => _capturing = true);
    try {
      final path = await _capturePhoto(
        primary ? 'Foto Temuan' : 'Foto Lingkungan',
      );
      if (mounted && path.isNotEmpty) {
        setState(() {
          if (primary) {
            _fotoTemuan = path;
          } else {
            _fotoSekitar = path;
          }
        });
      }
    } catch (error) {
      if (mounted) _message('$error');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _capturing || _gettingGps || _loading) return;
    if (_loadError != null) {
      _message(_loadError!);
      return;
    }
    if (_segmenController.text.trim().isEmpty) {
      _message('Isi Segmen terlebih dahulu.');
      return;
    }
    if (_tier == null || _tier!.isEmpty) {
      _message('Pilih Tier terlebih dahulu.');
      return;
    }
    if (_temuan == null || !_temuanOptions.contains(_temuan)) {
      _message('Pilih Temuan dari master data.');
      return;
    }
    if (_isRow &&
        (_jarakController.text.trim().isEmpty ||
            _tinggiController.text.trim().isEmpty ||
            _pohon == null ||
            _priority.isEmpty)) {
      _message('Lengkapi kriteria ROW.');
      return;
    }
    if (_gps == null || _fotoTemuan.isEmpty || _fotoSekitar.isEmpty) {
      _message('Lengkapi koordinat dan foto dokumentasi.');
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final coordinates = _gps!.coordinate.split(',');
      final item = TemuanInspeksi(
        kodeTemuan: _kode,
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
        segmen: _segmenController.text.trim(),
        koordinat: _gps!.coordinate,
        lat: coordinates.first.trim(),
        long: coordinates.length > 1 ? coordinates[1].trim() : '',
        jenisObject: _object,
        tier: _tier!,
        temuan: _temuan!,
        jarak: _isRow
            ? double.tryParse(_jarakController.text.replaceAll(',', '.'))
            : null,
        jenisPohon: _isRow ? (_pohon ?? '') : '',
        tinggiPohon: _isRow
            ? double.tryParse(_tinggiController.text.replaceAll(',', '.'))
            : null,
        prioritas: _priority,
        fotoTemuan: _fotoTemuan,
        fotoLingkungan: _fotoSekitar,
        waktuInput: WoInsjar.stampLengkap(now),
        userInput: '${widget.sesi['username'] ?? ''}',
        folderPath: TemuanRepository.folder(
          widget.wo,
          _object,
          _kode,
          now,
        ),
      );
      await _repo.simpan(item);
      if (!mounted) return;
      await _showSaved(item);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _message('Gagal menyimpan: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showSaved(TemuanInspeksi item) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 26),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF176DA8), Color(0xFF004D8C), KopitiamColors.navy],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: KopitiamColors.yellow,
                      foregroundColor: KopitiamColors.ink,
                      child: Icon(Icons.check_rounded, size: 30),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Temuan Tersimpan',
                      style: TextStyle(
                        color: KopitiamColors.surface,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    _receiptRow('Kode Temuan', item.kodeTemuan),
                    const SizedBox(height: 11),
                    _receiptRow('Temuan', item.temuan),
                    const SizedBox(height: 11),
                    _receiptRow('Prioritas', item.prioritas),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: FilledButton.styleFrom(
                          backgroundColor: KopitiamColors.navy,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Tutup'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  static Widget _receiptRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(
                color: KopitiamColors.muted,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: KopitiamColors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      );

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: KopitiamColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: KopitiamColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: KopitiamColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: KopitiamColors.ocean,
            width: 1.5,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving && !_capturing,
        child: Scaffold(
          backgroundColor: KopitiamColors.canvas,
          appBar: AppBar(
            backgroundColor: KopitiamColors.surface,
            foregroundColor: KopitiamColors.ink,
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tambah Temuan Baru',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                Text(
                  'Inspeksi Jaringan',
                  style: TextStyle(
                    color: KopitiamColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: AbsorbPointer(
                  absorbing: _saving || _capturing,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                    children: [
                      _hero(),
                      if (_loading) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                      ],
                      if (_loadError != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _loadError!,
                          style: const TextStyle(color: KopitiamColors.danger),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _identityCard(),
                      const SizedBox(height: 14),
                      _classificationCard(),
                      const SizedBox(height: 14),
                      _coordinateCard(),
                      const SizedBox(height: 14),
                      _photoCard(),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  18,
                  12,
                  18,
                  14 + MediaQuery.paddingOf(context).bottom,
                ),
                decoration: const BoxDecoration(
                  color: KopitiamColors.surface,
                  border: Border(top: BorderSide(color: KopitiamColors.line)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Text(
                            'Simpan Temuan',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _hero() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF176DA8), Color(0xFF004D8C), KopitiamColors.navy],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E063B5C),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KODE WORK ORDER',
              style: TextStyle(
                color: Color(0xFFD7EBEF),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.wo.kodeWo,
              style: const TextStyle(
                color: KopitiamColors.surface,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 13),
            const Divider(color: Color(0x80FBFDFE), height: 1),
            const SizedBox(height: 12),
            Text(
              'Inspeksi Jaringan • ${widget.wo.ulp}',
              style: const TextStyle(color: Color(0xFFD7EBEF), fontSize: 11),
            ),
          ],
        ),
      );

  Widget _sectionCard(int number, String title, Widget child) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: KopitiamColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: KopitiamColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10071F33),
              blurRadius: 20,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 29,
                  height: 29,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: KopitiamColors.warningSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: KopitiamColors.gold),
                  ),
                  child: Text(
                    number.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      color: KopitiamColors.warning,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 18),
            child,
          ],
        ),
      );

  Widget _identityCard() => _sectionCard(
        1,
        'Identitas Temuan',
        Column(
          children: [
            _read('NOMOR KODE TEMUAN', _kode),
            const SizedBox(height: 12),
            _read('PENYULANG', widget.wo.penyulang),
            const SizedBox(height: 12),
            _read('SECTION', widget.wo.section),
            const SizedBox(height: 12),
            TextField(
              controller: _segmenController,
              decoration: _decoration('Segmen *'),
            ),
          ],
        ),
      );

  Widget _classificationCard() => _sectionCard(
        2,
        'Klasifikasi Temuan',
        Column(
          children: [
            _read('JENIS OBJECT', _object),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('tier-$_tier'),
                    initialValue: _tier,
                    decoration: _decoration('Tier *'),
                    items: const [
                      DropdownMenuItem(value: 'Tier 1', child: Text('Tier 1')),
                      DropdownMenuItem(value: 'Tier 2', child: Text('Tier 2')),
                    ],
                    onChanged: (value) => setState(() {
                      _tier = value;
                      _temuan = null;
                      _pohon = null;
                      _jarakController.clear();
                      _tinggiController.clear();
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _read('PRIORITAS', _priority)),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('temuan-$_object-$_tier-$_temuan'),
              initialValue: _temuanOptions.contains(_temuan) ? _temuan : null,
              isExpanded: true,
              decoration: _decoration('Temuan *'),
              hint: Text(_tier == null ? 'Pilih Tier dahulu' : 'Pilih Temuan'),
              items: _temuanOptions
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: _tier == null
                  ? null
                  : (value) => setState(() {
                        _temuan = value;
                        _pohon = null;
                        _jarakController.clear();
                        _tinggiController.clear();
                      }),
            ),
            if (_isRow) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.park_rounded, color: KopitiamColors.ocean, size: 17),
                  SizedBox(width: 7),
                  Text(
                    'Kriteria ROW',
                    style: TextStyle(
                      color: KopitiamColors.ocean,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _jarakController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: _decoration('Jarak jaringan (m) *'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _tinggiController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: _decoration('Tinggi pohon (m) *'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('pohon-$_pohon'),
                initialValue: _pohonOptions.contains(_pohon) ? _pohon : null,
                isExpanded: true,
                decoration: _decoration('Jenis Pohon *'),
                items: _pohonOptions
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _pohon = value),
              ),
            ],
          ],
        ),
      );

  Widget _coordinateCard() => _sectionCard(
        3,
        'Koordinat Temuan',
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _gps == null ? KopitiamColors.surface : KopitiamColors.successSoft,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _gps == null ? KopitiamColors.line : const Color(0xFF86CFA5),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox.square(
                    dimension: 42,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_gettingGps)
                          const SizedBox.square(
                            dimension: 42,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _gps == null
                                ? KopitiamColors.cyanSoft
                                : KopitiamColors.successSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.my_location_rounded,
                            size: 19,
                            color: _gps == null
                                ? KopitiamColors.ocean
                                : KopitiamColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _gettingGps
                              ? 'Mengumpulkan sampel GPS'
                              : _gps?.coordinate ?? 'Belum diambil',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _gettingGps
                              ? 'Mengunci titik paling akurat'
                              : _gps == null
                                  ? 'Koordinat lokasi temuan belum tersedia'
                                  : 'Akurasi ${_gps!.accuracyLabel}',
                          style: const TextStyle(
                            color: KopitiamColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_gettingGps) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'Akurasi GPS',
                      style: TextStyle(color: KopitiamColors.muted, fontSize: 10),
                    ),
                    const Spacer(),
                    Text(
                      _searchAccuracy == null
                          ? 'Menunggu...'
                          : '${_searchAccuracy!.toStringAsFixed(1)} m',
                      style: const TextStyle(
                        color: KopitiamColors.ocean,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _gettingGps ? null : _getGps,
                  child: Text(
                    _gettingGps
                        ? 'Mencari koordinat...'
                        : _gps == null
                            ? 'Ambil Koordinat Temuan'
                            : 'Ambil Ulang Koordinat',
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _photoCard() => _sectionCard(
        4,
        'Foto Dokumentasi',
        Row(
          children: [
            Expanded(
              child: _photo(
                'Foto Temuan *',
                _fotoTemuan,
                () => _capture(true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _photo(
                'Foto Sekitar Tiang *',
                _fotoSekitar,
                () => _capture(false),
              ),
            ),
          ],
        ),
      );

  Widget _photo(String label, String path, VoidCallback capture) {
    final exists = path.isNotEmpty && File(path).existsSync();
    return InkWell(
      onTap: () => exists ? _photoActions(label, path, capture) : capture(),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 156,
        decoration: BoxDecoration(
          color: exists ? KopitiamColors.successSoft : KopitiamColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: exists ? KopitiamColors.success : KopitiamColors.line,
          ),
        ),
        child: exists
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(path), fit: BoxFit.cover),
                    const ColoredBox(color: Color(0x35071F33)),
                    const Center(
                      child: CircleAvatar(
                        backgroundColor: KopitiamColors.success,
                        foregroundColor: KopitiamColors.surface,
                        child: Icon(Icons.check_rounded),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 23,
                    backgroundColor: KopitiamColors.cyanSoft,
                    foregroundColor: KopitiamColors.ocean,
                    child: Icon(Icons.camera_alt_rounded),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Landscape wajib',
                    style: TextStyle(color: KopitiamColors.muted, fontSize: 9),
                  ),
                ],
              ),
      ),
    );
  }

  void _photoActions(String label, String path, VoidCallback capture) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label.replaceAll(' *', '')),
        content: const Text(
          'Foto telah tersimpan. Verifikasi apakah foto sudah sesuai.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showPhoto(path);
            },
            child: const Text('Lihat Foto'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              capture();
            },
            child: const Text('Ambil Ulang'),
          ),
        ],
      ),
    );
  }

  void _showPhoto(String path) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: KopitiamColors.cameraOverlay,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              minScale: .5,
              maxScale: 4,
              child: Center(child: Image.file(File(path), fit: BoxFit.contain)),
            ),
            Positioned(
              top: 42,
              right: 14,
              child: IconButton.filled(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded),
              ),
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
            style: const TextStyle(
              color: KopitiamColors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .3,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 46),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: KopitiamColors.surfaceStrong,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              value.trim().isEmpty ? '-' : value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: label == 'JENIS OBJECT'
                    ? KopitiamColors.ocean
                    : label == 'PRIORITAS'
                        ? KopitiamColors.success
                        : KopitiamColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      );
}
