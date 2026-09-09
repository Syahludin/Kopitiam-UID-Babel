import 'package:flutter/material.dart';

import '../../services/network_status_service.dart';
import '../../theme/kopitiam_theme.dart';

typedef NetworkProbe = Future<bool> Function();

class WelcomeCard extends StatefulWidget {
  final Map<String, dynamic> sesi;
  final NetworkProbe? networkProbe;

  const WelcomeCard({
    super.key,
    required this.sesi,
    this.networkProbe,
  });

  @override
  State<WelcomeCard> createState() => _WelcomeCardState();
}

class _WelcomeCardState extends State<WelcomeCard>
    with WidgetsBindingObserver {
  bool? _online;
  bool _checking = false;

  NetworkProbe get _probe =>
      widget.networkProbe ?? NetworkStatusService.isOnline;

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
    final providedDay = widget.sesi['Hari'] ?? widget.sesi['hari'];
    final providedDate = widget.sesi['Tanggal'] ?? widget.sesi['tanggal'];
    if (providedDay != null && providedDate != null) {
      return '${providedDay.toString()}, ${providedDate.toString()}';
    }

    final now = DateTime.now();
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final subTim =
        (widget.sesi['subTim'] ?? widget.sesi['tim'] ?? '-').toString();
    final ulp = (widget.sesi['ulp'] ?? '-').toString();
    final bidang = (widget.sesi['bidang'] ?? widget.sesi['Bidang'] ?? '-').toString();

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: KopitiamColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: KopitiamColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16063B5C),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(height: 5, color: KopitiamColors.gold),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _dateText(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: KopitiamColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Semangat Pagi,',
                            style: TextStyle(
                              color: KopitiamColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subTim,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: KopitiamColors.navy,
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _checking ? null : _checkNetwork,
                      borderRadius: BorderRadius.circular(100),
                      child: _NetworkStatusChip(online: _online),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _info(Icons.location_city_rounded, 'UNIT KERJA', ulp)),
                    const SizedBox(width: 12),
                    Expanded(child: _info(Icons.account_tree_rounded, 'BIDANG', bidang)),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: KopitiamColors.navy,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: KopitiamColors.gold,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bolt_rounded, color: KopitiamColors.navy, size: 22),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _online == true
                                  ? 'Terhubung ke server'
                                  : _online == false
                                      ? 'Mode offline aktif'
                                      : 'Memeriksa jaringan',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: KopitiamColors.surface, fontSize: 13, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _online == true
                                  ? 'Data siap diunduh dan disinkronkan'
                                  : _online == false
                                      ? 'Data lokal tetap aman di perangkat'
                                      : 'Mohon tunggu sebentar',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFFC5DFE7), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String label, String value) => Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: KopitiamColors.cyanSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17, color: KopitiamColors.ocean),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KopitiamColors.muted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .45)),
                const SizedBox(height: 3),
                Text(value.isEmpty ? '-' : value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KopitiamColors.ink, fontSize: 12, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      );
}

class _NetworkStatusChip extends StatelessWidget {
  final bool? online;
  const _NetworkStatusChip({required this.online});

  @override
  Widget build(BuildContext context) {
    final color = online == true
        ? KopitiamColors.success
        : online == false
            ? KopitiamColors.danger
            : KopitiamColors.muted;
    final label = online == true
        ? 'ONLINE'
        : online == false
            ? 'OFFLINE'
            : 'CEK...';

    return Semantics(
      label: 'Status jaringan $label. Ketuk untuk periksa ulang.',
      liveRegion: true,
      child: Container(
        key: const ValueKey('network-status-chip'),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const ValueKey('network-status-dot'),
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withValues(alpha: .22), blurRadius: 0, spreadRadius: 4)],
              ),
            ),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .55)),
          ],
        ),
      ),
    );
  }
}
