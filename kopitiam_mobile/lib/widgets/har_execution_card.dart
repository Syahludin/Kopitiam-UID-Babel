import 'package:flutter/material.dart';
import '../models/har_execution.dart';
import '../theme/kopitiam_theme.dart';

class HarExecutionCard extends StatelessWidget {
  final HarExecution item;
  final VoidCallback? onTap;
  const HarExecutionCard({super.key, required this.item, this.onTap});
  @override
  Widget build(BuildContext context) {
    final colors = item.finished
        ? const [Color(0xFFE1F5EC), Color(0xFFF9FDFB)]
        : item.started
            ? const [Color(0xFFDDF2F6), Color(0xFFF8FCFD)]
            : const [Color(0xFFFFF2C3), Color(0xFFFBFDFE)];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: KopitiamColors.line),
          boxShadow: const [BoxShadow(color: Color(0x13063B5C), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(item.code, style: const TextStyle(fontWeight: FontWeight.w900, color: KopitiamColors.ink))),
                  _chip(item.type == HarExecution.jar ? 'HAR JAR' : 'HAR DU', KopitiamColors.navy),
                ]),
                const SizedBox(height: 10),
                Text(item.type == HarExecution.du ? item.value('Nomor Gardu') : item.value('Penyulang'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('${item.value('Section')} • ${item.type == HarExecution.jar ? item.value('Segmen') : item.value('Penyulang')}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Text(item.value('Temuan'), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Row(children: [
                  _chip(item.status.isEmpty ? 'Siap Dikerjakan' : item.status, item.finished ? KopitiamColors.success : item.started ? KopitiamColors.ocean : KopitiamColors.warning),
                  const Spacer(),
                  Icon(item.error.isNotEmpty ? Icons.error_outline : item.dirty ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined, size: 18, color: item.error.isNotEmpty ? KopitiamColors.danger : KopitiamColors.ocean),
                  const SizedBox(width: 6),
                  Text(item.error.isNotEmpty ? 'Gagal sinkron' : item.dirty ? 'Belum sinkron' : 'Tersimpan', style: Theme.of(context).textTheme.bodySmall),
                ]),
                const Divider(height: 24),
                Row(children: [
                  Expanded(child: Text('Parent: ${item.value('Kode Temuan')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)),
                  Text(item.finished ? 'Lihat' : item.started ? 'Buka detail' : 'Mulai', style: const TextStyle(fontWeight: FontWeight.w900, color: KopitiamColors.ocean)),
                  const Icon(Icons.chevron_right_rounded, color: KopitiamColors.ocean),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(100)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .25)),
  );
}
