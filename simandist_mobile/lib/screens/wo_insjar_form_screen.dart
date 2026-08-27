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
  final _penyulangCtrl = TextEditingController();
  final _sectionAwalCtrl = TextEditingController();
  final _sectionAkhirCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();

  List<String> _penyulangOptions = const [];
  LocationFix? _awal;
  LocationFix? _akhir;
  DateTime? _waktuMulai;
  DateTime? _waktuSelesai;
  double? _realisasiKms;
  String _statusWo = 'Belum Dikerjakan';
  String _kodeWo = '';
  bool _mengambilAwal = false;
  bool _mengambilAkhir = false;
  bool _menyimpan = false;
  int _sampel = 0;
  double _akurasiTerbaik = 0;

  @override
  void initState() {
    super.initState();
    _muatAwal();
  }

  @override
  void dispose() {
    _penyulangCtrl.dispose();
    _sectionAwalCtrl.dispose();
    _sectionAkhirCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  Future<void> _muatAwal() async {
    final options = await _repo.daftarPenyulang();
    final existing = widget.existing;
    if (!mounted) return;
    setState(() {
      _penyulangOptions = options;
      if (existing != null) {
        _kodeWo = existing.kodeWo;
        _penyulangCtrl.text = existing.penyulang;
        _sectionAwalCtrl.text = existing.sectionAwal;
        _sectionAkhirCtrl.text = existing.sectionAkhir;
        _sectionCtrl.text = existing.section;
        _realisasiKms = existing.realisasiKms;
        _statusWo = existing.statusWo.isEmpty
            ? 'Belum Dikerjakan'
            : existing.statusWo;
        _waktuMulai = WoInsjar.parseStamp(existing.waktuMulai);
        _waktuSelesai = WoInsjar.parseStamp(existing.waktuSelesai);
      }
    });
    if (existing == null) await _siapkanKodeWo();
  }

  Future<void> _siapkanKodeWo() async {
    final kodeUlp = (widget.sesi['kodeUlp'] ?? '').toString();
    final kode = await _repo.buatKodeWo(
      kodeUlp: kodeUlp,
      tanggal: DateTime.now(),
    );
    if (mounted) setState(() => _kodeWo = kode);
  }

  Future<void> _ambilKoordinat({required bool awal}) async {
    setState(() {
      if (awal) {
        _mengambilAwal = true;
      } else {
        _mengambilAkhir = true;
      }
      _sampel = 0;
      _akurasiTerbaik = 0;
    });

    try {
      final fix = await HighAccuracyLocationService.acquire(
        onSample: (sample, best) {
          if (!mounted) return;
          setState(() {
            _sampel = sample;
            _akurasiTerbaik = best;
          });
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
      _pesan(
        fix.locked
            ? 'Titik terkunci pada akurasi ${fix.accuracyLabel}.'
            : 'Akurasi terbaik ${fix.accuracyLabel} dari ${fix.samples} sampel.',
      );
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
    final awal = _awal;
    final akhir = _akhir;
    if (awal != null && akhir != null) {
      _realisasiKms = HighAccuracyLocationService.distanceKm(awal, akhir);
      _statusWo = 'Selesai';
    }
  }

  String get _durasi {
    final mulai = _waktuMulai;
    final selesai = _waktuSelesai;
    if (mulai == null || selesai == null) return '-';
    return WoInsjar.hitungDurasi(mulai, selesai);
  }

  Future<void> _simpan() async {
    if (_penyulangCtrl.text.trim().isEmpty) {
      _pesan('Penyulang wajib diisi.', error: true);
      return;
    }
    if (_kodeWo.isEmpty) {
      _pesan('Kode WO belum terbentuk.', error: true);
      return;
    }

    setState(() => _menyimpan = true);
    try {
      final now = DateTime.now();
      final wo = WoInsjar(
        kodeWo: _kodeWo,
        kodeUiw: (widget.sesi['kodeUiw'] ?? '').toString(),
        kodeUp3: (widget.sesi['kodeUp3'] ?? '').toString(),
        kodeUlp: (widget.sesi['kodeUlp'] ?? '').toString(),
        ulp: (widget.sesi['ulp'] ?? '').toString(),
        hari: WoInsjar.hariIndonesia[now.weekday - 1],
        tanggal:
            '${now.day.toString().padLeft(2, '0')}/'
            '${now.month.toString().padLeft(2, '0')}/${now.year}',
        penyulang: _penyulangCtrl.text.trim(),
        sectionAwal: _sectionAwalCtrl.text.trim(),
        sectionAkhir: _sectionAkhirCtrl.text.trim(),
        section: _sectionCtrl.text.trim(),
        koordinatAwal:
            _awal?.coordinate ?? widget.existing?.koordinatAwal ?? '',
        koordinatAkhir:
            _akhir?.coordinate ?? widget.existing?.koordinatAkhir ?? '',
        realisasiKms: _realisasiKms,
        waktuMulai: _waktuMulai == null
            ? ''
            : WoInsjar.stampLengkap(_waktuMulai!),
        waktuSelesai: _waktuSelesai == null
            ? ''
            : WoInsjar.stampLengkap(_waktuSelesai!),
        durasiPekerjaan: _durasi == '-' ? '' : _durasi,
        statusWo: _statusWo,
        isDirty: true,
      );
      await _repo.simpan(wo);
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    return Scaffold(
      backgroundColor: neutral100,
      appBar: AppBar(
        backgroundColor: navy700,
        foregroundColor: Colors.white,
        title: const Text(
          'WO Inspeksi Jaringan',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: navy700,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kode WO',
                  style: TextStyle(
                    color: Color(0xFFB8DCEF),
                    fontSize: 11,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _kodeWo.isEmpty ? 'Menyiapkan...' : _kodeWo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${widget.sesi['ulp'] ?? ''} • ${widget.sesi['kodeUlp'] ?? ''}',
                  style: const TextStyle(
                    color: Color(0xFFD5E8F3),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _label('Penyulang'),
          _penyulangField(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Section Awal'),
                    _input(_sectionAwalCtrl, 'Section awal'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Section Akhir'),
                    _input(_sectionAkhirCtrl, 'Section akhir'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _label('Section'),
          _input(_sectionCtrl, 'Section'),
          const SizedBox(height: 26),
          _koordinatCard(
            judul: 'Koordinat Awal',
            fix: _awal,
            existing: widget.existing?.koordinatAwal ?? '',
            memproses: _mengambilAwal,
            onTekan: () => _ambilKoordinat(awal: true),
          ),
          const SizedBox(height: 14),
          _koordinatCard(
            judul: 'Koordinat Akhir',
            fix: _akhir,
            existing: widget.existing?.koordinatAkhir ?? '',
            memproses: _mengambilAkhir,
            onTekan: () => _ambilKoordinat(awal: false),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: neutral200),
            ),
            child: Column(
              children: [
                _ringkas(
                  'Realisasi kmS',
                  _realisasiKms == null
                      ? '-'
                      : '${_realisasiKms!.toStringAsFixed(3)} km',
                ),
                const Divider(height: 20),
                _ringkas(
                  'Waktu Mulai',
                  _waktuMulai == null
                      ? '-'
                      : WoInsjar.stampLengkap(_waktuMulai!),
                ),
                const Divider(height: 20),
                _ringkas(
                  'Waktu Selesai',
                  _waktuSelesai == null
                      ? '-'
                      : WoInsjar.stampLengkap(_waktuSelesai!),
                ),
                const Divider(height: 20),
                _ringkas('Durasi Pekerjaan', _durasi),
                const Divider(height: 20),
                _ringkas('Status WO', _statusWo),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _menyimpan ? null : _simpan,
              style: ElevatedButton.styleFrom(
                backgroundColor: amber600,
                foregroundColor: navy950,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _menyimpan ? 'Menyimpan...' : 'Simpan WO ke Server Lokal',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: navy950,
      ),
    ),
  );

  Widget _input(TextEditingController controller, String hint) => TextField(
    controller: controller,
    decoration: InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: neutral200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: neutral200),
      ),
    ),
  );

  Widget _penyulangField() {
    if (_penyulangOptions.isEmpty) {
      return _input(_penyulangCtrl, 'Nama penyulang');
    }
    return Autocomplete<String>(
      optionsBuilder: (value) {
        final query = value.text.toLowerCase().trim();
        if (query.isEmpty) return _penyulangOptions;
        return _penyulangOptions.where(
          (item) => item.toLowerCase().contains(query),
        );
      },
      onSelected: (value) => _penyulangCtrl.text = value,
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        controller.text = _penyulangCtrl.text;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (value) => _penyulangCtrl.text = value,
          decoration: InputDecoration(
            hintText: 'Pilih atau tulis penyulang',
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: neutral200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: neutral200),
            ),
          ),
        );
      },
    );
  }

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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  judul,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: navy950,
                  ),
                ),
              ),
              if (fix != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: fix.locked ? green100 : const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        fix.locked
                            ? Icons.lock_rounded
                            : Icons.gps_not_fixed_rounded,
                        size: 13,
                        color: fix.locked ? green600 : const Color(0xFF8A6300),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Akurasi ${fix.accuracyLabel}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: fix.locked
                              ? green600
                              : const Color(0xFF8A6300),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            koordinat,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: navy700,
            ),
          ),
          if (memproses) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: cyan500,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Akurasi terbaik ${_akurasiTerbaik.toStringAsFixed(1)} m',
                    style: const TextStyle(fontSize: 11, color: neutral500),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: memproses ? null : onTekan,
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: Text(
                memproses
                    ? 'Mencari titik presisi...'
                    : 'Ambil Koordinat Perangkat',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: navy700,
                side: const BorderSide(color: navy700, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ringkas(String judul, String nilai) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(judul, style: const TextStyle(fontSize: 12, color: neutral500)),
      Text(
        nilai,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: navy950,
        ),
      ),
    ],
  );
}
