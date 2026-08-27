import 'package:flutter/material.dart';

import '../models/wo_insjar.dart';
import '../services/high_accuracy_location_service.dart';
import '../services/wo_insjar_repository.dart';

class WoInsjarFormScreen extends StatefulWidget {
  final Map<String, dynamic> sesi;
  final WoInsjar? existing;

  const WoInsjarFormScreen({super.key, required this.sesi, this.existing});

  @override
  State<WoInsjarFormScreen> createState() => _WoInsjarFormScreenState();
}

class _WoInsjarFormScreenState extends State<WoInsjarFormScreen> {
  static const navy950 = Color(0xFF071B30);
  static const navy700 = Color(0xFF004D8C);
  static const cyan500 = Color(0xFF00E5FF);
  static const amber600 = Color(0xFFFFB800);
  static const green600 = Color(0xFF16A34A);
  static const green100 = Color(0xFFDCFCE7);
  static const neutral500 = Color(0xFF64748B);
  static const neutral200 = Color(0xFFE2E8F0);
  static const neutral100 = Color(0xFFF1F5F9);
  static const red600 = Color(0xFFDC2626);

  final _repo = WoInsjarRepository();
  LocationFix? _awal;
  LocationFix? _akhir;
  DateTime? _waktuMulai;
  DateTime? _waktuSelesai;
  double? _realisasiKms;
  String _statusWo = WoInsjar.statusMulai;
  bool _mengambilAwal = false;
  bool _mengambilAkhir = false;
  bool _menyimpan = false;
  double _akurasiTerbaik = 0;

  WoInsjar? get _wo => widget.existing;

  @override
  void initState() {
    super.initState();
    final existing = _wo;
    if (existing != null) {
      _realisasiKms = existing.realisasiKms;
      _statusWo = WoInsjar.normalisasiStatus(existing.statusWo);
      _waktuMulai = WoInsjar.parseStamp(existing.waktuMulai);
      _waktuSelesai = WoInsjar.parseStamp(existing.waktuSelesai);
    }
  }

