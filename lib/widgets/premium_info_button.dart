import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:presto_app/app_core.dart';

import '../app/presto_design_tokens.dart';
import 'presto_accessible_action.dart';

/// Bouton "Infos" premium : double anneau + halo rotatif + retour d’appui.
/// À placer dans un Stack via Positioned.
class PremiumInfoButton extends StatefulWidget {
  final VoidCallback onTap;
  final double size; // ex: 108..128
  final String? chipText; // ex: "Infos" (ou null si tu ne veux pas le badge)

  const PremiumInfoButton({
    super.key,
    required this.onTap,
    this.size = 116,
    this.chipText = 'Infos',
  });

  @override
  State<PremiumInfoButton> createState() => _PremiumInfoButtonState();
}

class _PremiumInfoButtonState extends State<PremiumInfoButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rot;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _rot = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _rot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final inner = s * 0.52;
    final ringW = s * 0.07;
    final label = (widget.chipText ?? '').trim().isEmpty
        ? 'Informations'
        : widget.chipText!.trim();

    return PrestoAccessibleAction(
      onActivate: widget.onTap,
      semanticLabel: label,
      semanticHint: 'Ouvrir les informations',
      excludeChildSemantics: true,
      borderRadius: BorderRadius.circular(s),
      onPressedChanged: (value) => setState(() => _pressed = value),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _pressed ? 0.96 : 1.0,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _rot,
              builder: (_, __) {
                return Transform.rotate(
                  angle: _rot.value * 2 * math.pi,
                  child: CustomPaint(
                    size: Size(s * 1.10, s * 1.10),
                    painter: _RotatingHaloPainter(
                      color: kPrestoBlue,
                      strokeWidth: ringW * 0.90,
                    ),
                  ),
                );
              },
            ),
            Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kPrestoBlue.withValues(alpha: 0.16),
                    blurRadius: 26,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            Material(
              color: Colors.transparent,
              child: Container(
                width: s,
                height: s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: kPrestoBlue, width: ringW),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: inner,
                    height: inner,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: kPrestoBlue,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.info_rounded,
                        color: Colors.white,
                        size: 54,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.chipText != null)
              Positioned(
                top: -8,
                right: -6,
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: PrestoColors.brandOrange,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                      border: Border.all(
                        color: PrestoColors.brandBlue,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      widget.chipText!,
                      style: const TextStyle(
                        color: PrestoColors.textOnOrange,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RotatingHaloPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _RotatingHaloPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (math.min(size.width, size.height) / 2) - strokeWidth;

    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.10),
          color.withValues(alpha: 0.90),
          color.withValues(alpha: 0.15),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.00, 0.18, 0.30, 0.48, 1.00],
      ).createShader(Rect.fromCircle(center: c, radius: r));

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 1.25,
      false,
      haloPaint,
    );

    final dotPaint = Paint()..color = color.withValues(alpha: 0.55);
    for (final a in <double>[0.15, 0.32, 0.52]) {
      final ang = -math.pi / 2 + a * 2 * math.pi;
      final p = Offset(c.dx + math.cos(ang) * r, c.dy + math.sin(ang) * r);
      canvas.drawCircle(p, strokeWidth * 0.28, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RotatingHaloPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
