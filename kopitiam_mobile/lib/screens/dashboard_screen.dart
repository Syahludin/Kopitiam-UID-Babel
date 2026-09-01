import 'dart:async';
import 'dart:math' as math;

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

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
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
<<<<<<< HEAD
  final _harJarRepo = WoHarJarRepository();
  late final AnimationController _bubbleController;
=======
>>>>>>> a1ffec0c6f32f93e9b06474d08e566d13e247def
  late final AnimationController _masterSpin;

  int _selectedIndex = 1;
  bool _hasLocal = false;
  bool _syncing = false;
  double _progress = 0;
  Timer? _progressTimer;
  DateTime? _lastSync;
  List<WoInsjar> _woList = const [];
  List<WoRow> _rowList = const [];
  List<WoHarJar> _harJarList = const [];

  String get _token => (widget.sesi['token'] ?? '').toString();
<<<<<<< HEAD

  String get _subTimLower =>
      '${widget.sesi['subTim'] ?? widget.sesi['tim'] ?? ''}'.toLowerCase();

  bool get _harJarTeam =>
      _subTimLower.contains('har jar') || _subTimLower.contains('harjar');

  bool get _rowTeam => !_harJarTeam && _subTimLower.contains('row');

  String get _teamLabel =>
      _harJarTeam ? 'Har Jar' : (_rowTeam ? 'ROW' : 'WO');
  int _percent(double value) => (value.clamp(0, 1) * 100).round();
=======
  bool get _rowTeam {
    final sub = '${widget.sesi['subTim'] ?? widget.sesi['tim'] ?? ''}'.toLowerCase();
    return sub.contains('row');
  }
  String get _rowLabel => _rowTeam ? 'ROW' : 'WO';
