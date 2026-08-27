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
        builder: (_) => TemuanForm(wo: widget.wo, sesi: widget.sesi),
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

class TemuanForm extends StatefulWidget {
  final WoInsjar wo;
  final Map<String, dynamic> sesi;

  const TemuanForm({super.key, required this.wo, required this.sesi});

  @override
  State<TemuanForm> createState() => _TemuanFormState();
}

class _TemuanFormState extends State<TemuanForm> {
  static const blue = Color(0xFF004D8C);
  static const navy = Color(0xFF071B30);
  static const amber = Color(0xFFFFB800);
  static const line = Color(0xFFE2E8F0);

  final repo = TemuanRepository();
  final segmen = TextEditingController();
  final jarak = TextEditingController();
  final tinggi = TextEditingController();
  final picker = ImagePicker();

  List<Map<String, dynamic>> listMaster = [];
  List<Map<String, dynamic>> pohonMaster = [];
  String kode = '';
  String object = '';
  String tier = '';
  String temuan = '';
  String pohon = '';
  LocationFix? gps;
  String foto = '';
  String lingkungan = '';
  bool saving = false;

  bool get vegetasi => {
        'Rabas / Pangkas',
        'Tebang Sedang',
        'Tebang Besar',
      }.contains(temuan);

  List<String> get temuanOptions {
    return listMaster
        .where((row) {
          final rowObject = '${row['Jenis Object'] ?? row['Object'] ?? ''}';
          final rowTier = '${row['Tier'] ?? ''}';
          return (rowObject.isEmpty || rowObject == object) &&
              (rowTier.isEmpty || rowTier == tier);
        })
        .map((row) => '${row['Temuan'] ?? ''}'.trim())
        .where((value) => value.isNotEmpty)
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
    segmen.dispose();
    jarak.dispose();
    tinggi.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    kode = await repo.kodeBaru(widget.wo.kodeWo);
    object = repo.jenisObject(widget.sesi);
    listMaster = await repo.master('List_Temuan');
    pohonMaster = await repo.master('Jenis Pohon');
    if (mounted) setState(() {});
  }

  Future<void> _ambilGps() async {
    final fix = await HighAccuracyLocationService.acquire(
      onSample: (_, __) {},
    );
    if (mounted) setState(() => gps = fix);
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

  Future<void> _save() async {
    final missingBase = segmen.text.trim().isEmpty ||
        gps == null ||
        object.isEmpty ||
        tier.isEmpty ||
        temuan.isEmpty ||
        foto.isEmpty ||
        lingkungan.isEmpty;
    if (missingBase) {
      _message('Lengkapi semua data wajib, GPS, dan dua foto.');
      return;
    }
    if (object == 'Jaringan' && jarak.text.trim().isEmpty) {
      _message('Jarak terhadap jaringan wajib diisi.');
      return;
    }
    if (vegetasi && (pohon.isEmpty || tinggi.text.trim().isEmpty)) {
      _message('Jenis dan tinggi pohon wajib diisi.');
      return;
    }

    setState(() => saving = true);
    try {
      final now = DateTime.now();
      final distance = double.tryParse(jarak.text.replaceAll(',', '.'));
      final treeHeight = double.tryParse(tinggi.text.replaceAll(',', '.'));
      final coordinate = gps!.coordinate.split(',');
      final priority = repo.prioritas(
        temuan,
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
        segmen: segmen.text.trim(),
        koordinat: gps!.coordinate,
        lat: coordinate.first.trim(),
        long: coordinate.length > 1 ? coordinate[1].trim() : '',
        jenisObject: object,
        tier: tier,
        temuan: temuan,
        jarak: object == 'Jaringan' ? distance : null,
        jenisPohon: vegetasi ? pohon : '',
        tinggiPohon: vegetasi ? treeHeight : null,
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
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        title: const Text(
          'Tambah Temuan',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _info('Kode WO', widget.wo.kodeWo),
          _info('Kode Temuan', kode.isEmpty ? 'Menyiapkan...' : kode),
          _info('Penyulang', widget.wo.penyulang),
          _info('Section', widget.wo.section),
          _field(segmen, 'Segmen *'),
          const SizedBox(height: 12),
          if (object.isEmpty)
            _drop(
              'Jenis Object *',
              const ['Jaringan', 'Gardu'],
              object,
              (value) => setState(() => object = value!),
            )
          else
            _info('Jenis Object', object),
          _drop(
            'Tier *',
            const ['Tier 1', 'Tier 2'],
            tier,
            (value) => setState(() {
              tier = value!;
              temuan = '';
            }),
          ),
          _drop(
            'Temuan *',
            temuanOptions,
            temuan,
            (value) => setState(() => temuan = value!),
          ),
          if (object == 'Jaringan')
            _field(
              jarak,
              'Jarak Terhadap Jaringan (m) *',
              number: true,
            ),
          if (vegetasi) ...[
            _drop(
              'Jenis Pohon *',
              treeOptions,
              pohon,
              (value) => setState(() => pohon = value!),
            ),
            _field(tinggi, 'Tinggi Pohon (m) *', number: true),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _ambilGps,
            icon: const Icon(Icons.my_location),
            label: Text(
              gps == null
                  ? 'Ambil Koordinat Temuan'
                  : 'Akurasi ${gps!.accuracyLabel}',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final value = await _ambilFoto('Foto Temuan');
              if (mounted) setState(() => foto = value);
            },
            icon: const Icon(Icons.camera_alt),
            label: Text(
              foto.isEmpty ? 'Ambil Foto Temuan' : 'Foto Temuan siap',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final value = await _ambilFoto('Foto Lingkungan');
              if (mounted) setState(() => lingkungan = value);
            },
            icon: const Icon(Icons.camera_alt),
            label: Text(
              lingkungan.isEmpty
                  ? 'Ambil Foto Lingkungan'
                  : 'Foto Lingkungan siap',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: amber,
              foregroundColor: navy,
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(
              saving ? 'Menyimpan...' : 'Simpan Temuan',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: line),
          ),
        ),
        child: Text(
          value.isEmpty ? '-' : value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _drop(
    String label,
    List<String> options,
    String value,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: options.contains(value) ? value : null,
        items: options
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: onChanged,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
