import 'package:flutter/material.dart';
import '../models/har_execution.dart';
import '../theme/kopitiam_theme.dart';

class HarExecutionCard extends StatelessWidget {
  final HarExecution item;
  final VoidCallback? onTap;
  const HarExecutionCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = item.error.isNotEmpty
        ? KopitiamColors.danger
        : item.finished
            ? KopitiamColors.success
            : item.started
                ? KopitiamColors.ocean
                : KopitiamColors.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: KopitiamColors.ink,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: KopitiamColors.navy),
          boxShadow: const [BoxShadow(color: Color(0x26071F33), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 6, decoration: const BoxDecoration(color: KopitiamColors.yellow, borderRadius: BorderRadius.horizontal(left: Radius.circular(18)))),
              Expanded(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(item.code, style: const TextStyle(fontWeight: FontWeight.w900, color: KopitiamColors.surface))),
                    _chip(item.type == HarExecution.jar ? 'HAR JAR' : 'HAR DU', KopitiamColors.gold),
                  ]),
                  const SizedBox(height: 10),
                  Text(item.type == HarExecution.du ? item.value('Nomor Gardu') : item.value('Penyulang'), style: const TextStyle(color: KopitiamColors.surface, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('${item.value('Section')} • ${item.type == HarExecution.jar ? item.value('Segmen') : item.value('Penyulang')}', style: const TextStyle(color: KopitiamColors.surface, fontSize: 12, height: 1.4)),
                  const SizedBox(height: 8),
                  Text(item.value('Temuan'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KopitiamColors.surface, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _chip(item.status.isEmpty ? 'Siap Dikerjakan' : item.status, statusColor),
                    const Spacer(),
                    Icon(item.error.isNotEmpty ? Icons.error_outline : item.dirty ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined, size: 18, color: KopitiamColors.gold),
                    const SizedBox(width: 6),
                    Text(item.error.isNotEmpty ? 'Gagal sinkron' : item.dirty ? 'Belum sinkron' : 'Tersimpan', style: const TextStyle(color: KopitiamColors.surface, fontSize: 12)),
                  ]),
                  const Divider(color: KopitiamColors.muted, height: 24),
                  Row(children: [
                    Expanded(child: Text('Parent: ${item.value('Kode Temuan')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KopitiamColors.surface, fontSize: 12))),
                    Text(item.finished ? 'Lihat' : item.started ? 'Buka detail' : 'Mulai', style: const TextStyle(fontWeight: FontWeight.w900, color: KopitiamColors.gold)),
                    const Icon(Icons.chevron_right_rounded, color: KopitiamColors.gold),
                  ]),
                ]),
              )),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: .18), borderRadius: BorderRadius.circular(100), border: Border.all(color: color.withValues(alpha: .65))),
    child: Text(text, style: TextStyle(color: color == KopitiamColors.gold ? KopitiamColors.surface : color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .25)),
  );
}
