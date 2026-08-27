import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/temuan_inspeksi.dart';
import '../models/wo_insjar.dart';
import '../services/sqlite_service.dart';
import '../services/temuan_repository.dart';
import '../services/wo_insjar_repository.dart';

class TemuanFormScreen extends StatefulWidget {
  final WoInsjar? wo;
  final TemuanInspeksi? existing;
  final Map<String, dynamic> sesi;

  const TemuanFormScreen({
    super.key,
    this.wo,
    this.existing,
    required this.sesi,
  });

  @override
  State<TemuanFormScreen> createState() => _TemuanFormScreenState();
}

class _TemuanFormScreenState extends State<TemuanFormScreen> {
  final TemuanRepository _repo = TemuanRepository();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _segmenCtrl;
  late TextEditingController _jarakCtrl;
  late TextEditingController _tinggiCtrl;

  String _kodeWo = '';
  String _kodeTemuan = '';
  String _jenisObject = 'Jaringan';
  String _tier = 'Tier 1';
  String? _selectedTemuan;
  String? _selectedJenisPohon;
  String _prioritas = 'Minor';

  GpsLockResult? _gpsResult;
  File? _fotoTemuan;
  File? _fotoLingkungan;

  List<String> _temuanOptions = [];
  List<String> _pohonOptions = [];
  bool _loadingInit = true;
  bool _mengambilGps = false;
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    _segmenCtrl = TextEditingController(text: widget.existing?.segmen ?? '');
    _jarakCtrl = TextEditingController(text: widget.existing?.jarakTerhadapJaringan ?? '');
    _tinggiCtrl = TextEditingController(text: widget.existing?.tinggiPohon ?? '');
    _initData();
  }

  @override
  void dispose() {
    _segmenCtrl.dispose();
    _jarakCtrl.dispose();
    _tinggiCtrl.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final subTim = (widget.sesi['subTim'] ?? widget.sesi['sub_tim'] ?? '').toString().toLowerCase();
    if (subTim.contains('gardu')) {
      _jenisObject = 'Gardu';
    } else {
      _jenisObject = 'Jaringan';
    }

    _kodeWo = widget.wo?.kodeWo ?? widget.existing?.kodeWo ?? '';
    if (widget.existing != null) {
      _kodeTemuan = widget.existing!.kodeTemuan;
      _jenisObject = widget.existing!.jenisObject;
      _tier = widget.existing!.tier;
      _selectedTemuan = widget.existing!.temuan;
      _selectedJenisPohon = widget.existing!.jenisPohon.isNotEmpty ? widget.existing!.jenisPohon : null;
      _prioritas = widget.existing!.prioritas;
      if (widget.existing!.koordinatTemuan.isNotEmpty) {
        _gpsResult = GpsLockResult(
          coordinate: widget.existing!.koordinatTemuan,
          accuracy: 5.0,
          samplesCollected: 30,
        );
      }
      if (widget.existing!.fotoTemuan.isNotEmpty) {
        final f = File(widget.existing!.fotoTemuan);
        if (f.existsSync()) _fotoTemuan = f;
      }
      if (widget.existing!.fotoLingkunganSekitaranTiang.isNotEmpty) {
        final f = File(widget.existing!.fotoLingkunganSekitaranTiang);
        if (f.existsSync()) _fotoLingkungan = f;
      }
    } else {
      _kodeTemuan = await _repo.generateKodeTemuan(_kodeWo);
    }

    await _loadMasterOptions();
    _hitungPrioritas();

    if (mounted) {
      setState(() => _loadingInit = false);
    }
  }

  Future<void> _loadMasterOptions() async {
    final db = await SqliteService().database;
    final temuanRows = await db.query(
      'master_list_temuan',
      where: 'LOWER(jenis_object) = ? AND LOWER(tier) = ?',
      whereArgs: [_jenisObject.toLowerCase(), _tier.toLowerCase()],
    );

    _temuanOptions = temuanRows
        .map((e) => (e['temuan'] ?? '').toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final pohonRows = await db.query('master_jenis_pohon');
    _pohonOptions = pohonRows
        .map((e) => (e['jenis_pohon'] ?? '').toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (_selectedTemuan != null && !_temuanOptions.contains(_selectedTemuan)) {
      if (_temuanOptions.isNotEmpty) {
        _selectedTemuan = _temuanOptions.first;
      } else {
        _selectedTemuan = null;
      }
    }
  }

  bool get _isVegetasi {
    final t = (_selectedTemuan ?? '').toLowerCase();
    return t.contains('rabas') || t.contains('pangkas') || t.contains('tebang');
  }

  void _hitungPrioritas() {
    if (_isVegetasi) {
      final jarak = double.tryParse(_jarakCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final tinggi = double.tryParse(_tinggiCtrl.text.replaceAll(',', '.')) ?? 0.0;

      if (tinggi < 9.0) {
        if (jarak > 5.0) {
          _prioritas = 'Minor';
        } else {
          _prioritas = 'Mayor';
        }
      } else {
        if (jarak < 3.0) {
          _prioritas = 'Mayor';
        } else if (jarak >= 3.0 && jarak < 6.0) {
          _prioritas = 'Sedang';
        } else {
          _prioritas = 'Minor';
        }
      }
    } else {
      _prioritas = 'Minor';
    }
    setState(() {});
  }

  Future<void> _ambilFoto({required bool temuanUtama}) async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (xFile == null) return;
      setState(() {
        if (temuanUtama) {
          _fotoTemuan = File(xFile.path);
        } else {
          _fotoLingkungan = File(xFile.path);
        }
      });
    } catch (e) {
      _pesan('Gagal membuka kamera: $e', error: true);
    }
  }

  Future<void> _ambilGps() async {
    setState(() => _mengambilGps = true);
    try {
      final res = await WoInsjarRepository().kunciGpsMultisample(
        onProgress: (_) {
          if (mounted) setState(() {});
        },
      );
      if (!mounted) return;
      setState(() {
        _gpsResult = res;
        _mengambilGps = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _mengambilGps = false);
        _pesan('Gagal mengunci GPS: $e', error: true);
      }
    }
  }

  void _pesan(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? const Color(0xFFD32F2F) : const Color(0xFF107C41),
      ),
    );
  }

  Future<void> _simpanTemuan() async {
    if (_segmenCtrl.text.trim().isEmpty) {
      _pesan('Segmen wajib diisi.', error: true);
      return;
    }
    if (_selectedTemuan == null || _selectedTemuan!.isEmpty) {
      _pesan('Temuan wajib dipilih.', error: true);
      return;
    }
    if (_jenisObject == 'Jaringan' && _jarakCtrl.text.trim().isEmpty) {
      _pesan('Jarak terhadap jaringan wajib diisi.', error: true);
      return;
    }
    if (_isVegetasi) {
      if (_tinggiCtrl.text.trim().isEmpty) {
        _pesan('Tinggi pohon wajib diisi untuk temuan vegetasi.', error: true);
        return;
      }
      if (_selectedJenisPohon == null || _selectedJenisPohon!.isEmpty) {
        _pesan('Jenis pohon wajib dipilih.', error: true);
        return;
      }
    }
    if (_gpsResult == null || _gpsResult!.coordinate.isEmpty) {
      _pesan('Koordinat GPS wajib diambil.', error: true);
      return;
    }
    if (_fotoTemuan == null) {
      _pesan('Foto Temuan wajib diambil dari kamera.', error: true);
      return;
    }

    setState(() => _menyimpan = true);
    try {
      final latLong = _gpsResult!.coordinate.split(',');
      final lat = latLong.isNotEmpty ? latLong[0].trim() : '';
      final long = latLong.length > 1 ? latLong[1].trim() : '';
      final now = DateTime.now();

      final folderPath = TemuanRepository.buatFolderPath(
        kodeUlp: widget.wo?.kodeUlp ?? widget.existing?.kodeUlp ?? '16130',
        jenisObject: _jenisObject,
        tanggal: now,
        kodeWo: _kodeWo,
        kodeTemuan: _kodeTemuan,
      );

      final temuan = TemuanInspeksi(
        id: widget.existing?.id,
        kodeUiw: widget.wo?.kodeUiw ?? widget.existing?.kodeUiw ?? '16',
        kodeUp3: widget.wo?.kodeUp3 ?? widget.existing?.kodeUp3 ?? '161',
        kodeUlp: widget.wo?.kodeUlp ?? widget.existing?.kodeUlp ?? '16130',
        ulp: widget.wo?.ulp ?? widget.existing?.ulp ?? 'Toboali',
        kodeWo: _kodeWo,
        kodeTemuan: _kodeTemuan,
        hari: WoInsjar.hariIndonesia[now.weekday - 1],
        tanggal: WoInsjar.tanggalFormat(now),
        penyulang: widget.wo?.penyulang ?? widget.existing?.penyulang ?? '',
        sectionAwal: widget.wo?.sectionAwal ?? widget.existing?.sectionAwal ?? '',
        sectionAkhir: widget.wo?.sectionAkhir ?? widget.existing?.sectionAkhir ?? '',
        section: widget.wo?.section ?? widget.existing?.section ?? '',
        segmen: _segmenCtrl.text.trim(),
        koordinatTemuan: _gpsResult!.coordinate,
        latTemuan: lat,
        longTemuan: long,
        jenisObject: _jenisObject,
        tier: _tier,
        temuan: _selectedTemuan!,
        jarakTerhadapJaringan: _jarakCtrl.text.trim(),
        jenisPohon: _isVegetasi ? (_selectedJenisPohon ?? '') : '',
        tinggiPohon: _isVegetasi ? _tinggiCtrl.text.trim() : '',
        prioritas: _prioritas,
        pekerjaan: '',
        fotoTemuan: _fotoTemuan?.path ?? '',
        linkFoto: widget.existing?.linkFoto ?? '',
        fotoLingkunganSekitaranTiang: _fotoLingkungan?.path ?? '',
        linkFotoSekitaranTiang: widget.existing?.linkFotoSekitaranTiang ?? '',
        jenisWo: '',
        waktuInput: WoInsjar.stampLengkap(now),
        userInput: (widget.sesi['username'] ?? '').toString(),
        folderPath: folderPath,
        isSynced: 0,
      );

      await _repo.simpanTemuanLokal(temuan);
      if (!mounted) return;
      _pesan('Temuan berhasil disimpan di server lokal.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _pesan('Gagal menyimpan temuan: $e', error: true);
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingInit) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F7FB),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text(
          widget.existing != null ? 'Edit Temuan' : 'Tambah Temuan Baru',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF0A3E74),
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
                _buildKlasifikasiCard(),
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
                onPressed: _menyimpan ? null : _simpanTemuan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFAE00),
                  foregroundColor: const Color(0xFF1E293B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _menyimpan
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
    final ulp = widget.wo?.ulp ?? widget.existing?.ulp ?? 'Toboali';
    final pny = widget.wo?.penyulang ?? widget.existing?.penyulang ?? '-';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A3E74),
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
            _kodeWo.isNotEmpty ? _kodeWo : '-',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '⚡ $pny • $ulp',
            style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentitasCard() {
    final section = widget.wo?.section ?? widget.existing?.section ?? '-';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📌 Identitas Temuan',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0A3E74)),
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
                    _buildReadOnlyPill(_kodeTemuan),
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
                    _buildReadOnlyPill(_jenisObject),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Section (Terkunci)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          _buildReadOnlyPill(section),
          const SizedBox(height: 12),
          const Text('Segmen *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
          const SizedBox(height: 6),
          TextField(
            controller: _segmenCtrl,
            decoration: InputDecoration(
              hintText: 'Ketik segmen / titik tiang...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0A3E74), width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKlasifikasiCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔍 Klasifikasi Temuan',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0A3E74)),
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
                      value: _tier,
                      items: const [
                        DropdownMenuItem(value: 'Tier 1', child: Text('Tier 1')),
                        DropdownMenuItem(value: 'Tier 2', child: Text('Tier 2')),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() => _tier = v);
                        await _loadMasterOptions();
                        _hitungPrioritas();
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
                        color: _prioritas == 'Mayor'
                            ? const Color(0xFFFEE2E2)
                            : (_prioritas == 'Sedang' ? const Color(0xFFFEF3C7) : const Color(0xFFE0E7FF)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _prioritas,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _prioritas == 'Mayor'
                              ? const Color(0xFFDC2626)
                              : (_prioritas == 'Sedang' ? const Color(0xFFD97706) : const Color(0xFF4338CA)),
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
            value: _selectedTemuan,
            items: _temuanOptions.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) {
              setState(() => _selectedTemuan = v);
              _hitungPrioritas();
            },
            decoration: InputDecoration(
              hintText: 'Pilih Temuan',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (_jenisObject == 'Jaringan') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                              controller: _jarakCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => _hitungPrioritas(),
                              decoration: InputDecoration(
                                hintText: '0.0',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isVegetasi) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tinggi (m) *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _tinggiCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => _hitungPrioritas(),
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
                    ],
                  ),
                  if (_isVegetasi) ...[
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Jenis Pohon *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedJenisPohon,
                          items: _pohonOptions.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) => setState(() => _selectedJenisPohon = v),
                          decoration: InputDecoration(
                            hintText: 'Pilih Jenis Pohon',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
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
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📍 Koordinat Temuan',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0A3E74)),
              ),
              if (_gpsResult != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Akurasi ${_gpsResult!.accuracy.toStringAsFixed(1)} m',
                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _gpsResult?.coordinate.isNotEmpty == true ? _gpsResult!.coordinate : '-',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0A3E74),
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _mengambilGps ? null : _ambilGps,
              icon: _mengambilGps
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, size: 18),
              label: Text(
                _mengambilGps ? 'Mencari akurasi...' : 'Ambil Koordinat Temuan',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0A3E74),
                side: const BorderSide(color: Color(0xFF0A3E74), width: 1.2),
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
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📷 Foto Temuan',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0A3E74)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPhotoBox(
                  label: 'Foto Temuan *',
                  file: _fotoTemuan,
                  onTap: () => _ambilFoto(temuanUtama: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPhotoBox(
                  label: 'Foto Sekitar Tiang',
                  file: _fotoLingkungan,
                  onTap: () => _ambilFoto(temuanUtama: false),
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
    required File? file,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null ? const Color(0xFF0A3E74) : const Color(0xFFCBD5E1),
            width: file != null ? 1.5 : 1.0,
            style: BorderStyle.solid,
          ),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(file, fit: BoxFit.cover),
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
                  const Icon(Icons.camera_alt, color: Color(0xFF0A3E74), size: 28),
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
