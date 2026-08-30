import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/wo_insjar.dart';
import '../models/wo_row.dart';
import '../services/api_service.dart';
import '../services/sqlite_service.dart';
import '../services/wo_insjar_repository.dart';
import '../services/wo_row_repository.dart';
import 'settings_session_section.dart';
import 'widgets/bubble_navbar.dart';
import 'widgets/success_overlay.dart';
import 'widgets/welcome_card.dart';
import 'widgets/wo_data_card.dart';
import 'widgets/wo_insjar_card.dart';
import 'widgets/wo_row_card.dart';
import 'widgets/wo_summary_card.dart';
import 'wo_insjar_form_screen.dart';
import 'wo_row_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> sesi;
  const DashboardScreen({super.key, required this.sesi});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  static const navy700 = Color(0xFF004D8C);
  static const navy950 = Color(0xFF071B30);
  static const cyan500 = Color(0xFF00E5FF);
  static const amber600 = Color(0xFFFFB800);
  static const green600 = Color(0xFF16A34A);
  static const neutral500 = Color(0xFF64748B);
  static const neutral200 = Color(0xFFE2E8F0);
  static const red600 = Color(0xFFDC2626);
  static const bgLight = Color(0xFFEDF4FA);

  final _labels = const ['Work Order', 'Beranda', 'Pengaturan'];
  final _woRepo = WoInsjarRepository();
  final _rowRepo = WoRowRepository();
  late final AnimationController _masterSpin;

  int _selectedIndex = 1;
  bool _hasLocal = false;
  bool _syncing = false;
  bool _woBusy = false;
  double _progress = 0;
  double _woProgress = 0;
  String _woProgressLabel = '';
  Timer? _progressTimer;
  DateTime? _lastSync;
  List<WoInsjar> _woList = const [];
  List<WoRow> _rowList = const [];

  String get _token => (widget.sesi['token'] ?? '').toString();
  bool get _rowTeam {
    final sub = '${widget.sesi['subTim'] ?? widget.sesi['tim'] ?? ''}'.toLowerCase();
    return sub.contains('row');
  }

  String get _rowLabel => _rowTeam ? 'ROW' : 'WO';

  @override
  void initState() {
    super.initState();
    _masterSpin = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _loadLocalStatus();
    _loadWo();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _masterSpin.dispose();
    super.dispose();
  }

  void _startProgress({required bool master, required String label}) {
    _progressTimer?.cancel();
    setState(() {
      if (master) { _progress = .05; } else { _woProgress = .05; _woProgressLabel = label; }
    });
    _progressTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (!mounted) return;
      setState(() {
        if (master) { _progress = math.min(.90, _progress + .04); } else { _woProgress = math.min(.90, _woProgress + .04); }
      });
    });
  }

  Future<void> _completeProgress({required bool master}) async {
    _progressTimer?.cancel();
    if (!mounted) return;
    setState(() { if (master) { _progress = 1; } else { _woProgress = 1; } });
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Future<void> _loadLocalStatus() async {
    final has = await SqliteService.instance.hasMasterData();
    final last = await SqliteService.instance.lastMasterSync();
    if (mounted) setState(() { _hasLocal = has; _lastSync = last; });
  }

  Future<void> _loadWo() async {
    if (_rowTeam) {
      final list = await _rowRepo.semua();
      if (mounted) setState(() => _rowList = list);
    } else {
      final list = await _woRepo.semua();
      if (mounted) setState(() => _woList = list);
    }
  }

  Future<void> _downloadWo() async {
    if (_woBusy || _token.isEmpty) return;
    setState(() => _woBusy = true);
    _startProgress(master: false, label: _rowTeam ? 'Mengunduh ROW' : 'Mengunduh WO');
    try {
      final hasil = _rowTeam ? await _rowRepo.download(_token) : await _woRepo.download(_token);
      await _loadWo();
      await _completeProgress(master: false);
      if (!mounted) return;
      if (hasil.pesan != null) { _message(hasil.pesan!, error: true); } else {
        await _resultDialog(title: 'Download $_rowLabel Selesai', count: hasil.diproses, label: '$_rowLabel baru ditambahkan', note: '${hasil.total} Total $_rowLabel.', icon: Icons.cloud_download_rounded);
      }
    } catch (e) { if (mounted) _message('$e', error: true); }
    finally { _progressTimer?.cancel(); if (mounted) setState(() { _woBusy = false; _woProgress = 0; _woProgressLabel = ''; }); }
  }

  Future<void> _syncWo() async {
    if (_woBusy) return;
    setState(() => _woBusy = true);
    _startProgress(master: false, label: _rowTeam ? 'Menyinkronkan ROW' : 'Menyinkronkan WO');
    try {
      final hasil = _rowTeam ? await _rowRepo.sinkron(_token) : await _woRepo.sinkron(_token);
      await _loadWo();
      await _completeProgress(master: false);
      if (!mounted) return;
      if (hasil.pesan != null) { _message(hasil.pesan!, error: true); } else {
        await _resultDialog(title: 'Sinkronisasi $_rowLabel Selesai', count: hasil.diproses, label: '$_rowLabel diSinkronkan', note: hasil.total == 0 ? 'Tidak ada yang perlu disinkronkan.' : '${hasil.total} $_rowLabel.', icon: Icons.cloud_upload_rounded);
      }
    } catch (e) { if (mounted) _message('$e', error: true); }
    finally { _progressTimer?.cancel(); if (mounted) setState(() { _woBusy = false; _woProgress = 0; _woProgressLabel = ''; }); }
  }

  Future<void> _syncMaster() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    _masterSpin.repeat();
    _startProgress(master: true, label: '');
    try {
      final result = await ApiService.getMasterData(_token);
      if (result['success'] != true || result['datasets'] is! Map) throw StateError((result['message'] ?? 'Data master tidak valid.').toString());
      if (mounted) setState(() => _progress = math.max(_progress, .75));
      await SqliteService.instance.replaceMasterData(Map<String, dynamic>.from(result['datasets']));
      if (!mounted) return;
      setState(() { _hasLocal = true; _lastSync = DateTime.now(); });
      await _completeProgress(master: true);
      if (mounted) await showDialog<void>(context: context, barrierDismissible: false, barrierColor: const Color(0x8C071B30), builder: (_) => const SuccessOverlay(title: 'Master Data Berhasil Disimpan', message: 'Data master siap digunakan saat offline.'));
    } catch (e) { if (mounted) _message('$e', error: true); }
    finally { _progressTimer?.cancel(); if (mounted) { _masterSpin.stop(); _masterSpin.value = 0; setState(() { _syncing = false; _progress = 0; }); } }
  }

  Future<void> _resultDialog({required String title, required int count, required String label, required String note, required IconData icon}) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      icon: Icon(icon, color: green600, size: 40),
      title: Text(title, textAlign: TextAlign.center),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$count', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: navy700)),
        Text(label, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(note, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: neutral500)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup'))],
    ),
  );

  Future<void> _startWo(WoInsjar wo) async { await _woRepo.mulaiPengerjaan(wo.kodeWo); await _loadWo(); }
  Future<void> _openWo(WoInsjar wo) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => WoInsjarFormScreen(sesi: widget.sesi, existing: wo)));
    if (changed == true) await _loadWo();
  }
  Future<void> _startRow(WoRow row) async { await _rowRepo.mulaiPekerjaan(row.kodeWo); await _loadWo(); }
  Future<void> _openRow(WoRow row) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => WoRowFormScreen(sesi: widget.sesi, existing: row)));
    if (changed == true) await _loadWo();
  }

  void _message(String text, {bool error = false}) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? red600 : green600, behavior: SnackBarBehavior.floating, margin: EdgeInsets.only(left: 16, right: 16, bottom: bottom + 90), duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bgLight,
    appBar: AppBar(
      backgroundColor: navy700,
      foregroundColor: Colors.white,
      title: Row(children: [
        SvgPicture.asset('assets/icons/${_selectedIndex == 0 ? 'work_order' : _selectedIndex == 1 ? 'beranda' : 'pengaturan'}.svg', width: 26, height: 26, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
        const SizedBox(width: 10),
        Text(_labels[_selectedIndex], style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
    ),
    body: IndexedStack(index: _selectedIndex, children: [_workOrders(), _home(), _settings()]),
    bottomNavigationBar: BubbleNavbar(selectedIndex: _selectedIndex, onTap: (i) => setState(() => _selectedIndex = i)),
  );

  Widget _home() {
    final isRow = _rowTeam;
    final total = isRow ? _rowList.length : _woList.length;
    final menunggu = isRow ? _rowList.where((r) => WoRow.normalisasiStatus(r.statusWo) == WoRow.statusPenugasan).length : _woList.where((w) => WoInsjar.normalisasiStatus(w.statusWo) == WoInsjar.statusMulai).length;
    final sedang = isRow ? _rowList.where((r) => WoRow.normalisasiStatus(r.statusWo) == WoRow.statusProgress).length : _woList.where((w) => WoInsjar.normalisasiStatus(w.statusWo) == WoInsjar.statusDalam).length;
    final selesai = isRow ? _rowList.where((r) => WoRow.normalisasiStatus(r.statusWo) == WoRow.statusSelesai).length : _woList.where((w) => WoInsjar.normalisasiStatus(w.statusWo) == WoInsjar.statusSelesai).length;
    final dirty = isRow ? _rowList.where((r) => r.isDirty).length : _woList.where((w) => w.isDirty).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        WelcomeCard(sesi: widget.sesi),
        const SizedBox(height: 16),
        WoDataCard(isRow: isRow, busy: _woBusy, dirty: dirty, progress: _woProgress, progressLabel: _woProgressLabel, onDownload: _downloadWo, onSync: _syncWo),
        const SizedBox(height: 16),
        isRow
            ? WoSummaryCard.row(total: total, penugasan: menunggu, progress: sedang, selesai: selesai)
            : WoSummaryCard.insjar(total: total, menunggu: menunggu, sedang: sedang, selesai: selesai),
      ],
    );
  }

  Widget _workOrders() {
    if (_rowTeam) {
      return RefreshIndicator(onRefresh: _loadWo, child: ListView(
        padding: const EdgeInsets.all(18),
        children: _rowList.isEmpty
            ? [_emptyState('Belum ada ROW yang di Download')]
            : _rowList.map((r) => WoRowCard(row: r, onStart: () => _startRow(r), onOpen: () => _openRow(r))).toList(),
      ));
    }
    return RefreshIndicator(onRefresh: _loadWo, child: ListView(
      padding: const EdgeInsets.all(18),
      children: _woList.isEmpty
          ? [_emptyState('Belum ada WO yang di Download')]
          : _woList.map((w) => WoInsjarCard(wo: w, onStart: () => _startWo(w), onOpen: () => _openWo(w))).toList(),
    ));
  }

  Widget _emptyState(String text) => Container(
    padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 22),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: neutral200)),
    child: Column(children: [
      const Icon(Icons.assignment_outlined, size: 42, color: navy700),
      const SizedBox(height: 12),
      Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      const Text('Gunakan Download WO pada menu Beranda.', textAlign: TextAlign.center, style: TextStyle(color: neutral500)),
    ]),
  );

  Widget _settings() {
    final title = _hasLocal ? 'Sinkron Master Data' : 'Download Master Data';
    final time = _lastSync == null ? 'Belum sinkron' : 'Terakhir ${_lastSync!.hour.toString().padLeft(2, '0')}:${_lastSync!.minute.toString().padLeft(2, '0')} WIB';
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('Data & Server Lokal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: navy950)),
        const SizedBox(height: 5),
        const Text('Download Master Data Agar siap digunakan saat offline.', style: TextStyle(color: neutral500)),
        const SizedBox(height: 22),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: neutral200)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              Row(children: [
                RotationTransition(turns: _masterSpin, child: SvgPicture.asset('assets/icons/pengaturan.svg', width: 44, height: 44)),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                Text(time, style: const TextStyle(fontSize: 10, color: neutral500)),
              ]),
              const SizedBox(height: 18),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _syncing ? null : _syncMaster, style: ElevatedButton.styleFrom(backgroundColor: amber600, foregroundColor: navy950), child: Text(_syncing ? 'Memproses...' : title))),
              if (_syncing) ...[
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Proses master data', style: TextStyle(fontSize: 11, color: neutral500)),
                  Text('${(_progress.clamp(0, 1) * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: navy700)),
                ]),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: _progress, color: cyan500, backgroundColor: neutral200),
              ],
            ]),
          ),
        ),
        SettingsSessionSection(session: widget.sesi),
      ],
    );
  }
}
