import 'package:flutter/material.dart';

import '../../models/wo_insjar.dart';

class WoInsjarCard extends StatelessWidget {
  final WoInsjar wo;
  final VoidCallback onStart;
  final VoidCallback onOpen;

  const WoInsjarCard({super.key, required this.wo, required this.onStart, required this.onOpen});

  static const navy950 = Color(0xFF071B30);
  static const navy700 = Color(0xFF004D8C);
  static const amber600 = Color(0xFFFFB800);
  static const green600 = Color(0xFF16A34A);
  static const green100 = Color(0xFFDCFCE7);
  static const neutral500 = Color(0xFF64748B);
  static const neutral200 = Color(0xFFE2E8F0);
  static const blueCard = Color(0xFFE8F4FC);

  @override
  Widget build(BuildContext context) {
    final status = WoInsjar.normalisasiStatus(wo.statusWo);
    final canOpen = status != WoInsjar.statusMulai;
    final color = status == WoInsjar.statusSelesai ? green100 : status == WoInsjar.statusDalam ? blueCard : Colors.white;
    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status == WoInsjar.statusSelesai ? const Color(0xFF86CFA5) : status == WoInsjar.statusDalam ? const Color(0xFF8BC5E8) : neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(wo.kodeWo, style: const TextStyle(fontWeight: FontWeight.w800, color: navy950))),
            Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: status == WoInsjar.statusSelesai ? green600 : status == WoInsjar.statusDalam ? navy700 : neutral500)),
          ]),
          const SizedBox(height: 9),
          Text(wo.penyulang, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy950)),
          const SizedBox(height: 4),
          Text('${wo.tanggal} \u2022 ${wo.sectionAwal} \u2192 ${wo.sectionAkhir}', style: const TextStyle(fontSize: 12, color: neutral500)),
          const SizedBox(height: 13),
          Align(
            alignment: Alignment.centerRight,
            child: status == WoInsjar.statusMulai
                ? ElevatedButton(onPressed: onStart, style: ElevatedButton.styleFrom(backgroundColor: amber600, foregroundColor: navy950), child: const Text('Mulai Pengerjaan'))
                : OutlinedButton(onPressed: onOpen, child: const Text('Buka')),
          ),
        ],
      ),
    );
    return canOpen ? InkWell(onTap: onOpen, borderRadius: BorderRadius.circular(16), child: card) : card;
  }
}
