import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static const navy950 = Color(0xFF071B30);
  static const navy700 = Color(0xFF004D8C);
  static const cyan500 = Color(0xFF00E5FF);
  static const cyan600 = Color(0xFF0891B2);
  static const amber600 = Color(0xFFFFB800);
  static const green600 = Color(0xFF16A34A);
  static const green400 = Color(0xFF4ADE80);
  static const green100 = Color(0xFFDCFCE7);
  static const neutral500 = Color(0xFF64748B);
  static const neutral200 = Color(0xFFE2E8F0);
  static const red600 = Color(0xFFDC2626);
  static const blueCard = Color(0xFFE8F4FC);
  static const blueSoft = Color(0xFFE8F1FA);
  static const bgLight = Color(0xFFEDF4FA);

  final _labels = const ['Work Order', 'Beranda', 'Pengaturan'];
  final _woRepo = WoInsjarRepository();
  final _rowRepo = WoRowRepository();
  final _harJarRepo = WoHarJarRepository();
  late final AnimationController _bubbleController;
  late final AnimationController _masterSpin;

  int _selectedIndex = 1;
  int _previousIndex = 1;
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
  List<WoHarJar> _harJarList = const [];

  String get _token => (widget.sesi['token'] ?? '').toString();

  String get _subTimLower =>
      '${widget.sesi['subTim'] ?? widget.sesi['tim'] ?? ''}'.toLowerCase();

  bool get _harJarTeam =>
      _subTimLower.contains('har jar') || _subTimLower.contains('harjar');

  bool get _rowTeam => !_harJarTeam && _subTimLower.contains('row');

  String get _teamLabel =>
      _harJarTeam ? 'Har Jar' : (_rowTeam ? 'ROW' : 'WO');
  int _percent(double value) => (value.clamp(0, 1) * 100).round();

  @override
  void initState() {
    super.initState();
    _bubbleController = AnimationController(vsync: this, value: 1);
    _masterSpin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadLocalStatus();
    _loadWo();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _bubbleController.dispose();
    _masterSpin.dispose();
    super.dispose();
  }

  void _startProgress({required bool master, required String label}) {
    _progressTimer?.cancel();
    setState(() {
      if (master) {
        _progress = .05;
      } else {
        _woProgress = .05;
        _woProgressLabel = label;
      }
    });
    _progressTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (!mounted) return;
      setState(() {
        if (master) {
          _progress = math.min(.90, _progress + .04);
        } else {
          _woProgress = math.min(.90, _woProgress + .04);
        }
      });
    });
  }

  Future<void> _completeProgress({required bool master}) async {
    _progressTimer?.cancel();
    if (!mounted) return;
    setState(() {
      if (master) {
        _progress = 1;
      } else {
        _woProgress = 1;
      }
    });
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Future<void> _loadLocalStatus() async {
    final has = await SqliteService.instance.hasMasterData();
    final last = await SqliteService.instance.lastMasterSync();
    if (mounted)
      setState(() {
        _hasLocal = has;
        _lastSync = last;
      });
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

  void _selectMenu(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = index;
    });
    _bubbleController.reset();
    _bubbleController.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 210, damping: 27),
        0,
        1,
        0,
      ),
    );
  }

  Future<void> _downloadWo() async {
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
    }
  }

  Future<void> _syncWo() async {
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
    }
  }

  Future<void> _syncMaster() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    _masterSpin.repeat();
    _startProgress(master: true, label: '');
    try {
      final result = await ApiService.getMasterData(_token);
      if (result['success'] != true || result['datasets'] is! Map) {
        throw StateError(
          (result['message'] ?? 'Data master tidak valid.').toString(),
        );
      }
      if (mounted) setState(() => _progress = math.max(_progress, .75));
      await SqliteService.instance.replaceMasterData(
        Map<String, dynamic>.from(result['datasets']),
      );
      if (!mounted) return;
      setState(() {
        _hasLocal = true;
        _lastSync = DateTime.now();
      });
      await _completeProgress(master: true);
      if (mounted) {
        await _showSuccessOverlay(
          title: 'Master Data Berhasil Disimpan',
          message: 'Data master siap digunakan saat offline.',
        );
      }
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    } finally {
      _progressTimer?.cancel();
      if (mounted) {
        _masterSpin.stop();
        _masterSpin.value = 0;
        setState(() {
          _syncing = false;
          _progress = 0;
        });
      }
    }
  }

  Future<void> _resultDialog({
    required String title,
    required int count,
    required String label,
    required String note,
    required IconData icon,
  }) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      icon: Icon(icon, color: green600, size: 40),
      title: Text(title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: navy700,
            ),
          ),
          Text(label, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            note,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: neutral500),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    ),
  );

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

  void _message(String text, {bool error = false}) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? red600 : green600,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(left: 16, right: 16, bottom: bottom + 90),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showSuccessOverlay({
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x8C071B30),
      builder: (_) => _SuccessOverlay(title: title, message: message),
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
          _menuTopIcon(_selectedIndex),
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
    bottomNavigationBar: _animatedNavigation(),
  );

  Widget _progressView(double value, String label) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: neutral500)),
          Text(
            '${_percent(value)}%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: navy700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      LinearProgressIndicator(
        value: value,
        color: cyan500,
        backgroundColor: neutral200,
      ),
    ],
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
    final menunggu = isRow
        ? _rowList
            .where(
              (wo) =>
                  WoRow.normalisasiStatus(wo.statusWo) ==
                  WoRow.statusPenugasan,
            )
            .length
        : _woList
            .where(
              (wo) =>
                  WoInsjar.normalisasiStatus(wo.statusWo) ==
                  WoInsjar.statusMulai,
            )
            .length;
    final sedang = isRow
        ? _rowList
            .where(
              (wo) =>
                  WoRow.normalisasiStatus(wo.statusWo) ==
                  WoRow.statusProgress,
            )
            .length
        : _woList
            .where(
              (wo) =>
                  WoInsjar.normalisasiStatus(wo.statusWo) ==
                  WoInsjar.statusDalam,
            )
            .length;
    final selesai = isRow
        ? _rowList
            .where(
              (wo) =>
                  WoRow.normalisasiStatus(wo.statusWo) ==
                  WoRow.statusSelesai,
            )
            .length
        : _woList
            .where(
              (wo) =>
                  WoInsjar.normalisasiStatus(wo.statusWo) ==
                  WoInsjar.statusSelesai,
            )
            .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        _welcomeCard(),
        const SizedBox(height: 16),
        _woDataCard(),
        const SizedBox(height: 16),
        isRow
            ? _rowSummaryCard(total, menunggu, sedang, selesai)
            : _woSummaryCard(total, menunggu, sedang, selesai),
      ],
    );
  }

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
  }

  Widget _rowWorkOrders() => RefreshIndicator(
    onRefresh: _loadWo,
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        if (_rowList.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: neutral200),
            ),
            child: const Column(
              children: [
                Icon(Icons.task_alt_rounded, size: 42, color: navy700),
                SizedBox(height: 12),
                Text(
                  'Belum ada ROW yang di Download',
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
          ..._rowList.map(_woRowCard),
      ],
    ),
  );

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

  Widget _settings() {
    final title = _hasLocal ? 'Sinkron Master Data' : 'Download Master Data';
    final time = _lastSync == null
        ? 'Belum sinkron'
        : 'Terakhir ${_lastSync!.hour.toString().padLeft(2, '0')}:${_lastSync!.minute.toString().padLeft(2, '0')} WIB';
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
          'Download Master Data Agar siap digunakan saat offline.',
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
                      style: const TextStyle(fontSize: 10, color: neutral500),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _syncing ? null : _syncMaster,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: amber600,
                      foregroundColor: navy950,
                    ),
                    child: Text(_syncing ? 'Memproses...' : title),
                  ),
                ),
                if (_syncing) ...[
                  const SizedBox(height: 14),
                  _progressView(_progress, 'Proses master data'),
                ],
              ],
            ),
          ),
        ),
        SettingsSessionSection(session: widget.sesi),
      ],
    );
  }

  Widget _animatedNavigation() => SafeArea(
    top: false,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final tabWidth = width / _labels.length;
        double centerFor(int index) => tabWidth * index + tabWidth / 2;
        return SizedBox(
          height: 82,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: _bubbleController,
                builder: (_, __) {
                  final x =
                      centerFor(_previousIndex) +
                      (centerFor(_selectedIndex) - centerFor(_previousIndex)) *
                          _bubbleController.value;
                  return CustomPaint(
                    size: Size(width, 82),
                    painter: _BubbleNavbarPainter(notchCenterX: x),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _bubbleController,
                builder: (_, __) {
                  final x =
                      centerFor(_previousIndex) +
                      (centerFor(_selectedIndex) - centerFor(_previousIndex)) *
                          _bubbleController.value;
                  return Positioned(
                    left: x - 29,
                    top: -18,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: navy700,
                        border: Border.all(color: cyan500, width: 2),
                      ),
                      child: Center(child: _navIcon(_selectedIndex, true)),
                    ),
                  );
                },
              ),
              Positioned.fill(
                child: Row(
                  children: List.generate(_labels.length, (index) {
                    final active = index == _selectedIndex;
                    return Expanded(
                      child: InkWell(
                        onTap: () => _selectMenu(index),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Opacity(
                              opacity: active ? 0 : 1,
                              child: _navIcon(index, false),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _labels[index],
                              style: TextStyle(
                                fontWeight: active
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: active ? navy700 : neutral500,
                              ),
                            ),
                            const SizedBox(height: 9),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _navIcon(int index, bool active) {
    final size = active ? 34.0 : 23.0;
    final color = active ? Colors.white : navy700;
    if (index == 0)
      return Icon(Icons.assignment_outlined, size: size, color: color);
    if (index == 1) return Icon(Icons.home_rounded, size: size, color: color);
    return SvgPicture.asset(
      'assets/icons/pengaturan.svg',
      width: size,
      height: size,
    );
  }

  Widget _menuTopIcon(int index) {
    final file = index == 0
        ? 'work_order.svg'
        : index == 1
            ? 'beranda.svg'
            : 'pengaturan.svg';
    return SvgPicture.asset(
      'assets/icons/$file',
      width: 26,
      height: 26,
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );
  }
}

class _BubbleNavbarPainter extends CustomPainter {
  final double notchCenterX;
  const _BubbleNavbarPainter({required this.notchCenterX});

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = Colors.white;
    final line = Paint()
      ..color = _DashboardScreenState.navy700
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const centerY = 11.0;
    const radius = 40.0;
    final reach = math.sqrt(radius * radius - centerY * centerY);
    final fill = Path()
      ..moveTo(0, 0)
      ..lineTo(notchCenterX - reach, 0)
      ..arcToPoint(
        Offset(notchCenterX + reach, 0),
        radius: const Radius.circular(radius),
        clockwise: true,
      )
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, background);
    final outline = Path()
      ..moveTo(0, 0)
      ..lineTo(notchCenterX - reach, 0)
      ..arcToPoint(
        Offset(notchCenterX + reach, 0),
        radius: const Radius.circular(radius),
        clockwise: true,
      )
      ..lineTo(size.width, 0);
    canvas.drawPath(outline, line);
  }

  @override
  bool shouldRepaint(covariant _BubbleNavbarPainter oldDelegate) =>
      oldDelegate.notchCenterX != notchCenterX;
}

class _SuccessOverlay extends StatefulWidget {
  final String title;
  final String message;

  const _SuccessOverlay({required this.title, required this.message});

  @override
  State<_SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<_SuccessOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..forward();
  late final Animation<double> _scale = CurvedAnimation(
    parent: _intro,
    curve: Curves.elasticOut,
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: .45,
  ).animate(_pulse);

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => Navigator.of(context).pop(),
    child: Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _scale,
                  child: FadeTransition(
                    opacity: _opacity,
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF16A34A), Color(0xFF4ADE80)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x3D16A34A),
                            blurRadius: 18,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 52,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF071B30),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 14,
                        color: Color(0xFF16A34A),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Ketuk untuk menutup',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
