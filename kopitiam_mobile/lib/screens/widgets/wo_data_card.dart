import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/kopitiam_theme.dart';

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

class _WoDataCardState extends State<WoDataCard>
    with TickerProviderStateMixin {
  bool _busy = false;
  String _active = '';
  String _lastState = '';
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _run(String type) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _active = type;
      _lastState = '';
    });
    final progress = ValueNotifier<double>(.05);
    final failed = ValueNotifier<bool>(false);
    final dialog = _showProgress(type, progress, failed);
    final ticker = Timer.periodic(const Duration(milliseconds: 320), (_) {
      progress.value = math.min(.90, progress.value + .055);
    });
    try {
      if (type == 'download') {
        await widget.onDownload();
      } else {
        await widget.onSync();
      }
      progress.value = 1;
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      await dialog;
      if (mounted) setState(() => _lastState = 'success');
    } catch (_) {
      failed.value = true;
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      await dialog;
      if (mounted) setState(() => _lastState = 'failed');
    } finally {
      ticker.cancel();
      progress.dispose();
      failed.dispose();
      if (mounted) {
        setState(() {
          _busy = false;
          _active = '';
        });
        await Future<void>.delayed(const Duration(milliseconds: 1300));
        if (mounted) setState(() => _lastState = '');
      }
    }
  }

  Future<void> _showProgress(
    String type,
    ValueNotifier<double> progress,
    ValueNotifier<bool> failed,
  ) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: const Color(0xB3071F33),
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: KopitiamColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: ValueListenableBuilder<bool>(
              valueListenable: failed,
              builder: (_, isFailed, __) => ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (_, value, __) {
                  final done = value >= 1 && !isFailed;
                  final color = isFailed
                      ? KopitiamColors.danger
                      : done
                          ? KopitiamColors.success
                          : KopitiamColors.cyan;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: CircularProgressIndicator(
                                value: isFailed || done ? 1 : null,
                                strokeWidth: 4,
                                color: color,
                              ),
                            ),
                            if (isFailed)
                              const Icon(Icons.close_rounded,
                                  color: KopitiamColors.danger, size: 36)
                            else if (done)
                              const Icon(Icons.check_rounded,
                                  color: KopitiamColors.success, size: 36)
                            else
                              RotationTransition(
                                turns: _spin,
                                child: Icon(
                                  type == 'download'
                                      ? Icons.cloud_download_rounded
                                      : Icons.sync_rounded,
                                  color: KopitiamColors.navy,
                                  size: 32,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        isFailed
                            ? 'Proses gagal'
                            : done
                                ? 'Selesai'
                                : type == 'download'
                                    ? 'Mengunduh data'
                                    : 'Menyinkronkan data',
                        style: const TextStyle(
                          color: KopitiamColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        isFailed
                            ? 'Detail akan ditampilkan setelah proses ditutup.'
                            : done
                                ? 'Data selesai diproses.'
                                : '${(value * 100).round()}% selesai',
                        style: const TextStyle(
                          color: KopitiamColors.muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: isFailed ? 1 : value,
                          minHeight: 6,
                          color: color,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: KopitiamColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: KopitiamColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10071F33),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: KopitiamColors.cyanSoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.cloud_sync_rounded,
                    color: KopitiamColors.ocean,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    widget.isRow ? 'Data ROW Penugasan' : 'Data Work Order',
                    style: const TextStyle(
                      color: KopitiamColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _button('download')),
                const SizedBox(width: 12),
                Expanded(child: _button('sync')),
              ],
            ),
          ],
        ),
      );

  Widget _button(String type) {
    final active = _busy && _active == type;
    final success = !_busy && _lastState == 'success';
    final failed = !_busy && _lastState == 'failed';
    final label = active
        ? type == 'download'
            ? 'Mengunduh...'
            : 'Mengirim...'
        : success
            ? 'Berhasil'
            : failed
                ? 'Gagal'
                : type == 'download'
                    ? 'Download WO'
                    : widget.dirty > 0
                        ? 'Sinkron (${widget.dirty})'
                        : 'Sinkron ${widget.isRow ? "ROW" : "WO"}';
    final icon = active
        ? Icons.sync_rounded
        : success
            ? Icons.check_circle_rounded
            : failed
                ? Icons.error_rounded
                : type == 'download'
                    ? Icons.cloud_download_outlined
                    : Icons.cloud_upload_outlined;
    final color = failed
        ? KopitiamColors.danger
        : success
            ? KopitiamColors.success
            : KopitiamColors.ocean;

    if (type == 'download') {
      return SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : () => _run(type),
          icon: Icon(icon, size: 18),
          label: FittedBox(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(
              color: failed || success ? color : KopitiamColors.line,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _busy ? null : () => _run(type),
        icon: active
            ? RotationTransition(turns: _spin, child: Icon(icon, size: 18))
            : Icon(icon, size: 18),
        label: FittedBox(
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: KopitiamColors.surface,
        ),
      ),
    );
  }
}
