import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/wo_har_jar.dart';
import '../models/wo_insjar.dart';
import '../models/wo_row.dart';
import '../services/api_service.dart';
import '../services/sqlite_service.dart';
import '../services/wo_har_jar_repository.dart';
import '../services/wo_insjar_repository.dart';
import '../services/wo_row_repository.dart';
import '../widgets/wo_har_jar_card.dart';
import 'form_tindak_lanjut_har_jar_screen.dart';
import 'settings_session_section.dart';
import 'widgets/bubble_navbar.dart';
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
    with SingleTickerProviderStateMixin {
  static const navy700 = Color(0xFF004D8C);
  static const navy950 = Color(0xFF071B30);
  static const amber600 = Color(0xFFFFB800);
  static const green600 = Color(0xFF16A34A);
  static const neutral500 = Color(0xFF64748B);
  static const neutral200 = Color(0xFFE2E8F0);
  static const red600 = Color(0xFFDC2626);
  static const bgLight = Color(0xFFEDF4FA);

  final _labels = const ['Work Order', 'Beranda', 'Pengaturan'];
  final _woRepo = WoInsjarRepository();
  final _rowRepo = WoRowRepository();
  final _harJarRepo = WoHarJarRepository();

  late final AnimationController _masterSpin;
  int _selectedIndex = 1;
  bool _hasLocal = false;
  bool _syncingMaster = false;
  DateTime? _lastSync;
  List<WoInsjar> _woList = const [];
  List<WoRow> _rowList = const [];
  List<WoHarJar> _harJarList = const [];

  String get _token => '${widget.sesi['token'] ?? ''}';
  String get _subTim =>
      '${widget.sesi['subTim'] ?? widget.sesi['tim'] ?? ''}'.toLowerCase();
  bool get _harJarTeam =>
      _subTim.contains('har jar') || _subTim.contains('harjar');
  bool get _rowTeam => !_harJarTeam && _subTim.contains('row');
  String get _teamLabel =>
      _harJarTeam ? 'Har Jar' : (_rowTeam ? 'ROW' : 'WO');

  @override
  void initState() {
    super.initState();
    _masterSpin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadLocalStatus();
    _loadWo();
  }

  @override
  void dispose() {
    _masterSpin.dispose();
    super.dispose();
  }

  Future<void> _loadLocalStatus() async {
    final has = await SqliteService.instance.hasMasterData();
    final last = await SqliteService.instance.lastMasterSync();
    if (mounted) {
      setState(() {
        _hasLocal = has;
        _lastSync = last;
      });
    }
  }

  Future<void> _loadWo() async {
    if (_harJarTeam) {
      final data = await _harJarRepo.semua();
      if (mounted) setState(() => _harJarList = data);
    } else if (_rowTeam) {
      final data = await _rowRepo.semua();
      if (mounted) setState(() => _rowList = data);
    } else {
      final data = await _woRepo.semua();
      if (mounted) setState(() => _woList = data);
    }
  }

  Future<void> _downloadWo() async {
    if (_token.isEmpty) {
      _message('Sesi tidak valid. Silakan login ulang.', error: true);
      return;
    }
    try {
      final result = _harJarTeam
          ? await _harJarRepo.download(_token)
          : _rowTeam
              ? await _rowRepo.download(_token)
              : await _woRepo.download(_token);
      await _loadWo();
      if (!mounted) return;
      if (result.pesan != null) {
        _message(result.pesan!, error: true);
      } else {
        _message('${result.diproses} data $_teamLabel berhasil diunduh.');
      }
    } catch (error) {
      if (mounted) _message('$error', error: true);
    }
  }

  Future<void> _syncWo() async {
    if (_token.isEmpty) {
      _message('Sesi tidak valid. Silakan login ulang.', error: true);
      return;
    }
    try {
      final result = _harJarTeam
          ? await _harJarRepo.sinkron(_token)
          : _rowTeam
              ? await _rowRepo.sinkron(_token)
              : await _woRepo.sinkron(_token);
      await _loadWo();
      if (!mounted) return;
      if (result.pesan != null) {
        _message(result.pesan!, error: true);
      } else {
        _message('${result.diproses} data $_teamLabel berhasil disinkronkan.');
      }
    } catch (error) {
      if (mounted) _message('$error', error: true);
    }
  }

  Future<void> _syncMaster() async {
    if (_syncingMaster) return;
    setState(() => _syncingMaster = true);
    _masterSpin.repeat();
    try {
      final result = await ApiService.getMasterData(_token);
      if (result['success'] != true || result['datasets'] is! Map) {
        throw StateError('${result['message'] ?? 'Data master tidak valid.'}');
      }
      await SqliteService.instance.replaceMasterData(
        Map<String, dynamic>.from(result['datasets']),
      );
      if (!mounted) return;
      setState(() {
        _hasLocal = true;
        _lastSync = DateTime.now();
      });
      _message('Master data berhasil disimpan.');
    } catch (error) {
      if (mounted) _message('$error', error: true);
    } finally {
      if (mounted) {
        _masterSpin.stop();
        _masterSpin.value = 0;
        setState(() => _syncingMaster = false);
      }
    }
  }

  Future<void> _startWo(WoInsjar wo) async {
    await _woRepo.mulaiPengerjaan(wo.kodeWo);
    await _loadWo();
  }

  Future<void> _openWo(WoInsjar wo) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WoInsjarFormScreen(sesi: widget.sesi, existing: wo),
      ),
    );
    if (changed == true) await _loadWo();
  }

  Future<void> _startRow(WoRow row) async {
    await _rowRepo.mulaiPekerjaan(row.kodeWo);
    await _loadWo();
  }

  Future<void> _openRow(WoRow row) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WoRowFormScreen(sesi: widget.sesi, existing: row),
      ),
    );
    if (changed == true) await _loadWo();
  }

  Future<void> _openHarJar(WoHarJar wo, {bool start = false}) async {
    var current = wo;
    if (start &&
        WoHarJar.normalisasiStatus(wo.statusWo) == WoHarJar.statusMenunggu) {
      await _harJarRepo.mulaiPekerjaan(wo.kodeWo);
      current = await _harJarRepo.cari(wo.kodeWo) ?? wo;
    }
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
    if (changed == true || start) await _loadWo();
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? red600 : green600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: bgLight,
        appBar: AppBar(
          backgroundColor: navy700,
          foregroundColor: Colors.white,
          title: Row(
            children: [
              SvgPicture.asset(
                'assets/icons/${_selectedIndex == 0 ? 'work_order' : _selectedIndex == 1 ? 'beranda' : 'pengaturan'}.svg',
                width: 26,
                height: 26,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _labels[_selectedIndex],
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [_workOrders(), _home(), _settings()],
        ),
        bottomNavigationBar: BubbleNavbar(
          selectedIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
        ),
      );

  Widget _home() {
    final isRow = _rowTeam;
    final total = _harJarTeam
        ? _harJarList.length
        : isRow
            ? _rowList.length
            : _woList.length;
    final waiting = _harJarTeam
        ? _harJarList
            .where((w) => WoHarJar.normalisasiStatus(w.statusWo) == WoHarJar.statusMenunggu)
            .length
        : isRow
            ? _rowList
                .where((w) => WoRow.normalisasiStatus(w.statusWo) == WoRow.statusPenugasan)
                .length
            : _woList
                .where((w) => WoInsjar.normalisasiStatus(w.statusWo) == WoInsjar.statusMulai)
                .length;
    final progress = _harJarTeam
        ? _harJarList
            .where((w) => WoHarJar.normalisasiStatus(w.statusWo) == WoHarJar.statusSedang)
            .length
        : isRow
            ? _rowList
                .where((w) => WoRow.normalisasiStatus(w.statusWo) == WoRow.statusProgress)
                .length
            : _woList
                .where((w) => WoInsjar.normalisasiStatus(w.statusWo) == WoInsjar.statusDalam)
                .length;
    final done = _harJarTeam
        ? _harJarList
            .where((w) => WoHarJar.normalisasiStatus(w.statusWo) == WoHarJar.statusSelesai)
            .length
        : isRow
            ? _rowList
                .where((w) => WoRow.normalisasiStatus(w.statusWo) == WoRow.statusSelesai)
                .length
            : _woList
                .where((w) => WoInsjar.normalisasiStatus(w.statusWo) == WoInsjar.statusSelesai)
                .length;
    final dirty = _harJarTeam
        ? _harJarList.where((w) => !w.isSynced).length
        : isRow
            ? _rowList.where((w) => w.isDirty).length
            : _woList.where((w) => w.isDirty).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        WelcomeCard(sesi: widget.sesi),
        const SizedBox(height: 16),
        WoDataCard(
          isRow: isRow,
          dirty: dirty,
          onDownload: _downloadWo,
          onSync: _syncWo,
        ),
        const SizedBox(height: 16),
        isRow
            ? WoSummaryCard.row(
                total: total,
                penugasan: waiting,
                progress: progress,
                selesai: done,
              )
            : WoSummaryCard.insjar(
                total: total,
                menunggu: waiting,
                sedang: progress,
                selesai: done,
              ),
      ],
    );
  }

  Widget _workOrders() {
    if (_harJarTeam) {
      return _list(
        emptyText: 'Belum ada WO Har Jar yang diunduh',
        children: _harJarList
            .map(
              (wo) => WoHarJarCard(
                wo: wo,
                onKerjakan: () => _openHarJar(wo, start: true),
                onLanjut: () => _openHarJar(wo),
              ),
            )
            .toList(),
      );
    }
    if (_rowTeam) {
      return _list(
        emptyText: 'Belum ada ROW yang diunduh',
        children: _rowList
            .map(
              (row) => WoRowCard(
                row: row,
                onStart: () => _startRow(row),
                onOpen: () => _openRow(row),
              ),
            )
            .toList(),
      );
    }
    return _list(
      emptyText: 'Belum ada WO yang diunduh',
      children: _woList
          .map(
            (wo) => WoInsjarCard(
              wo: wo,
              onStart: () => _startWo(wo),
              onOpen: () => _openWo(wo),
            ),
          )
          .toList(),
    );
  }

  Widget _list({required String emptyText, required List<Widget> children}) =>
      RefreshIndicator(
        onRefresh: _loadWo,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: children.isEmpty ? [_emptyState(emptyText)] : children,
        ),
      );

  Widget _emptyState(String text) => Container(
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: neutral200),
        ),
        child: Column(
          children: [
            const Icon(Icons.assignment_outlined, size: 42, color: navy700),
            const SizedBox(height: 12),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            const Text(
              'Gunakan Download WO pada menu Beranda.',
              textAlign: TextAlign.center,
              style: TextStyle(color: neutral500),
            ),
          ],
        ),
      );

  Widget _settings() {
    final title = _hasLocal ? 'Sinkron Master Data' : 'Download Master Data';
    final time = _lastSync == null
        ? 'Belum sinkron'
        : '${_lastSync!.hour.toString().padLeft(2, '0')}:${_lastSync!.minute.toString().padLeft(2, '0')} WIB';
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Data & Server Lokal',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: navy950,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Download master data agar siap digunakan saat offline.',
          style: TextStyle(color: neutral500),
        ),
        const SizedBox(height: 22),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: neutral200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    RotationTransition(
                      turns: _masterSpin,
                      child: SvgPicture.asset(
                        'assets/icons/pengaturan.svg',
                        width: 44,
                        height: 44,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 10,
                        color: neutral500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _syncingMaster ? null : _syncMaster,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: amber600,
                      foregroundColor: navy950,
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
}
