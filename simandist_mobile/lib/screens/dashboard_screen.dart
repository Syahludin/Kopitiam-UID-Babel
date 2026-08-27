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

  final _labels = const ['Work Order', 'Beranda', 'Pengaturan'];
  final _woRepo = WoInsjarRepository();
  late final AnimationController _bubbleController;

  int _selectedIndex = 1;
  int _previousIndex = 1;
  bool _hasLocal = false;
  bool _syncing = false;
  bool _woBusy = false;
  double _progress = 0;
  DateTime? _lastSync;
  List<WoInsjar> _woList = const [];

  @override
  void initState() {
    super.initState();
    _bubbleController = AnimationController(vsync: this, value: 1);
    _loadLocalStatus();
    _loadWo();
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    super.dispose();
  }

  String get _token => (widget.sesi['token'] ?? '').toString();

  Future<void> _loadLocalStatus() async {
    final has = await SqliteService.instance.hasMasterData();
    final last = await SqliteService.instance.lastMasterSync();
    if (!mounted) return;
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
    try {
      final hasil = await _woRepo.download(_token);
      await _loadWo();
      if (!mounted) return;
      if (hasil.pesan != null) {
        _message(hasil.pesan!, error: true);
      } else {
        await _showHasilDialog(
          judul: 'Download WO Selesai',
          jumlah: hasil.diproses,
          satuan: 'WO baru ditambahkan',
          keterangan: '${hasil.total} WO dibaca dari spreadsheet.',
          ikon: Icons.cloud_download_rounded,
        );
      }
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Bad state: ', ''), error: true);
      }
    } finally {
      if (mounted) setState(() => _woBusy = false);
    }
  }

  Future<void> _sinkronWo() async {
    if (_woBusy) return;
    if (_token.isEmpty) {
      _message('Sesi tidak valid. Silakan login ulang.', error: true);
      return;
    }
    setState(() => _woBusy = true);
    try {
      final hasil = await _woRepo.sinkron(_token);
      await _loadWo();
      if (!mounted) return;
      if (hasil.pesan != null) {
        _message(hasil.pesan!, error: true);
      } else {
        await _showHasilDialog(
          judul: 'Sinkronisasi WO Selesai',
          jumlah: hasil.diproses,
          satuan: 'WO dikirim ke spreadsheet',
          keterangan: hasil.total == 0
              ? 'Tidak ada perubahan lokal yang menunggu.'
              : '${hasil.total} WO lokal diproses.',
          ikon: Icons.cloud_upload_rounded,
        );
      }
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Bad state: ', ''), error: true);
      }
    } finally {
      if (mounted) setState(() => _woBusy = false);
    }
  }

  Future<void> _showHasilDialog({
    required String judul,
    required int jumlah,
    required String satuan,
    required String keterangan,
    required IconData ikon,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 66,
              height: 66,
              decoration: const BoxDecoration(color: green100, shape: BoxShape.circle),
              child: Icon(ikon, size: 34, color: green600),
            ),
            const SizedBox(height: 16),
            Text(judul,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: navy950)),
            const SizedBox(height: 12),
            Text('$jumlah',
                style: const TextStyle(
                    fontSize: 40, fontWeight: FontWeight.w800, color: navy700)),
            Text(satuan,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: neutral500)),
            const SizedBox(height: 10),
            Text(keterangan,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: neutral500)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: navy700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Tutup',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _syncMaster() async {
    if (_syncing) return;
    if (_token.isEmpty) {
      _message('Sesi tidak valid. Silakan login ulang.', error: true);
      return;
    }
    setState(() {
      _syncing = true;
      _progress = .12;
    });
    try {
      final result = await ApiService.getMasterData(_token);
      if (!mounted) return;
      setState(() => _progress = .6);
      if (result['success'] != true || result['datasets'] is! Map) {
        throw StateError((result['message'] ?? 'Data master tidak valid.').toString());
      }
      await SqliteService.instance
          .replaceMasterData(Map<String, dynamic>.from(result['datasets']));
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _hasLocal = true;
        _lastSync = DateTime.now();
      });
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) _message('Master data berhasil disimpan.');
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Bad state: ', ''), error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
          _progress = 0;
        });
      }
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? red600 : green600),
    );
  }

  Future<void> _bukaForm({WoInsjar? existing}) async {
    final tersimpan = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WoInsjarFormScreen(sesi: widget.sesi, existing: existing),
      ),
    );
    if (tersimpan == true) {
      await _loadWo();
      if (mounted) _message('WO tersimpan di server lokal.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: neutral100,
      appBar: AppBar(
        backgroundColor: navy700,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleSpacing: 16,
        title: Row(children: [
          SvgPicture.asset('assets/icons/logo_app.svg', width: 38, height: 38),
          const SizedBox(width: 10),
          Text(_labels[_selectedIndex],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ]),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _bukaForm(),
              backgroundColor: amber600,
              foregroundColor: navy950,
              icon: const Icon(Icons.add_rounded),
              label: const Text('WO Baru',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [_workOrders(), _home(), _settings()],
      ),
      bottomNavigationBar: _animatedNavigation(),
    );
  }

  Widget _animatedNavigation() {
    return SafeArea(
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
                  builder: (context, _) {
                    final x = centerFor(_previousIndex) +
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
                  builder: (context, _) {
                    final x = centerFor(_previousIndex) +
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
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x42004D8C),
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
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
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
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
                                  fontSize: active ? 13.5 : 11,
                                  fontWeight:
                                      active ? FontWeight.w800 : FontWeight.w500,
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
  }

  Widget _navIcon(int index, bool active) {
    final size = active ? 34.0 : 23.0;
    final color = active ? Colors.white : navy700;
    if (index == 0) {
      return Icon(Icons.assignment_outlined, size: size, color: color);
    }
    if (index == 1) {
      return Icon(Icons.home_rounded, size: size, color: color);
    }
    return SvgPicture.asset('assets/icons/pengaturan.svg', width: size, height: size);
  }

  Widget _workOrders() {
    final menungguSinkron = _woList.where((wo) => wo.isDirty).length;
    return RefreshIndicator(
      onRefresh: _loadWo,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
        children: [
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _woBusy ? null : _downloadWo,
                icon: const Icon(Icons.cloud_download_outlined, size: 18),
                label: const Text('Download WO',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: navy700,
                  side: const BorderSide(color: navy700, width: 1.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _woBusy ? null : _sinkronWo,
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: Text(
                  menungguSinkron > 0 ? 'Sinkron ($menungguSinkron)' : 'Sinkron WO',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: navy700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
          if (_woBusy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(minHeight: 6, color: cyan500),
          ],
          const SizedBox(height: 22),
          if (_woList.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: neutral200),
              ),
              child: const Column(children: [
                Icon(Icons.assignment_outlined, size: 42, color: navy700),
                SizedBox(height: 12),
                Text('Belum ada WO lokal',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 5),
                Text(
                  'Tekan Download WO untuk menarik penugasan, atau buat WO baru.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: neutral500, fontSize: 12),
                ),
              ]),
            )
          else
            ..._woList.map(_woCard),
        ],
      ),
    );
  }

  Widget _woCard(WoInsjar wo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(wo.kodeWo,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13, color: navy950)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: wo.isDirty ? const Color(0xFFFFF3CD) : green100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                wo.isDirty ? 'Menunggu sinkron' : 'Tersinkron',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: wo.isDirty ? const Color(0xFF8A6300) : green600,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text('${wo.penyulang} • ${wo.section}',
              style: const TextStyle(fontSize: 12, color: neutral500)),
          const SizedBox(height: 4),
          Text(
            '${wo.tanggal.isEmpty ? '-' : wo.tanggal} • ${wo.realisasiKms == null ? '-' : '${wo.realisasiKms!.toStringAsFixed(3)} km'} • ${wo.statusWo}',
            style: const TextStyle(fontSize: 11, color: neutral500),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: OutlinedButton(
              onPressed: () => _bukaForm(existing: wo),
              style: OutlinedButton.styleFrom(
                foregroundColor: navy700,
                side: const BorderSide(color: neutral200),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Kerjakan / Perbarui',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _home() {
    final username = (widget.sesi['username'] ?? 'Pengguna').toString();
    final role = (widget.sesi['role'] ?? 'User').toString();
    final unit = (widget.sesi['ulp'] ?? 'PLN UID Babel').toString();
    final bidang = (widget.sesi['bidang'] ?? 'Distribusi').toString();
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('Selamat datang,', style: TextStyle(color: neutral500)),
        Text(username,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, color: navy950)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [navy700, Color(0xFF006FAE)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.verified_rounded, color: green100),
                SizedBox(width: 9),
                Text('Akun Terverifikasi',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 16),
              Text(username,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800)),
              Text('$role • $bidang',
                  style: const TextStyle(color: Color(0xFFD5E8F3))),
              const Divider(color: Color(0x5588DFFF)),
              Text(unit,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settings() {
    final title = _hasLocal ? 'Sinkron Master Data' : 'Download Master Data';
    final time = _lastSync == null
        ? 'Belum sinkron'
        : 'Terakhir ${_lastSync!.hour.toString().padLeft(2, '0')}:${_lastSync!.minute.toString().padLeft(2, '0')} WIB';
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('Data & Server Lokal',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, color: navy950)),
        const SizedBox(height: 5),
        const Text('Kelola master data agar aplikasi siap digunakan saat offline.',
            style: TextStyle(color: neutral500)),
        const SizedBox(height: 22),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: neutral200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F7FC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SvgPicture.asset('assets/icons/pengaturan.svg'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: navy950)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: _hasLocal ? green100 : const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _hasLocal ? green600 : const Color(0xFF8A6300),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _syncing ? null : _syncMaster,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: amber600,
                    foregroundColor: navy950,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _syncing
                        ? (_hasLocal ? 'Sedang menyinkronkan...' : 'Sedang mengunduh...')
                        : title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (_syncing) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _hasLocal
                          ? 'Menyinkronkan master data...'
                          : 'Mengunduh master data...',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: navy700),
                    ),
                    Text('${(_progress * 100).round()}%',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: navy700)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _progress,
                  minHeight: 9,
                  borderRadius: BorderRadius.circular(20),
                  backgroundColor: neutral200,
                  color: cyan500,
                ),
              ],
            ]),
          ),
        ),
      ],
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
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const bubbleCenterY = 11.0;
    const topRadius = 40.0;
    const lowerRadius = 38.0;
    const lowerY = 14.0;
    final topDy = -bubbleCenterY;
    final topReach = math.sqrt(topRadius * topRadius - topDy * topDy);
    final lowerDy = lowerY - bubbleCenterY;
    final lowerReach = math.sqrt(lowerRadius * lowerRadius - lowerDy * lowerDy);

    final fillPath = Path()
      ..moveTo(0, 0)
      ..lineTo(notchCenterX - topReach, 0)
      ..arcToPoint(
        Offset(notchCenterX + topReach, 0),
        radius: const Radius.circular(topRadius),
        clockwise: true,
      )
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, background);

    final topStart = math.pi - math.atan2(topDy, topReach);
    final topEnd = math.atan2(topDy, topReach);
    final topLine = Path()
      ..moveTo(0, 0)
      ..lineTo(notchCenterX - topReach, 0)
      ..arcTo(
        Rect.fromCircle(
            center: Offset(notchCenterX, bubbleCenterY), radius: topRadius),
        topStart,
        (topEnd - topStart) + 2 * math.pi,
        false,
      )
      ..lineTo(size.width, 0);
    canvas.drawPath(topLine, line);

    final lowerStart = math.pi - math.atan2(lowerDy, lowerReach);
    final lowerEnd = math.atan2(lowerDy, lowerReach);
    final lowerLine = Path()
      ..moveTo(0, lowerY)
      ..lineTo(notchCenterX - lowerReach, lowerY)
      ..arcTo(
        Rect.fromCircle(
            center: Offset(notchCenterX, bubbleCenterY), radius: lowerRadius),
        lowerStart,
        lowerEnd - lowerStart,
        false,
      )
      ..lineTo(size.width, lowerY);
    canvas.drawPath(lowerLine, line);
  }

  @override
  bool shouldRepaint(covariant _BubbleNavbarPainter oldDelegate) {
    return oldDelegate.notchCenterX != notchCenterX;
  }
}
