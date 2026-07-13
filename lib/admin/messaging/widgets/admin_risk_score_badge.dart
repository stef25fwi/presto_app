import 'package:flutter/material.dart';

class AdminRiskScoreBadge extends StatelessWidget {
  final int score;

  const AdminRiskScoreBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? const Color(0xFFB42318)
        : score >= 50
            ? const Color(0xFFB54708)
            : const Color(0xFF0F766E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Risque $score',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
