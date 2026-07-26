import 'package:flutter/material.dart';
import 'package:presto_app/features/guided_journey/guided_journey_models.dart';

import 'guided_journey_common_widgets.dart';
import 'guided_journey_overview_tiles.dart';

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
    final ctaLabel = completed == 0
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
                    GuidedJourneyOverviewChip(
                      icon: Icons.place_outlined,
                      label: region,
                    ),
                  if (currentStatus.isNotEmpty)
                    GuidedJourneyOverviewChip(
                      icon: Icons.badge_outlined,
                      label: currentStatus,
                    ),
                  GuidedJourneyOverviewChip(
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
          subtitle:
              'Touchez une étape pour la consulter. Suivez-les de préférence dans l’ordre.',
          icon: Icons.route_outlined,
          child: Column(
            children: [
              for (var index = 0; index < stages.length; index++)
                GuidedJourneyOverviewStageTile(
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
