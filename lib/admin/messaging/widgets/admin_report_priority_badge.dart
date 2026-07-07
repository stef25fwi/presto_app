import 'package:flutter/material.dart';

class AdminReportPriorityBadge extends StatelessWidget {
  final String priority;

  const AdminReportPriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final normalized = priority.trim().toLowerCase();
    final color = switch (normalized) {
      'critique' => const Color(0xFFB42318),
      'haute' => const Color(0xFFD97706),
      'moyenne' => const Color(0xFF1D4ED8),
      _ => const Color(0xFF667085),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        priority,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}