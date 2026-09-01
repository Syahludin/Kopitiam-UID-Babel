import 'package:flutter/material.dart';

import '../models/wo_har_jar.dart';

class WoHarJarCard extends StatelessWidget {
  static const navy950 = Color(0xFF071B30);
  static const navy700 = Color(0xFF004D8C);
  static const amber600 = Color(0xFFFFB800);
  static const green600 = Color(0xFF16A34A);
  static const green100 = Color(0xFFDCFCE7);
  static const neutral500 = Color(0xFF64748B);
  static const neutral200 = Color(0xFFE2E8F0);
  static const blueCard = Color(0xFFE8F4FC);
  static const red600 = Color(0xFFDC2626);

  final WoHarJar wo;
  final VoidCallback onKerjakan;
  final VoidCallback onLanjut;

  const WoHarJarCard({
    super.key,
    required this.wo,
    required this.onKerjakan,
    required this.onLanjut,
  });

  @override
  Widget build(BuildContext context) {
    final status = WoHarJar.normalisasiStatus(wo.statusWo);
    final isMenunggu = status == WoHarJar.statusMenunggu;
    final isSedang = status == WoHarJar.statusSedang;
    final isSelesai = status == WoHarJar.statusSelesai;
    final color = isSelesai
        ? green100
        : isSedang
            ? blueCard
            : Colors.white;
    final borderColor = isSelesai
        ? const Color(0xFF86CFA5)
        : isSedang
            ? const Color(0xFF8BC5E8)
            : neutral200;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _prioritasBadge(wo.prioritas),
              const SizedBox(width: 6),
              _pekerjaanBadge(wo.pekerjaan),
              const Spacer(),
              Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelesai
                      ? green600
                      : isSedang
                          ? navy700
                          : amber600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            wo.kodeWo,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: navy950,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            wo.penyulang,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: navy950,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${wo.section} • ${wo.segmen}',
            style: const TextStyle(fontSize: 12, color: neutral500),
          ),
          const SizedBox(height: 4),
          Text(
            wo.temuan,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: navy950,
            ),
          ),
          const SizedBox(height: 13),
          Align(
            alignment: Alignment.centerRight,
            child: isMenunggu
                ? ElevatedButton(
                    onPressed: onKerjakan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: amber600,
                      foregroundColor: navy950,
                    ),
                    child: const Text('Kerjakan'),
                  )
                : OutlinedButton(
                    onPressed: onLanjut,
                    child: Text(isSelesai ? 'Lihat' : 'Lanjut'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _prioritasBadge(String prioritas) {
    final lower = prioritas.toLowerCase();
    final isTinggi = lower.contains('tinggi') || lower.contains('1');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isTinggi ? red600.withValues(alpha: .12) : amber600.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        prioritas.isEmpty ? 'Prioritas' : prioritas,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isTinggi ? red600 : const Color(0xFFB45309),
        ),
      ),
    );
  }

  Widget _pekerjaanBadge(String pekerjaan) {
    final padam = pekerjaan.toLowerCase().contains('padam') &&
        !pekerjaan.toLowerCase().contains('tanpa');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: padam ? red600.withValues(alpha: .10) : navy700.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        pekerjaan.isEmpty ? 'Pekerjaan' : pekerjaan,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: padam ? red600 : navy700,
        ),
      ),
    );
  }
}
