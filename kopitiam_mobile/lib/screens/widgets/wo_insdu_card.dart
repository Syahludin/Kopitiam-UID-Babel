import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/wo_insdu.dart';
import 'start_work_order_dialog.dart';

class WoInsduCard extends StatelessWidget {
  final WoInsdu wo;
  final VoidCallback onStart;
  final VoidCallback onOpen;
  const WoInsduCard({super.key, required this.wo, required this.onStart, required this.onOpen});
  static const navy = Color(0xFF071B30), blue = Color(0xFF004D8C), amber = Color(0xFFFFB800), green = Color(0xFF16A34A), muted = Color(0xFF64748B), line = Color(0xFFE2E8F0);
  String get _coordinate { if (wo.koordinatGardu.trim().isNotEmpty) return wo.koordinatGardu.trim(); if (wo.lat.trim().isNotEmpty && wo.long.trim().isNotEmpty) return '${wo.lat.trim()}, ${wo.long.trim()}'; return ''; }
  Future<void> _maps(BuildContext context) async { if (_coordinate.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Koordinat Gardu belum tersedia.'))); return; } await launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(_coordinate)}'), mode: LaunchMode.externalApplication); }
  @override
  Widget build(BuildContext context) {
    final status = WoInsdu.normalisasiStatus(wo.statusWo); final waiting = status == WoInsdu.statusMulai; final done = status == WoInsdu.statusSelesai;
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: done ? const Color(0xFFECFDF5) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: done ? const Color(0xFFA7F3D0) : line)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(wo.kodeWo, style: const TextStyle(color: navy, fontWeight: FontWeight.w800))), Text(status, style: TextStyle(color: done ? green : blue, fontSize: 10, fontWeight: FontWeight.w800))]),
      const SizedBox(height: 8), Text(wo.nomorGardu.isEmpty ? 'Gardu belum ditentukan' : wo.nomorGardu, style: const TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4), Text('${wo.penyulang} • ${wo.section}', style: const TextStyle(color: muted, fontSize: 12)), const SizedBox(height: 12),
      Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => _maps(context), icon: const Icon(Icons.directions_rounded, size: 18), label: const Text('Arahkan'))), const SizedBox(width: 10), Expanded(child: waiting ? ElevatedButton(onPressed: () async { if (await confirmStartWorkOrder(context, code: wo.kodeWo, title: 'pekerjaan')) onStart(); }, style: ElevatedButton.styleFrom(backgroundColor: amber, foregroundColor: navy), child: const Text('Mulai')) : OutlinedButton(onPressed: onOpen, child: Text(done ? 'Lihat' : 'Lanjut')))]),
    ]));
  }
}
