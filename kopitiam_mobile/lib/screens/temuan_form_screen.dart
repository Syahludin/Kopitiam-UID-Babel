import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/temuan_inspeksi.dart';
import '../models/c4a_selection.dart';
import '../models/wo_insjar.dart';
import '../services/high_accuracy_location_service.dart';
import '../services/photo_watermark_service.dart';
import '../services/role_provider.dart';
import '../services/temuan_repository.dart';
import 'landscape_camera_screen.dart';
import 'c4a_route_guard.dart';

class TemuanFormScreen extends StatefulWidget {
  final WoInsjar? wo;
  final Map<String, dynamic> sesi;
  final TemuanRepository? repository;
  final Future<LocationFix> Function()? acquireLocation;
  final Future<String?> Function(String label)? capturePhoto;

  const TemuanFormScreen({
    super.key,
    required WoInsjar this.wo,
    required this.sesi,
    this.repository,
    this.acquireLocation,
    this.capturePhoto,
  });

  /// Dipanggil FAB daftar lokal C4A (integrasi beranda pada Fase 2).
  const TemuanFormScreen.c4a({
    super.key,
    required this.sesi,
    this.repository,
    this.acquireLocation,
    this.capturePhoto,
  }) : wo = null;

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

  late final repo = widget.repository ?? TemuanRepository();
  bool get isC4a => widget.wo == null;
  C4aSelection? c4a;
  String? loadError;
  List<Map<String, dynamic>> penyulangMaster = [], keypointMaster = [];
  String? penyulang, sectionAwal, sectionAkhir;
  String garduSection = '', garduLat = '', garduLong = '';
  String get selectedSection => isInspeksiGardu
      ? garduSection
      : C4aSelection.section(sectionAwal, sectionAkhir);
  String get coordinate => isC4a && isInspeksiGardu
      ? (C4aSelection.validCoordinate(garduLat, garduLong)
            ? '$garduLat, $garduLong'
            : '')
      : (gps?.coordinate ?? '');
  String unitValue(String key) => c4a?.identity[key] ?? '';
  final segmenCtrl = TextEditingController();
  final garduCtrl = TextEditingController();
  final jarakCtrl = TextEditingController();
  final tinggiCtrl = TextEditingController();

  List<Map<String, dynamic>> listMaster = [];
  List<Map<String, dynamic>> garduMaster = [];
  List<Map<String, dynamic>> pohonMaster = [];
  String kode = '';
  String object = 'Jaringan';
  String? tier;
  String? temuan;
  String? pohon;
  String? selectedGardu;
  LocationFix? gps;
  String foto = '';
  String lingkungan = '';
  bool saving = false;
  bool capturing = false;
  bool mengambilGps = false;

  bool get isInspeksiGardu => object.toLowerCase() == 'gardu';

  bool get isVegetasi {
    if (isC4a) return repo.isRowC4a(temuan ?? '');
    final value = (temuan ?? '').toLowerCase();
    return value.contains('rabas') ||
        value.contains('pangkas') ||
        value.contains('tebang');
  }

  bool get objectLocked => !isC4a && repo.jenisObject(widget.sesi).isNotEmpty;
  List<String> get objectOptions => const ['Jaringan', 'Gardu'];

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
    if (isC4a) {
      return C4aSelection.temuanForTier(listMaster, object, tier)
          .map((r) => _findValue(r, ['Temuan']))
          .where((v) => v.isNotEmpty)
          .toSet()
          .toList();
    }

    // Tentukan target object strictly: 'jaringan' atau 'gardu'
    final determined = isC4a
        ? ''
        : repo.jenisObject(widget.sesi).toLowerCase().trim();
    final targetObject = (determined.isNotEmpty ? determined : object)
        .toLowerCase()
        .trim();

