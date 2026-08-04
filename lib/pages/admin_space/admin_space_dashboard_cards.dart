// Cartes, graphiques et pastilles du tableau de bord.
//
// Fragment de la bibliothèque `admin_space_page.dart` : le découpage
// réduit la taille des fichiers sans modifier la visibilité des types.
part of '../admin_space_page.dart';

class _AdminMetricDomainCard extends StatelessWidget {
  final _AdminMetricDomain domain;
  final List<_AdminDashboardStat> highlights;
  final List<double> series;
  final String trendLabel;
  final String note;
  final VoidCallback? onTap;

  const _AdminMetricDomainCard({
    required this.domain,
    required this.highlights,
    required this.series,
    required this.trendLabel,
    required this.note,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: domain.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: domain.color.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Icon(domain.icon, color: domain.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      domain.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final stat in highlights)
                    _DashboardPill(
                      label: stat.label,
                      value: stat.value,
                      color: domain.color,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _AdminMiniChart(
                color: domain.color,
                label: trendLabel,
                points: series,
              ),
              const SizedBox(height: 10),
              Text(
                note,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final metric in domain.metrics)
                    _AdminMetricPill(label: metric, color: domain.color),
                ],
              ),
              if (onTap != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Appuyer pour le détail + export CSV',
                  style: TextStyle(
                    color: domain.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminMiniChart extends StatelessWidget {
  final Color color;
  final String label;
  final List<double> points;

  const _AdminMiniChart({
    required this.color,
    required this.label,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            child: CustomPaint(
              painter: _AdminSparklinePainter(color: color, points: points),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSparklinePainter extends CustomPainter {
  final Color color;
  final List<double> points;

  const _AdminSparklinePainter({required this.color, required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      axisPaint,
    );

    if (points.isEmpty) {
      return;
    }

    var minValue = points.first;
    var maxValue = points.first;
    for (final point in points) {
      if (point < minValue) minValue = point;
      if (point > maxValue) maxValue = point;
    }

    final span = (maxValue - minValue).abs();
    final effectiveSpan = span <= 0 ? 1.0 : span;
    final xStep =
        points.length <= 1 ? size.width : size.width / (points.length - 1);

    final path = Path();
    final fillPath = Path();
    for (var index = 0; index < points.length; index += 1) {
      final x = xStep * index;
      final normalized = (points[index] - minValue) / effectiveSpan;
      final y = size.height - 8 - (normalized * (size.height - 16));
      if (index == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _AdminSparklinePainter oldDelegate) {
    if (oldDelegate.color != color) return true;
    if (oldDelegate.points.length != points.length) return true;
    for (var index = 0; index < points.length; index += 1) {
      if (oldDelegate.points[index] != points[index]) return true;
    }
    return false;
  }
}

class _AdminMetricPill extends StatelessWidget {
  final String label;
  final Color color;

  const _AdminMetricPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
    );
  }
}
