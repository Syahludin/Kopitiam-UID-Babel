import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/wo_insjar.dart';
import '../services/api_service.dart';
import '../services/sqlite_service.dart';
import '../services/wo_insjar_repository.dart';
import 'wo_insjar_form_screen.dart';

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
  static const amber600 = Color(0xFFFFB800);
  static const green600 = Color(0xFF16A34A);
  static const green100 = Color(0xFFDCFCE7);
  static const neutral500 = Color(0xFF64748B);
  static const neutral100 = Color(0xFFF1F5F9);
  static const neutral200 = Color(0xFFE2E8F0);
  static const red600 = Color(0xFFDC2626);
  static const blueCard = Color(0xFFE8F4FC);

  final _labels = const ['Work Order', 'Beranda', 'Pengaturan'];
  final _woRepo = WoInsjarRepository();
  late final AnimationController _bubbleController;

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

  String get _token => (widget.sesi['token'] ?? '').toString();
  int _percent(double value) => (value.clamp(0, 1) * 100).round();

  @override
  void initState() {
    super.initState();
    _bubbleController = AnimationController(vsync: this, value: 1);
    _loadLocalStatus();
    _loadWo();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _bubbleController.dispose();
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
    final list = await _woRepo.semua();
    if (mounted) setState(() => _woList = list);
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
    _startProgress(master: false, label: 'Mengunduh WO');
    try {
      final hasil = await _woRepo.download(_token);
      await _loadWo();
      await _completeProgress(master: false);
      if (!mounted) return;
      if (hasil.pesan != null) {
        _message(hasil.pesan!, error: true);
      } else {
        await _resultDialog(
          title: 'Download WO Selesai',
          count: hasil.diproses,
          label: 'WO baru Sudah ditambahkan',
          note: '${hasil.total} Total WO.',
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
    _startProgress(master: false, label: 'Menyinkronkan WO');
    try {
      final hasil = await _woRepo.sinkron(_token);
      await _loadWo();
      await _completeProgress(master: false);
      if (!mounted) return;
      if (hasil.pesan != null) {
        _message(hasil.pesan!, error: true);
      } else {
        await _resultDialog(
          title: 'Sinkronisasi WO Selesai',
          count: hasil.diproses,
          label: 'WO Sudah diSinkronkan',
          note: hasil.total == 0
              ? 'Tidak ada Yang Perlu diSinkronkan.'
              : '${hasil.total} WO Sedang di Kerjakan.',
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
      if (mounted) _message('Master data berhasil disimpan.');
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    } finally {
      _progressTimer?.cancel();
      if (mounted)
        setState(() {
          _syncing = false;
          _progress = 0;
        });
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? red600 : green600),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: neutral100,
    appBar: AppBar(
      backgroundColor: navy700,
      foregroundColor: Colors.white,
      title: Row(
        children: [
          SvgPicture.asset('assets/icons/logo_app.svg', width: 38, height: 38),
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
    final dirty = _woList.where((wo) => wo.isDirty).length;
    final username = (widget.sesi['username'] ?? 'Pengguna').toString();
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('Selamat datang,', style: TextStyle(color: neutral500)),
        Text(
          username,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: navy950,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Data Work Order',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: navy700,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: neutral200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _woBusy ? null : _downloadWo,
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: const Text('Download WO'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _woBusy ? null : _syncWo,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: Text(
                          dirty > 0 ? 'Sinkron ($dirty)' : 'Sinkron WO',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: navy700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_woBusy) ...[
                  const SizedBox(height: 14),
                  _progressView(_woProgress, _woProgressLabel),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _workOrders() => RefreshIndicator(
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
                    SvgPicture.asset(
                      'assets/icons/pengaturan.svg',
                      width: 44,
                      height: 44,
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
