import 'package:flutter/material.dart';

import '../../models/wo_insjar.dart';
import '../../widgets/branded_inspection_work_order_card.dart';

class WoInsjarCard extends StatelessWidget {
  final WoInsjar wo;
  final VoidCallback onStart;
  final VoidCallback onOpen;

  const WoInsjarCard({
    super.key,
    required this.wo,
    required this.onStart,
    required this.onOpen,
  });

  String get _mapUrl {
    final start = wo.koordinatAwal.trim();
    final end = wo.koordinatAkhir.trim();
    if (start.isEmpty && end.isEmpty) return '';
    if (start.isEmpty || end.isEmpty) {
      final destination = start.isNotEmpty ? start : end;
      return 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}';
    }
    return 'https://www.google.com/maps/dir/?api=1&origin=${Uri.encodeComponent(start)}&destination=${Uri.encodeComponent(end)}';
  }

  String get _section {
    if (wo.section.trim().isNotEmpty) return wo.section.trim();
    return [wo.sectionAwal.trim(), wo.sectionAkhir.trim()]
        .where((value) => value.isNotEmpty)
        .join(' → ');
  }

  @override
  Widget build(BuildContext context) {
    final status = WoInsjar.normalisasiStatus(wo.statusWo);
    return BrandedInspectionWorkOrderCard(
      code: wo.kodeWo,
      typeLabel: 'INSPEKSI JARINGAN',
      status: status,
      title: wo.penyulang.trim().isEmpty
          ? 'Penyulang belum tersedia'
          : wo.penyulang,
      subtitle: '',
      section: _section,
      date: wo.tanggal,
      mapUrl: _mapUrl,
      locationLabel: 'Rute',
      waiting: status == WoInsjar.statusMulai,
      finished: status == WoInsjar.statusSelesai,
      onStart: onStart,
      onOpen: onOpen,
    );
  }
}
