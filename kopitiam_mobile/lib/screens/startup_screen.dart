import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/session_bootstrap_service.dart';
import '../theme/kopitiam_theme.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});
  @override State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  late final Future<Map<String, dynamic>?> _restore = SessionBootstrapService.restore();
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
        future: _restore,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              backgroundColor: KopitiamColors.surface,
              body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  KopitiamLoading(size: 72),
                  SizedBox(height: 18),
                  Text('Memulihkan sesi...', style: TextStyle(color: KopitiamColors.muted, fontWeight: FontWeight.w800)),
                ]),
              ),
            );
          }
          final session = snapshot.data;
          if (session == null) return const LoginScreen();
          return DashboardScreen(sesi: session);
        },
      );
}

class KopitiamLoading extends StatefulWidget {
  final double size;
  final bool onDarkBackground;
  const KopitiamLoading({super.key, this.size = 48, this.onDarkBackground = false});
  @override State<KopitiamLoading> createState() => _KopitiamLoadingState();
}

class _KopitiamLoadingState extends State<KopitiamLoading> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(); }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final track = widget.onDarkBackground ? KopitiamColors.navy : KopitiamColors.surfaceStrong;
    final arc = widget.onDarkBackground ? KopitiamColors.cyan : KopitiamColors.ocean;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(animation: _controller, builder: (_, __) => Transform.rotate(angle: _controller.value * math.pi * 2, child: CustomPaint(size: Size.square(widget.size), painter: _LoadingRingPainter(track: track, arc: arc)))),
          SvgPicture.asset('assets/icons/loading_bolt.svg', width: widget.size * .49, height: widget.size * .49, placeholderBuilder: (_) => Icon(Icons.bolt_rounded, size: widget.size * .55, color: KopitiamColors.yellow)),
        ]),
      ),
    );
  }
}

class _LoadingRingPainter extends CustomPainter {
  final Color track;
  final Color arc;
  const _LoadingRingPainter({required this.track, required this.arc});
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * .075;
    final ringRect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(ringRect, 0, math.pi * 2, false, Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = stroke);
    canvas.drawArc(ringRect, -math.pi / 2, math.pi * .72, false, Paint()..color = arc..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round);
  }
  @override bool shouldRepaint(covariant _LoadingRingPainter oldDelegate) => oldDelegate.track != track || oldDelegate.arc != arc;
}
