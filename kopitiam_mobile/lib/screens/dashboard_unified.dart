import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/wo_har_jar.dart';
import '../models/wo_insdu.dart';
import '../models/wo_insjar.dart';
import '../models/wo_row.dart';
import '../services/api_service.dart';
import '../services/sqlite_service.dart';
import '../services/wo_har_jar_repository.dart';
import '../services/wo_insdu_repository.dart';
import '../services/wo_insjar_repository.dart';
import '../services/wo_row_repository.dart';
import '../widgets/wo_har_jar_card.dart';
import 'form_tindak_lanjut_har_jar_screen.dart';
import 'settings_session_section.dart';
import 'widgets/bubble_navbar.dart';
import 'widgets/operation_result_dialog.dart';
import 'widgets/welcome_card.dart';
import 'widgets/wo_data_card.dart';
import 'widgets/wo_insdu_card.dart';
import 'widgets/wo_insjar_card.dart';
import 'widgets/wo_row_card.dart';
import 'widgets/wo_summary_card.dart';
import 'wo_insdu_form_screen.dart';
import 'wo_insjar_form_screen.dart';
import 'wo_row_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> sesi;
  const DashboardScreen({super.key, required this.sesi});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  static const blue = Color(0xFF004D8C);
  static const navy = Color(0xFF071B30);
  static const amber = Color(0xFFFFB800);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);
  static const background = Color(0xFFEDF4FA);

  final _insjarRepo = WoInsjarRepository();
  final _insduRepo = WoInsduRepository();
  final _rowRepo = WoRowRepository();
  final _harJarRepo = WoHarJarRepository();
  late final AnimationController _masterSpin;

  int _selected = 1;
  bool _syncingMaster = false;
  bool _hasMaster = false;
  DateTime? _lastSync;
  List<WoInsjar> _insjar = const [];
  List<WoInsdu> _insdu = const [];
  List<WoRow> _rows = const [];
  List<WoHarJar> _harJar = const [];

  String get _token => '${widget.sesi['token'] ?? ''}';
  String get _identity =>
      '${widget.sesi['subTim'] ?? widget.sesi['tim'] ?? ''} ${widget.sesi['username'] ?? ''}'
          .toLowerCase();
  bool get _isInsdu =>
      _identity.contains('inspeksi gardu') || _identity.contains('insdu');
  bool get _isRow => !_isInsdu && _identity.contains('row');
  bool get _isHarJar => !_isInsdu && !_isRow &&
      (_identity.contains('har jar') || _identity.contains('harjar'));
  String get _label => _isInsdu
      ? 'WO Inspeksi Gardu'
      : _isRow
          ? 'ROW'
          : _isHarJar
              ? 'WO Har Jar'
              : 'WO Inspeksi Jaringan';

  @override
  void initState() {
    super.initState();
    _masterSpin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _load();
    _loadMasterState();
  }

  @override
  void dispose() {
    _masterSpin.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isInsdu) {
      final data = await _insduRepo.semua();
      if (mounted) setState(() => _insdu = data);
    } else if (_isRow) {
      final data = await _rowRepo.semua();
      if (mounted) setState(() => _rows = data);
    } else if (_isHarJar) {
      final data = await _harJarRepo.semua();
      if (mounted) setState(() => _harJar = data);
    } else {
      final data = await _insjarRepo.semua();
      if (mounted) setState(() => _insjar = data);
    }
  }

  Future<void> _loadMasterState() async {
    final has = await SqliteService.instance.hasMasterData();
    final last = await SqliteService.instance.lastMasterSync();
    if (mounted) setState(() { _hasMaster = has; _lastSync = last; });
  }

  void _resultLater({required bool success, required String title, required String message}) {
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (mounted) {
        showOperationResultDialog(
          context,
          success: success,
          title: title,
          message: message,
        );
      }
    });
  }

  Future<void> _download() async {
    try {
      String? error;
      int processed = 0;
      int total = 0;
      if (_isInsdu) {
        final result = await _insduRepo.download(_token);
        error = result.pesan;
        processed = result.diproses;
        total = result.total;
      } else if (_isRow) {
        final result = await _rowRepo.download(_token);
        error = result.pesan;
        processed = result.diproses;
        total = result.total;
      } else if (_isHarJar) {
        final result = await _harJarRepo.download(_token);
        error = result.pesan;
        processed = result.diproses;
        total = result.total;
      } else {
        final result = await _insjarRepo.download(_token);
        error = result.pesan;
        processed = result.diproses;
        total = result.total;
      }
      await _load();
      if (error != null) {
        _resultLater(success: false, title: 'Download Gagal', message: error);
        throw StateError(error);
      }
      final message = processed == 0
          ? 'Server merespons, tetapi tidak ada data baru yang disimpan. Total data yang lolos filter: $total.'
          : '$processed data berhasil disimpan ke perangkat.';
      _resultLater(
        success: processed > 0,
        title: processed > 0 ? 'Download Selesai' : 'Tidak Ada Data Baru',
        message: message,
      );
    } catch (error) {
      if (!error.toString().contains('StateError')) {
        _resultLater(
          success: false,
          title: 'Download Gagal',
          message: error.toString(),
        );
      }
      rethrow;
    }
  }

  Future<void> _sync() async {
    try {
      String? error;
      int processed = 0;
      if (_isInsdu) {
        final result = await _insduRepo.sinkron(_token);
        error = result.pesan;
        processed = result.diproses;
      } else if (_isRow) {
        final result = await _rowRepo.sinkron(_token);
        error = result.pesan;
        processed = result.diproses;
      } else if (_isHarJar) {
        final result = await _harJarRepo.sinkron(_token);
        error = result.pesan;
        processed = result.diproses;
      } else {
        final result = await _insjarRepo.sinkron(_token);
        error = result.pesan;
        processed = result.diproses;
      }
      await _load();
      if (error != null) {
        _resultLater(success: false, title: 'Sinkronisasi Gagal', message: error);
        throw StateError(error);
      }
      _resultLater(
        success: true,
        title: 'Sinkronisasi Selesai',
        message: '$processed data berhasil dikirim ke server.',
      );
    } catch (error) {
      if (!error.toString().contains('StateError')) {
        _resultLater(success: false, title: 'Sinkronisasi Gagal', message: '$error');
      }
      rethrow;
    }
  }

  Future<void> _master() async {
    if (_syncingMaster) return;
    setState(() => _syncingMaster = true);
    _masterSpin.repeat();
    try {
      final response = await ApiService.getMasterData(_token);
      if (response['success'] != true || response['datasets'] is! Map) {
        throw StateError('${response['message'] ?? 'Data master tidak valid.'}');
      }
      await SqliteService.instance.replaceMasterData(
        Map<String, dynamic>.from(response['datasets']),
      );
      await _loadMasterState();
      if (mounted) {
        await showOperationResultDialog(
          context,
          success: true,
          title: 'Master Data Tersimpan',
          message: '${response['total'] ?? 0} baris master siap digunakan secara offline.',
        );
      }
    } catch (error) {
      if (mounted) {
        await showOperationResultDialog(
          context,
          success: false,
          title: 'Download Master Gagal',
          message: error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) {
        _masterSpin.stop();
        _masterSpin.value = 0;
        setState(() => _syncingMaster = false);
      }
    }
  }

  Future<void> _openInsjar(WoInsjar wo, {bool start = false}) async {
    if (start) await _insjarRepo.mulaiPengerjaan(wo.kodeWo);
    final current = await _insjarRepo.cariKode(wo.kodeWo) ?? wo;
    if (!mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WoInsjarFormScreen(sesi: widget.sesi, existing: current),
      ),
    );
    if (changed == true || start) await _load();
  }

  Future<void> _openInsdu(WoInsdu wo, {bool start = false}) async {
    if (start) await _insduRepo.mulaiPekerjaan(wo.kodeWo);
    final current = await _insduRepo.cari(wo.kodeWo) ?? wo;
    if (!mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WoInsduFormScreen(existing: current, sesi: widget.sesi),
      ),
    );
    if (changed == true || start) await _load();
  }

  Future<void> _openRow(WoRow row, {bool start = false}) async {
    if (start) await _rowRepo.mulaiPekerjaan(row.kodeWo);
    final current = await _rowRepo.cari(row.kodeWo) ?? row;
    if (!mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WoRowFormScreen(sesi: widget.sesi, existing: current),
      ),
    );
    if (changed == true || start) await _load();
  }

  Future<void> _openHarJar(WoHarJar wo, {bool start = false}) async {
    if (start) await _harJarRepo.mulaiPekerjaan(wo.kodeWo);
    final current = await _harJarRepo.cari(wo.kodeWo) ?? wo;
    if (!mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FormTindakLanjutHarJarScreen(
          sesi: widget.sesi,
          existing: current,
        ),
      ),
    );
    if (changed == true || start) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: blue,
          foregroundColor: const Color(0xFFFDFEFF),
          title: Row(
            children: [
              SvgPicture.asset(
                'assets/icons/${_selected == 0 ? 'work_order' : _selected == 1 ? 'beranda' : 'pengaturan'}.svg',
                width: 26,
                height: 26,
                colorFilter: const ColorFilter.mode(
                  Color(0xFFFDFEFF),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                const ['Work Order', 'Beranda', 'Pengaturan'][_selected],
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        body: IndexedStack(
          index: _selected,
          children: [_workOrders(), _home(), _settings()],
        ),
        bottomNavigationBar: BubbleNavbar(
          selectedIndex: _selected,
          onTap: (index) => setState(() => _selected = index),
        ),
      );

  List<Object> get _activeItems => _isInsdu
      ? _insdu
      : _isRow
          ? _rows
          : _isHarJar
              ? _harJar
              : _insjar;

  Widget _workOrders() {
    final children = <Widget>[];
    if (_isInsdu) {
      children.addAll(_insdu.map((wo) => WoInsduCard(
            wo: wo,
            onStart: () => _openInsdu(wo, start: true),
            onOpen: () => _openInsdu(wo),
          )));
    } else if (_isRow) {
      children.addAll(_rows.map((wo) => WoRowCard(
            row: wo,
            onStart: () => _openRow(wo, start: true),
            onOpen: () => _openRow(wo),
          )));
    } else if (_isHarJar) {
      children.addAll(_harJar.map((wo) => WoHarJarCard(
            wo: wo,
            onKerjakan: () => _openHarJar(wo, start: true),
            onLanjut: () => _openHarJar(wo),
          )));
    } else {
      children.addAll(_insjar.map((wo) => WoInsjarCard(
            wo: wo,
            onStart: () => _openInsjar(wo, start: true),
            onOpen: () => _openInsjar(wo),
          )));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: children.isEmpty ? [_empty()] : children,
      ),
    );
  }

  Widget _home() {
    int waiting = 0, progress = 0, done = 0, dirty = 0;
    if (_isInsdu) {
      waiting = _insdu.where((w) => WoInsdu.normalisasiStatus(w.statusWo) == WoInsdu.statusMulai).length;
      progress = _insdu.where((w) => WoInsdu.normalisasiStatus(w.statusWo) == WoInsdu.statusDalam).length;
      done = _insdu.where((w) => WoInsdu.normalisasiStatus(w.statusWo) == WoInsdu.statusSelesai).length;
      dirty = _insdu.where((w) => w.isDirty).length;
    } else if (_isRow) {
      waiting = _rows.where((w) => WoRow.normalisasiStatus(w.statusWo) == WoRow.statusPenugasan).length;
      progress = _rows.where((w) => WoRow.normalisasiStatus(w.statusWo) == WoRow.statusProgress).length;
      done = _rows.where((w) => WoRow.normalisasiStatus(w.statusWo) == WoRow.statusSelesai).length;
      dirty = _rows.where((w) => w.isDirty).length;
    } else if (_isHarJar) {
      waiting = _harJar.where((w) => WoHarJar.normalisasiStatus(w.statusWo) == WoHarJar.statusMenunggu).length;
      progress = _harJar.where((w) => WoHarJar.normalisasiStatus(w.statusWo) == WoHarJar.statusSedang).length;
      done = _harJar.where((w) => WoHarJar.normalisasiStatus(w.statusWo) == WoHarJar.statusSelesai).length;
      dirty = _harJar.where((w) => !w.isSynced).length;
    } else {
      waiting = _insjar.where((w) => WoInsjar.normalisasiStatus(w.statusWo) == WoInsjar.statusMulai).length;
      progress = _insjar.where((w) => WoInsjar.normalisasiStatus(w.statusWo) == WoInsjar.statusDalam).length;
      done = _insjar.where((w) => WoInsjar.normalisasiStatus(w.statusWo) == WoInsjar.statusSelesai).length;
      dirty = _insjar.where((w) => w.isDirty).length;
    }
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        WelcomeCard(sesi: widget.sesi),
        const SizedBox(height: 16),
        WoDataCard(
          isRow: _isRow,
          dirty: dirty,
          onDownload: _download,
          onSync: _sync,
        ),
        const SizedBox(height: 16),
        _isRow
            ? WoSummaryCard.row(
                total: _activeItems.length,
                penugasan: waiting,
                progress: progress,
                selesai: done,
              )
            : WoSummaryCard.insjar(
                total: _activeItems.length,
                menunggu: waiting,
                sedang: progress,
                selesai: done,
              ),
      ],
    );
  }

  Widget _settings() {
    final title = _hasMaster ? 'Sinkron Master Data' : 'Download Master Data';
    final time = _lastSync == null
        ? 'Belum sinkron'
        : '${_lastSync!.hour.toString().padLeft(2, '0')}:${_lastSync!.minute.toString().padLeft(2, '0')} WIB';
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Data & Server Lokal',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: navy),
        ),
        const SizedBox(height: 6),
        const Text(
          'Simpan master data agar aplikasi tetap siap saat offline.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 22),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    RotationTransition(
                      turns: _masterSpin,
                      child: SvgPicture.asset('assets/icons/pengaturan.svg', width: 42),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    Text(time, style: const TextStyle(fontSize: 10, color: muted)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _syncingMaster ? null : _master,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: amber,
                      foregroundColor: navy,
                    ),
                    child: Text(_syncingMaster ? 'Memproses...' : title),
                  ),
                ),
              ],
            ),
          ),
        ),
        SettingsSessionSection(session: widget.sesi),
      ],
    );
  }

  Widget _empty() => Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFEFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: line),
        ),
        child: Column(
          children: [
            const Icon(Icons.assignment_outlined, size: 46, color: blue),
            const SizedBox(height: 12),
            Text(
              'Belum ada $_label yang tersimpan',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            const Text(
              'Gunakan tombol Download WO di Beranda.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
          ],
        ),
      );
}
