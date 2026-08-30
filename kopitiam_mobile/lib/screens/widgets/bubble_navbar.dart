import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BubbleNavbar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const BubbleNavbar({super.key, required this.selectedIndex, required this.onTap});

  @override
  State<BubbleNavbar> createState() => _BubbleNavbarState();
}

class _BubbleNavbarState extends State<BubbleNavbar> with SingleTickerProviderStateMixin {
  static const navy700 = Color(0xFF004D8C);
  static const cyan500 = Color(0xFF00E5FF);
  static const neutral500 = Color(0xFF64748B);
  static const labels = ['Work Order', 'Beranda', 'Pengaturan'];

  late final AnimationController _ctrl;
  int _prev = 1;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, value: 1);
    _prev = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(covariant BubbleNavbar old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      _prev = old.selectedIndex;
      _ctrl.reset();
      _ctrl.animateWith(SpringSimulation(const SpringDescription(mass: 1, stiffness: 210, damping: 27), 0, 1, 0));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _icon(int index, bool active) {
    final size = active ? 34.0 : 23.0;
    final color = active ? Colors.white : navy700;
    if (index == 0) return Icon(Icons.assignment_outlined, size: size, color: color);
    if (index == 1) return Icon(Icons.home_rounded, size: size, color: color);
    return SvgPicture.asset('assets/icons/pengaturan.svg', width: size, height: size);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final tabWidth = width / labels.length;
          double centerFor(int i) => tabWidth * i + tabWidth / 2;
          return SizedBox(
            height: 82,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) {
                    final x = centerFor(_prev) + (centerFor(widget.selectedIndex) - centerFor(_prev)) * _ctrl.value;
                    return CustomPaint(size: Size(width, 82), painter: _BubblePainter(notchCenterX: x));
                  },
                ),
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) {
                    final x = centerFor(_prev) + (centerFor(widget.selectedIndex) - centerFor(_prev)) * _ctrl.value;
                    return Positioned(
                      left: x - 29, top: -18,
                      child: Container(
                        width: 58, height: 58,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: navy700, border: Border.all(color: cyan500, width: 2)),
                        child: Center(child: _icon(widget.selectedIndex, true)),
                      ),
                    );
                  },
                ),
                Positioned.fill(
                  child: Row(
                    children: List.generate(labels.length, (i) {
                      final active = i == widget.selectedIndex;
                      return Expanded(
                        child: InkWell(
                          onTap: () => widget.onTap(i),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Opacity(opacity: active ? 0 : 1, child: _icon(i, false)),
                              const SizedBox(height: 6),
                              Text(labels[i], style: TextStyle(fontWeight: active ? FontWeight.w800 : FontWeight.w500, color: active ? navy700 : neutral500)),
                              const SizedBox(height: 9),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  final double notchCenterX;
  const _BubblePainter({required this.notchCenterX});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.white;
    final line = Paint()..color = const Color(0xFF004D8C)..strokeWidth = 3..style = PaintingStyle.stroke;
    const cy = 11.0, r = 40.0;
    final reach = math.sqrt(r * r - cy * cy);
    final fill = Path()..moveTo(0, 0)..lineTo(notchCenterX - reach, 0)..arcToPoint(Offset(notchCenterX + reach, 0), radius: const Radius.circular(r), clockwise: true)..lineTo(size.width, 0)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(fill, bg);
    final outline = Path()..moveTo(0, 0)..lineTo(notchCenterX - reach, 0)..arcToPoint(Offset(notchCenterX + reach, 0), radius: const Radius.circular(r), clockwise: true)..lineTo(size.width, 0);
    canvas.drawPath(outline, line);
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) => old.notchCenterX != notchCenterX;
}