>>>>>>> a1ffec0c6f32f93e9b06474d08e566d13e247def

  @override
  void initState() {
    super.initState();
    _masterSpin = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _loadLocalStatus();
    _loadWo();
  }

  @override
  void dispose() { _progressTimer?.cancel(); _masterSpin.dispose(); super.dispose(); }

  Future<void> _loadLocalStatus() async {
    final has = await SqliteService.instance.hasMasterData();
    final last = await SqliteService.instance.lastMasterSync();
    if (mounted) setState(() { _hasLocal = has; _lastSync = last; });
  }

  Future<void> _loadWo() async {
    if (_harJarTeam) {
      final list = await _harJarRepo.semua();
      if (mounted) setState(() => _harJarList = list);
    } else if (_rowTeam) {
      final list = await _rowRepo.semua();
      if (mounted) setState(() => _rowList = list);
    } else {
      final list = await _woRepo.semua();
      if (mounted) setState(() => _woList = list);
    }
  }

  Future<void> _downloadWo() async {
<<<<<<< HEAD
    if (_woBusy) return;
    if (_token.isEmpty) {
      _message('Sesi tidak valid. Silakan login ulang.', error: true);
      return;
    }
    setState(() => _woBusy = true);
    _startProgress(
      master: false,
      label: 'Mengunduh $_teamLabel',
    );
    try {
      final hasil = _harJarTeam
          ? await _harJarRepo.download(_token)
          : _rowTeam
              ? await _rowRepo.download(_token)
              : await _woRepo.download(_token);
      await _loadWo();
      await _completeProgress(master: false);
      if (!mounted) return;
      if (hasil.pesan != null) {
        _message(hasil.pesan!, error: true);
      } else {
        await _resultDialog(
          title: 'Download $_teamLabel Selesai',
          count: hasil.diproses,
          label: '$_teamLabel baru sudah ditambahkan',
          note: '${hasil.total} Total $_teamLabel.',
          icon: Icons.cloud_download_rounded,
        );
      }
    } catch (error) {
      if (mounted)
        _message(error.toString().replaceFirst('Bad state: ', ''), error: true);
    } finally {
      _progressTimer?.cancel();
      if (mounted)
        setState(() {
          _woBusy = false;
          _woProgress = 0;
          _woProgressLabel = '';
        });
=======
    if (_token.isEmpty) return;
    final hasil = _rowTeam ? await _rowRepo.download(_token) : await _woRepo.download(_token);
    await _loadWo();
    if (!mounted) return;
    if (hasil.pesan != null) { _message(hasil.pesan!, error: true); } else {
      await _resultDialog(title: 'Download $_rowLabel Selesai', count: hasil.diproses, label: '$_rowLabel baru ditambahkan', note: '${hasil.total} Total $_rowLabel.', icon: Icons.cloud_download_rounded);
>>>>>>> a1ffec0c6f32f93e9b06474d08e566d13e247def
    }
  }

  Future<void> _syncWo() async {
<<<<<<< HEAD
    if (_woBusy) return;
    setState(() => _woBusy = true);
    _startProgress(
      master: false,
      label: 'Menyinkronkan $_teamLabel',
    );
    try {
      final hasil = _harJarTeam
          ? await _harJarRepo.sinkron(_token)
          : _rowTeam
              ? await _rowRepo.sinkron(_token)
              : await _woRepo.sinkron(_token);
      await _loadWo();
      await _completeProgress(master: false);
      if (!mounted) return;
      if (hasil.pesan != null) {
        _message(hasil.pesan!, error: true);
      } else {
        await _resultDialog(
          title: 'Sinkronisasi $_teamLabel Selesai',
          count: hasil.diproses,
          label: '$_teamLabel sudah disinkronkan',
          note: hasil.total == 0
              ? 'Tidak ada yang perlu disinkronkan.'
              : '${hasil.total} $_teamLabel sedang dikerjakan.',
          icon: Icons.cloud_upload_rounded,
        );
      }
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    } finally {
      _progressTimer?.cancel();
      if (mounted)
        setState(() {
          _woBusy = false;
          _woProgress = 0;
          _woProgressLabel = '';
        });
=======
    final hasil = _rowTeam ? await _rowRepo.sinkron(_token) : await _woRepo.sinkron(_token);
    await _loadWo();
    if (!mounted) return;
    if (hasil.pesan != null) { _message(hasil.pesan!, error: true); } else {
      await _resultDialog(title: 'Sinkronisasi $_rowLabel Selesai', count: hasil.diproses, label: '$_rowLabel diSinkronkan', note: hasil.total == 0 ? 'Tidak ada yang perlu disinkronkan.' : '${hasil.total} $_rowLabel.', icon: Icons.cloud_upload_rounded);
>>>>>>> a1ffec0c6f32f93e9b06474d08e566d13e247def
    }
  }

  Future<void> _syncMaster() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    _masterSpin.repeat();
    _progress = .05;
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (!mounted) return;
      setState(() => _progress = math.min(.90, _progress + .04));
    });
    try {
      final result = await ApiService.getMasterData(_token);
      if (result['success'] != true || result['datasets'] is! Map) throw StateError((result['message'] ?? 'Data master tidak valid.').toString());
      if (mounted) setState(() => _progress = math.max(_progress, .75));
      await SqliteService.instance.replaceMasterData(Map<String, dynamic>.from(result['datasets']));
      if (!mounted) return;
      _progressTimer?.cancel();
      setState(() { _hasLocal = true; _lastSync = DateTime.now(); _progress = 1; });
      await Future<void>.delayed(const Duration(milliseconds: 350));
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
        Text(label, textAlign: TextAlign.center), const SizedBox(height: 8),
        Text(note, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: neutral500)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup'))],
    ),
  );

  Future<void> _startWo(WoInsjar wo) async { await _woRepo.mulaiPengerjaan(wo.kodeWo); await _loadWo(); }
  Future<void> _openWo(WoInsjar wo) async { final c = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => WoInsjarFormScreen(sesi: widget.sesi, existing: wo))); if (c == true) await _loadWo(); }
  Future<void> _startRow(WoRow row) async { await _rowRepo.mulaiPekerjaan(row.kodeWo); await _loadWo(); }
  Future<void> _openRow(WoRow row) async { final c = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => WoRowFormScreen(sesi: widget.sesi, existing: row))); if (c == true) await _loadWo(); }

  void _message(String text, {bool error = false}) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? red600 : green600, behavior: SnackBarBehavior.floating, margin: EdgeInsets.only(left: 16, right: 16, bottom: bottom + 90), duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bgLight,
    appBar: AppBar(
      backgroundColor: navy700, foregroundColor: Colors.white,
      title: Row(children: [
        SvgPicture.asset('assets/icons/${_selectedIndex == 0 ? 'work_order' : _selectedIndex == 1 ? 'beranda' : 'pengaturan'}.svg', width: 26, height: 26, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
        const SizedBox(width: 10), Text(_labels[_selectedIndex], style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
    ),
    body: IndexedStack(index: _selectedIndex, children: [_workOrders(), _home(), _settings()]),
    bottomNavigationBar: BubbleNavbar(selectedIndex: _selectedIndex, onTap: (i) => setState(() => _selectedIndex = i)),
  );

  Widget _home() {
    if (_harJarTeam) {
      final total = _harJarList.length;
      final menunggu = _harJarList
          .where(
            (wo) =>
                WoHarJar.normalisasiStatus(wo.statusWo) ==
                WoHarJar.statusMenunggu,
          )
          .length;
      final sedang = _harJarList
          .where(
            (wo) =>
                WoHarJar.normalisasiStatus(wo.statusWo) ==
                WoHarJar.statusSedang,
          )
          .length;
      final selesai = _harJarList
          .where(
            (wo) =>
                WoHarJar.normalisasiStatus(wo.statusWo) ==
                WoHarJar.statusSelesai,
          )
          .length;
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        children: [
          _welcomeCard(),
          const SizedBox(height: 16),
          _woDataCard(),
          const SizedBox(height: 16),
          _harJarSummaryCard(total, menunggu, sedang, selesai),
        ],
      );
    }

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
        WoDataCard(isRow: isRow, dirty: dirty, onDownload: _downloadWo, onSync: _syncWo),
        const SizedBox(height: 16),
        isRow ? WoSummaryCard.row(total: total, penugasan: menunggu, progress: sedang, selesai: selesai) : WoSummaryCard.insjar(total: total, menunggu: menunggu, sedang: sedang, selesai: selesai),
      ],
    );
  }

