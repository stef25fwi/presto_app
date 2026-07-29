import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/account/guided_journey_page.dart';

void main() {
  // L'aperçu du parcours est un ListView : ses enfants sont construits
  // paresseusement. Dans le viewport de test par défaut (800x600), les
  // sections situées sous la carte d'en-tête ne sont jamais montées et
  // restent introuvables. On élargit donc la fenêtre, comme le font déjà
  // les autres tests d'écrans longs du dépôt.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1200, 3600);
    view.devicePixelRatio = 1;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  Widget buildSubject({Map<String, dynamic> progress = const {}}) {
    return MaterialApp(
      home: GuidedJourneyPage(
        projectLabel: 'Jardinage',
        region: 'Guadeloupe',
        currentStatus: 'Salarié',
        selectedActivity: 'Jardinage',
        recommendation: const {
          'statut': 'Micro-entrepreneur',
          'why': 'Un cadre simple pour tester l’activité.',
        },
        blockingAlerts: const ['Vérifier les assurances utiles.'],
        costs: const {
          'formalitesEstimees': {'min': 0, 'max': 50},
          'assuranceProAn': 250,
          'note': 'Montants indicatifs.',
        },
        aides: const [
          {
            'name': 'ACRE',
            'desc': 'Exonération partielle au démarrage',
            'relevant': true,
          },
        ],
        plan30: const [
          {'week': 'Semaine 1', 'label': 'Vérifier la réglementation'},
          {'week': 'Semaine 2', 'label': 'Préparer le dossier'},
        ],
        summary: const {
          'activity': 'Jardinage',
          'region': 'Guadeloupe',
          'currentStatus': 'Salarié',
        },
        regulationTutorial: const [
          {
            'title': 'Activité libre ou réglementée',
            'description':
                'Vérifier les règles applicables avant de commencer.',
          },
        ],
        statusWarnings: const [
          {
            'title': 'Contrat de travail',
            'description': 'Relire les clauses utiles.',
            'checks': ['Clause d’exclusivité', 'Non-concurrence'],
          },
        ],
        recommendedLegalStatus: const {
          'recommended': 'Micro-entrepreneur',
          'justification': 'Démarches simplifiées.',
          'disclaimer': 'Orientation à confirmer selon la situation.',
        },
        steps: const [
          {
            'order': 1,
            'title': 'Préparer les documents',
            'objective': 'Constituer le dossier',
            'todos': ['Préparer une pièce d’identité'],
          },
          {
            'order': 2,
            'title': 'Déclarer l’activité',
            'objective': 'Utiliser le guichet unique',
            'todos': ['Déposer la formalité'],
          },
        ],
        guidedProgress: progress,
      ),
    );
  }

  testWidgets('affiche un aperçu puis ouvre une seule étape guidée', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Voici votre parcours'), findsOneWidget);
    expect(find.text('Aperçu du parcours'), findsOneWidget);
    expect(find.text('Commencer l’étape 1'), findsOneWidget);

    await tester.tap(find.text('Commencer l’étape 1'));
    await tester.pumpAndSettle();

    expect(find.text('Étape 1 sur 8'), findsWidgets);
    expect(find.text('Comprendre les règles de mon activité'), findsWidgets);
    expect(
      find.text('Ce que vous devez faire maintenant — 0/1'),
      findsOneWidget,
    );
    expect(find.text('Choisir mon cadre de lancement'), findsNothing);
  });

  testWidgets('déroule une liste longue de liens cliquables', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    await tester.tap(find.text('Commencer l’étape 1'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Liens et organismes utiles'), findsOneWidget);
    expect(find.textContaining('Afficher les'), findsOneWidget);

    await tester.tap(find.textContaining('Afficher les'));
    await tester.pumpAndSettle();
    expect(find.text('Réduire la liste'), findsOneWidget);
  });

  testWidgets('restaure la dernière étape incomplète et la progression', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        progress: const {
          'activeStageId': 'legal-frame',
          'completedStageIds': ['rules', 'personal-status'],
          'checklistDone': {
            'legal-frame': ['legal-frame-1'],
          },
        },
      ),
    );
    await tester.pump();

    expect(find.text('Étape 3 sur 8'), findsWidgets);
    expect(find.text('Choisir mon cadre de lancement'), findsWidgets);
    expect(find.textContaining('25 %'), findsOneWidget);
  });
}
