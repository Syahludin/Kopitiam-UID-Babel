import 'package:flutter/material.dart';

import '../../theme/kopitiam_theme.dart';

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

  factory WoSummaryCard.insjar({
    required int total,
    required int menunggu,
    required int sedang,
    required int selesai,
  }) =>
      WoSummaryCard(
        title: 'Ringkasan Work Order',
        totalLabel: 'Total WO',
        total: total,
        stats: [
          _StatEntry('Belum dikerjakan', menunggu, KopitiamColors.warning),
          _StatEntry('Progress', sedang, KopitiamColors.ocean),
          _StatEntry('Selesai', selesai, KopitiamColors.success),
        ],
      );

  factory WoSummaryCard.row({
    required int total,
    required int penugasan,
    required int progress,
    required int selesai,
  }) =>
      WoSummaryCard(
        title: 'Ringkasan ROW',
        totalLabel: 'Total ROW',
        total: total,
        stats: [
          _StatEntry('Belum dikerjakan', penugasan, KopitiamColors.warning),
          _StatEntry('Progress', progress, KopitiamColors.ocean),
          _StatEntry('Selesai', selesai, KopitiamColors.success),
        ],
      );

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(
          color: KopitiamColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: KopitiamColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10071F33),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: KopitiamColors.cyanSoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in_rounded,
                    color: KopitiamColors.ocean,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: KopitiamColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    totalLabel,
                    style: const TextStyle(
                      color: KopitiamColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$total',
                  style: const TextStyle(
                    color: KopitiamColors.ink,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 44,
                      color: KopitiamColors.line,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                    ),
                  Expanded(child: _item(stats[i])),
                ],
              ],
            ),
          ],
        ),
      );

  Widget _item(_StatEntry entry) => Column(
        children: [
          Text(
            '${entry.value}',
            style: TextStyle(
              color: entry.color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            entry.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              color: KopitiamColors.muted,
              fontSize: 11,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _StatEntry {
  final String label;
  final int value;
  final Color color;
  const _StatEntry(this.label, this.value, this.color);
}