<<<<<<< HEAD
  Widget _welcomeCard() {
    final username = (widget.sesi['username'] ?? 'Pengguna').toString();
    final subTim = (widget.sesi['subTim'] ?? widget.sesi['tim'] ?? '-')
        .toString();
    final ulp = (widget.sesi['ulp'] ?? '-').toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: navy700,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: navy950.withValues(alpha: .10)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14004D8C),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Selamat datang,',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: .75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: green400),
                    SizedBox(width: 6),
                    Text(
                      'Sesi Aktif',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: .16)),
          const SizedBox(height: 16),
          _welcomeInfo(Icons.groups_rounded, 'Sub-Tim', subTim),
          const SizedBox(height: 12),
          _welcomeInfo(Icons.location_city_rounded, 'ULP', ulp),
        ],
      ),
    );
  }

  Widget _welcomeInfo(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 16, color: Colors.white.withValues(alpha: .70)),
      const SizedBox(width: 10),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: .70),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value.isEmpty ? '-' : value,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    ],
  );

  Widget _woDataCard() {
    final dirty = _harJarTeam
        ? _harJarList
            .where(
              (wo) =>
                  !wo.isSynced &&
                  WoHarJar.normalisasiStatus(wo.statusWo) ==
                      WoHarJar.statusSelesai,
            )
            .length
        : _rowTeam
            ? _rowList.where((row) => row.isDirty).length
            : _woList.where((wo) => wo.isDirty).length;
    final dataTitle = _harJarTeam
        ? 'Data WO Har Jar'
        : (_rowTeam ? 'Data ROW Penugasan' : 'Data Work Order');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: blueSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.cloud_sync_rounded,
                  size: 18,
                  color: navy700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  dataTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: navy950,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _woBusy ? null : _downloadWo,
                    icon: const Icon(Icons.cloud_download_outlined, size: 18),
                    label: const Text(
                      'Download WO',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: navy700,
                      side: const BorderSide(color: neutral200),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _woBusy ? null : _syncWo,
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: FittedBox(
                      child: Text(
                        dirty > 0
                            ? 'Sinkron ($dirty)'
                            : 'Sinkron $_teamLabel',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navy700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_woBusy) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: neutral200),
            const SizedBox(height: 14),
            _progressView(_woProgress, _woProgressLabel),
          ],
        ],
      ),
    );
  }

  Widget _woSummaryCard(int total, int menunggu, int sedang, int selesai) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: blueSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    size: 18,
                    color: navy700,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Ringkasan Work Order',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: navy950,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: neutral200),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total WO',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: neutral500,
                    ),
                  ),
                ),
                Text(
                  '$total',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: navy700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: neutral200),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _statItem('Menunggu Dikerjakan', menunggu, amber600),
                ),
                _statDivider(),
                Expanded(child: _statItem('Sedang Dikerjakan', sedang, cyan600)),
                _statDivider(),
                Expanded(child: _statItem('Selesai', selesai, green600)),
              ],
            ),
          ],
        ),
      );

  Widget _statDivider() => Container(
    width: 1,
    height: 44,
    color: neutral200,
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );

  Widget _statItem(String label, int value, Color color) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      FittedBox(
        child: Text(
          '$value',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: neutral500,
        ),
      ),
    ],
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: neutral200),
    boxShadow: const [
      BoxShadow(
        color: Color(0x0A0F172A),
        blurRadius: 10,
        offset: Offset(0, 2),
      ),
    ],
  );

  Widget _workOrders() {
    if (_harJarTeam) return _harJarWorkOrders();
    if (_rowTeam) return _rowWorkOrders();
    return RefreshIndicator(
      onRefresh: _loadWo,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (_woList.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: neutral200),
              ),
              child: const Column(
                children: [
                  Icon(Icons.assignment_outlined, size: 42, color: navy700),
                  SizedBox(height: 12),
                  Text(
                    'Belum ada WO yang di Download',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Gunakan Download WO pada menu Beranda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: neutral500),
                  ),
                ],
              ),
            )
          else
            ..._woList.map(_woCard),
        ],
      ),
    );
