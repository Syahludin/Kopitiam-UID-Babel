import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  final Map<String, dynamic> sesi;

  const DashboardScreen({super.key, required this.sesi});

  static const navy950 = Color(0xFF071B30);
  static const navy700 = Color(0xFF004D8C);
  static const cyan500 = Color(0xFF00E5FF);
  static const green600 = Color(0xFF16A34A);
  static const green100 = Color(0xFFDCFCE7);
  static const neutral500 = Color(0xFF64748B);
  static const neutral100 = Color(0xFFF1F5F9);
  static const neutral200 = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final username = (sesi['username'] ?? 'Pengguna').toString();
    final role = (sesi['role'] ?? 'User').toString();
    final unit = (sesi['ulp'] ?? sesi['unit'] ?? 'PLN UID Babel').toString();
    final bidang = (sesi['bidang'] ?? 'Distribusi').toString();

    return Scaffold(
      backgroundColor: neutral100,
      appBar: AppBar(
        backgroundColor: navy700,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('SiManDist', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Pengaturan',
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('Selamat datang,', style: TextStyle(color: neutral500, fontSize: 14)),
          const SizedBox(height: 3),
          Text(username, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: navy950)),
          const SizedBox(height: 18),
          _verifiedAccountCard(username: username, role: role, unit: unit, bidang: bidang),
          const SizedBox(height: 18),
          const Text('Menu Utama', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy700)),
          const SizedBox(height: 10),
          _menuCard(Icons.groups_outlined, 'Tim Operasional', 'Kelola aktivitas dan pekerjaan tim'),
          _menuCard(Icons.electrical_services_outlined, 'Data Distribusi', 'Akses data jaringan dan gardu'),
          _menuCard(Icons.assessment_outlined, 'Laporan', 'Pantau laporan kegiatan distribusi'),
        ],
      ),
    );
  }

  Widget _verifiedAccountCard({required String username, required String role, required String unit, required String bidang}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [navy700, Color(0xFF006FAE)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: navy700.withValues(alpha: .24), blurRadius: 14, offset: const Offset(0, 7))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), shape: BoxShape.circle), child: const Icon(Icons.person_outline, color: Colors.white, size: 25)),
            const SizedBox(width: 12),
            const Text('Akun Terverifikasi', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          ]),
          Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: green100, shape: BoxShape.circle), child: const Icon(Icons.verified_rounded, color: green600, size: 22)),
        ]),
        const SizedBox(height: 18),
        Text(username, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('$role • $bidang', style: TextStyle(color: Colors.white.withValues(alpha: .82), fontSize: 13)),
        const SizedBox(height: 14),
        Container(height: 1, color: Colors.white.withValues(alpha: .18)),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.business_outlined, color: cyan500, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(unit, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.lock_outline, color: cyan500, size: 17),
          const SizedBox(width: 8),
          Text('Sesi perangkat aktif', style: TextStyle(color: Colors.white.withValues(alpha: .82), fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _menuCard(IconData icon, String title, String subtitle) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: neutral200)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: navy700.withValues(alpha: .1), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: navy700)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: navy950)),
          subtitle: Text(subtitle, style: const TextStyle(color: neutral500, fontSize: 12)),
          trailing: const Icon(Icons.chevron_right_rounded, color: neutral500),
        ),
      );
}
