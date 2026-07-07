import 'package:flutter/material.dart';

class AdminUserMessagingStatusBadge extends StatelessWidget {
  final String status;

  const AdminUserMessagingStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final color = switch (normalized) {
      'bloqué' || 'bloque' || 'suspendu' => const Color(0xFFB42318),
      'restreint' || 'surveillé' || 'surveille' => const Color(0xFFD97706),
      _ => const Color(0xFF0F766E),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}