=======
  Widget _workOrders() {
    if (_rowTeam) return RefreshIndicator(onRefresh: _loadWo, child: ListView(padding: const EdgeInsets.all(18), children: _rowList.isEmpty ? [_emptyState('Belum ada ROW yang di Download')] : _rowList.map((r) => WoRowCard(row: r, onStart: () => _startRow(r), onOpen: () => _openRow(r))).toList()));
    return RefreshIndicator(onRefresh: _loadWo, child: ListView(padding: const EdgeInsets.all(18), children: _woList.isEmpty ? [_emptyState('Belum ada WO yang di Download')] : _woList.map((w) => WoInsjarCard(wo: w, onStart: () => _startWo(w), onOpen: () => _openWo(w))).toList()));
>>>>>>> a1ffec0c6f32f93e9b06474d08e566d13e247def
  }

  Widget _emptyState(String text) => Container(
    padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 22),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: neutral200)),
    child: Column(children: [const Icon(Icons.assignment_outlined, size: 42, color: navy700), const SizedBox(height: 12), Text(text, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 5), const Text('Gunakan Download WO pada menu Beranda.', textAlign: TextAlign.center, style: TextStyle(color: neutral500))]),
  );

<<<<<<< HEAD
  Future<void> _startRow(WoRow row) async {
    await _rowRepo.mulaiPekerjaan(row.kodeWo);
    await _loadWo();
  }

  Future<void> _openHarJar(WoHarJar wo, {bool mulai = false}) async {
    if (mulai &&
        WoHarJar.normalisasiStatus(wo.statusWo) == WoHarJar.statusMenunggu) {
      await _harJarRepo.mulaiPekerjaan(wo.kodeWo);
      await _loadWo();
      final refreshed = await _harJarRepo.cari(wo.kodeWo);
      if (refreshed != null) wo = refreshed;
    }
    if (!mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FormTindakLanjutHarJarScreen(
          sesi: widget.sesi,
          existing: wo,
        ),
      ),
    );
    if (changed == true) await _loadWo();
  }

  Widget _harJarWorkOrders() => RefreshIndicator(
        onRefresh: _loadWo,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (_harJarList.isEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 34, horizontal: 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: neutral200),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.engineering_rounded, size: 42, color: navy700),
                    SizedBox(height: 12),
                    Text(
                      'Belum ada WO Har Jar yang diunduh',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Gunakan Download WO pada menu Beranda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: neutral500),
                    ),
                  ],
                ),
              )
            else
              ..._harJarList.map(
                (wo) => WoHarJarCard(
                  wo: wo,
                  onKerjakan: () => _openHarJar(wo, mulai: true),
                  onLanjut: () => _openHarJar(wo, mulai: true),
                ),
              ),
          ],
        ),
      );

  Widget _harJarSummaryCard(
    int total,
    int menunggu,
    int sedang,
    int selesai,
  ) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: blueSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    size: 18,
                    color: navy700,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Ringkasan WO Har Jar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: navy950,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: neutral200),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total WO',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: neutral500,
                    ),
                  ),
                ),
                Text(
                  '$total',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: navy700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: neutral200),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _statItem('Menunggu', menunggu, amber600)),
                _statDivider(),
                Expanded(
                  child: _statItem('Sedang Dikerjakan', sedang, cyan600),
                ),
                _statDivider(),
                Expanded(child: _statItem('Selesai', selesai, green600)),
              ],
            ),
          ],
        ),
      );

  Future<void> _openRow(WoRow row) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WoRowFormScreen(sesi: widget.sesi, existing: row),
      ),
    );
    if (changed == true) await _loadWo();
  }

  void _bukaMapsRow(WoRow row) {
    final clean = row.koordinat.trim();
    if (clean.isEmpty) {
      _message('Koordinat temuan belum tersedia pada ROW ini.', error: true);
      return;
    }
    launchUrl(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination='
        '${Uri.encodeComponent(clean)}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  Widget _woRowCard(WoRow row) {
    final status = WoRow.normalisasiStatus(row.statusWo);
    final canOpen = status != WoRow.statusPenugasan;
    final color = status == WoRow.statusSelesai
        ? green100
        : status == WoRow.statusProgress
        ? blueCard
        : Colors.white;
    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == WoRow.statusSelesai
              ? const Color(0xFF86CFA5)
              : status == WoRow.statusProgress
              ? const Color(0xFF8BC5E8)
              : neutral200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.kodeWo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: navy950,
                  ),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: status == WoRow.statusSelesai
                      ? green600
                      : status == WoRow.statusProgress
                      ? navy700
                      : amber600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            row.temuan,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: navy950,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${row.kodeTemuan} • ${row.segmen}',
            style: const TextStyle(fontSize: 12, color: neutral500),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  row.koordinat,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: neutral500),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _bukaMapsRow(row),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: blueSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_rounded, size: 14, color: navy700),
                      SizedBox(width: 4),
                      Text(
                        'Arahkan',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: navy700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Align(
            alignment: Alignment.centerRight,
            child: status == WoRow.statusPenugasan
                ? ElevatedButton(
                    onPressed: () => _startRow(row),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: amber600,
                      foregroundColor: navy950,
                    ),
                    child: const Text('Mulai Pekerjaan'),
                  )
                : OutlinedButton(
                    onPressed: () => _openRow(row),
                    child: const Text('Buka'),
                  ),
          ),
        ],
      ),
    );
    return canOpen
        ? InkWell(
            onTap: () => _openRow(row),
            borderRadius: BorderRadius.circular(16),
            child: card,
          )
        : card;
  }

  Widget _rowSummaryCard(int total, int penugasan, int progress, int selesai) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: blueSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    size: 18,
                    color: navy700,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Ringkasan ROW Eksekusi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: navy950,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: neutral200),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total ROW',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: neutral500,
                    ),
                  ),
                ),
                Text(
                  '$total',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: navy700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: neutral200),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _statItem('Penugasan Tim', penugasan, amber600),
                ),
                _statDivider(),
                Expanded(
                  child: _statItem('Progress Pekerjaan', progress, cyan600),
                ),
                _statDivider(),
                Expanded(child: _statItem('Selesai', selesai, green600)),
              ],
            ),
          ],
        ),
      );

  Widget _woCard(WoInsjar wo) {
    final status = WoInsjar.normalisasiStatus(wo.statusWo);
    final canOpen = status != WoInsjar.statusMulai;
    final color = status == WoInsjar.statusSelesai
        ? green100
        : status == WoInsjar.statusDalam
        ? blueCard
        : Colors.white;
    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == WoInsjar.statusSelesai
              ? const Color(0xFF86CFA5)
              : status == WoInsjar.statusDalam
              ? const Color(0xFF8BC5E8)
              : neutral200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  wo.kodeWo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: navy950,
                  ),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: status == WoInsjar.statusSelesai
                      ? green600
                      : status == WoInsjar.statusDalam
                      ? navy700
                      : neutral500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            wo.penyulang,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: navy950,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${wo.tanggal} • ${wo.sectionAwal} → ${wo.sectionAkhir}',
            style: const TextStyle(fontSize: 12, color: neutral500),
          ),
          const SizedBox(height: 13),
          Align(
            alignment: Alignment.centerRight,
            child: status == WoInsjar.statusMulai
                ? ElevatedButton(
                    onPressed: () => _startWo(wo),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: amber600,
                      foregroundColor: navy950,
                    ),
                    child: const Text('Mulai Pengerjaan'),
                  )
                : OutlinedButton(
                    onPressed: () => _openWo(wo),
                    child: const Text('Buka'),
                  ),
          ),
        ],
      ),
    );
    return canOpen
        ? InkWell(
            onTap: () => _openWo(wo),
            borderRadius: BorderRadius.circular(16),
            child: card,
          )
        : card;
  }

