import 'package:flutter/material.dart';

/// Widget de badge pour afficher le statut de modération sur une annonce
class ModerationBadge extends StatelessWidget {
  final String status; // 'pending_moderation', 'approved', 'rejected'
  final String? userMessage;

  const ModerationBadge({
    super.key,
    required this.status,
    this.userMessage,
  });

  @override
  Widget build(BuildContext context) {
    switch (status.toLowerCase()) {
      case 'pending_moderation':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_bottom_rounded,
                  size: 14, color: Colors.orange.shade700),
              const SizedBox(width: 6),
              Text(
                'Attente de validation',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        );

      case 'rejected':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close_rounded, size: 14, color: Colors.red.shade700),
              const SizedBox(width: 6),
              Tooltip(
                message: userMessage ?? 'Annonce rejetée',
                child: Text(
                  'Rejetée',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
