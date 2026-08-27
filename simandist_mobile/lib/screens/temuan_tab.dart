import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../models/temuan_inspeksi.dart';
import '../models/wo_insjar.dart';
import '../services/high_accuracy_location_service.dart';
import '../services/temuan_repository.dart';

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
      await repo.unduh(
        '${widget.sesi['token'] ?? ''}',
        widget.wo.kodeWo,
      );
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
  static const line = Color(0xFFE2E8F0);

  final repo = TemuanRepository();
  final segmenCtrl = TextEditingController();
  final jarakCtrl = TextEditingController();
  final tinggiCtrl = TextEditingController();
  final picker = ImagePicker();

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
    final t = (temuan ?? '').toLowerCase();
    return t.contains('rabas') || t.contains('pangkas') || t.contains('tebang');
  }

  String _cleanKey(String key) {
    return key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _findValue(Map<String, dynamic> map, List<String> candidateKeys) {
    for (final cand in candidateKeys) {
      if (map.containsKey(cand) && '${map[cand] ?? ''}'.trim().isNotEmpty) {
        return '${map[cand]}'.trim();
      }
    }
    final normalizedCandidates = candidateKeys.map(_cleanKey).toSet();
    for (final entry in map.entries) {
      if (normalizedCandidates.contains(_cleanKey(entry.key)) && '${entry.value ?? ''}'.trim().isNotEmpty) {
        return '${entry.value}'.trim();
      }
    }
    return '';
  }

  List<String> get temuanOptions {
    if (tier == null || tier!.isEmpty) return [];

    final list = listMaster
        .where((row) {
          final rowObject = _findValue(row, [
            'Objek Inspeksi',
            'Objek_Inspeksi',
            'Jenis Object',
            'Jenis_Object',
            'Object',
            'objek',
            'object'
          ]);
          final rowTier = _findValue(row, ['Tier', 'tier']);

          final matchObject = rowObject.isEmpty || rowObject.toLowerCase().contains(object.toLowerCase()) || object.toLowerCase().contains(rowObject.toLowerCase());
          final matchTier = rowTier.isEmpty || rowTier.toLowerCase() == tier!.toLowerCase();

          return matchObject && matchTier;
        })
        .map((row) => _findValue(row, ['Temuan', 'Nama Temuan', 'temuan']))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    if (list.isEmpty) {
      return listMaster
          .where((row) {
            final rowTier = _findValue(row, ['Tier', 'tier']);
            return rowTier.isEmpty || rowTier.toLowerCase() == tier!.toLowerCase();
          })
          .map((row) => _findValue(row, ['Temuan', 'Nama Temuan', 'temuan']))
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();
    }
    return list;
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
    final determinedObject = repo.jenisObject(widget.sesi);
    object = determinedObject.isNotEmpty ? determinedObject : 'Jaringan';
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
    } catch (e) {
      if (mounted) {
        setState(() => mengambilGps = false);
        _message('Gagal mengambil koordinat: $e');
      }
    }
  }

  Future<String> _ambilFoto(String label) async {
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1920,
    );
    if (image == null) return '';
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final name =
        '$kode.$label.${two(now.hour)}${two(now.minute)}${two(now.second)}.jpg';
    final target = p.join(p.dirname(image.path), name);
    return (await File(image.path).copy(target)).path;
  }

  String _pick(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = '${row[key] ?? ''}'.trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String get calculatedPriority {
    if (temuan == null || temuan!.isEmpty) return '';
    final distance = double.tryParse(jarakCtrl.text.replaceAll(',', '.'));
    final treeHeight = double.tryParse(tinggiCtrl.text.replaceAll(',', '.'));
    return repo.prioritas(temuan!, distance, treeHeight, listMaster);
  }

  Future<void> _save() async {
    if (tier == null || tier!.isEmpty) {
      _message('Pilih Tier terlebih dahulu.');
      return;
    }
    final missingBase = segmenCtrl.text.trim().isEmpty ||
        gps == null ||
        object.isEmpty ||
        temuan == null ||
        temuan!.isEmpty ||
        foto.isEmpty;
    if (missingBase) {
      _message('Lengkapi Segmen, Temuan, GPS, dan Foto Temuan.');
      return;
    }
    if (isVegetasi) {
      if (jarakCtrl.text.trim().isEmpty) {
        _message('Jarak terhadap jaringan wajib diisi.');
        return;
      }
      if (pohon == null || pohon!.isEmpty || tinggiCtrl.text.trim().isEmpty) {
        _message('Jenis dan tinggi pohon wajib diisi untuk temuan vegetasi.');
        return;
      }
    }

    setState(() => saving = true);
    try {
      final now = DateTime.now();
      final distance = double.tryParse(jarakCtrl.text.replaceAll(',', '.'));
      final treeHeight = double.tryParse(tinggiCtrl.text.replaceAll(',', '.'));
      final coordinate = gps!.coordinate.split(',');
      final priority = repo.prioritas(
        temuan!,
        distance,
        treeHeight,
        listMaster,
      );
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
        tinggiPohon: isVegetasi ? treeHeight : null,
        prioritas: priority,
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
    final treeOptions = pohonMaster
        .map((row) => _pick(row, ['Jenis Pohon', 'Pohon', 'Nama']))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Tambah Temuan Baru',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 14),
                _buildIdentitasCard(),
                const SizedBox(height: 14),
                _buildKlasifikasiCard(treeOptions),
                const SizedBox(height: 14),
                _buildGpsCard(),
                const SizedBox(height: 14),
                _buildFotoCard(),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 10,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFAE00),
                  foregroundColor: const Color(0xFF1E293B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Simpan Temuan ke Server Lokal',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: blue,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0A3E74),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Konteks Work Order',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.wo.kodeWo.isNotEmpty ? widget.wo.kodeWo : '-',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.wo.ulp.isNotEmpty ? widget.wo.ulp : 'Toboali',
            style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentitasCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📌 Identitas Temuan',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: blue),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kode Temuan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    _buildReadOnlyPill(kode.isNotEmpty ? kode : 'Menyiapkan...'),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Jenis Object', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    _buildReadOnlyPill(object.isNotEmpty ? object : '-'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Penyulang (Terkunci)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    _buildReadOnlyPill(widget.wo.penyulang),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Section (Terkunci)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    _buildReadOnlyPill(widget.wo.section),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Segmen *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
          const SizedBox(height: 6),
          TextField(
            controller: segmenCtrl,
            decoration: InputDecoration(
              hintText: 'Ketik segmen / titik tiang...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: blue, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKlasifikasiCard(List<String> treeOptions) {
    final priority = calculatedPriority;
    final currentTemuanOptions = temuanOptions;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔍 Klasifikasi Temuan',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: blue),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tier *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: tier,
                      hint: const Text('--Pilih Tier--', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                      items: const [
                        DropdownMenuItem(value: 'Tier 1', child: Text('Tier 1', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'Tier 2', child: Text('Tier 2', style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (v) {
                        setState(() {
                          tier = v;
                          temuan = null;
                        });
                      },
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Prioritas (Auto)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: priority == 'Mayor'
                            ? const Color(0xFFFEE2E2)
                            : (priority == 'Sedang' ? const Color(0xFFFEF3C7) : const Color(0xFFE0E7FF)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        priority.isNotEmpty ? priority : '-',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: priority == 'Mayor'
                              ? const Color(0xFFDC2626)
                              : (priority == 'Sedang' ? const Color(0xFFD97706) : const Color(0xFF4338CA)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Nama Temuan *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: (temuan != null && currentTemuanOptions.contains(temuan)) ? temuan : null,
            hint: Text(
              tier == null ? 'Pilih Tier terlebih dahulu' : 'Pilih Temuan',
              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
            items: currentTemuanOptions.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: tier == null ? null : (v) => setState(() => temuan = v),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (isVegetasi) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: line),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Jarak Jar. (m) *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                            const SizedBox(height: 4),
                            TextField(
                              controller: jarakCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: '0.0',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tinggi (m) *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                            const SizedBox(height: 4),
                            TextField(
                              controller: tinggiCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: '0.0',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Jenis Pohon *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: (pohon != null && treeOptions.contains(pohon)) ? pohon : null,
                        hint: const Text('Pilih Jenis Pohon', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                        items: treeOptions.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (v) => setState(() => pohon = v),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGpsCard() {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📍 Koordinat Temuan',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: blue),
              ),
              if (gps != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Akurasi ${gps!.accuracyLabel}',
                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            gps?.coordinate.isNotEmpty == true ? gps!.coordinate : '-',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: blue,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: mengambilGps ? null : _ambilGps,
              icon: mengambilGps
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, size: 18),
              label: Text(
                mengambilGps ? 'Mencari akurasi...' : 'Ambil Koordinat Temuan',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: blue,
                side: const BorderSide(color: blue, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFotoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📷 Foto Temuan',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: blue),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPhotoBox(
                  label: 'Foto Temuan *',
                  path: foto,
                  onTap: () async {
                    final p = await _ambilFoto('Foto Temuan');
                    if (mounted) setState(() => foto = p);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPhotoBox(
                  label: 'Foto Sekitar Tiang',
                  path: lingkungan,
                  onTap: () async {
                    final p = await _ambilFoto('Foto Lingkungan');
                    if (mounted) setState(() => lingkungan = p);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoBox({
    required String label,
    required String path,
    required VoidCallback onTap,
  }) {
    final exists = path.isNotEmpty && File(path).existsSync();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: exists ? blue : const Color(0xFFCBD5E1),
            width: exists ? 1.5 : 1.0,
          ),
        ),
        child: exists
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(path), fit: BoxFit.cover),
                    Container(
                      color: Colors.black38,
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        label,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt, color: blue, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildReadOnlyPill(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text.isNotEmpty ? text : '-',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
      ),
    );
  }
}
