import 'package:flutter/material.dart';
import 'package:presto_app/features/guided_journey/guided_journey_models.dart';
import 'package:presto_app/features/guided_journey/guided_journey_visible_content.dart';

import 'guided_journey_callout.dart';
import 'guided_journey_common_widgets.dart';
import 'guided_journey_resource_list.dart';

class GuidedJourneyStageView extends StatelessWidget {
  final JourneyStage stage;
  final int totalStages;
  final double progress;
  final Set<String> checkedIds;
  final ValueChanged<String> onToggleChecklist;
  final ValueChanged<String> onOpenResource;

  const GuidedJourneyStageView({
    super.key,
    required this.stage,
    required this.totalStages,
    required this.progress,
    required this.checkedIds,
    required this.onToggleChecklist,
    required this.onOpenResource,
  });

  @override
  Widget build(BuildContext context) {
    final visible = GuidedJourneyVisibleContent.fromStage(stage);
    final completed = visible.checklist
        .where((item) => checkedIds.contains(item.id))
        .length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 140),
      children: [
        GuidedJourneyProgressStrip(
          current: stage.order,
          total: totalStages,
          progress: progress,
          label: '${stage.title} · environ ${stage.estimatedMinutes} minutes',
        ),
        const SizedBox(height: 12),
        GuidedJourneySectionCard(
          title: stage.title,
          subtitle: stage.objective,
          icon: _stageIcon(stage.id),
          accent: kGuidedJourneyOrange,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                stage.explanation,
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              GuidedJourneyCallout(
                title: 'Dans votre situation',
                text: stage.personalizedSummary,
                icon: Icons.person_pin_circle_outlined,
              ),
              if (visible.warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                GuidedJourneyCallout(
                  title: stage.isBlocking
                      ? 'À vérifier avant de continuer'
                      : 'Points de vigilance',
                  text: visible.warnings.join('\n\n'),
                  icon: Icons.warning_amber_rounded,
                  tone: const Color(0xFFD97706),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        GuidedJourneySectionCard(
          title:
              'Ce que vous devez faire maintenant — $completed/${visible.checklist.length}',
          subtitle:
              'Cochez chaque action lorsque vous l’avez réellement vérifiée.',
          icon: Icons.checklist_rounded,
          accent: const Color(0xFF0F766E),
          child: Column(
            children: visible.checklist
                .map(
                  (item) => CheckboxListTile(
                    value: checkedIds.contains(item.id),
                    onChanged: (_) => onToggleChecklist(item.id),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF0F766E),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: kGuidedJourneyText,
                        fontWeight: FontWeight.w700,
                        decoration: checkedIds.contains(item.id)
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        GuidedJourneySectionCard(
          title: 'Documents et informations à préparer',
          subtitle: '${visible.documents.length} élément(s) à réunir',
          icon: Icons.folder_copy_outlined,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8),
            title: const Text(
              'Afficher la liste',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            children: [GuidedJourneyInfoList(items: visible.documents)],
          ),
        ),
        const SizedBox(height: 12),
        GuidedJourneySectionCard(
          title: 'Comprendre cette étape en détail',
          subtitle:
              'Les précisions complémentaires sont affichées sans répéter les actions ou documents déjà visibles.',
          icon: Icons.menu_book_outlined,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8),
            title: const Text(
              'En savoir plus',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            children: [GuidedJourneyInfoList(items: visible.details)],
          ),
        ),
        const SizedBox(height: 12),
        GuidedJourneySectionCard(
          title:
              'Liens et organismes utiles — ${visible.resources.length} ressources',
          subtitle:
              'Les ressources prioritaires sont affichées en premier. Touchez une tuile pour ouvrir le site.',
          icon: Icons.link_rounded,
          accent: kGuidedJourneyBlue,
          child: GuidedJourneyResourceList(
            resources: visible.resources,
            onOpen: onOpenResource,
          ),
        ),
      ],
    );
  }

  IconData _stageIcon(String id) {
    switch (id) {
      case 'rules':
        return Icons.gavel_outlined;
      case 'personal-status':
        return Icons.badge_outlined;
      case 'legal-frame':
        return Icons.account_balance_outlined;
      case 'prepare-file':
        return Icons.folder_copy_outlined;
      case 'declare':
        return Icons.assignment_turned_in_outlined;
      case 'secure':
        return Icons.shield_outlined;
      case 'aids-budget':
        return Icons.volunteer_activism_outlined;
      default:
        return Icons.calendar_month_outlined;
    }
  }
}
