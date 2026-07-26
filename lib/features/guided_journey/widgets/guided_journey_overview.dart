import 'package:flutter/material.dart';
import 'package:presto_app/features/guided_journey/guided_journey_models.dart';

import 'guided_journey_common_widgets.dart';

class GuidedJourneyOverview extends StatelessWidget {
  final String activity;
  final String region;
  final String currentStatus;
  final List<JourneyStage> stages;
  final Set<String> completedStageIds;
  final int nextStageIndex;
  final ValueChanged<int> onOpenStage;

  const GuidedJourneyOverview({
    super.key,
    required this.activity,
    required this.region,
    required this.currentStatus,
    required this.stages,
    required this.completedStageIds,
    required this.nextStageIndex,
    required this.onOpenStage,
  });

  @override
  Widget build(BuildContext context) {
    final safeIndex = nextStageIndex.clamp(0, stages.length - 1);
    final nextStage = stages[safeIndex];
    final completed = completedStageIds.length;
    final progress = stages.isEmpty ? 0.0 : completed / stages.length;
    final firstAction = completed == 0;
        final ctaLabel = firstAction
        ? 'Commencer l’étape 1'
        : completed >= stages.length
            ? 'Revoir mon parcours'
            : 'Reprendre l’étape ${nextStage.order}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF1E8), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFFD7BF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Voici votre parcours',
                style: TextStyle(
                  color: kGuidedJourneyText,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Créer une activité de $activity${region.isEmpty ? '' : ' en $region'}${currentStatus.isEmpty ? '' : ' avec le statut actuel : $currentStatus'}.',
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (region.isNotEmpty)
                    _OverviewChip(
                      icon: Icons.place_outlined,
                      label: region,
                    ),
                  if (currentStatus.isNotEmpty)
                    _OverviewChip(
                      icon: Icons.badge_outlined,
                      label: currentStatus,
                    ),
                  _OverviewChip(
                    icon: Icons.work_outline_rounded,
                    label: activity,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GuidedJourneyProgressStrip(
          current: 0,
          total: stages.length,
          progress: progress,
          label: '$completed étape(s) terminée(s) sur ${stages.length}',
        ),
        const SizedBox(height: 12),
        GuidedJourneySectionCard(
          title: 'Votre prochaine action',
          subtitle: 'Une seule priorité est proposée pour avancer sans vous perdre.',
          icon: Icons.near_me_outlined,
          accent: kGuidedJourneyOrange,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                nextStage.title,
                style: const TextStyle(
                  color: kGuidedJourneyText,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                nextStage.objective,
                style: const TextStyle(
                  color: kGuidedJourneyMuted,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => onOpenStage(safeIndex),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGuidedJourneyBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(ctaLabel),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GuidedJourneySectionCard(
          title: 'Aperçu du parcours',
          subtitle: 'Touchez une étape pour la consulter. Suivez-les de préférence dans l’ordre.',
          icon: Icons.route_outlined,
          child: Column(
            children: [
              for (var index = 0; index < stages.length; index++)
                _OverviewStageTile(
                  stage: stages[index],
                  completed: completedStageIds.contains(stages[index].id),
                  active: index == safeIndex,
                  onTap: () => onOpenStage(index),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _OverviewChip({required this.icon, required this.label});

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

class _OverviewStageTile extends StatelessWidget {
  final JourneyStage stage;
  final bool completed;
  final bool active;
  final VoidCallback onTap;

  const _OverviewStageTile({
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
        completed ? 'Terminée' : active ? 'Prochaine étape' : 'À faire',
        style: TextStyle(color: tone, fontWeight: FontWeight.w700),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
