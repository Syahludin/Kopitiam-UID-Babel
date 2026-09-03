import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/kopitiam_theme.dart';

class BubbleNavbar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const BubbleNavbar({super.key, required this.selectedIndex, required this.onTap});

  @override
  State<BubbleNavbar> createState() => _BubbleNavbarState();
}

class _BubbleNavbarState extends State<BubbleNavbar>
    with SingleTickerProviderStateMixin {
  static const labels = ['Work Order', 'Beranda', 'Pengaturan'];
  late final AnimationController _controller;
  int _previous = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, value: 1);
    _previous = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(covariant BubbleNavbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _previous = oldWidget.selectedIndex;
      _controller.reset();
      _controller.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 235, damping: 30),
          0,
          1,
          0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _icon(int index, bool active) {
    final size = active ? 31.0 : 22.0;
    final color = active ? KopitiamColors.surface : KopitiamColors.ocean;
    if (index == 0) {
      return Icon(Icons.assignment_rounded, size: size, color: color);
    }
    if (index == 1) {
      return Icon(Icons.home_rounded, size: size, color: color);
    }
    return SvgPicture.asset(
      'assets/icons/pengaturan.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (_, constraints) {
            final width = constraints.maxWidth;
            final tabWidth = width / labels.length;
            double center(int index) => tabWidth * index + tabWidth / 2;
            return SizedBox(
              height: 82,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) {
                      final x = center(_previous) +
                          (center(widget.selectedIndex) - center(_previous)) *
                              _controller.value;
                      return CustomPaint(
                        size: Size(width, 82),
                        painter: _BubblePainter(centerX: x),
                      );
                    },
                  ),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) {
                      final x = center(_previous) +
                          (center(widget.selectedIndex) - center(_previous)) *
                              _controller.value;
                      return Positioned(
                        left: x - 28,
                        top: -17,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: KopitiamColors.navy,
                            border: Border.all(
                              color: KopitiamColors.gold,
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x30063B5C),
                                blurRadius: 16,
                                offset: Offset(0, 7),
                              ),
                            ],
                          ),
                          child: Center(child: _icon(widget.selectedIndex, true)),
                        ),
                      );
                    },
                  ),
                  Positioned.fill(
                    child: Row(
                      children: List.generate(labels.length, (index) {
                        final active = index == widget.selectedIndex;
                        return Expanded(
                          child: InkWell(
                            onTap: () => widget.onTap(index),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Opacity(
                                  opacity: active ? 0 : 1,
                                  child: _icon(index, false),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  labels[index],
                                  style: TextStyle(
                                    color: active
                                        ? KopitiamColors.navy
                                        : KopitiamColors.muted,
                                    fontWeight: active
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 10),
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

class _BubblePainter extends CustomPainter {
  final double centerX;
  const _BubblePainter({required this.centerX});

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = KopitiamColors.surface;
    final outline = Paint()
      ..color = KopitiamColors.line
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const centerY = 11.0;
    const radius = 39.0;
    final reach = math.sqrt(radius * radius - centerY * centerY);
    final fill = Path()
      ..moveTo(0, 0)
      ..lineTo(centerX - reach, 0)
      ..arcToPoint(
        Offset(centerX + reach, 0),
        radius: const Radius.circular(radius),
        clockwise: true,
      )
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, background);
    final line = Path()
      ..moveTo(0, 0)
      ..lineTo(centerX - reach, 0)
      ..arcToPoint(
        Offset(centerX + reach, 0),
        radius: const Radius.circular(radius),
        clockwise: true,
      )
      ..lineTo(size.width, 0);
    canvas.drawPath(line, outline);
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) =>
      oldDelegate.centerX != centerX;
}
