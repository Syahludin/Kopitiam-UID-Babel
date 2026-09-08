import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/temuan_inspeksi.dart';
import '../models/wo_har_jar.dart';
import '../models/wo_insdu.dart';
import '../models/wo_insjar.dart';
import '../models/wo_row.dart';
import '../services/api_service.dart';
import '../services/role_provider.dart';
import '../services/sqlite_service.dart';
import '../services/temuan_repository.dart';
import '../services/wo_har_jar_repository.dart';
import '../services/wo_insdu_repository.dart';
import '../services/wo_insjar_repository.dart';
import '../services/wo_row_repository.dart';
import '../widgets/wo_har_jar_card.dart';
import 'form_tindak_lanjut_har_jar_screen.dart';
import 'c4a_route_guard.dart';
import 'settings_session_section.dart';
import 'temuan_form_screen.dart';
import 'widgets/bubble_navbar.dart';
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
  static const blue = Color(0xFF004D8C),
      navy = Color(0xFF071B30),
      amber = Color(0xFFFFB800),
      muted = Color(0xFF64748B),
      line = Color(0xFFE2E8F0),
      background = Color(0xFFEDF4FA);
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
  String get _identity =>
      '${widget.sesi['subTim'] ?? widget.sesi['tim'] ?? ''} ${widget.sesi['username'] ?? ''}'
          .toLowerCase();
  bool get _isInsdu =>
      _identity.contains('inspeksi gardu') || _identity.contains('insdu');
  bool get _isRow => !_isInsdu && _identity.contains('row');
  bool get _isHarJar =>
      !_isInsdu &&
      !_isRow &&
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _download() async {
    try {
      if (_isInsdu) {
        await _insduRepo.download(_token);
      } else if (_isRow) {
        await _rowRepo.download(_token);
      } else if (_isHarJar) {
        await _harJarRepo.download(_token);
      } else {
        await _insjarRepo.download(_token);
      }
      await _load();
      _message('Data WO tersimpan di perangkat.');
    } catch (e) {
      _message('$e', error: true);
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
    } catch (e) {
      _message('$e', error: true);
    }
  }

  Future<void> _master() async {
    if (_syncingMaster) return;
    setState(() => _syncingMaster = true);
    try {
      final response = await ApiService.getMasterData(_token);
      if (response['success'] != true || response['datasets'] is! Map) {
        throw StateError(
          '${response['message'] ?? 'Data master tidak valid.'}',
        );
      }
      await SqliteService.instance.replaceMasterData(
        Map<String, dynamic>.from(response['datasets']),
      );
      await _loadMasterState();
      _message('Master data siap dipakai offline.');
    } catch (e) {
      _message('$e', error: true);
    } finally {
      if (mounted) setState(() => _syncingMaster = false);
    }
  }

  Future<void> _openC4a() async {
    if (!RoleProvider.hasC4aAccess(widget.sesi)) {
      _message('Akses C4A tidak tersedia untuk role ini.', error: true);
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => C4aRouteGuard(
          sesi: widget.sesi,
          child: C4aFindingsHome(sesi: widget.sesi),
        ),
      ),
    );
  }

  Future<void> _openInsjar(WoInsjar wo, {bool start = false}) async {
    if (start) await _insjarRepo.mulaiPengerjaan(wo.kodeWo);
    final current = await _insjarRepo.cariKode(wo.kodeWo) ?? wo;
    if (!mounted) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WoInsjarFormScreen(sesi: widget.sesi, existing: current),
      ),
    );
    await _load();
  }

  Future<void> _openInsdu(WoInsdu wo, {bool start = false}) async {
    if (start) await _insduRepo.mulaiPekerjaan(wo.kodeWo);
    final current = await _insduRepo.cari(wo.kodeWo) ?? wo;
    if (!mounted) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WoInsduFormScreen(existing: current, sesi: widget.sesi),
      ),
    );
    await _load();
  }

  Future<void> _openRow(WoRow wo, {bool start = false}) async {
    if (start) await _rowRepo.mulaiPekerjaan(wo.kodeWo);
    final current = await _rowRepo.cari(wo.kodeWo) ?? wo;
    if (!mounted) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WoRowFormScreen(sesi: widget.sesi, existing: current),
      ),
    );
    await _load();
  }

  Future<void> _openHarJar(WoHarJar wo, {bool start = false}) async {
    if (start) await _harJarRepo.mulaiPekerjaan(wo.kodeWo);
    final current = await _harJarRepo.cari(wo.kodeWo) ?? wo;
    if (!mounted) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FormTindakLanjutHarJarScreen(sesi: widget.sesi, existing: current),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      backgroundColor: blue,
      foregroundColor: Colors.white,
      title: Row(
        children: [
          SvgPicture.asset(
            'assets/icons/${_selected == 0
                ? 'work_order'
                : _selected == 1
                ? 'beranda'
                : 'pengaturan'}.svg',
            width: 26,
            height: 26,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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

  Widget _workOrders() {
    final children = <Widget>[];
    if (_isInsdu) {
      children.addAll(
        _insdu.map(
          (wo) => WoInsduCard(
            wo: wo,
            onStart: () => _openInsdu(wo, start: true),
            onOpen: () => _openInsdu(wo),
          ),
        ),
      );
    } else if (_isRow) {
      children.addAll(
        _rows.map(
          (wo) => WoRowCard(
            row: wo,
            onStart: () => _openRow(wo, start: true),
            onOpen: () => _openRow(wo),
          ),
        ),
      );
    } else if (_isHarJar) {
      children.addAll(
        _harJar.map(
          (wo) => WoHarJarCard(
            wo: wo,
            onKerjakan: () => _openHarJar(wo, start: true),
            onLanjut: () => _openHarJar(wo),
          ),
        ),
      );
    } else {
      children.addAll(
        _insjar.map(
          (wo) => WoInsjarCard(
            wo: wo,
            onStart: () => _openInsjar(wo, start: true),
            onOpen: () => _openInsjar(wo),
          ),
        ),
      );
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
    final children = <Widget>[
      WelcomeCard(sesi: widget.sesi),
      const SizedBox(height: 16),
    ];
    if (RoleProvider.hasC4aAccess(widget.sesi)) {
      children.add(
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: line),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(18),
            leading: const CircleAvatar(
              backgroundColor: amber,
              foregroundColor: navy,
              child: Icon(Icons.fact_check_outlined),
            ),
            title: const Text(
              'Temuan C4A',
              style: TextStyle(fontWeight: FontWeight.w900, color: navy),
            ),
            subtitle: const Text(
              'Draft lokal, antrean kirim, status gagal, dan kirim ulang.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openC4a,
          ),
        ),
      );
    }
    children.addAll([
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.download),
              label: const Text('Download WO'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _sync,
              icon: const Icon(Icons.sync),
              label: const Text('Sinkron WO'),
            ),
          ),
        ],
      ),
    ]);
    return ListView(padding: const EdgeInsets.all(18), children: children);
  }

  Widget _settings() {
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
            color: navy,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(18),
            leading: const Icon(Icons.storage, color: blue),
            title: Text(
              _hasMaster ? 'Sinkron Master Data' : 'Download Master Data',
            ),
            subtitle: Text(time),
            trailing: _syncingMaster
                ? const CircularProgressIndicator()
                : const Icon(Icons.download),
            onTap: _syncingMaster ? null : _master,
          ),
        ),
        SettingsSessionSection(session: widget.sesi),
      ],
    );
  }

  Widget _empty() => Container(
    padding: const EdgeInsets.all(36),
    decoration: BoxDecoration(
      color: Colors.white,
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
        const Text(
          'Gunakan tombol Download WO di Beranda.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted),
        ),
      ],
    ),
  );
}

