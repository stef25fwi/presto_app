import 'package:flutter/material.dart';

class AdminConversationStatusBadge extends StatelessWidget {
  final String status;

  const AdminConversationStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final color = switch (normalized) {
      'closed' || 'bloquée' || 'blocked' => const Color(0xFFB42318),
      'archived' || 'archivée' => const Color(0xFF667085),
      'reported' || 'signalée' => const Color(0xFFB54708),
      'deleted' || 'supprimée' => const Color(0xFF7F1D1D),
      _ => const Color(0xFF0F766E),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
