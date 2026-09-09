import 'package:flutter/material.dart';

import '../../services/network_status_service.dart';
import '../../theme/kopitiam_theme.dart';

typedef NetworkProbe = Future<bool> Function();
typedef WoAction = Future<void> Function();

class WelcomeCard extends StatefulWidget {
  final Map<String, dynamic> sesi;
  final NetworkProbe? networkProbe;
  final int total;
  final int ready;
  final int progress;
  final int done;
  final WoAction? onDownload;
  final WoAction? onSync;

  const WelcomeCard({
    super.key,
    required this.sesi,
    this.networkProbe,
    this.total = 0,
    this.ready = 0,
    this.progress = 0,
    this.done = 0,
    this.onDownload,
    this.onSync,
  });

  @override
  State<WelcomeCard> createState() => _WelcomeCardState();
}

class _WelcomeCardState extends State<WelcomeCard> with WidgetsBindingObserver {
  bool? _online;
  bool _checking = false;

  NetworkProbe get _probe => widget.networkProbe ?? NetworkStatusService.isOnline;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNetwork();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkNetwork();
  }

  Future<void> _checkNetwork() async {
    if (_checking) return;
    _checking = true;
    try {
      final online = await _probe();
      if (mounted && online != _online) setState(() => _online = online);
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _dateText() {
    final day = widget.sesi['Hari'] ?? widget.sesi['hari'];
    final date = widget.sesi['Tanggal'] ?? widget.sesi['tanggal'];
    if (day != null && date != null) return '${day.toString()}, ${date.toString()}';
    final now = DateTime.now();
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final subTim = (widget.sesi['subTim'] ?? widget.sesi['tim'] ?? '-').toString();
    final ulp = (widget.sesi['ulp'] ?? '-').toString();
    final bidang = (widget.sesi['bidang'] ?? widget.sesi['Bidang'] ?? '-').toString();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _card(
        background: KopitiamColors.ink,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_dateText(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KopitiamColors.gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .35)),
              const SizedBox(height: 8),
              const Text('Semangat Pagi,', style: TextStyle(color: KopitiamColors.surface, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subTim, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KopitiamColors.surface, fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -.35)),
            ])),
            const SizedBox(width: 8),
            InkWell(onTap: _checking ? null : _checkNetwork, borderRadius: BorderRadius.circular(100), child: _NetworkStatusChip(online: _online)),
          ]),
          const SizedBox(height: 18),
          const Divider(color: KopitiamColors.muted, height: 1),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _info('UNIT KERJA', ulp)),
            const SizedBox(width: 18),
            Expanded(child: _info('BIDANG', bidang)),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      _card(
        background: KopitiamColors.surface,
        border: KopitiamColors.line,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('RINGKASAN WORK ORDER', style: TextStyle(color: KopitiamColors.muted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
              SizedBox(height: 4),
              Text('Penugasan aktif', style: TextStyle(color: KopitiamColors.ink, fontSize: 17, fontWeight: FontWeight.w900)),
            ]),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('0', style: TextStyle(color: KopitiamColors.ink, fontSize: 36, height: 1, fontWeight: FontWeight.w950)),
              SizedBox(width: 3),
              Padding(padding: EdgeInsets.only(bottom: 3), child: Text('WO', style: TextStyle(color: KopitiamColors.muted, fontSize: 9, fontWeight: FontWeight.w800))),
            ]),
          ]),
          const SizedBox(height: 17),
          _metrics(),
          const SizedBox(height: 17),
          Row(children: [
            Expanded(child: _ActionButton(label: 'Download WO', icon: Icons.download_rounded, primary: true, action: widget.onDownload)),
            const SizedBox(width: 10),
            Expanded(child: _ActionButton(label: 'Sinkron WO', icon: Icons.sync_rounded, action: widget.onSync)),
          ]),
          const SizedBox(height: 10),
          const Center(child: Text('Terakhir sinkron: status lokal aktif', style: TextStyle(color: KopitiamColors.muted, fontSize: 9))),
        ]),
      ),
    ]);
  }

  Widget _card({required Color background, Color? border, required Widget child}) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(22), border: border == null ? Border.all(color: KopitiamColors.navy) : Border.all(color: border), boxShadow: const [BoxShadow(color: Color(0x24071F33), blurRadius: 20, offset: Offset(0, 9))]),
    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(width: 6, color: KopitiamColors.gold),
      Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(17, 20, 18, 20), child: child)),
    ]),
  );

  Widget _info(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KopitiamColors.gold, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .45)),
    const SizedBox(height: 4),
    Text(value.isEmpty ? '-' : value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KopitiamColors.surface, fontSize: 13, fontWeight: FontWeight.w850)),
  ]);

  Widget _metrics() => Row(children: [_metric('Belum dikerjakan', widget.ready), _metric('Progress', widget.progress), _metric('Selesai', widget.done)]);

  Widget _metric(String label, int value) => Expanded(child: Column(children: [
    Text('$value', style: const TextStyle(color: KopitiamColors.ink, fontSize: 20, fontWeight: FontWeight.w900)),
    const SizedBox(height: 3),
    Text(label, textAlign: TextAlign.center, style: const TextStyle(color: KopitiamColors.muted, fontSize: 9, fontWeight: FontWeight.w700)),
  ]));
}

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final WoAction? action;
  const _ActionButton({required this.label, required this.icon, required this.primary, this.action});
  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool loading = false;
  bool success = false;

  Future<void> _run() async {
    if (loading || widget.action == null) return;
    setState(() { loading = true; success = false; });
    try {
      await widget.action!();
      if (mounted) setState(() { loading = false; success = true; });
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) setState(() => success = false);
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final background = success ? KopitiamColors.success : widget.primary ? KopitiamColors.gold : KopitiamColors.navy;
    final foreground = widget.primary && !success ? KopitiamColors.ink : KopitiamColors.surface;
    return SizedBox(
      height: 49,
      child: ElevatedButton.icon(
        onPressed: loading ? null : _run,
        icon: loading ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: foreground)) : Icon(success ? Icons.check_rounded : widget.icon, color: foreground, size: 17),
        label: Text(success ? 'Selesai' : widget.label, style: TextStyle(color: foreground, fontWeight: FontWeight.w900, fontSize: 11)),
        style: ElevatedButton.styleFrom(backgroundColor: background, disabledBackgroundColor: background.withValues(alpha: .65), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
      ),
    );
  }
}

class _NetworkStatusChip extends StatelessWidget {
  final bool? online;
  const _NetworkStatusChip({required this.online});
  @override
  Widget build(BuildContext context) {
    final color = online == true ? KopitiamColors.success : online == false ? KopitiamColors.danger : KopitiamColors.muted;
    final label = online == true ? 'ONLINE' : online == false ? 'OFFLINE' : 'CEK...';
    return Semantics(label: 'Status jaringan $label. Ketuk untuk periksa ulang.', liveRegion: true, child: Container(key: const ValueKey('network-status-chip'), padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), decoration: BoxDecoration(color: KopitiamColors.navy, borderRadius: BorderRadius.circular(100), border: Border.all(color: KopitiamColors.surface)), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(key: const ValueKey('network-status-dot'), width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 7), Text(label, style: const TextStyle(color: KopitiamColors.surface, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .55))])));
  }
}
