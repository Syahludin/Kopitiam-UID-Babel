import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/wo_har_du.dart';

class WoHarDuCard extends StatelessWidget {
  final WoHarDu wo;
  final VoidCallback onKerjakan;
  final VoidCallback onLanjut;

  const WoHarDuCard({
    super.key,
    required this.wo,
    required this.onKerjakan,
    required this.onLanjut,
  });

  static const navy = Color(0xFF071B30);
  static const blue = Color(0xFF004D8C);
  static const amber = Color(0xFFFFB800);
  static const green = Color(0xFF16A34A);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);
  static const soft = Color(0xFFE8F1FA);
  static const red = Color(0xFFDC2626);

  String get _coordinate {
    if (wo.koordinat.trim().isNotEmpty) return wo.koordinat.trim();
    if (wo.lat != null && wo.long != null) return '${wo.lat}, ${wo.long}';
    return '';
  }

  Future<void> _bukaMaps(BuildContext context) async {
    if (_coordinate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Koordinat WO Har Du belum tersedia.'),
          backgroundColor: red,
        ),
      );
      return;
    }
    await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination='
        '${Uri.encodeComponent(_coordinate)}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = WoHarDu.normalisasiStatus(wo.statusWo);
    final waiting = status == WoHarDu.statusMenunggu;
    final done = status == WoHarDu.statusSelesai;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFDCFCE7) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: done ? const Color(0xFF86CFA5) : line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  wo.kodeWo,
                  style: const TextStyle(
                    color: navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  color: done ? green : blue,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            wo.nomorGardu.isEmpty ? 'Gardu belum ditentukan' : wo.nomorGardu,
            style: const TextStyle(
              color: navy,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${wo.penyulang} • ${wo.section}',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            wo.temuan,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: navy, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _bukaMaps(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: soft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_rounded, size: 17, color: blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _coordinate.isEmpty ? 'Koordinat belum tersedia' : _coordinate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ),
                  const Text(
                    'Arahkan',
                    style: TextStyle(
                      color: blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: waiting
                ? ElevatedButton(
                    onPressed: onKerjakan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: amber,
                      foregroundColor: navy,
                    ),
                    child: const Text('Kerjakan'),
                  )
                : OutlinedButton(
                    onPressed: onLanjut,
                    child: Text(done ? 'Lihat' : 'Lanjut'),
                  ),
          ),
        ],
      ),
    );
  }
}
