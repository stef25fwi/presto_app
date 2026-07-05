import 'dart:math' as math;

import 'package:flutter/material.dart';

class OrbitingAiVisual extends StatefulWidget {
  const OrbitingAiVisual({
    super.key,
    this.size = 60,
    this.strokeColor = const Color(0x73FFFFFF),
    this.dotColor = Colors.white,
  });

  final double size;
  final Color strokeColor;
  final Color dotColor;

  @override
  State<OrbitingAiVisual> createState() => _OrbitingAiVisualState();
}

class _OrbitingAiVisualState extends State<OrbitingAiVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Transform.rotate(
            angle: _controller.value * math.pi * 2,
            child: CustomPaint(
              painter: _OrbitPainter(
                strokeColor: widget.strokeColor,
                dotColor: widget.dotColor,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({
    required this.strokeColor,
    required this.dotColor,
  });

  final Color strokeColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 3;
    final innerRadius = size.width / 2 - 11;

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, outerRadius, strokePaint);
    canvas.drawCircle(center, innerRadius, strokePaint);

    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    final positions = [
      Offset(center.dx + outerRadius, center.dy),
      Offset(
        center.dx + (innerRadius * math.cos(math.pi * 0.75)),
        center.dy + (innerRadius * math.sin(math.pi * 0.75)),
      ),
      Offset(
        center.dx + (outerRadius * math.cos(math.pi * 1.4)),
        center.dy + (outerRadius * math.sin(math.pi * 1.4)),
      ),
    ];

    for (final position in positions) {
      canvas.drawCircle(position, 3.6, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) {
    return oldDelegate.strokeColor != strokeColor ||
        oldDelegate.dotColor != dotColor;
  }
}
