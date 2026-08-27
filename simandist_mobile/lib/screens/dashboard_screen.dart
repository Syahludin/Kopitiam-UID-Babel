import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../services/sqlite_service.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> sesi;
  const DashboardScreen({super.key, required this.sesi});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const navy950 = Color(0xFF071B30), navy700 = Color(0xFF004D8C), cyan500 = Color(0xFF00E5FF), amber600 = Color(0xFFFFB800), green600 = Color(0xFF16A34A), green100 = Color(0xFFDCFCE7), neutral500 = Color(0xFF64748B), neutral100 = Color(0xFFF1F5F9), neutral200 = Color(0xFFE2E8F0), red600 = Color(0xFFDC2626);
  int _tab = 0;
  bool _hasLocal = false, _syncing = false;
  double _progress = 0;
  DateTime? _lastSync;

  @override void initState() { super.initState(); _loadLocalStatus(); }
  Future<void> _loadLocalStatus() async { final has = await SqliteService.instance.hasMasterData(); final last = await SqliteService.instance.lastMasterSync(); if (mounted) setState(() { _hasLocal = has; _lastSync = last; }); }

  Future<void> _syncMaster() async {
    if (_syncing) return;
    final token = (widget.sesi['token'] ?? '').toString();
    if (token.isEmpty) { _message('Sesi tidak valid. Silakan login ulang.', error: true); return; }
    setState(() { _syncing = true; _progress = .12; });
    try {
      final result = await ApiService.getMasterData(token);
      if (!mounted) return;
      setState(() => _progress = .6);
      if (result['success'] != true || result['datasets'] is! Map) throw StateError((result['message'] ?? 'Data master tidak valid.').toString());
      await SqliteService.instance.replaceMasterData(Map<String, dynamic>.from(result['datasets']));
      if (!mounted) return;
      setState(() { _progress = 1; _hasLocal = true; _lastSync = DateTime.now(); });
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) _message('Master data berhasil disimpan.');
    } catch (e) { if (mounted) _message(e.toString().replaceFirst('Bad state: ', ''), error: true); }
    finally { if (mounted) setState(() { _syncing = false; _progress = 0; }); }
  }

  void _message(String text, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? red600 : green600));

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: neutral100,
      appBar: AppBar(backgroundColor: navy700, foregroundColor: Colors.white, title: Text(_tab == 0 ? 'SiManDist' : 'Pengaturan', style: const TextStyle(fontWeight: FontWeight.w800))),
      body: _tab == 0 ? _home() : _settings(),
      bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (value) => setState(() => _tab = value), destinations: [const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Beranda'), NavigationDestination(icon: SvgPicture.asset('assets/icons/pengaturan.svg', width: 24, height: 24), selectedIcon: SvgPicture.asset('assets/icons/pengaturan.svg', width: 28, height: 28), label: 'Pengaturan')]),
    );
  }

  Widget _home() {
    final username = (widget.sesi['username'] ?? 'Pengguna').toString(), role = (widget.sesi['role'] ?? 'User').toString(), unit = (widget.sesi['ulp'] ?? 'PLN UID Babel').toString(), bidang = (widget.sesi['bidang'] ?? 'Distribusi').toString();
    return ListView(padding: const EdgeInsets.all(18), children: [Text('Selamat datang,', style: const TextStyle(color: neutral500)), Text(username, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: navy950)), const SizedBox(height: 18), Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(colors: [navy700, Color(0xFF006FAE)]), borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.verified_rounded, color: green100), SizedBox(width: 9), Text('Akun Terverifikasi', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))]), const SizedBox(height: 16), Text(username, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)), Text('$role • $bidang', style: const TextStyle(color: Color(0xFFD5E8F3))), const Divider(color: Color(0x5588DFFF)), Text(unit, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))])), const SizedBox(height: 20), const Text('Menu Utama', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy700)), _menu(Icons.assignment_outlined, 'WO Saya', 'Pekerjaan inspeksi dan eksekusi'), _menu(Icons.sync_rounded, 'Sinkronisasi', 'Kirim dan tarik data pekerjaan')]);
  }

  Widget _settings() {
    final title = _hasLocal ? 'Sinkron Master Data' : 'Download Master Data';
    final time = _lastSync == null ? 'Belum sinkron' : 'Terakhir ${_lastSync!.hour.toString().padLeft(2,'0')}:${_lastSync!.minute.toString().padLeft(2,'0')} WIB';
    return ListView(padding: const EdgeInsets.all(18), children: [const Text('Data & Server Lokal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: navy950)), const SizedBox(height: 5), const Text('Kelola master data agar aplikasi siap digunakan saat offline.', style: TextStyle(color: neutral500)), const SizedBox(height: 22), Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: neutral200)), child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [Row(children: [Container(width: 48, height: 48, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFE0F7FC), borderRadius: BorderRadius.circular(14)), child: SvgPicture.asset('assets/icons/pengaturan.svg')), const SizedBox(width: 12), Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: navy950))), Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: _hasLocal ? green100 : const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(20)), child: Text(time, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _hasLocal ? green600 : const Color(0xFF8A6300))))]), const SizedBox(height: 18), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _syncing ? null : _syncMaster, style: ElevatedButton.styleFrom(backgroundColor: amber600, foregroundColor: navy950, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text(_syncing ? (_hasLocal ? 'Sedang menyinkronkan...' : 'Sedang mengunduh...') : title, style: const TextStyle(fontWeight: FontWeight.w800)))), if (_syncing) ...[const SizedBox(height: 16), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_hasLocal ? 'Menyinkronkan master data...' : 'Mengunduh master data...', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: navy700)), Text('${(_progress * 100).round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: navy700))]), const SizedBox(height: 8), LinearProgressIndicator(value: _progress, minHeight: 9, borderRadius: BorderRadius.circular(20), backgroundColor: neutral200, color: cyan500)] ]))),]);
  }

  Widget _menu(IconData icon, String title, String subtitle) => Card(elevation: 0, margin: const EdgeInsets.only(top: 10), child: ListTile(leading: Icon(icon, color: navy700), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right_rounded)));
}
