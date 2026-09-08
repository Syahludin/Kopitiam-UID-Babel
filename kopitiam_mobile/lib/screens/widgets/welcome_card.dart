import 'package:flutter/material.dart';
import '../../theme/kopitiam_theme.dart';

class WelcomeCard extends StatelessWidget {
  final Map<String, dynamic> sesi;
  const WelcomeCard({super.key, required this.sesi});
  @override
  Widget build(BuildContext context) {
    final username = (sesi['username'] ?? 'Pengguna').toString();
    final subTim = (sesi['subTim'] ?? sesi['tim'] ?? '-').toString();
    final ulp = (sesi['ulp'] ?? '-').toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF063B5C), Color(0xFF087797), Color(0xFFD6A93A)], stops: [0, .78, 1.25], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF32A9C2)),
        boxShadow: const [BoxShadow(color: Color(0x2A063B5C), blurRadius: 22, offset: Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Selamat datang', style: TextStyle(color: Color(0xFFC5DFE7), fontSize: 13, fontWeight: FontWeight.w600))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF0E526B), borderRadius: BorderRadius.circular(100)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, size: 8, color: KopitiamColors.yellow), SizedBox(width: 7), Text('SESI AKTIF', style: TextStyle(color: KopitiamColors.surface, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .7))])),
        ]),
        const SizedBox(height: 9),
        Text(username, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KopitiamColors.surface, fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -.35)),
        const SizedBox(height: 16), const Divider(color: Color(0xFF63B4C7)), const SizedBox(height: 12),
        _info(Icons.groups_rounded, 'Sub-Tim', subTim), const SizedBox(height: 11), _info(Icons.location_city_rounded, 'ULP', ulp),
      ]),
    );
  }
  Widget _info(IconData icon, String label, String value) => Row(children: [Icon(icon, size: 17, color: const Color(0xFFC5E4EA)), const SizedBox(width: 10), Text(label, style: const TextStyle(color: Color(0xFFD7EBEF), fontSize: 12, fontWeight: FontWeight.w600)), const SizedBox(width: 10), Expanded(child: Text(value.isEmpty ? '-' : value, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KopitiamColors.surface, fontSize: 13, fontWeight: FontWeight.w900)))]);
}
