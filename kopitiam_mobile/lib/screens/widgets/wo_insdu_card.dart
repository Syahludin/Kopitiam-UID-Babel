import 'package:flutter/material.dart';

import '../../models/wo_insdu.dart';
import '../../widgets/branded_inspection_work_order_card.dart';

class WoInsduCard extends StatelessWidget {
  final WoInsdu wo;
  final VoidCallback onStart;
  final VoidCallback onOpen;

  const WoInsduCard({
    super.key,
    required this.wo,
    required this.onStart,
    required this.onOpen,
  });

  String get _coordinate {
    if (wo.koordinatGardu.trim().isNotEmpty) return wo.koordinatGardu.trim();
    if (wo.lat.trim().isNotEmpty && wo.long.trim().isNotEmpty) {
      return '${wo.lat.trim()}, ${wo.long.trim()}';
    }
    return '';
  }

  String get _mapUrl => _coordinate.isEmpty
      ? ''
      : 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(_coordinate)}';

  @override
  Widget build(BuildContext context) {
    final status = WoInsdu.normalisasiStatus(wo.statusWo);
    return BrandedInspectionWorkOrderCard(
      code: wo.kodeWo,
      typeLabel: 'INSPEKSI GARDU',
      status: status,
      title: wo.nomorGardu.trim().isEmpty ? 'Gardu belum ditentukan' : wo.nomorGardu,
      subtitle: wo.penyulang.trim().isEmpty
          ? 'Penyulang belum tersedia'
          : wo.penyulang,
      section: [
        if (wo.section.trim().isNotEmpty) wo.section.trim(),
        if (wo.jurusan.trim().isNotEmpty) 'Jurusan ${wo.jurusan.trim()}',
      ].join(' • '),
      date: wo.tanggal,
      mapUrl: _mapUrl,
      locationLabel: 'Lokasi',
      waiting: status == WoInsdu.statusMulai,
      finished: status == WoInsdu.statusSelesai,
      onStart: onStart,
      onOpen: onOpen,
    );
  }
}
