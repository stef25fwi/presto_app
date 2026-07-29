import 'package:flutter/material.dart';
import 'package:presto_app/features/guided_journey/guided_journey_models.dart';

import 'guided_journey_common_widgets.dart';

class GuidedJourneyOverviewChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const GuidedJourneyOverviewChip({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: kGuidedJourneyBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: kGuidedJourneyText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class GuidedJourneyOverviewStageTile extends StatelessWidget {
  final JourneyStage stage;
  final bool completed;
  final bool active;
  final VoidCallback onTap;

  const GuidedJourneyOverviewStageTile({
    super.key,
    required this.stage,
    required this.completed,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = completed
        ? const Color(0xFF0F766E)
        : active
        ? kGuidedJourneyOrange
        : const Color(0xFF9CA3AF);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: tone.withValues(alpha: 0.12),
        foregroundColor: tone,
        child: completed
            ? const Icon(Icons.check_rounded)
            : Text(
                '${stage.order}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
      ),
      title: Text(
        stage.title,
        style: const TextStyle(
          color: kGuidedJourneyText,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        completed
            ? 'Terminée'
            : active
            ? 'Prochaine étape'
            : 'À faire',
        style: TextStyle(color: tone, fontWeight: FontWeight.w700),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
