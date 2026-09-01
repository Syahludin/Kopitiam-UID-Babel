import 'package:flutter/material.dart';

class WoSummaryCard extends StatelessWidget {
  final String title;
  final String totalLabel;
  final int total;
  final List<_StatEntry> stats;

  const WoSummaryCard({
    super.key,
    required this.title,
    required this.totalLabel,
    required this.total,
    required this.stats,
  });

  static const navy700 = Color(0xFF004D8C);
  static const navy950 = Color(0xFF071B30);
  static const neutral200 = Color(0xFFE2E8F0);
  static const neutral500 = Color(0xFF64748B);
  static const blueSoft = Color(0xFFE8F1FA);

  factory WoSummaryCard.insjar({required int total, required int menunggu, required int sedang, required int selesai}) {
    return WoSummaryCard(
      title: 'Ringkasan Work Order',
      totalLabel: 'Total WO',
      total: total,
      stats: [
        _StatEntry('Menunggu Dikerjakan', menunggu, const Color(0xFFFFB800)),
        _StatEntry('Sedang Dikerjakan', sedang, const Color(0xFF0891B2)),
        _StatEntry('Selesai', selesai, const Color(0xFF16A34A)),
      ],
    );
  }

  factory WoSummaryCard.row({required int total, required int penugasan, required int progress, required int selesai}) {
    return WoSummaryCard(
      title: 'Ringkasan ROW Eksekusi',
      totalLabel: 'Total ROW',
      total: total,
      stats: [
        _StatEntry('Penugasan Tim', penugasan, const Color(0xFFFFB800)),
        _StatEntry('Progress Pekerjaan', progress, const Color(0xFF0891B2)),
        _StatEntry('Selesai', selesai, const Color(0xFF16A34A)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: neutral200),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: blueSoft, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.insights_rounded, size: 18, color: navy700),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy950))),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: neutral200),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Text(totalLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: neutral500))),
              Text('$total', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: navy700)),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: neutral200),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) Container(width: 1, height: 44, color: neutral200, margin: const EdgeInsets.symmetric(horizontal: 4)),
                Expanded(child: _item(stats[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _item(_StatEntry entry) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      FittedBox(child: Text('${entry.value}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: entry.color))),
      const SizedBox(height: 6),
      Text(entry.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, height: 1.3, fontWeight: FontWeight.w600, color: neutral500)),
    ],
  );
}

class _StatEntry {
  final String label;
  final int value;
  final Color color;
  const _StatEntry(this.label, this.value, this.color);
}