=======
>>>>>>> a1ffec0c6f32f93e9b06474d08e566d13e247def
  Widget _settings() {
    final title = _hasLocal ? 'Sinkron Master Data' : 'Download Master Data';
    final time = _lastSync == null ? 'Belum sinkron' : 'Terakhir ${_lastSync!.hour.toString().padLeft(2, '0')}:${_lastSync!.minute.toString().padLeft(2, '0')} WIB';
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Data & Server Lokal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: navy950)),
      const SizedBox(height: 5), const Text('Download Master Data Agar siap digunakan saat offline.', style: TextStyle(color: neutral500)),
      const SizedBox(height: 22),
      Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: neutral200)), child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
        Row(children: [RotationTransition(turns: _masterSpin, child: SvgPicture.asset('assets/icons/pengaturan.svg', width: 44, height: 44)), const SizedBox(width: 12), Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))), Text(time, style: const TextStyle(fontSize: 10, color: neutral500))]),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _syncing ? null : _syncMaster, style: ElevatedButton.styleFrom(backgroundColor: amber600, foregroundColor: navy950), child: Text(_syncing ? 'Memproses...' : title))),
        if (_syncing) ...[
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Proses master data', style: TextStyle(fontSize: 11, color: neutral500)), Text('${(_progress.clamp(0, 1) * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: navy700))]),
          const SizedBox(height: 6), LinearProgressIndicator(value: _progress, color: cyan500, backgroundColor: neutral200),
        ],
      ]))),
      SettingsSessionSection(session: widget.sesi),
    ]);
  }
}
