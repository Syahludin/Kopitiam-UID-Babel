import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/har_execution.dart';
import '../models/wo_har_jar.dart';
import '../models/wo_insdu.dart';
import '../models/wo_insjar.dart';
import '../models/wo_row.dart';
import '../services/api_service.dart';
import '../services/role_provider.dart';
import '../services/sqlite_service.dart';
import '../services/wo_har_jar_repository.dart';
import '../services/wo_insdu_repository.dart';
import '../services/wo_insjar_repository.dart';
import '../services/wo_row_repository.dart';
import '../widgets/wo_har_jar_card.dart';
import 'c4a_findings_home.dart';
import 'c4a_route_guard.dart';
import 'form_tindak_lanjut_har_jar_screen.dart';
import 'settings_session_section.dart';
import 'widgets/bubble_navbar.dart';
import 'widgets/download_sync_panel.dart';
import 'widgets/operation_result_dialog.dart';
import 'widgets/welcome_card.dart';
import 'widgets/wo_insdu_card.dart';
import 'widgets/wo_insjar_card.dart';
import 'widgets/wo_row_card.dart';
import 'wo_insdu_form_screen.dart';
import 'wo_insjar_form_screen.dart';
import 'wo_row_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> sesi;
  const DashboardScreen({super.key, required this.sesi});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
  int _selected = 1;
  bool _syncingMaster = false;
  bool _hasMaster = false;
  DateTime? _lastSync;
  List<WoInsjar> _insjar = const [];
  List<WoInsdu> _insdu = const [];
  List<WoRow> _rows = const [];
  List<WoHarJar> _harJar = const [];

  String get _token => '${widget.sesi['token'] ?? ''}';
  String get _identity => '${widget.sesi['subTim'] ?? widget.sesi['tim'] ?? ''} ${widget.sesi['username'] ?? ''}'.toLowerCase();
  bool get _isInsdu => _identity.contains('inspeksi gardu') || _identity.contains('insdu');
  bool get _isRow => !_isInsdu && _identity.contains('row');
  bool get _isHarJar => !_isInsdu && !_isRow && (_identity.contains('har jar') || _identity.contains('harjar'));
  String get _label => _isInsdu ? 'WO Inspeksi Gardu' : _isRow ? 'ROW' : _isHarJar ? 'WO Har Jar' : 'WO Inspeksi Jaringan';
  int get _totalReady => _isInsdu ? _insdu.length : _isRow ? _rows.length : _isHarJar ? _harJar.length : _insjar.length;
  int get _syncQueue => _isInsdu
      ? _insdu.where((item) => item.isDirty).length
      : _isRow
          ? _rows.where((item) => item.isDirty).length
          : _isHarJar
              ? _harJar.where((item) => WoHarJar.normalisasiStatus(item.statusWo) == WoHarJar.statusSelesai && !item.isSynced).length
              : _insjar.where((item) => item.isDirty).length;

  @override
  void initState() {
    super.initState();
    _load();
    _loadMasterState();
  }

  Future<void> _load() async {
    if (_isInsdu) {
      _insdu = await _insduRepo.semua();
    } else if (_isRow) {
      _rows = await _rowRepo.semua();
    } else if (_isHarJar) {
      _harJar = await _harJarRepo.semua();
    } else {
      _insjar = await _insjarRepo.semua();
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadMasterState() async {
    _hasMaster = await SqliteService.instance.hasMasterData();
    _lastSync = await SqliteService.instance.lastMasterSync();
    if (mounted) setState(() {});
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? Colors.red.shade700 : null));
  }

  Future<void> _download() async {
    try {
      var downloaded = 0;
      String? error;
      if (_isInsdu) {
        final result = await _insduRepo.download(_token);
        downloaded = result.diproses;
        error = result.pesan;
      } else if (_isRow) {
        final result = await _rowRepo.download(_token);
        downloaded = result.diproses;
        error = result.pesan;
      } else if (_isHarJar) {
        final result = await _harJarRepo.download(_token);
        downloaded = result.diproses;
        error = result.pesan;
      } else {
        final result = await _insjarRepo.download(_token);
        downloaded = result.diproses;
        error = result.pesan;
      }
      if (!mounted) return;
      if (error != null && error.trim().isNotEmpty) {
        await showOperationResultDialog(context, success: false, title: 'Download WO Gagal', message: error);
        return;
      }
      await _load();
      if (!mounted) return;
      if (downloaded == 0) {
        await showOperationResultDialog(context, success: true, title: 'WO Sudah di Download Semua', message: 'Tidak ada Work Order baru yang perlu diunduh.');
        return;
      }
      _message('$downloaded WO baru tersimpan di perangkat.');
    } catch (error) {
      _message('$error', error: true);
    }
  }

  Future<void> _sync() async {
    try {
      if (_isInsdu) {
        await _insduRepo.sinkron(_token);
      } else if (_isRow) {
        await _rowRepo.sinkron(_token);
      } else if (_isHarJar) {
        await _harJarRepo.sinkron(_token);
      } else {
        await _insjarRepo.sinkron(_token);
      }
      await _load();
      _message('Sinkronisasi WO selesai.');
    } catch (error) {
      _message('$error', error: true);
    }
  }

  Future<void> _master() async {
    if (_syncingMaster) return;
    setState(() => _syncingMaster = true);
    try {
      final response = await ApiService.getMasterData(_token);
      if (response['success'] != true || response['datasets'] is! Map) {
        throw StateError('${response['message'] ?? 'Data master tidak valid.'}');
      }
      await SqliteService.instance.replaceMasterData(Map<String, dynamic>.from(response['datasets']));
      await _loadMasterState();
      _message('Master data siap dipakai offline.');
    } catch (error) {
      _message('$error', error: true);
    } finally {
      if (mounted) setState(() => _syncingMaster = false);
    }
  }

  Future<void> _openC4a() async {
    if (!RoleProvider.hasC4aAccess(widget.sesi)) {
      _message('Akses C4A tidak tersedia untuk role ini.', error: true);
      return;
    }
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => C4aRouteGuard(sesi: widget.sesi, child: C4aFindingsHome(sesi: widget.sesi))));
  }

  Future<void> _openInsjar(WoInsjar wo, {bool start = false}) async {
    if (start) await _insjarRepo.mulaiPengerjaan(wo.kodeWo);
    final current = await _insjarRepo.cariKode(wo.kodeWo) ?? wo;
    if (!mounted) return;
    await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => WoInsjarFormScreen(sesi: widget.sesi, existing: current)));
    await _load();
  }

  Future<void> _openInsdu(WoInsdu wo, {bool start = false}) async {
    if (start) await _insduRepo.mulaiPekerjaan(wo.kodeWo);
    final current = await _insduRepo.cari(wo.kodeWo) ?? wo;
    if (!mounted) return;
    await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => WoInsduFormScreen(existing: current, sesi: widget.sesi)));
    await _load();
  }

  Future<void> _openRow(WoRow wo, {bool start = false}) async {
    if (start) await _rowRepo.mulaiPekerjaan(wo.kodeWo);
    final current = await _rowRepo.cari(wo.kodeWo) ?? wo;
    if (!mounted) return;
    await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => WoRowFormScreen(sesi: widget.sesi, existing: current)));
    await _load();
  }

  Future<void> _openHarJar(WoHarJar wo, {bool start = false}) async {
    if (start) await _harJarRepo.mulaiPekerjaan(wo.kodeWo);
    final current = await _harJarRepo.cari(wo.kodeWo) ?? wo;
    if (!mounted) return;
    await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => FormTindakLanjutHarJarScreen(sesi: widget.sesi, existing: current)));
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          title: Row(children: [
            SvgPicture.asset(
              'assets/icons/${_selected == 0 ? 'work_order' : _selected == 1 ? 'beranda' : 'pengaturan'}.svg',
              width: 26,
              height: 26,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            const SizedBox(width: 10),
            Text(const ['Work Order', 'Beranda', 'Pengaturan'][_selected], style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ),
        body: IndexedStack(index: _selected, children: [_workOrders(), _home(), _settings()]),
        bottomNavigationBar: BubbleNavbar(selectedIndex: _selected, onTap: (index) => setState(() => _selected = index)),
      );

  Widget _workOrders() {
    final children = <Widget>[];
    if (_isInsdu) {
      children.addAll(_insdu.map((wo) => WoInsduCard(wo: wo, onStart: () => _openInsdu(wo, start: true), onOpen: () => _openInsdu(wo))));
    } else if (_isRow) {
      children.addAll(_rows.map((wo) => WoRowCard(row: wo, onStart: () => _openRow(wo, start: true), onOpen: () => _openRow(wo))));
    } else if (_isHarJar) {
      children.addAll(_harJar.map((wo) => WoHarJarCard(wo: wo, onKerjakan: () => _openHarJar(wo, start: true), onLanjut: () => _openHarJar(wo))));
    } else {
      children.addAll(_insjar.map((wo) => WoInsjarCard(wo: wo, onStart: () => _openInsjar(wo, start: true), onOpen: () => _openInsjar(wo))));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(18), children: children.isEmpty ? [_empty()] : children),
    );
  }

  Widget _home() {
    final children = <Widget>[WelcomeCard(sesi: widget.sesi), const SizedBox(height: 16)];
    if (RoleProvider.hasC4aAccess(widget.sesi)) {
      children.add(Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: line)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(18),
          leading: const CircleAvatar(backgroundColor: amber, foregroundColor: navy, child: Icon(Icons.fact_check_outlined)),
          title: const Text('Temuan C4A', style: TextStyle(fontWeight: FontWeight.w900, color: navy)),
          subtitle: const Text('Draft lokal, antrean kirim, status gagal, dan kirim ulang.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _openC4a,
        ),
      ));
      children.add(const SizedBox(height: 16));
    }
    children.addAll([
      const Text('PUSAT DATA WORK ORDER', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
      const SizedBox(height: 12),
      DownloadSyncPanel(totalReady: _totalReady, syncQueue: _syncQueue, onDownload: _download, onSync: _sync),
    ]);
    return ListView(padding: const EdgeInsets.all(18), children: children);
  }

  Widget _settings() {
    final time = _lastSync == null ? 'Belum sinkron' : '${_lastSync!.hour.toString().padLeft(2, '0')}:${_lastSync!.minute.toString().padLeft(2, '0')} WIB';
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Data & Server Lokal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: navy)),
      const SizedBox(height: 16),
      Card(child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: const Icon(Icons.storage, color: blue),
        title: Text(_hasMaster ? 'Sinkron Master Data' : 'Download Master Data'),
        subtitle: Text(time),
        trailing: _syncingMaster ? const CircularProgressIndicator() : const Icon(Icons.download),
        onTap: _syncingMaster ? null : _master,
      )),
      SettingsSessionSection(session: widget.sesi),
    ]);
  }

  Widget _empty() => Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: line)),
        child: Column(children: [
          const Icon(Icons.assignment_outlined, size: 46, color: blue),
          const SizedBox(height: 12),
          Text('Belum ada $_label yang tersimpan', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
          const Text('Gunakan tombol Download WO di Beranda.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
        ]),
      );
}