class C4aFindingsHome extends StatefulWidget {
  final Map<String, dynamic> sesi;
  final TemuanRepository? repository;
  const C4aFindingsHome({super.key, required this.sesi, this.repository});
  @override
  State<C4aFindingsHome> createState() => _C4aFindingsHomeState();
}

class _C4aFindingsHomeState extends State<C4aFindingsHome> {
  static const blue = Color(0xFF004D8C),
      amber = Color(0xFFFFB800),
      green = Color(0xFF16A34A),
      red = Color(0xFFDC2626),
      muted = Color(0xFF64748B);
  late final TemuanRepository repo;
  late final C4aSyncService service;
  List<TemuanInspeksi> items = const [];
  bool busy = false;
  String get token => '${widget.sesi['token'] ?? ''}';

  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? TemuanRepository();
    service = C4aSyncService(repository: repo, token: token);
    if (!RoleProvider.hasC4aAccess(widget.sesi)) return;
    _load();
    service.start(onResult: (_) => _load());
  }

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    items = await repo.daftarC4a();
    if (mounted) setState(() {});
  }

  Future<void> _sync() async {
    if (busy) return;
    setState(() => busy = true);
    final result = await repo.sinkronC4a(token);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.berhasil} terkirim, ${result.gagal} gagal.'),
        ),
      );
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _retry(TemuanInspeksi item) async {
    setState(() => busy = true);
    final ok = await repo.kirimUlangC4a(token, item.kodeTemuan);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Temuan berhasil dikirim.'
                : 'Masih gagal, data lokal tetap aman.',
          ),
        ),
      );
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _add() async {
    if (!RoleProvider.hasC4aAccess(widget.sesi)) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TemuanFormScreen.c4a(sesi: widget.sesi, repository: repo),
      ),
    );
    if (changed == true) {
      await _load();
      await service.flush(onResult: (_) => _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!RoleProvider.hasC4aAccess(widget.sesi)) {
      return const C4aAccessDeniedScreen();
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        title: const Text('Temuan C4A'),
        actions: [
          TextButton.icon(
            onPressed: busy ? null : _sync,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: const Text('Sinkron'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 180),
                  Icon(Icons.fact_check_outlined, size: 52, color: blue),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Belum ada draft C4A',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Center(
                    child: Text(
                      'Tekan + untuk mencatat temuan.',
                      style: TextStyle(color: muted),
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: items.map(_card).toList(),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        backgroundColor: amber,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _card(TemuanInspeksi item) {
    final failed = item.syncStatus == TemuanInspeksi.statusFailed;
    final synced = item.syncStatus == TemuanInspeksi.statusSynced;
    final color = failed
        ? red
        : synced
        ? green
        : amber;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                Icon(
                  synced
                      ? Icons.cloud_done
                      : failed
                      ? Icons.error_outline
                      : Icons.schedule,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 5),
                Text(
                  _statusLabel(item.syncStatus),
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _thumb(item.fotoTemuan),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.temuan,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${item.jenisObject} • ${item.penyulang} • ${item.prioritas}',
                        style: const TextStyle(color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (failed) ...[
              const SizedBox(height: 8),
              Text(
                item.syncError,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: red, fontSize: 12),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: busy ? null : () => _retry(item),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Kirim ulang'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _thumb(String path) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: path.isNotEmpty && File(path).existsSync()
        ? Image.file(File(path), width: 64, height: 64, fit: BoxFit.cover)
        : Container(
            width: 64,
            height: 64,
            color: Colors.grey.shade200,
            child: const Icon(Icons.image_not_supported_outlined),
          ),
  );
  String _statusLabel(String value) => switch (value) {
    TemuanInspeksi.statusSynced => 'Terkirim',
    TemuanInspeksi.statusFailed => 'Gagal',
    TemuanInspeksi.statusSending => 'Mengirim',
    TemuanInspeksi.statusDraft => 'Draft',
    _ => 'Antrean',
  };
}
