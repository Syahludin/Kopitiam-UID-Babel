import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'work_order_start_dialog.dart';
import 'work_order_status_chip.dart';

class BrandedInspectionWorkOrderCard extends StatelessWidget {
  static const ink = Color(0xFF071F33);
  static const logoBlue = Color(0xFF004D8C);
  static const yellow = Color(0xFFF6D03F);
  static const surface = Color(0xFFFBFDFE);
  static const line = Color(0xFFDCE8EC);
  static const muted = Color(0xFF667D86);
  static const locationSurface = Color(0xFFE0F5F8);

  final String code, typeLabel, status, title, subtitle, section, date, mapUrl, locationLabel;
  final bool waiting, finished;
  final VoidCallback onStart, onOpen;

  const BrandedInspectionWorkOrderCard({super.key, required this.code, required this.typeLabel, required this.status, required this.title, required this.subtitle, required this.section, required this.date, required this.mapUrl, required this.locationLabel, required this.waiting, required this.finished, required this.onStart, required this.onOpen});

  Future<void> _openMap(BuildContext context) async {
    final uri = Uri.tryParse(mapUrl);
    if (uri == null || mapUrl.isEmpty) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google Maps tidak dapat dibuka.')));
    }
  }

  Future<void> _start(BuildContext context) async {
    final confirmed = await showWorkOrderStartDialog(
      context,
      code: code,
      module: typeLabel,
      title: title,
      detail: [subtitle, section].where((value) => value.trim().isNotEmpty).join(' • '),
    );
    if (confirmed) onStart();
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: line),
      boxShadow: const [BoxShadow(color: Color(0x18063B5C), blurRadius: 24, offset: Offset(0, 10))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _header(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: WorkOrderStatusChip(status: status, waiting: waiting, finished: finished)),
            if (mapUrl.trim().isNotEmpty) ...[
              const SizedBox(width: 12),
              _locationButton(context),
            ],
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: _details()),
            const SizedBox(width: 14),
            _primaryAction(context),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1, color: line),
          const SizedBox(height: 10),
          _dateRow(),
        ]),
      ),
    ]),
  );

  Widget _header() => Container(
    constraints: const BoxConstraints(minHeight: 72),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF176DA8), logoBlue, Color(0xFF004279)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: Row(children: [
      Expanded(child: Text(code, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: surface, fontSize: 15, fontWeight: FontWeight.w900))),
      const SizedBox(width: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(100), border: Border.all(color: const Color(0x99D6A93A))),
        child: Text(typeLabel, style: const TextStyle(color: yellow, fontSize: 10, fontWeight: FontWeight.w900)),
      ),
    ]),
  );

  Widget _locationButton(BuildContext context) => SizedBox(
    height: 44,
    child: Align(alignment: Alignment.topRight, child: Material(
      color: locationSurface,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        onTap: () => _openMap(context),
        borderRadius: BorderRadius.circular(100),
        child: SizedBox(height: 32, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.location_on_outlined, size: 15, color: logoBlue),
            const SizedBox(width: 5),
            Text(locationLabel, style: const TextStyle(color: logoBlue, fontSize: 11, fontWeight: FontWeight.w900)),
          ]),
        )),
      ),
    )),
  );

  Widget _details() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ink, fontSize: 18, height: 1.2, fontWeight: FontWeight.w900)),
    if (subtitle.trim().isNotEmpty) ...[
      const SizedBox(height: 8),
      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w800)),
    ],
    if (section.trim().isNotEmpty) ...[
      SizedBox(height: subtitle.trim().isEmpty ? 8 : 4),
      Text(section, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 11)),
    ],
  ]);

  Widget _primaryAction(BuildContext context) => SizedBox(
    height: 48,
    child: waiting
      ? ElevatedButton(
          onPressed: () => _start(context),
          style: ElevatedButton.styleFrom(elevation: 0, backgroundColor: yellow, foregroundColor: ink, padding: const EdgeInsets.symmetric(horizontal: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
          child: const Text('Mulai', style: TextStyle(fontWeight: FontWeight.w900)),
        )
      : OutlinedButton(
          onPressed: onOpen,
          style: OutlinedButton.styleFrom(foregroundColor: logoBlue, side: const BorderSide(color: logoBlue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
          child: Text(finished ? 'Lihat' : 'Lanjutkan', style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
  );

  Widget _dateRow() => Row(children: [
    const Icon(Icons.schedule_rounded, size: 15, color: muted),
    const SizedBox(width: 7),
    const Text('Tanggal WO', style: TextStyle(color: muted, fontSize: 11)),
    const SizedBox(width: 6),
    Flexible(child: Text(date.trim().isEmpty ? 'Belum tersedia' : date, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w800))),
  ]);
}
