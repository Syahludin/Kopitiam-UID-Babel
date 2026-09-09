import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/wo_row.dart';
import 'start_work_order_dialog.dart';

class WoRowCard extends StatelessWidget {
  final WoRow row; final VoidCallback onStart; final VoidCallback onOpen;
  const WoRowCard({super.key, required this.row, required this.onStart, required this.onOpen});
  static const navy950 = Color(0xFF071B30), navy700 = Color(0xFF004D8C), amber600 = Color(0xFFFFB800), green600 = Color(0xFF16A34A), green100 = Color(0xFFDCFCE7), neutral500 = Color(0xFF64748B), neutral200 = Color(0xFFE2E8F0), blueCard = Color(0xFFE8F4FC), blueSoft = Color(0xFFE8F1FA);
  String get _coordinate { if (row.koordinat.trim().isNotEmpty) return row.koordinat.trim(); if (row.lat.trim().isNotEmpty && row.long.trim().isNotEmpty) return '${row.lat.trim()}, ${row.long.trim()}'; return ''; }
  Future<void> _bukaMaps(BuildContext context) async { if (_coordinate.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Koordinat temuan belum tersedia pada ROW ini.'), backgroundColor: Color(0xFFDC2626))); return; } await launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(_coordinate)}'), mode: LaunchMode.externalApplication); }
  @override
  Widget build(BuildContext context) {
    final status = WoRow.normalisasiStatus(row.statusWo); final canOpen = status != WoRow.statusPenugasan; final color = status == WoRow.statusSelesai ? green100 : status == WoRow.statusProgress ? blueCard : Colors.white;
    final card = Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), border: Border.all(color: status == WoRow.statusSelesai ? const Color(0xFF86CFA5) : status == WoRow.statusProgress ? const Color(0xFF8BC5E8) : neutral200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(row.kodeWo, style: const TextStyle(fontWeight: FontWeight.w800, color: navy950))), Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: status == WoRow.statusSelesai ? green600 : status == WoRow.statusProgress ? navy700 : amber600))]), const SizedBox(height: 4),
      Text(row.temuan, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: navy950)), const SizedBox(height: 4), Text('${row.kodeTemuan} • ${row.segmen}', style: const TextStyle(fontSize: 12, color: neutral500)), const SizedBox(height: 10),
      InkWell(onTap: () => _bukaMaps(context), borderRadius: BorderRadius.circular(10), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), decoration: BoxDecoration(color: blueSoft, borderRadius: BorderRadius.circular(10)), child: Row(children: [const Icon(Icons.directions_rounded, size: 17, color: navy700), const SizedBox(width: 8), Expanded(child: Text(_coordinate.isEmpty ? 'Koordinat belum tersedia' : _coordinate, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: neutral500))), const Text('Arahkan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: navy700))]))), const SizedBox(height: 13),
      Align(alignment: Alignment.centerRight, child: status == WoRow.statusPenugasan ? ElevatedButton(onPressed: () async { if (await confirmStartWorkOrder(context, code: row.kodeWo, title: 'pekerjaan ROW')) onStart(); }, style: ElevatedButton.styleFrom(backgroundColor: amber600, foregroundColor: navy950), child: const Text('Mulai Pekerjaan')) : OutlinedButton(onPressed: onOpen, child: const Text('Buka'))),
    ]));
    return canOpen ? InkWell(onTap: onOpen, borderRadius: BorderRadius.circular(16), child: card) : card;
  }
}
