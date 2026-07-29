import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/account/saved_journey_summary_page.dart';

/// `SavedJourneySummaryPage` n'a plus d'interface propre : elle réhydrate un
/// instantané persisté puis délègue au même renderer guidé que le parcours
/// fraîchement généré. Ces tests couvrent donc ce qui lui reste en propre —
/// la robustesse du parsing de l'instantané — et vérifient que le parcours
/// guidé s'affiche bien derrière.
Widget _host(Map<String, dynamic> snapshot) {
  return MaterialApp(home: SavedJourneySummaryPage(snapshot: snapshot));
}

void main() {
  // Aperçu et vue d'étape sont des ListView à construction paresseuse : dans
  // le viewport de test par défaut (800x600), les sections situées sous
  // l'en-tête ne seraient jamais montées.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1200, 3600);
    view.devicePixelRatio = 1;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  testWidgets('restitue un instantané complet dans le renderer guidé', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(<String, dynamic>{
        'projectLabel': 'Mon activité',
        'savedAt': '2026-07-05T12:30:00.000Z',
        'region': 'Guadeloupe',
        'currentStatus': 'Fonctionnaire',
        'selectedActivity': 'Photographe',
        'recommendation': <String, dynamic>{
          'statut': 'Micro-entreprise',
          'why': 'Une structure rapide à créer.',
        },
        'blockingAlerts': <dynamic>['Vérifier le cumul avec l’emploi public.'],
        'costs': <String, dynamic>{'cout_initial': 120},
        'aides': <dynamic>[
          <String, dynamic>{'name': 'ACRE'},
        ],
        'plan30': <dynamic>[
          <String, dynamic>{'title': 'Semaine 1'},
        ],
        'steps': <dynamic>[
          <String, dynamic>{'title': 'Immatriculation'},
        ],
      }),
    );
    await tester.pump();

    expect(find.text('Mon parcours personnalisé'), findsOneWidget);
    expect(find.text('Voici votre parcours'), findsOneWidget);
    // L'activité, la région et le statut de l'instantané composent la phrase
    // d'introduction : c'est ce qui prouve que le parsing a bien transmis.
    expect(
      find.text(
        'Créer une activité de Photographe en Guadeloupe '
        'avec le statut actuel : Fonctionnaire.',
      ),
      findsOneWidget,
    );
    expect(find.text('Aperçu du parcours'), findsOneWidget);
    expect(find.text('Commencer l’étape 1'), findsOneWidget);
  });

  testWidgets('restaure la progression guidée enregistrée', (tester) async {
    await tester.pumpWidget(
      _host(<String, dynamic>{
        'projectLabel': 'Mon activité',
        'selectedActivity': 'Photographe',
        'guidedProgress': <String, dynamic>{
          'activeStageId': 'legal-frame',
          'completedStageIds': <String>['rules', 'personal-status'],
          'checklistDone': <String, dynamic>{
            'legal-frame': <String>['legal-frame-1'],
          },
        },
      }),
    );
    await tester.pump();

    // Une progression enregistrée ouvre directement l'étape en cours plutôt
    // que l'aperçu.
    expect(find.text('Étape 3 sur 8'), findsWidgets);
    expect(find.text('Choisir mon cadre de lancement'), findsWidgets);
    expect(find.textContaining('25 %'), findsOneWidget);
  });

  testWidgets('tolère des valeurs malformées sans planter', (tester) async {
    await tester.pumpWidget(
      _host(<String, dynamic>{
        'projectLabel': 'Projet couture',
        'savedAt': 'date invalide',
        'region': ' ',
        'currentStatus': '',
        'selectedActivity': '',
        // Types volontairement incorrects : listes reçues comme chaînes,
        // maps reçues comme nombres, entrées nulles ou hétérogènes.
        'blockingAlerts': 'not-a-list',
        'summary': 'not-a-map',
        'costs': 12,
        'regulationTutorial': 'not-a-list',
        'statusWarnings': null,
        'aides': false,
        'plan30': <dynamic>[false],
        'steps': <dynamic>[
          42,
          <String, dynamic>{'label': 'Démarrer'},
        ],
      }),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Mon parcours personnalisé'), findsOneWidget);
    // selectedActivity vide : le libellé du projet prend le relais, et les
    // champs vides ou blancs disparaissent de la phrase.
    expect(
      find.text('Créer une activité de Projet couture.'),
      findsOneWidget,
    );
    expect(find.text('Aperçu du parcours'), findsOneWidget);
  });

  testWidgets('applique les valeurs de repli sur un instantané vide', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const <String, dynamic>{}));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Mon parcours personnalisé'), findsOneWidget);
    expect(find.text('Créer une activité de votre projet.'), findsOneWidget);
    expect(find.text('Commencer l’étape 1'), findsOneWidget);
  });
}