  Future<void> _ambilKoordinat({required bool awal}) async {
    setState(() {
      if (awal) {
        _mengambilAwal = true;
      } else {
        _mengambilAkhir = true;
      }
      _akurasiTerbaik = 0;
    });
    try {
      final fix = await HighAccuracyLocationService.acquire(
        onSample: (_, best) {
          if (mounted) setState(() => _akurasiTerbaik = best);
        },
      );
      if (!mounted) return;
      setState(() {
        if (awal) {
          _awal = fix;
          _waktuMulai = fix.capturedAt;
        } else {
          _akhir = fix;
          _waktuSelesai = fix.capturedAt;
        }
        _hitungTurunan();
      });
      _pesan('Akurasi ${fix.accuracyLabel}.');
    } catch (error) {
      if (mounted) {
        _pesan(error.toString().replaceFirst('Bad state: ', ''), error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _mengambilAwal = false;
          _mengambilAkhir = false;
        });
      }
    }
  }

  void _hitungTurunan() {
    if (_awal != null && _akhir != null) {
      _realisasiKms = HighAccuracyLocationService.distanceKm(_awal!, _akhir!);
      _statusWo = WoInsjar.statusSelesai;
    }
  }

  String get _durasi {
    if (_waktuMulai == null || _waktuSelesai == null) return '-';
    return WoInsjar.hitungDurasi(_waktuMulai!, _waktuSelesai!);
  }

  Future<void> _simpan() async {
    final existing = _wo;
    if (existing == null) {
      _pesan('WO harus diunduh dari server terlebih dahulu.', error: true);
      return;
    }
    setState(() => _menyimpan = true);
    try {
      final wo = WoInsjar(
        kodeWo: existing.kodeWo,
        kodeUiw: existing.kodeUiw,
        kodeUp3: existing.kodeUp3,
        kodeUlp: existing.kodeUlp,
        ulp: existing.ulp,
        hari: existing.hari,
        tanggal: existing.tanggal,
        penyulang: existing.penyulang,
        sectionAwal: existing.sectionAwal,
        sectionAkhir: existing.sectionAkhir,
        section: existing.section,
        koordinatAwal: _awal?.coordinate ?? existing.koordinatAwal,
        koordinatAkhir: _akhir?.coordinate ?? existing.koordinatAkhir,
        realisasiKms: _realisasiKms,
        waktuMulai: _waktuMulai == null ? existing.waktuMulai : WoInsjar.stampLengkap(_waktuMulai!),
        waktuSelesai: _waktuSelesai == null ? existing.waktuSelesai : WoInsjar.stampLengkap(_waktuSelesai!),
        durasiPekerjaan: _durasi == '-' ? existing.durasiPekerjaan : _durasi,
        statusWo: _statusWo,
        isDirty: true,
      );
      await _repo.simpan(wo);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _pesan(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  void _pesan(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? red600 : green600),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wo = _wo;
    if (wo == null) {
      return const Scaffold(body: Center(child: Text('WO tidak ditemukan.')));
    }
    return Scaffold(
      backgroundColor: neutral100,
      appBar: AppBar(
        backgroundColor: navy700,
        foregroundColor: Colors.white,
        title: const Text('WO Inspeksi Jaringan', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: navy700, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Kode WO', style: TextStyle(color: Color(0xFFB8DCEF), fontSize: 11, letterSpacing: 1.1)),
              const SizedBox(height: 4),
              Text(wo.kodeWo, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text('${wo.ulp} • ${wo.kodeUlp}', style: const TextStyle(color: Color(0xFFD5E8F3), fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 22),
          _label('Penyulang'),
          _readOnly(wo.penyulang),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Section Awal'), _readOnly(wo.sectionAwal)])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Section Akhir'), _readOnly(wo.sectionAkhir)])),
          ]),
          const SizedBox(height: 16),
          _label('Section'),
          _readOnly(wo.section),
          const SizedBox(height: 26),
          _koordinatCard(
            judul: 'Koordinat Awal',
            fix: _awal,
            existing: wo.koordinatAwal,
            memproses: _mengambilAwal,
            onTekan: () => _ambilKoordinat(awal: true),
          ),
          const SizedBox(height: 14),
          _koordinatCard(
            judul: 'Koordinat Akhir',
            fix: _akhir,
            existing: wo.koordinatAkhir,
            memproses: _mengambilAkhir,
            onTekan: () => _ambilKoordinat(awal: false),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: neutral200)),
            child: Column(children: [
              _ringkas('Realisasi kmS', _realisasiKms == null ? '-' : '${_realisasiKms!.toStringAsFixed(3)} km'),
              const Divider(height: 20),
              _ringkas('Waktu Mulai', _waktuMulai == null ? '-' : WoInsjar.stampLengkap(_waktuMulai!)),
              const Divider(height: 20),
              _ringkas('Waktu Selesai', _waktuSelesai == null ? '-' : WoInsjar.stampLengkap(_waktuSelesai!)),
              const Divider(height: 20),
              _ringkas('Durasi Pekerjaan', _durasi),
              const Divider(height: 20),
              _ringkas('Status WO', _statusWo),
            ]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _menyimpan ? null : _simpan,
              style: ElevatedButton.styleFrom(backgroundColor: amber600, foregroundColor: navy950, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text(_menyimpan ? 'Menyimpan...' : 'Simpan WO ke Server Lokal', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: navy950)),
      );

  Widget _readOnly(String value) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: neutral200)),
        child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontSize: 14, color: navy950)),
      );

  Widget _koordinatCard({
    required String judul,
    required LocationFix? fix,
    required String existing,
    required bool memproses,
    required VoidCallback onTekan,
  }) {
    final koordinat = fix?.coordinate ?? (existing.isEmpty ? '-' : existing);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: neutral200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(judul, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: navy950))),
          if (fix != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: fix.locked ? green100 : const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(20)),
              child: Text('Akurasi ${fix.accuracyLabel}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fix.locked ? green600 : const Color(0xFF8A6300))),
            ),
        ]),
        const SizedBox(height: 10),
        Text(koordinat, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: navy700)),
        if (memproses) ...[
          const SizedBox(height: 12),
          Row(children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.4, color: cyan500)),
            const SizedBox(width: 10),
            Text(
              _akurasiTerbaik > 0 ? 'Akurasi ${_akurasiTerbaik.toStringAsFixed(1)} m' : 'Mencari akurasi...',
              style: const TextStyle(fontSize: 11, color: neutral500),
            ),
          ]),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: memproses ? null : onTekan,
            icon: const Icon(Icons.my_location_rounded, size: 18),
            label: Text(memproses ? 'Mencari titik presisi...' : 'Ambil Koordinat Perangkat', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            style: OutlinedButton.styleFrom(foregroundColor: navy700, side: const BorderSide(color: navy700, width: 1.4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ]),
    );
  }

  Widget _ringkas(String judul, String nilai) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(judul, style: const TextStyle(fontSize: 12, color: neutral500)),
          Flexible(child: Text(nilai, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: navy950))),
        ],
      );
}
