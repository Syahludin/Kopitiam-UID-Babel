import 'package:flutter/material.dart';

class WoDataCard extends StatelessWidget {
  final bool isRow;
  final bool busy;
  final int dirty;
  final double progress;
  final String progressLabel;
  final VoidCallback onDownload;
  final VoidCallback onSync;

  const WoDataCard({
    super.key,
    required this.isRow,
    required this.busy,
    required this.dirty,
    required this.progress,
    required this.progressLabel,
    required this.onDownload,
    required this.onSync,
  });

  static const navy700 = Color(0xFF004D8C);
  static const navy950 = Color(0xFF071B30);
  static const cyan500 = Color(0xFF00E5FF);
  static const neutral200 = Color(0xFFE2E8F0);
  static const neutral500 = Color(0xFF64748B);
  static const blueSoft = Color(0xFFE8F1FA);

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
                child: const Icon(Icons.cloud_sync_rounded, size: 18, color: navy700),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(isRow ? 'Data ROW Penugasan' : 'Data Work Order', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy950)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onDownload,
                    icon: const Icon(Icons.cloud_download_outlined, size: 18),
                    label: const Text('Download WO', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(foregroundColor: navy700, side: const BorderSide(color: neutral200), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : onSync,
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: FittedBox(child: Text(dirty > 0 ? 'Sinkron ($dirty)' : 'Sinkron ${isRow ? 'ROW' : 'WO'}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    style: ElevatedButton.styleFrom(backgroundColor: navy700, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                ),
              ),
            ],
          ),
          if (busy) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: neutral200),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(progressLabel, style: const TextStyle(fontSize: 11, color: neutral500)),
                Text('${(progress.clamp(0, 1) * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: navy700)),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: progress, color: cyan500, backgroundColor: neutral200),
          ],
        ],
      ),
    );
  }
}
