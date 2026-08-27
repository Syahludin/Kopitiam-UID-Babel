import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/wo_insjar.dart';
import '../services/high_accuracy_location_service.dart';
import '../services/wo_insjar_repository.dart';
import 'temuan_tab.dart';

class WoInsjarFormScreen extends StatefulWidget {
  final WoInsjar? existing;
  final Map<String, dynamic> sesi;

  const WoInsjarFormScreen({
    super.key,
    this.existing,
    required this.sesi,
  });

  @override
  State<WoInsjarFormScreen> createState() => _WoInsjarFormScreenState();
}

class _WoInsjarFormScreenState extends State<WoInsjarFormScreen>
    with SingleTickerProviderStateMixin {
  final WoInsjarRepository _repo = WoInsjarRepository();
  late final TabController _tabController;

  late TextEditingController _penyulangCtrl;
  late TextEditingController _sectionAwalCtrl;
  late TextEditingController _sectionAkhirCtrl;
  late TextEditingController _sectionCtrl;

  String _kodeWo = '';
  LocationFix? _awal;
  LocationFix? _akhir;
  DateTime? _waktuMulai;
  DateTime? _waktuSelesai;
  double _realisasiKms = 0.0;
  String _statusWo = WoInsjar.statusMulai;
  bool _mengambilAwal = false;
  bool _mengambilAkhir = false;
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final ex = widget.existing;
    _kodeWo = ex?.kodeWo ?? '';
    _penyulangCtrl = TextEditingController(text: ex?.penyulang ?? '');
    _sectionAwalCtrl = TextEditingController(text: ex?.sectionAwal ?? '');
    _sectionAkhirCtrl = TextEditingController(text: ex?.sectionAkhir ?? '');
    _sectionCtrl = TextEditingController(text: ex?.section ?? '');
    _realisasiKms = ex?.realisasiKms ?? 0.0;
    _statusWo = ex != null && ex.statusWo.isNotEmpty
        ? WoInsjar.normalisasiStatus(ex.statusWo)
        : WoInsjar.statusMulai;

    if (ex?.koordinatAwal.isNotEmpty == true) {
      final parts = ex!.koordinatAwal.split(',');
      final lat = parts.isNotEmpty ? double.tryParse(parts[0].trim()) ?? 0.0 : 0.0;
      final lng = parts.length > 1 ? double.tryParse(parts[1].trim()) ?? 0.0 : 0.0;
      _awal = LocationFix(
        latitude: lat,
        longitude: lng,
        accuracy: 5.0,
        capturedAt: DateTime.now(),
        samples: 30,
        locked: true,
      );
    }
    if (ex?.koordinatAkhir.isNotEmpty == true) {
      final parts = ex!.koordinatAkhir.split(',');
      final lat = parts.isNotEmpty ? double.tryParse(parts[0].trim()) ?? 0.0 : 0.0;
      final lng = parts.length > 1 ? double.tryParse(parts[1].trim()) ?? 0.0 : 0.0;
      _akhir = LocationFix(
        latitude: lat,
        longitude: lng,
        accuracy: 5.0,
        capturedAt: DateTime.now(),
        samples: 30,
        locked: true,
      );
    }
    if (ex?.waktuMulai.isNotEmpty == true) {
      _waktuMulai = WoInsjar.parseStamp(ex!.waktuMulai);
    }
    if (ex?.waktuSelesai.isNotEmpty == true) {
      _waktuSelesai = WoInsjar.parseStamp(ex!.waktuSelesai);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _penyulangCtrl.dispose();
    _sectionAwalCtrl.dispose();
    _sectionAkhirCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  Duration? get _durasi {
    if (_waktuMulai == null || _waktuSelesai == null) return null;
    return _waktuSelesai!.difference(_waktuMulai!);
  }

  String _formatDurasi(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void _hitungOtomatis() {
    if (_awal != null && _akhir == null) {
      _statusWo = WoInsjar.statusDalam;
    } else if (_awal != null && _akhir != null) {
      _statusWo = WoInsjar.statusSelesai;
      final distMeters = Geolocator.distanceBetween(
        _awal!.latitude,
        _awal!.longitude,
        _akhir!.latitude,
        _akhir!.longitude,
      );
      _realisasiKms = distMeters / 1000.0;
      _waktuSelesai ??= DateTime.now();
    }
  }

  Future<void> _ambilKoordinat({required bool awal}) async {
    setState(() {
      if (awal) {
        _mengambilAwal = true;
      } else {
        _mengambilAkhir = true;
      }
    });

    try {
      final res = await HighAccuracyLocationService.acquire(
        onSample: (_, __) {
          if (mounted) setState(() {});
        },
      );
      if (!mounted) return;

      setState(() {
        if (awal) {
          _awal = res;
          _waktuMulai ??= DateTime.now();
          _mengambilAwal = false;
        } else {
          _akhir = res;
          _waktuSelesai = DateTime.now();
          _mengambilAkhir = false;
        }
        _hitungOtomatis();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (awal) {
          _mengambilAwal = false;
        } else {
          _mengambilAkhir = false;
        }
      });
      _pesan('Gagal mengambil koordinat: $e', error: true);
    }
  }

  void _pesan(String teks, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(teks),
        backgroundColor:
            error ? const Color(0xFFD32F2F) : const Color(0xFF107C41),
      ),
    );
  }

  Future<void> _simpan() async {
    final existing = widget.existing;
    if (existing == null) {
      _pesan('WO harus diunduh dari server terlebih dahulu.', error: true);
      return;
    }

    setState(() => _menyimpan = true);
    try {
      final wo = existing.copyWith(
        koordinatAwal: _awal?.coordinate ?? existing.koordinatAwal,
        koordinatAkhir: _akhir?.coordinate ?? existing.koordinatAkhir,
        realisasiKms: _realisasiKms,
        waktuMulai: _waktuMulai == null
            ? existing.waktuMulai
            : WoInsjar.stampLengkap(_waktuMulai!),
        waktuSelesai: _waktuSelesai == null
            ? existing.waktuSelesai
            : WoInsjar.stampLengkap(_waktuSelesai!),
        durasiPekerjaan: _durasi != null
            ? _formatDurasi(_durasi!)
            : existing.durasiPekerjaan,
        statusWo: _statusWo,
        isDirty: true,
      );

      await _repo.simpan(wo);
      if (!mounted) return;
      _pesan('Perubahan WO berhasil disimpan di server lokal.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _pesan('Gagal menyimpan: $e', error: true);
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'WO Inspeksi Jaringan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF0A3E74),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0A3E74),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF00A3E0),
              indicatorWeight: 3,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: const [
                Tab(text: 'Work Order'),
                Tab(text: 'Temuan'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWoTab(),
          TemuanTab(
            wo: widget.existing ??
                WoInsjar(
                  kodeWo: _kodeWo,
                  ulp: widget.sesi['ulp']?.toString() ?? '',
                  kodeUlp: widget.sesi['kodeUlp']?.toString() ?? '',
                ),
            sesi: widget.sesi,
          ),
        ],
      ),
    );
  }

  Widget _buildWoTab() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 14),
              _buildSectionFieldCard(),
              const SizedBox(height: 14),
              _buildGpsCard(
                judul: 'Koordinat Awal',
                hasil: _awal,
                loading: _mengambilAwal,
                onAmbil: () => _ambilKoordinat(awal: true),
              ),
              const SizedBox(height: 14),
              _buildGpsCard(
                judul: 'Koordinat Akhir',
                hasil: _akhir,
                loading: _mengambilAkhir,
                onAmbil: () => _ambilKoordinat(awal: false),
              ),
              const SizedBox(height: 14),
              _buildSummaryCard(),
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
              onPressed: _menyimpan ? null : _simpan,
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
                      'Simpan WO ke Server Lokal',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    final ulp = widget.existing?.ulp.isNotEmpty == true
        ? widget.existing!.ulp
        : 'Toboali';
    final kodeUlp = widget.existing?.kodeUlp.isNotEmpty == true
        ? widget.existing!.kodeUlp
        : '16130';

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
          const Text(
            'Kode WO',
            style: TextStyle(
                color: Color(0xFFB0CBE8),
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
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
            '$ulp • $kodeUlp',
            style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionFieldCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Penyulang',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569)),
          ),
          const SizedBox(height: 6),
          _buildReadOnlyBox(_penyulangCtrl.text),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Section Awal',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    _buildReadOnlyBox(_sectionAwalCtrl.text),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Section Akhir',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    _buildReadOnlyBox(_sectionAkhirCtrl.text),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Section',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569)),
          ),
          const SizedBox(height: 6),
          _buildReadOnlyBox(_sectionCtrl.text),
        ],
      ),
    );
  }

  Widget _buildReadOnlyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text.isNotEmpty ? text : '-',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _buildGpsCard({
    required String judul,
    required LocationFix? hasil,
    required bool loading,
    required VoidCallback onAmbil,
  }) {
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
              Text(
                judul,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (hasil != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Akurasi ${hasil.accuracyLabel}',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasil?.coordinate.isNotEmpty == true ? hasil!.coordinate : '-',
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
              onPressed: loading ? null : onAmbil,
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: Text(
                loading ? 'Mencari akurasi...' : 'Ambil Koordinat Perangkat',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0A3E74),
                side: const BorderSide(color: Color(0xFF0A3E74), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildInfoRow(
              'Realisasi kmS', '${_realisasiKms.toStringAsFixed(3)} km'),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildInfoRow(
            'Waktu Mulai',
            _waktuMulai != null ? WoInsjar.stampLengkap(_waktuMulai!) : '-',
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildInfoRow(
            'Waktu Selesai',
            _waktuSelesai != null ? WoInsjar.stampLengkap(_waktuSelesai!) : '-',
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildInfoRow(
            'Durasi Pekerjaan',
            _durasi != null ? _formatDurasi(_durasi!) : '-',
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildInfoRow('Status WO', _statusWo, isStatus: true),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isStatus
                  ? (_statusWo == WoInsjar.statusSelesai
                      ? const Color(0xFF107C41)
                      : const Color(0xFFFFAE00))
                  : const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}
