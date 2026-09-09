import 'package:flutter/material.dart';

import '../../models/har_execution.dart';
import '../../models/wo_insdu.dart';
import '../../models/wo_insjar.dart';
import '../../models/wo_row.dart';
import '../../services/network_status_service.dart';
import '../../services/wo_insdu_repository.dart';
import '../../services/wo_insjar_repository.dart';
import '../../services/wo_row_repository.dart';
import '../../theme/kopitiam_theme.dart';
import 'wo_summary_card.dart';

typedef NetworkProbe = Future<bool> Function();

class WelcomeCard extends StatefulWidget {
  final Map<String, dynamic> sesi;
  final NetworkProbe? networkProbe;

  const WelcomeCard({super.key, required this.sesi, this.networkProbe});

  @override
  State<WelcomeCard> createState() => _WelcomeCardState();
}

class _WelcomeCardState extends State<WelcomeCard>
    with WidgetsBindingObserver {
  bool? _online;
  bool _checking = false;
  bool _loadingSummary = false;
  int _total = 0;
  int _waiting = 0;
  int _progress = 0;
  int _done = 0;

  NetworkProbe get _probe =>
      widget.networkProbe ?? NetworkStatusService.isOnline;

  String get _identity =>
      '${widget.sesi['subTim'] ?? widget.sesi['tim'] ?? ''} '
      '${widget.sesi['username'] ?? ''}'
          .toLowerCase();

  bool get _showNonHarSummary =>
      HarExecution.allowedTypes(widget.sesi).isEmpty;
  bool get _isInsdu =>
      _identity.contains('inspeksi gardu') || _identity.contains('insdu');
  bool get _isRow => !_isInsdu && _identity.contains('row');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNetwork();
    _loadSummary();
  }

  @override
  void didUpdateWidget(covariant WelcomeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_showNonHarSummary) _loadSummary();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNetwork();
      _loadSummary();
    }
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

  Future<void> _loadSummary() async {
    if (!_showNonHarSummary || _loadingSummary) return;
    _loadingSummary = true;
    try {
      var total = 0;
      var waiting = 0;
      var progress = 0;
      var done = 0;

      if (_isInsdu) {
        final items = await WoInsduRepository().semua();
        total = items.length;
        waiting = items
            .where((item) =>
                WoInsdu.normalisasiStatus(item.statusWo) ==
                WoInsdu.statusMulai)
            .length;
        progress = items
            .where((item) =>
                WoInsdu.normalisasiStatus(item.statusWo) ==
                WoInsdu.statusDalam)
            .length;
        done = items
            .where((item) =>
                WoInsdu.normalisasiStatus(item.statusWo) ==
                WoInsdu.statusSelesai)
            .length;
      } else if (_isRow) {
        final items = await WoRowRepository().semua();
        total = items.length;
        waiting = items
            .where((item) =>
                WoRow.normalisasiStatus(item.statusWo) ==
                WoRow.statusPenugasan)
            .length;
        progress = items
            .where((item) =>
                WoRow.normalisasiStatus(item.statusWo) ==
                WoRow.statusProgress)
            .length;
        done = items
            .where((item) =>
                WoRow.normalisasiStatus(item.statusWo) == WoRow.statusSelesai)
            .length;
      } else {
        final items = await WoInsjarRepository().semua();
        total = items.length;
        waiting = items
            .where((item) =>
                WoInsjar.normalisasiStatus(item.statusWo) ==
                WoInsjar.statusMulai)
            .length;
        progress = items
            .where((item) =>
                WoInsjar.normalisasiStatus(item.statusWo) ==
                WoInsjar.statusDalam)
            .length;
        done = items
            .where((item) =>
                WoInsjar.normalisasiStatus(item.statusWo) ==
                WoInsjar.statusSelesai)
            .length;
      }

      if (!mounted) return;
      setState(() {
        _total = total;
        _waiting = waiting;
        _progress = progress;
        _done = done;
      });
    } finally {
      _loadingSummary = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _dateText() {
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
    return '${days[now.weekday - 1]}, ${now.day} '
        '${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final subTim =
        (widget.sesi['subTim'] ?? widget.sesi['tim'] ?? '-').toString();
    final ulp = (widget.sesi['ulp'] ?? '-').toString();
    final bidang =
        (widget.sesi['bidang'] ?? widget.sesi['Bidang'] ?? '-').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _welcomeCard(subTim: subTim, ulp: ulp, bidang: bidang),
        if (_showNonHarSummary) ...[
          const SizedBox(height: 16),
          if (_loadingSummary && _total == 0)
            const LinearProgressIndicator()
          else if (_isRow)
            WoSummaryCard.row(
              total: _total,
              penugasan: _waiting,
              progress: _progress,
              selesai: _done,
            )
          else
            WoSummaryCard.insjar(
              total: _total,
              menunggu: _waiting,
              sedang: _progress,
              selesai: _done,
            ),
        ],
      ],
    );
  }

  Widget _welcomeCard({
    required String subTim,
    required String ulp,
    required String bidang,
  }) =>
      Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: KopitiamColors.ink,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: KopitiamColors.navy),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24071F33),
              blurRadius: 20,
              offset: Offset(0, 9),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: KopitiamColors.gold),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(17, 20, 18, 20),
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
                                    color: KopitiamColors.gold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .35,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Semangat Pagi,',
                                  style: TextStyle(
                                    color: KopitiamColors.surface,
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
                                    color: KopitiamColors.surface,
                                    fontSize: 25,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _checking ? null : _checkNetwork,
                              borderRadius: BorderRadius.circular(100),
                              child: _NetworkChip(online: _online),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(color: KopitiamColors.muted, height: 1),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _info('UNIT KERJA', ulp)),
                          const SizedBox(width: 18),
                          Expanded(child: _info('BIDANG', bidang)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _info(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: KopitiamColors.gold,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .45,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '-' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: KopitiamColors.surface,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
}

class _NetworkChip extends StatelessWidget {
  final bool? online;
  const _NetworkChip({required this.online});

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
          color: KopitiamColors.navy,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: KopitiamColors.surface),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const ValueKey('network-status-dot'),
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: KopitiamColors.surface,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
