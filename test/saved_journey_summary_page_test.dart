import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/account/saved_journey_summary_page.dart';

Widget _host(Map<String, dynamic> snapshot) {
  return MaterialApp(home: SavedJourneySummaryPage(snapshot: snapshot));
}

Future<void> _scrollTo(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    500,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

List<String> _visibleRichTextValues(WidgetTester tester) {
  return tester
      .widgetList<RichText>(find.byType(RichText))
      .map((widget) => widget.text.toPlainText())
      .toList();
}

void main() {
  testWidgets('renders every saved journey section and dynamic value format',
      (tester) async {
    final snapshot = <String, dynamic>{
      'projectLabel': 'Mon activité',
      'savedAt': '2026-07-05T12:30:00.000Z',
      'region': 'Guadeloupe',
      'currentStatus': 'Fonctionnaire',
      'selectedActivity': 'Photographe',
      'recommendation': <String, dynamic>{
        'statut': 'Micro-entreprise',
        'why': 'Une structure rapide à créer.',
        'planB': 'Entreprise individuelle',
      },
      'recommendedLegalStatus': <String, dynamic>{
        'recommended': 'Micro-entreprise BNC',
        'justification': 'Le régime correspond à cette activité.',
      },
      'blockingAlerts': <dynamic>[
        'Vérifier le cumul avec l’emploi public.',
        42,
      ],
      'summary': <String, dynamic>{
        'nextAction': 'Demander une autorisation',
        'niveau_risque': 'Modéré',
      },
      'costs': <String, dynamic>{
        'cout_initial': 120,
        'details': <String, dynamic>{
          'inscription': 10,
          'assurance': 20,
        },
        'postes': <String>['Matériel', 'Communication'],
      },
      'regulationTutorial': <dynamic>[
        <String, dynamic>{
          'title': 'Vérifier le cumul',
          'description': 'Consulter son administration.',
          'todos': <String>['Demander une autorisation'],
          'checks': 'Obtenir un accord écrit',
        },
      ],
      'statusWarnings': <dynamic>[
        <String, dynamic>{
          'label': 'Temps de travail',
          'text': 'Respecter les limites applicables.',
        },
      ],
      'aides': <dynamic>[
        <String, dynamic>{
          'name': 'ACRE',
          'summary': 'Réduction temporaire de cotisations.',
        },
      ],
      'plan30': <dynamic>[
        <String, dynamic>{
          'title': 'Semaine 1',
          'description': 'Valider le droit d’exercer.',
          'todos': <String>['Lister les justificatifs'],
        },
      ],
      'steps': <dynamic>[
        12,
        <String, dynamic>{},
        <String, dynamic>{
          'title': 'Immatriculation',
          'checks': <String>['Conserver le récépissé'],
        },
      ],
    };

    await tester.pumpWidget(_host(snapshot));

    expect(find.text('Mon parcours personnalisé'), findsOneWidget);
    expect(find.text('Photographe'), findsAtLeastNWidgets(1));
    expect(find.text('Sauvegardé le 05/07/2026'), findsOneWidget);
    expect(find.text('Guadeloupe'), findsOneWidget);
    expect(find.text('Fonctionnaire'), findsOneWidget);
    expect(find.text('Recommandation'), findsOneWidget);
    expect(find.text('Micro-entreprise'), findsOneWidget);
    expect(find.text('Une structure rapide à créer.'), findsOneWidget);
    expect(find.text('Le régime correspond à cette activité.'), findsOneWidget);

    await _scrollTo(tester, 'Alertes importantes');
    expect(find.text('Vérifier le cumul avec l’emploi public.'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);

    await _scrollTo(tester, 'Résumé du parcours');
    final summaryValues = _visibleRichTextValues(tester);
    expect(
      summaryValues,
      contains('Next Action : Demander une autorisation'),
    );
    expect(summaryValues, contains('Niveau risque : Modéré'));

    await _scrollTo(tester, 'Coûts et points financiers');
    final costValues = _visibleRichTextValues(tester);
    expect(costValues, contains('Cout initial : 120'));
    expect(
      costValues,
      contains('Details : Inscription : 10 · Assurance : 20'),
    );
    expect(costValues, contains('Postes : Matériel · Communication'));

    await _scrollTo(tester, 'Réglementation et démarches');
    expect(find.text('Vérifier le cumul'), findsOneWidget);
    expect(find.text('Consulter son administration.'), findsOneWidget);
    expect(find.text('Demander une autorisation'), findsOneWidget);
    expect(find.text('Obtenir un accord écrit'), findsOneWidget);

    await _scrollTo(tester, 'Points de vigilance liés au statut');
    expect(find.text('Temps de travail'), findsOneWidget);
    expect(find.text('Respecter les limites applicables.'), findsOneWidget);

    await _scrollTo(tester, 'Aides possibles');
    expect(find.text('ACRE'), findsOneWidget);
    expect(
      find.text('Réduction temporaire de cotisations.'),
      findsOneWidget,
    );

    await _scrollTo(tester, 'Plan d’action 30 jours');
    expect(find.text('Semaine 1'), findsOneWidget);
    expect(find.text('Valider le droit d’exercer.'), findsOneWidget);
    expect(find.text('Lister les justificatifs'), findsOneWidget);

    await _scrollTo(tester, 'Étapes détaillées');
    expect(find.text('Étape'), findsOneWidget);
    expect(find.text('Immatriculation'), findsOneWidget);
    expect(find.text('Conserver le récépissé'), findsOneWidget);
  });

  testWidgets('uses alternate keys and filters malformed list entries',
      (tester) async {
    final snapshot = <String, dynamic>{
      'projectLabel': 'Projet couture',
      'savedAt': 'date invalide',
      'region': ' ',
      'currentStatus': '',
      'selectedActivity': '',
      'recommendation': <String, dynamic>{
        'recommended': 'Entreprise individuelle',
        'justification': 'Une justification alternative.',
      },
      'blockingAlerts': 'not-a-list',
      'summary': 'not-a-map',
      'costs': 12,
      'regulationTutorial': 'not-a-list',
      'statusWarnings': null,
      'aides': false,
      'plan30': <dynamic>[false],
      'steps': <dynamic>[
        42,
        <String, dynamic>{
          'label': 'Démarrer',
          'text': 'Commencer simplement.',
          'todos': 'Action unique',
          'checks': const <String>[],
        },
      ],
    };

    await tester.pumpWidget(_host(snapshot));

    expect(find.text('Projet couture'), findsOneWidget);
    expect(find.text('Parcours sauvegardé'), findsOneWidget);
    expect(find.text('Région non renseignée'), findsOneWidget);
    expect(find.text('Statut non renseigné'), findsOneWidget);
    expect(find.text('Activité non renseignée'), findsOneWidget);
    expect(find.text('Entreprise individuelle'), findsOneWidget);
    expect(find.text('Une justification alternative.'), findsOneWidget);
    expect(find.text('Alertes importantes'), findsNothing);
    expect(find.text('Résumé du parcours'), findsNothing);
    expect(find.text('Coûts et points financiers'), findsNothing);

    await _scrollTo(tester, 'Étapes détaillées');
    expect(find.text('Démarrer'), findsOneWidget);
    expect(find.text('Commencer simplement.'), findsOneWidget);
    expect(find.text('Action unique'), findsOneWidget);
  });

  testWidgets('renders safe defaults for an empty snapshot', (tester) async {
    await tester.pumpWidget(_host(const <String, dynamic>{}));

    expect(find.text('Mon parcours personnalisé'), findsNWidgets(2));
    expect(find.text('Parcours sauvegardé'), findsOneWidget);
    expect(find.text('Région non renseignée'), findsOneWidget);
    expect(find.text('Statut non renseigné'), findsOneWidget);
    expect(find.text('Activité non renseignée'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Alertes importantes'), findsNothing);
    expect(find.text('Résumé du parcours'), findsNothing);
    expect(find.text('Coûts et points financiers'), findsNothing);
  });
}
