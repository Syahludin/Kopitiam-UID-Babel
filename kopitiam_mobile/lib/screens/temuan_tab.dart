import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/temuan_inspeksi.dart';
import '../models/wo_insjar.dart';
import '../services/device_session_service.dart';
import '../services/high_accuracy_location_service.dart';
import '../services/local_auth_service.dart';
import '../services/photo_watermark_service.dart';
import '../services/temuan_repository.dart';
import 'landscape_camera_screen.dart';
import 'login_screen.dart';

class TemuanTab extends StatefulWidget {
  final WoInsjar wo;
  final Map<String, dynamic> sesi;

  const TemuanTab({super.key, required this.wo, required this.sesi});

  @override
  State<TemuanTab> createState() => _TemuanTabState();
}

class _TemuanTabState extends State<TemuanTab>
    with AutomaticKeepAliveClientMixin {
  static const blue = Color(0xFF004D8C);
  static const navy = Color(0xFF071B30);
  static const amber = Color(0xFFFFB800);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);

  final repo = TemuanRepository();
  List<TemuanInspeksi> items = [];
  bool busy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _load(remote: true);
  }

  Future<void> _load({bool remote = false}) async {
    if (!remote) {
      items = await repo.untukWo(widget.wo.kodeWo);
      if (mounted) setState(() {});
      return;
    }
    await repo.unduh('${widget.sesi['token'] ?? ''}', widget.wo.kodeWo);
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
    } catch (error) {
      if (!mounted) return;
      final text = error.toString().replaceFirst('StateError: ', '');
      final isSessionInvalid = text.toLowerCase().contains('sesi tidak valid') ||
          text.toLowerCase().contains('sudah berakhir') ||
          text.contains('[SESSION_');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: const Color(0xFFDC2626),
          action: isSessionInvalid
              ? SnackBarAction(
                  label: 'Login Ulang',
                  textColor: Colors.white,
                  onPressed: _logoutKarenaSesiInvalid,
                )
              : null,
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _logoutKarenaSesiInvalid() async {
    await DeviceSessionService.clear();
    await LocalAuthService.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumb(item.fotoTemuan),
              const SizedBox(width: 8),
              _thumb(item.fotoLingkungan),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.temuan,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
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
              ),
            ],
          ),
          if (item.dirty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.cloud_upload_outlined, size: 12, color: amber),
                const SizedBox(width: 4),
                const Text(
                  'Belum sinkron',
                  style: TextStyle(fontSize: 10, color: amber),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showImage(String path) {
    showDialog<void>(
      context: context,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Dialog.fullscreen(
          backgroundColor: Colors.black.withOpacity(0.9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: Hero(
                    tag: path,
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const Positioned(
                top: 48,
                right: 16,
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(String path) {
    final exists = path.isNotEmpty && File(path).existsSync();
    final image = exists
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(path),
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          )
        : Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: line),
            ),
            child: const Icon(
              Icons.photo_camera_back_rounded,
              color: blue,
              size: 24,
            ),
          );
    if (!exists) return image;
    return GestureDetector(
      onTap: () => _showImage(path),
      child: Hero(tag: path, child: image),
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
    return value.contains('rabas') ||
        value.contains('pangkas') ||
        value.contains('tebang');
  }

  bool get objectLocked => repo.jenisObject(widget.sesi).isNotEmpty;

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
    final options = listMaster
        .where((row) {
          final rowObject = _findValue(row, const [
            'Objek Inspeksi',
            'Jenis Object',
            'Object',
          ]);
          final rowTier = _findValue(row, const ['Tier']);
          final rowNorm = rowObject.toLowerCase().trim();
          final objNorm = object.toLowerCase().trim();
          final matchObject =
              rowNorm.isEmpty || rowNorm == objNorm;
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
    final copied = await source.copy(p.join(p.dirname(source.path), name));
    final item = TemuanInspeksi(
      kodeTemuan: kode,
      kodeWo: widget.wo.kodeWo,
      temuan: temuan ?? '',
      jenisObject: object,
      koordinat: gps?.coordinate ?? '',
      ulp: widget.wo.ulp,
      penyulang: widget.wo.penyulang,
      section: widget.wo.section,
      segmen: segmenCtrl.text.trim(),
      hari: WoInsjar.hariIndonesia[now.weekday - 1],
      tanggal: WoInsjar.formatTanggal(now),
      waktuInput: WoInsjar.stampLengkap(now),
    );
    // Watermark dibuat saat pengambilan foto, bukan saat simpan, agar
    // foto tampil menampilkan tanda air langsung.
    return PhotoWatermarkService.render(
      sourcePath: copied.path,
      item: item,
      photoLabel: label,
    );
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
        folderPath: TemuanRepository.folder(widget.wo, object, kode, now),
      );
      await repo.simpan(item);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
        elevation: 0,
        titleSpacing: 16,
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
                const Text(
                  'Temuan disimpan di server lokal, lalu disinkronkan.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: saving ? null : _save,
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
                        : const Text(
                            'Simpan Temuan ke Server Lokal',
                            style: TextStyle(fontWeight: FontWeight.w800),
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
          widget.wo.kodeWo,
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
                widget.wo.ulp,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _identity() =>
      _sectionCard('1', Icons.tag_rounded, 'Identitas Temuan', [
        Row(
          children: [
            Expanded(child: _read('Kode Temuan', kode)),
            const SizedBox(width: 10),
            Expanded(child: _objectField()),
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
          decoration: _inputDecoration('Segmen *'),
        ),
      ]);

  Widget _objectField() {
    if (objectLocked) {
      return _read('Jenis Object', object);
    }
    return DropdownButtonFormField<String>(
      value: objectOptions.contains(object) ? object : null,
      hint: const Text('--Pilih Object--'),
      items: objectOptions
          .map(
            (value) => DropdownMenuItem(value: value, child: Text(value)),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          object = value;
          temuan = null;
        });
      },
      decoration: _inputDecoration('Jenis Object *'),
    );
  }

  Widget _classification(
    List<String> trees,
  ) => _sectionCard('2', Icons.tune_rounded, 'Klasifikasi Temuan', [
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
            decoration: _inputDecoration('Tier *'),
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
          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
          .toList(),
      onChanged: tier == null
          ? null
          : (value) => setState(() => temuan = value),
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
              decoration: _inputDecoration('Jarak Terhadap Jaringan(m) *'),
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
              decoration: _inputDecoration('Tinggi Batang(m) *'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: trees.contains(pohon) ? pohon : null,
        items: trees
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: (value) => setState(() => pohon = value),
        decoration: _inputDecoration('Jenis Pohon *'),
      ),
    ],
  ]);

  Widget _gpsCard() => _sectionCard(
    '3',
    Icons.my_location_rounded,
    'Koordinat Temuan',
    [
      Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            mengambilGps ? 'Mencari akurasi...' : 'Ambil Koordinat Temuan',
          ),
        ),
      ),
    ],
  );

  Widget _photos() =>
      _sectionCard('4', Icons.photo_camera_back_rounded, 'Foto Dokumentasi', [
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
      ]);

  Widget _photo(String label, String path, VoidCallback onTap) {
    final exists = path.isNotEmpty && File(path).existsSync();
    return InkWell(
      onTap: onTap,
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
