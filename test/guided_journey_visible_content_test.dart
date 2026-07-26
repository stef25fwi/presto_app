import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/guided_journey/guided_journey_models.dart';
import 'package:presto_app/features/guided_journey/guided_journey_visible_content.dart';

void main() {
  test('retire les répétitions visibles entre les sections d’une étape', () {
    final stage = JourneyStage(
      id: 'secure',
      order: 6,
      title: 'Sécuriser mon lancement',
      objective: 'Vérifier les protections utiles.',
      estimatedMinutes: 5,
      explanation: 'Préparer les protections nécessaires.',
      personalizedSummary: 'Votre activité nécessite une vérification.',
      warnings: const [
        'Vérifier mon assurance professionnelle',
        'Vérifier mon assurance professionnelle',
      ],
      checklist: const [
        JourneyChecklistItem(
          id: 'secure-1',
          label: 'Vérifier mon assurance professionnelle',
        ),
        JourneyChecklistItem(
          id: 'secure-duplicate',
          label: 'Vérifier mon assurance professionnelle',
        ),
      ],
      documents: const [
        'Attestation d’assurance professionnelle',
        'Attestation d’assurance professionnelle',
      ],
      details: const [
        'Vérifier mon assurance professionnelle — Vérifier mon assurance professionnelle — Comparer les garanties proposées',
        'Comparer les garanties proposées',
        'Attestation d’assurance professionnelle',
      ],
      resources: const [
        JourneyResourceLink(
          label: 'CCI',
          description: 'Accompagnement',
          url: 'https://www.cci.fr',
        ),
        JourneyResourceLink(
          label: 'CCI France',
          description: 'Même ressource',
          url: 'https://www.cci.fr/',
        ),
      ],
    );

    final visible = GuidedJourneyVisibleContent.fromStage(stage);

    expect(visible.checklist, hasLength(1));
    expect(visible.warnings, hasLength(1));
    expect(visible.documents, hasLength(1));
    expect(visible.details, equals(const ['Comparer les garanties proposées']));
    expect(visible.resources, hasLength(1));
  });

  test('conserve une précision lorsqu’un titre est déjà dans la checklist', () {
    final stage = JourneyStage(
      id: 'rules',
      order: 1,
      title: 'Comprendre les règles',
      objective: 'Comprendre.',
      estimatedMinutes: 5,
      explanation: 'Explication.',
      personalizedSummary: 'Résumé.',
      checklist: const [
        JourneyChecklistItem(
          id: 'rules-1',
          label: 'Activité libre ou réglementée',
        ),
      ],
      details: const [
        'Activité libre ou réglementée — Une qualification peut être obligatoire selon le métier',
      ],
    );

    final visible = GuidedJourneyVisibleContent.fromStage(stage);

    expect(
      visible.details,
      equals(const [
        'Une qualification peut être obligatoire selon le métier',
      ]),
    );
  });
}