    return listMaster
        .where((row) {
          // Periksa kolom objek inspeksi
          final rowObject = _findValue(row, const [
            'Object Inspeksi',
            'Objek Inspeksi',
            'Object',
            'Objek',
            'Jenis Object',
            'Jenis Objek',
            'Objektif',
            'Kategori',
          ]).trim().toLowerCase();

          // Bila kolom objek terdeteksi di master temuan
          if (rowObject.isNotEmpty) {
            if (targetObject == 'jaringan') {
              // Harus memuat kata jaringan atau jtr/jtm dan tidak boleh khusus gardu
              if (rowObject.contains('gardu') &&
                  !rowObject.contains('jaringan')) {
                return false;
              }
              if (!rowObject.contains('jaringan') &&
                  !rowObject.contains('jar') &&
                  !rowObject.contains('line') &&
                  !rowObject.contains('saluran')) {
                return false;
              }
            } else if (targetObject == 'gardu') {
              if (!rowObject.contains('gardu') &&
                  !rowObject.contains('trafo')) {
                return false;
              }
            }
          }

          final rowTier = _findValue(row, const ['Tier']);
          if (rowTier.trim().isNotEmpty &&
              rowTier.trim().toLowerCase() != tier!.toLowerCase()) {
            return false;
          }
          return true;
        })
        .map((row) => _findValue(row, const ['Temuan', 'Nama Temuan']))
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> get garduOptions {
    if (isC4a) return c4a?.garduOptions(garduMaster) ?? [];
    return garduMaster
        .map(
          (row) =>
              _findValue(row, const ['GARDU', 'Gardu', 'Nama Gardu', 'gardu']),
        )
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    segmenCtrl.dispose();
    garduCtrl.dispose();
    jarakCtrl.dispose();
    tinggiCtrl.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      kode = isC4a ? '' : await repo.kodeBaru(widget.wo!.kodeWo);
      final determined = isC4a ? '' : repo.jenisObject(widget.sesi);
      object = isC4a ? '' : (determined.isNotEmpty ? determined : 'Jaringan');
      listMaster = await repo.master('Master_Temuan');
      pohonMaster = await repo.master('Jenis Pohon');
      garduMaster = await repo.master('Master_Gardu');
      if (isC4a) {
        c4a = C4aSelection(widget.sesi, await repo.master('User_App_Mobile'));
        penyulangMaster = await repo.master('Master_Penyulang');
        keypointMaster = await repo.master('Master_Keypoint');
      }
    } catch (error) {
      loadError = 'Master lokal belum tersedia: $error';
    }
    if (mounted) setState(() {});
  }

  Future<void> _ambilGps() async {
    if (mengambilGps || saving || (isC4a && object != 'Jaringan')) return;
    setState(() => mengambilGps = true);
    final asset = '${c4a?.ulp}|$object|$penyulang|$selectedSection';
    try {
      final fix =
          await (widget.acquireLocation?.call() ??
              HighAccuracyLocationService.acquire(onSample: (_, __) {}));
      if (isC4a &&
          (!fix.locked ||
              fix.accuracy > HighAccuracyLocationService.lockAccuracy ||
              !fix.accuracy.isFinite ||
              fix.accuracy <= 0 ||
              !C4aSelection.validCoordinate(
                '${fix.latitude}',
                '${fix.longitude}',
              ))) {
        throw StateError('GPS belum presisi (maksimal 5 m). Ambil ulang.');
      }
      if (mounted &&
          (!isC4a ||
              asset == '${c4a?.ulp}|$object|$penyulang|$selectedSection')) {
        setState(() {
          gps = fix;
          if (isC4a) {
            foto = '';
            lingkungan = '';
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => mengambilGps = false);
        _message('Gagal mengambil koordinat: $error');
      }
    } finally {
      if (mounted) setState(() => mengambilGps = false);
    }
  }

  Future<String> _ambilFoto(String label) async {
    if (isC4a &&
        (coordinate.isEmpty ||
            !temuanOptions.contains(temuan) ||
            selectedSection.isEmpty)) {
      throw StateError(
        'Lengkapi aset, Temuan dan koordinat sebelum mengambil foto.',
      );
    }
    final capturedPath =
        await (widget.capturePhoto?.call(label) ??
            LandscapeCameraScreen.capture(context, title: label));
    if (capturedPath == null || capturedPath.isEmpty) return '';
    final source = File(capturedPath);
    if (!await source.exists() || await source.length() <= 0) {
      throw StateError('Foto kamera tidak tersimpan.');
    }
    // Watermark C4A dibuat saat nomor final dialokasikan pada simpan atomik.
    if (isC4a) return source.path;
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final name =
        '$kode.$label.${two(now.hour)}${two(now.minute)}${two(now.second)}.jpg';
    final copied = await source.copy(p.join(p.dirname(source.path), name));
    final item = TemuanInspeksi(
      kodeTemuan: kode,
      kodeWo: widget.wo?.kodeWo ?? '',
      temuan: temuan ?? '',
      jenisObject: object,
      koordinat: gps?.coordinate ?? '',
      ulp: isC4a ? unitValue('ulp') : widget.wo!.ulp,
      penyulang: isC4a ? (penyulang ?? '') : widget.wo!.penyulang,
      section: isC4a ? selectedSection : widget.wo!.section,
      segmen: isInspeksiGardu
          ? (selectedGardu ?? garduCtrl.text.trim())
          : segmenCtrl.text.trim(),
      nomorGardu: isInspeksiGardu
          ? (selectedGardu ?? garduCtrl.text.trim())
          : '',
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

  String get calculatedPriority {
    if (temuan == null || temuan!.isEmpty) return '';
    if (isC4a) {
      return repo.prioritasC4a(
        temuan!,
        double.tryParse(jarakCtrl.text.replaceAll(',', '.')),
        double.tryParse(tinggiCtrl.text.replaceAll(',', '.')),
        C4aSelection.temuanForTier(listMaster, object, tier),
      );
    }
    return repo.prioritas(
      temuan!,
      double.tryParse(jarakCtrl.text.replaceAll(',', '.')),
      double.tryParse(tinggiCtrl.text.replaceAll(',', '.')),
      listMaster,
    );
  }

  Future<void> _save() async {
    if (saving || capturing || mengambilGps) return;
    if (isC4a &&
        (c4a?.identity.isNotEmpty != true ||
            !temuanOptions.contains(temuan) ||
            selectedSection.isEmpty ||
            (penyulang ?? '').isEmpty ||
            (isInspeksiGardu &&
                c4a?.gardu(garduMaster, selectedGardu) == null))) {
      _message('Lengkapi unit, aset dan Temuan dari master lokal.');
      return;
    }
    if (tier == null || tier!.isEmpty) {
      _message('Pilih Tier terlebih dahulu.');
      return;
    }

    final locationValue = isInspeksiGardu
        ? (selectedGardu ?? garduCtrl.text.trim())
        : segmenCtrl.text.trim();

    if (locationValue.isEmpty) {
      _message(
        isInspeksiGardu
            ? 'Pilih atau isi Nomor Gardu.'
            : 'Isi Segmen terlebih dahulu.',
      );
      return;
    }

    if (coordinate.isEmpty ||
        object.isEmpty ||
        temuan == null ||
        temuan!.isEmpty ||
        foto.isEmpty ||
        lingkungan.isEmpty) {
      _message(
        'Lengkapi ${isInspeksiGardu ? "Nomor Gardu" : "Segmen"}, Temuan, GPS, dan kedua foto.',
      );
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
      final coordinates = coordinate.split(',');
      final item = TemuanInspeksi(
        kodeTemuan: kode,
        kodeWo: widget.wo?.kodeWo ?? '',
        kodeUiw: isC4a ? unitValue('kode_uiw') : widget.wo!.kodeUiw,
        kodeUp3: isC4a ? unitValue('kode_up3') : widget.wo!.kodeUp3,
        kodeUlp: isC4a ? unitValue('kode_ulp') : widget.wo!.kodeUlp,
        ulp: isC4a ? unitValue('ulp') : widget.wo!.ulp,
        hari: WoInsjar.hariIndonesia[now.weekday - 1],
        tanggal: WoInsjar.formatTanggal(now),
        penyulang: isC4a ? (penyulang ?? '') : widget.wo!.penyulang,
        sectionAwal: isC4a ? (sectionAwal ?? '') : widget.wo!.sectionAwal,
        sectionAkhir: isC4a ? (sectionAkhir ?? '') : widget.wo!.sectionAkhir,
        section: isC4a ? selectedSection : widget.wo!.section,
        segmen: isInspeksiGardu ? locationValue : segmenCtrl.text.trim(),
        nomorGardu: isInspeksiGardu ? locationValue : '',
        koordinat: coordinate,
        lat: coordinates.first.trim(),
        long: coordinates.length > 1 ? coordinates[1].trim() : '',
        jenisObject: object,
        tier: tier!,
        temuan: temuan!,
        jarak: isVegetasi
            ? double.tryParse(jarakCtrl.text.replaceAll(',', '.'))
            : null,
        jenisPohon: isVegetasi ? (pohon ?? '') : '',
        tinggiPohon: isVegetasi
            ? double.tryParse(tinggiCtrl.text.replaceAll(',', '.'))
            : null,
        prioritas: calculatedPriority,
        fotoTemuan: foto,
        fotoLingkungan: lingkungan,
        waktuInput: WoInsjar.stampLengkap(now),
        userInput: '${widget.sesi['username'] ?? ''}',
        folderPath: isC4a
            ? ''
            : TemuanRepository.folder(widget.wo!, object, kode, now),
      );
      if (isC4a) {
        repo.validateC4a(item);
        final stored = await repo.simpanC4a(item);
        kode = stored.kodeTemuan;
      } else {
        await repo.simpan(item);
      }
      if (mounted) {
        setState(() => saving = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) _message('Gagal menyimpan: $error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (isC4a &&
        widget.sesi.containsKey('role') &&
        !RoleProvider.hasC4aAccess(widget.sesi)) {
      return const C4aAccessDeniedScreen();
    }
    final trees = pohonMaster
        .map((row) => _findValue(row, const ['Jenis Pohon', 'Pohon', 'Nama']))
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
    return PopScope(
      canPop: !saving && !capturing,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          title: Text(
            isC4a ? 'Tambah Temuan C4A' : 'Tambah Temuan Baru',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          backgroundColor: blue,
          foregroundColor: Colors.white,
          elevation: 0,
          titleSpacing: 16,
        ),
        body: Column(
          children: [
            Expanded(
              child: AbsorbPointer(
                absorbing: saving || capturing,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (loadError != null) Text(loadError!),
                    if (isC4a) _unitFields() else _header(),
                    const SizedBox(height: 14),
                    _identity(),
                    const SizedBox(height: 14),
                    if (isC4a) ...[_assetSummary(), const SizedBox(height: 14)],
                    _classification(trees),
                    const SizedBox(height: 14),
                    _gpsCard(),
                    const SizedBox(height: 14),
                    _photos(),
                  ],
                ),
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
                  Text(
                    isC4a
                        ? 'Temuan disimpan di perangkat tanpa Work Order.'
                        : 'Temuan disimpan di server lokal, lalu disinkronkan.',
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed:
                          saving ||
                              capturing ||
                              mengambilGps ||
                              (isC4a && c4a == null)
                          ? null
                          : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: amber,
                        foregroundColor: navy,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: saving
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
                              isC4a
                                  ? 'Simpan Lokal'
                                  : 'Simpan Temuan ke Server Lokal',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _box() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: line),
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

  Widget _sectionCard(
    String badge,
    IconData icon,
    String title,
    List<Widget> children,
  ) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: _box(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 18, color: blue),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: blue,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );

  Widget _header() => Container(
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
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.assignment_turned_in_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Work Order',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: amber,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text(
                'Temuan',
                style: TextStyle(
                  color: navy,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          widget.wo!.kodeWo,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.location_city_rounded,
              size: 15,
              color: Colors.white70,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.wo!.ulp,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _identity() => _sectionCard(
    isC4a ? '2' : '1',
    Icons.tag_rounded,
    isC4a ? 'Pilih Aset C4A' : 'Identitas Temuan',
    [
      if (isC4a)
        _objectField()
      else
        Row(
          children: [
            Expanded(child: _read('Kode Temuan', kode)),
            const SizedBox(width: 10),
            Expanded(child: _objectField()),
          ],
        ),
      const SizedBox(height: 12),
      if (isC4a && object == 'Jaringan')
        ..._networkFields()
      else if (!isC4a)
        Row(
          children: [
            Expanded(child: _read('Penyulang', widget.wo?.penyulang ?? '')),
            const SizedBox(width: 10),
            Expanded(child: _read('Section', widget.wo?.section ?? '')),
          ],
        ),
      const SizedBox(height: 12),
      if (isC4a && isInspeksiGardu) ...[
        _drop(
          'Nomor Gardu *',
          selectedGardu,
          garduOptions,
          (v) => setState(() {
            selectedGardu = v;
            gps = null;
            foto = '';
            lingkungan = '';
            final row = c4a?.gardu(garduMaster, v) ?? <String, dynamic>{};
            penyulang = C4aSelection.value(row, ['Penyulang']);
            garduSection = C4aSelection.value(row, ['PTS/LBS', 'Section']);
            garduLat = C4aSelection.latitude(row);
            garduLong = C4aSelection.longitude(row);
          }),
        ),
        _read('Penyulang', penyulang ?? ''),
        _read('Section', garduSection),
      ] else if (!isInspeksiGardu && (!isC4a || object == 'Jaringan'))
        TextField(
          controller: segmenCtrl,
          onChanged: isC4a
              ? (_) => setState(() {
                  foto = '';
                  lingkungan = '';
                })
              : null,
          decoration: _inputDecoration('Segmen *'),
        )
      else if (!isC4a)
        garduOptions.isNotEmpty
            ? DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: garduOptions.contains(selectedGardu)
                    ? selectedGardu
                    : null,
                hint: const Text('--Pilih Nomor Gardu--'),
                items: garduOptions
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => selectedGardu = v),
                decoration: _inputDecoration('Nomor Gardu *'),
              )
            : TextField(
                controller: garduCtrl,
                decoration: _inputDecoration('Nomor Gardu *'),
              ),
    ],
  );

  Widget _objectField() {
    if (objectLocked) return _read('Jenis Object', object);
    return DropdownButtonFormField<String>(
      key: ValueKey('object-$object'),
      initialValue: objectOptions.contains(object) ? object : null,
      hint: const Text('--Pilih Object--'),
      items: objectOptions
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: isC4a && c4a?.ready != true
          ? null
          : (v) {
              if (v == null || v == object) return;
              setState(() {
                object = v;
                if (isC4a) {
                  penyulang = null;
                  sectionAwal = null;
                  sectionAkhir = null;
                  garduSection = '';
                  garduLat = '';
                  garduLong = '';
                }
                tier = null;
                temuan = null;
                pohon = null;
                selectedGardu = null;
                segmenCtrl.clear();
                garduCtrl.clear();
                jarakCtrl.clear();
                tinggiCtrl.clear();
                if (isC4a) {
                  gps = null;
                  foto = '';
                  lingkungan = '';
                }
              });
            },
      decoration: _inputDecoration('Jenis Object *'),
    );
  }

  void _resetC4aAsset() {
    garduSection = '';
    garduLat = '';
    garduLong = '';
    penyulang = null;
    sectionAwal = null;
    sectionAkhir = null;
    object = '';
    selectedGardu = null;
    tier = null;
    temuan = null;
    gps = null;
    foto = '';
    lingkungan = '';
    pohon = null;
    segmenCtrl.clear();
    garduCtrl.clear();
    jarakCtrl.clear();
    tinggiCtrl.clear();
  }

  Widget _drop(
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?>? change, {
    Map<String, String> labels = const {},
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$value-${options.join(',')}'),
      initialValue: options.contains(value) ? value : null,
      isExpanded: true,
      decoration: _inputDecoration(label),
      items: options
          .map((v) => DropdownMenuItem(value: v, child: Text(labels[v] ?? v)))
          .toList(),
      onChanged: options.isEmpty ? null : change,
    ),
  );

  List<Widget> _networkFields() {
    final sections =
        c4a?.sectionOptions(keypointMaster, penyulang) ?? <String>[];
    void resetEvidence() {
      gps = null;
      foto = '';
      lingkungan = '';
      segmenCtrl.clear();
    }

    return [
      _drop(
        'Penyulang *',
        penyulang,
        c4a?.penyulangOptions(penyulangMaster) ?? [],
        (v) => setState(() {
          penyulang = v;
          sectionAwal = null;
          sectionAkhir = null;
          resetEvidence();
        }),
      ),
      _drop(
        'Section Awal *',
        sectionAwal,
        sections,
        (v) => setState(() {
          sectionAwal = v;
          sectionAkhir = null;
          resetEvidence();
        }),
      ),
      _drop(
        'Section Akhir *',
        sectionAkhir,
        sections.where((s) => s != sectionAwal).toList(),
        sectionAwal == null
            ? null
            : (v) => setState(() {
                sectionAkhir = v;
                resetEvidence();
              }),
      ),
      _read('Section', selectedSection),
    ];
  }

  Widget _unitFields() {
    final selection = c4a;
    if (selection == null) return const Text('Memuat master lokal...');
    return _sectionCard('1', Icons.location_city, 'Unit C4A', [
      if (selection.isUid)
        _drop(
          'UP3',
          selection.up3,
          selection.up3Options,
          (v) => setState(() {
            selection.selectUp3(v);
            _resetC4aAsset();
          }),
          labels: C4aSelection.up3Labels,
        ),
      if (!selection.isUlp)
        _drop(
          'ULP',
          selection.ulp,
          selection.ulpOptions,
          (v) => setState(() {
            selection.selectUlp(v);
            _resetC4aAsset();
          }),
          labels: C4aSelection.ulpLabels,
        )
      else
        _read('ULP', C4aSelection.ulpLabels[selection.ulp] ?? ''),
      if (!selection.ready)
        const Text('Pilih unit; unduh master jika pilihan tidak tersedia.'),
      if (selection.ready) ...[
        _read('Kode UIW', unitValue('kode_uiw')),
        _read('Kode UP3', unitValue('kode_up3')),
        _read('Kode ULP', unitValue('kode_ulp')),
        _read('User Input', C4aSelection.value(widget.sesi, ['username'])),
      ],
    ]);
  }

  Widget _assetSummary() =>
      _sectionCard('3', Icons.fact_check_outlined, 'Aset yang Dinilai', [
        if (c4a?.ready != true ||
            object.isEmpty ||
            (penyulang ?? '').isEmpty ||
            selectedSection.isEmpty)
          const Text('Belum ada aset lengkap yang dipilih.')
        else
          Row(
            key: const ValueKey('c4a-asset-row'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isInspeksiGardu ? Icons.electrical_services : Icons.cable,
                color: blue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  [
                    C4aSelection.ulpLabels[c4a!.ulp] ?? '',
                    object,
                    if (isInspeksiGardu) selectedGardu ?? '',
                    penyulang!,
                    selectedSection,
                    if (!isInspeksiGardu) segmenCtrl.text.trim(),
                  ].where((s) => s.isNotEmpty).join(' • '),
                ),
              ),
            ],
          ),
      ]);

  Widget _classification(List<String> trees) => _sectionCard(
    isC4a ? '4' : '2',
    Icons.tune_rounded,
    'Klasifikasi Temuan',
    [
      if (isC4a) ...[
        _read(
          'Kode Temuan',
          kode.isEmpty ? 'Otomatis saat Simpan Lokal' : kode,
        ),
        const SizedBox(height: 12),
      ],
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              key: ValueKey('tier-$tier'),
              isExpanded: true,
              initialValue: tier,
              hint: const Text('--Pilih Tier--'),
              items: const [
                DropdownMenuItem(value: 'Tier 1', child: Text('Tier 1')),
                DropdownMenuItem(value: 'Tier 2', child: Text('Tier 2')),
              ],
              onChanged: isC4a && object.isEmpty
                  ? null
                  : (v) {
                      if (v == null || v == tier) return;
                      setState(() {
                        tier = v;
                        if (isC4a) {
                          foto = '';
                          lingkungan = '';
                        }
                        temuan = null;
                        pohon = null;
                        jarakCtrl.clear();
                        tinggiCtrl.clear();
                      });
                    },
              decoration: _inputDecoration('Tier *'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _read('Prioritas', calculatedPriority)),
        ],
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey('temuan-$object-$tier-$temuan'),
        isExpanded: true,
        initialValue: temuanOptions.contains(temuan) ? temuan : null,
        hint: Text(tier == null ? 'Pilih Tier dahulu' : 'Pilih Temuan'),
        items: temuanOptions
            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
            .toList(),
        onChanged: tier == null
            ? null
            : (v) {
                if (v == temuan) return;
                final wasVegetasi = isVegetasi;
                setState(() {
                  temuan = v;
                  if (isC4a) {
                    foto = '';
                    lingkungan = '';
                  }
                  if (wasVegetasi) {
                    pohon = null;
                    jarakCtrl.clear();
                    tinggiCtrl.clear();
                  }
                });
              },
        decoration: _inputDecoration('Nama Temuan *'),
      ),
      if (isVegetasi) ...[
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: jarakCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: _inputDecoration('Jarak Thd\nJaringan (m) *'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: tinggiCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: _inputDecoration('Tinggi\nBatang (m) *'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('pohon-$object-$tier-$temuan-$pohon'),
          isExpanded: true,
          initialValue: trees.contains(pohon) ? pohon : null,
          items: trees
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) => setState(() => pohon = v),
          decoration: _inputDecoration('Jenis Pohon *'),
        ),
      ],
    ],
  );

  Widget _gpsCard() => isC4a && isInspeksiGardu
      ? _sectionCard('5', Icons.place, 'Koordinat Temuan', [
          _read(
            'Koordinat Master Gardu (lat, long)',
            coordinate.isEmpty
                ? 'Koordinat master tidak valid / belum dipilih'
                : coordinate,
          ),
        ])
      : _sectionCard(
          isC4a ? '5' : '3',
          Icons.my_location_rounded,
          'Koordinat Temuan',
          [
            InkWell(
              onTap: mengambilGps ? null : _ambilGps,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.place_rounded,
                      size: 20,
                      color: gps == null ? muted : green,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        gps?.coordinate ?? 'Belum diambil',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: gps == null ? muted : navy,
                        ),
                      ),
                    ),
                    if (gps != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'Akurasi ${gps!.accuracyLabel}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: green,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: mengambilGps ? null : _ambilGps,
                style: OutlinedButton.styleFrom(
                  foregroundColor: blue,
                  side: const BorderSide(color: blue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.my_location),
                label: Text(
                  mengambilGps
                      ? 'Mencari akurasi...'
                      : 'Ambil Koordinat Temuan',
                ),
              ),
            ),
          ],
        );

  Widget _photos() => _sectionCard(
    isC4a ? '6' : '4',
    Icons.photo_camera_back_rounded,
    'Foto Dokumentasi',
    [
      Row(
        children: [
          Expanded(
            child: _photo('Foto Temuan *', foto, () => _captureEvidence(true)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _photo(
              'Foto Sekitar Tiang *',
              lingkungan,
              () => _captureEvidence(false),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Row(
        children: [
          Icon(Icons.gpp_good_rounded, size: 14, color: green),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Foto diambil landscape',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ),
        ],
      ),
    ],
  );

  Future<void> _captureEvidence(bool primary) async {
    if (saving || capturing || mengambilGps) return;
    setState(() => capturing = true);
    try {
      final path = await _ambilFoto(
        primary ? 'Foto Temuan' : 'Foto Lingkungan',
      );
      if (mounted && path.isNotEmpty) {
        setState(() {
          if (primary) {
            foto = path;
          } else {
            lingkungan = path;
          }
        });
      }
    } catch (error) {
      if (mounted) _message('$error');
    } finally {
      if (mounted) setState(() => capturing = false);
    }
  }

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
    return InkWell(
      onTap: () => _onPhotoTap(label, path, onCapture),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: exists ? blue : line,
            width: exists ? 1.4 : 1,
          ),
        ),
        child: exists
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.file(File(path), fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC071B30),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        label.replaceAll(' *', ''),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
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
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F1FA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.screen_rotation_rounded,
                      color: blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Landscape wajib',
                    style: TextStyle(fontSize: 10, color: muted),
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
}
