import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/guided_journey/guided_journey_models.dart';
import 'package:presto_app/features/guided_journey/guided_journey_visible_content.dart';
import 'package:presto_app/features/guided_journey/widgets/guided_journey_stage_view.dart';

void main() {
  // La vue d'étape est une liste défilante à construction paresseuse : dans le
  // viewport de test par défaut (800x600), la section des ressources n'est
  // jamais montée et reste introuvable.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1200, 3600);
    view.devicePixelRatio = 1;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  JourneyStage duplicatedStage() => JourneyStage(
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

  test('retire les répétitions visibles entre les sections d’une étape', () {
    final visible = GuidedJourneyVisibleContent.fromStage(duplicatedStage());

    expect(visible.checklist, hasLength(1));
    expect(visible.warnings, isEmpty);
    expect(visible.documents, hasLength(1));
    expect(visible.details, equals(const ['Comparer les garanties proposées']));
    expect(visible.resources, hasLength(1));
  });

  testWidgets('affiche une seule fois le même texte dans les sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuidedJourneyStageView(
            stage: duplicatedStage(),
            totalStages: 8,
            progress: 0,
            checkedIds: const <String>{},
            onToggleChecklist: (_) {},
            onOpenResource: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vérifier mon assurance professionnelle'), findsOneWidget);
    expect(find.textContaining('1 ressources'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('En savoir plus'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('En savoir plus'));
    await tester.pumpAndSettle();

    expect(find.text('Comparer les garanties proposées'), findsOneWidget);
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
      equals(const ['Une qualification peut être obligatoire selon le métier']),
    );
  });

  test(
    'compare les textes sans être trompé par les accents ou la ponctuation',
    () {
      final stage = JourneyStage(
        id: 'prepare-file',
        order: 4,
        title: 'Préparer mon dossier',
        objective: 'Préparer.',
        estimatedMinutes: 5,
        explanation: 'Explication.',
        personalizedSummary: 'Résumé.',
        checklist: const [
          JourneyChecklistItem(
            id: 'prepare-1',
            label: 'Préparer une pièce d’identité',
          ),
        ],
        warnings: const ['Preparer une piece d identite !'],
        documents: const [
          'Préparer une pièce d’identité.',
          'Justificatif de domicile',
        ],
      );

      final visible = GuidedJourneyVisibleContent.fromStage(stage);

      expect(visible.checklist, hasLength(1));
      expect(visible.warnings, isEmpty);
      expect(visible.documents, equals(const ['Justificatif de domicile']));
    },
  );
}
