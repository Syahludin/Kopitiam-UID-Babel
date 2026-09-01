import 'package:flutter/material.dart';

class SuccessOverlay extends StatefulWidget {
  final String title;
  final String message;

  const SuccessOverlay({super.key, required this.title, required this.message});

  @override
  State<SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<SuccessOverlay> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 850))..forward();
  late final Animation<double> _scale = CurvedAnimation(parent: _intro, curve: Curves.elasticOut);
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  late final Animation<double> _opacity = Tween<double>(begin: 1, end: .45).animate(_pulse);

  @override
  void dispose() { _intro.dispose(); _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => Navigator.of(context).pop(),
    child: Container(
      width: double.infinity, height: double.infinity,
      padding: const EdgeInsets.all(24), alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 28, offset: Offset(0, 12))]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(scale: _scale, child: FadeTransition(opacity: _opacity, child: Container(
                  width: 92, height: 92,
                  decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF16A34A), Color(0xFF4ADE80)], begin: Alignment.topLeft, end: Alignment.bottomRight), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x3D16A34A), blurRadius: 18, offset: Offset(0, 6))]),
                  child: const Icon(Icons.check_rounded, size: 52, color: Colors.white),
                ))),
                const SizedBox(height: 20),
                Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF071B30))),
                const SizedBox(height: 8),
                Text(widget.message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF64748B))),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(100)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFF16A34A)), SizedBox(width: 6), Text('Ketuk untuk menutup', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D)))]),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
