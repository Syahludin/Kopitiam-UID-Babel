import 'package:flutter/material.dart';

import '../../theme/kopitiam_theme.dart';

class WoSummaryCard extends StatelessWidget {
  final String title;
  final String totalLabel;
  final int total;
  final List<StatEntry> stats;

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
          StatEntry('Belum dikerjakan', menunggu, KopitiamColors.warning),
          StatEntry('Progress', sedang, KopitiamColors.ocean),
          StatEntry('Selesai', selesai, KopitiamColors.success),
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
          StatEntry('Belum dikerjakan', penugasan, KopitiamColors.warning),
          StatEntry('Progress', progress, KopitiamColors.ocean),
          StatEntry('Selesai', selesai, KopitiamColors.success),
        ],
      );

  int get completed => stats
      .where((entry) => entry.label == 'Selesai')
      .fold(0, (sum, entry) => sum + entry.value);

  double get completion => total <= 0 ? 0 : (completed / total).clamp(0, 1);

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('wo-summary-card'),
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: KopitiamColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: KopitiamColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x17071F33),
              blurRadius: 22,
              offset: Offset(0, 9),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 24,
              child: Container(
                width: 6,
                height: 78,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [KopitiamColors.yellow, KopitiamColors.gold],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(8),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: KopitiamColors.cyanSoft,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.assignment_turned_in_rounded,
                          color: Color(0xFF004D8C),
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: KopitiamColors.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _CompletionRing(
                        total: total,
                        label: totalLabel,
                        completion: completion,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          children: [
                            for (var index = 0;
                                index < stats.length;
                                index++) ...[
                              _legend(stats[index]),
                              if (index < stats.length - 1)
                                const SizedBox(height: 13),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _legend(StatEntry entry) => Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: entry.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              entry.label,
              style: const TextStyle(
                color: KopitiamColors.muted,
                fontSize: 11,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            key: ValueKey('${entry.label}-${entry.value}'),
            tween: Tween(begin: 0, end: entry.value.toDouble()),
            duration: const Duration(milliseconds: 520),
            curve: const Cubic(0.16, 1, 0.3, 1),
            builder: (_, value, __) => Text(
              '${value.round()}',
              style: TextStyle(
                color: entry.color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      );
}

class _CompletionRing extends StatelessWidget {
  final int total;
  final String label;
  final double completion;

  const _CompletionRing({
    required this.total,
    required this.label,
    required this.completion,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (completion * 100).round();
    return SizedBox(
      width: 112,
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey('completion-$total-$percentage'),
            tween: Tween(begin: 0, end: completion),
            duration: const Duration(milliseconds: 900),
            curve: const Cubic(0.16, 1, 0.3, 1),
            builder: (_, value, __) => SizedBox.square(
              dimension: 112,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.square(
                    dimension: 104,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      backgroundColor: KopitiamColors.line,
                      color: KopitiamColors.success,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$total',
                        style: const TextStyle(
                          color: KopitiamColors.ink,
                          fontSize: 30,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: KopitiamColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: KopitiamColors.successSoft,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: KopitiamColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$percentage% selesai',
                  style: const TextStyle(
                    color: KopitiamColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatEntry {
  final String label;
  final int value;
  final Color color;
  const StatEntry(this.label, this.value, this.color);
}
