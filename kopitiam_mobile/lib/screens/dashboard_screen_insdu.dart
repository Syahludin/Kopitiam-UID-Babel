import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/wo_insdu.dart';
import '../services/api_service.dart';
import '../services/sqlite_service.dart';
import '../services/wo_insdu_repository.dart';
import 'settings_session_section.dart';
import 'widgets/bubble_navbar.dart';
import 'widgets/welcome_card.dart';
import 'widgets/wo_data_card.dart';
import 'widgets/wo_insdu_card.dart';
import 'widgets/wo_summary_card.dart';
import 'wo_insdu_form_screen.dart';

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
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);
  static const background = Color(0xFFEDF4FA);

  final _repo = WoInsduRepository();
  late final AnimationController _masterSpin;
  List<WoInsdu> _items = const [];
  int _selected = 1;
  bool _syncingMaster = false;
  bool _hasMaster = false;
  DateTime? _lastSync;

  String get _token => '${widget.sesi['token'] ?? ''}';

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
    final data = await _repo.semua();
    if (mounted) setState(() => _items = data);
  }

  Future<void> _loadMasterState() async {
    final has = await SqliteService.instance.hasMasterData();
    final last = await SqliteService.instance.lastMasterSync();
    if (mounted) setState(() { _hasMaster = has; _lastSync = last; });
  }

  Future<void> _download() async {
    final result = await _repo.download(_token);
    await _load();
    if (!mounted) return;
    _message(
      result.pesan ?? '${result.diproses} WO Inspeksi Gardu berhasil diunduh.',
      error: result.pesan != null,
    );
  }

  Future<void> _sync() async {
    final result = await _repo.sinkron(_token);
    await _load();
    if (!mounted) return;
    _message(
      result.pesan ?? '${result.diproses} WO Inspeksi Gardu berhasil disinkronkan.',
      error: result.pesan != null,
    );
  }

  Future<void> _open(WoInsdu item, {bool start = false}) async {
    var current = item;
    if (start) {
      await _repo.mulaiPekerjaan(item.kodeWo);
      current = await _repo.cari(item.kodeWo) ?? item;
    }
    if (!mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WoInsduFormScreen(
          existing: current,
          sesi: widget.sesi,
        ),
      ),
    );
    if (changed == true || start) await _load();
  }

  Future<void> _master() async {
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
      await _loadMasterState();
      if (mounted) _message('Master data berhasil disimpan.');
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

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? red : green,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                'assets/icons/${_selected == 0 ? 'work_order' : _selected == 1 ? 'beranda' : 'pengaturan'}.svg',
                width: 26,
                height: 26,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
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

  Widget _workOrders() => RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: _items.isEmpty
              ? [_empty('Belum ada WO Inspeksi Gardu yang diunduh')]
              : _items
                  .map(
                    (item) => WoInsduCard(
                      wo: item,
                      onStart: () => _open(item, start: true),
                      onOpen: () => _open(item),
                    ),
                  )
                  .toList(),
        ),
      );

  Widget _home() {
    final waiting = _items.where((w) => WoInsdu.normalisasiStatus(w.statusWo) == WoInsdu.statusMulai).length;
    final progress = _items.where((w) => WoInsdu.normalisasiStatus(w.statusWo) == WoInsdu.statusDalam).length;
    final done = _items.where((w) => WoInsdu.normalisasiStatus(w.statusWo) == WoInsdu.statusSelesai).length;
    final dirty = _items.where((w) => w.isDirty).length;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        WelcomeCard(sesi: widget.sesi),
        const SizedBox(height: 16),
        WoDataCard(
          isRow: false,
          dirty: dirty,
          onDownload: _download,
          onSync: _sync,
        ),
        const SizedBox(height: 16),
        WoSummaryCard.insjar(
          total: _items.length,
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
        const SizedBox(height: 20),
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

  Widget _empty(String text) => Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: line),
        ),
        child: Column(
          children: [
            const Icon(Icons.electrical_services_rounded, size: 46, color: blue),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
