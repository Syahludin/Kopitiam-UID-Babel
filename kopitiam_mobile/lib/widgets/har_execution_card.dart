import 'package:flutter/material.dart';

import '../models/har_execution.dart';
import 'branded_work_order_card.dart';

class HarExecutionCard extends StatelessWidget {
  final HarExecution item;
  final VoidCallback? onStart;
  final VoidCallback? onOpen;

  const HarExecutionCard({
    super.key,
    required this.item,
    this.onStart,
    this.onOpen,
  });

  String get _coordinate {
    final coordinate = item.value('Koordinat').trim();
    if (coordinate.isNotEmpty) return coordinate;
    final lat = item.value('Lat').trim();
    final long = item.value('Long').trim();
    return lat.isNotEmpty && long.isNotEmpty ? '$lat, $long' : '';
  }

  String get _section => [
        if (item.value('Section').trim().isNotEmpty) item.value('Section').trim(),
        if (item.value('Segmen').trim().isNotEmpty) item.value('Segmen').trim(),
        if (item.type == HarExecution.du &&
            item.value('Nomor Gardu').trim().isNotEmpty)
          item.value('Nomor Gardu').trim(),
      ].join(' • ');

  @override
  Widget build(BuildContext context) => BrandedWorkOrderCard(
        code: item.code,
        typeLabel: item.type == HarExecution.jar ? 'HAR JAR' : 'HAR DU',
        status: item.status.isEmpty ? 'Progress Pekerjaan' : item.status,
        finding: item.value('Temuan'),
        feeder: item.value('Penyulang'),
        section: _section,
        date: item.value('Tanggal'),
        coordinate: _coordinate,
        photos: [
          WorkOrderPhoto('Foto Temuan', item.value('Link Foto Temuan')),
          WorkOrderPhoto(
            'Foto Sekitar',
            item.value('Link Foto Tiang Sekitar').isNotEmpty
                ? item.value('Link Foto Tiang Sekitar')
                : item.value('Link Foto Sekitar'),
          ),
        ],
        waiting: item.ready,
        finished: item.finished,
        onStart: onStart ?? () {},
        onOpen: onOpen ?? () {},
      );
}
