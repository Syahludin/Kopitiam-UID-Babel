import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Callback yang mengembalikan Future agar card bisa menunggu proses selesai.
typedef AsyncAction = Future<void> Function();

class WoDataCard extends StatefulWidget {
  final bool isRow;
  final int dirty;
  final AsyncAction onDownload;
  final AsyncAction onSync;

  const WoDataCard({
    super.key,
    required this.isRow,
    required this.dirty,
    required this.onDownload,
    required this.onSync,
  });

  @override
  State<WoDataCard> createState() => _WoDataCardState();
}

class _WoDataCardState extends State<WoDataCard> with TickerProviderStateMixin {
  static const navy700 = Color(0xFF004D8C);
  static const navy950 = Color(0xFF071B30);
  static const cyan500 = Color(0xFF00E5FF);
  static const green600 = Color(0xFF16A34A);
  static const neutral200 = Color(0xFFE2E8F0);
  static const neutral500 = Color(0xFF64748B);
  static const blueSoft = Color(0xFFE8F1FA);

  bool _busy = false;
  bool _dlDone = false;
  bool _syncDone = false;
  String _activeType = '';
  double _progress = 0;
  String _progressLabel = '';

  late final AnimationController _bounceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
  late final AnimationController _spinCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  late final AnimationController _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _spinCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(String type) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _activeType = type;
      _progress = 0;
      _progressLabel = type == 'dl'
          ? (widget.isRow ? 'Mengunduh ROW' : 'Mengunduh WO')
          : (widget.isRow ? 'Menyinkronkan ROW' : 'Menyinkronkan WO');
      _dlDone = false;
      _syncDone = false;
    });

    // Show progress popup
    final popupDone = _showProgressPopup(type);

    // Simulate progress ticking
    final ticker = Stream.periodic(const Duration(milliseconds: 300), (i) => i);
    final sub = ticker.listen((_) {
      if (!mounted) return;
      setState(() => _progress = math.min(0.90, _progress + 0.06));
    });

    try {
      if (type == 'dl') {
        await widget.onDownload();
      } else {
        await widget.onSync();
      }
    } catch (_) {
      // Error handling is done by the parent
    }

    await sub.cancel();
    if (!mounted) return;
    setState(() => _progress = 1.0);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // Close popup
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    await popupDone;

    // Show checkmark on button
    if (mounted) {
      setState(() {
        _busy = false;
        if (type == 'dl') _dlDone = true; else _syncDone = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (mounted) setState(() { _dlDone = false; _syncDone = false; });
    }
  }

  Future<void> _showProgressPopup(String type) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x8C071B30),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPopup) {
          // Listen to state changes via animation frame callback
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ctx.mounted) setPopup(() {});
          });
          final pct = (_progress.clamp(0, 1) * 100).round();
          final isDone = _progress >= 1.0;
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 72, height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 72, height: 72,
                          child: CircularProgressIndicator(
                            value: isDone ? 1.0 : null,
                            strokeWidth: 4,
                            color: isDone ? green600 : cyan500,
                            backgroundColor: neutral200,
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: isDone
                              ? const Icon(Icons.check_rounded, key: ValueKey('done'), size: 36, color: green600)
                              : type == 'dl'
                                  ? const Icon(Icons.cloud_download_rounded, key: ValueKey('dl'), size: 32, color: navy700)
                                  : RotationTransition(
                                      key: const ValueKey('sync'),
                                      turns: _spinCtrl,
                                      child: const Icon(Icons.sync_rounded, size: 32, color: navy700),
                                    ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isDone ? 'Selesai!' : _progressLabel,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDone ? green600 : navy950,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isDone ? 'Data berhasil diproses' : '$pct% selesai',
                    style: const TextStyle(fontSize: 13, color: neutral500),
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 6,
                      color: isDone ? green600 : cyan500,
                      backgroundColor: neutral200,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

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
          Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: blueSoft, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.cloud_sync_rounded, size: 18, color: navy700),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.isRow ? 'Data ROW Penugasan' : 'Data Work Order', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy950))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _dlButton()),
            const SizedBox(width: 12),
            Expanded(child: _syncButton()),
          ]),
        ],
      ),
    );
  }

  Widget _dlButton() {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: _busy ? null : () => _run('dl'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _dlDone ? green600 : navy700,
          side: BorderSide(color: _dlDone ? green600 : neutral200),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _dlDone
              ? Row(key: const ValueKey('dl-done'), mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Icon(Icons.check_circle_rounded, size: 18, color: green600),
                  SizedBox(width: 6),
                  Text('Berhasil', style: TextStyle(fontWeight: FontWeight.w700, color: green600)),
                ])
              : _busy && _activeType == 'dl'
                  ? Row(key: const ValueKey('dl-busy'), mainAxisAlignment: MainAxisAlignment.center, children: [
                      AnimatedBuilder(
                        animation: _bounceCtrl,
                        builder: (_, child) => Transform.translate(offset: Offset(0, 2 * _bounceCtrl.value), child: child),
                        child: const Icon(Icons.cloud_download_rounded, size: 18),
                      ),
                      const SizedBox(width: 6),
                      const Text('Mengunduh...', style: TextStyle(fontWeight: FontWeight.w700)),
                    ])
                  : Row(key: const ValueKey('dl-idle'), mainAxisAlignment: MainAxisAlignment.center, children: const [
                      Icon(Icons.cloud_download_outlined, size: 18),
                      SizedBox(width: 6),
                      Text('Download WO', style: TextStyle(fontWeight: FontWeight.w700)),
                    ]),
        ),
      ),
    );
  }

  Widget _syncButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _busy ? null : () => _run('sync'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _syncDone ? green600 : navy700,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _syncDone
              ? Row(key: const ValueKey('s-done'), mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Icon(Icons.check_circle_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Berhasil', style: TextStyle(fontWeight: FontWeight.w700)),
                ])
              : _busy && _activeType == 'sync'
                  ? Row(key: const ValueKey('s-busy'), mainAxisAlignment: MainAxisAlignment.center, children: [
                      RotationTransition(turns: _spinCtrl, child: const Icon(Icons.sync_rounded, size: 18)),
                      const SizedBox(width: 6),
                      const Text('Mengirim...', style: TextStyle(fontWeight: FontWeight.w700)),
                    ])
                  : Row(key: const ValueKey('s-idle'), mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.cloud_upload_outlined, size: 18),
                      const SizedBox(width: 6),
                      FittedBox(child: Text(widget.dirty > 0 ? 'Sinkron (${widget.dirty})' : 'Sinkron ${widget.isRow ? "ROW" : "WO"}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    ]),
        ),
      ),
    );
  }
}
