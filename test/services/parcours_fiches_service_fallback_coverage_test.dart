import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/parcours_fiches_service.dart';

void main() {
  const ficheSansRecommandation = <String, dynamic>{
    'activite': 'Conseil numérique',
    'categorie': '',
    'niveau_vigilance': '',
    'activite_reglementee': false,
    'parcours': <String, dynamic>{},
  };

  test('utilise les fallbacks juridiques et le plan 30 fourni', () {
    final derived = mapFonctionnaireFicheToDerivedData(
      fiche: ficheSansRecommandation,
      region: 'Guadeloupe',
      currentStatus: 'Fonctionnaire / agent public',
      fallback: <String, dynamic>{
        'recommendation': <String, dynamic>{
          'statut': 'Statut de recommandation',
          'why': 'Justification de recommandation',
          'planB': 'Plan B de recommandation',
        },
        'recommendedLegalStatus': <String, dynamic>{
          'recommended': 'SASU de secours',
          'justification': 'Justification juridique de secours',
          'planB': 'Portage salarial',
        },
        'plan30': <Map<String, dynamic>>[
          <String, dynamic>{
            'week': 'Semaine 1',
            'label': 'Valider le cumul',
            'done': false,
          },
        ],
        'blockingAlerts': <String>[
          'Conserver l autorisation écrite',
          'Conserver l autorisation écrite',
          '   ',
        ],
      },
    );

    final legal =
        (derived['recommendedLegalStatus'] as Map).cast<String, dynamic>();
    final recommendation =
        (derived['recommendation'] as Map).cast<String, dynamic>();
    final summary = (derived['summary'] as Map).cast<String, dynamic>();
    final plan30 =
        (derived['plan30'] as List).cast<Map<String, dynamic>>();
    final alerts = (derived['blockingAlerts'] as List).cast<String>();

    expect(legal['recommended'], 'SASU de secours');
    expect(legal['justification'], 'Justification juridique de secours');
    expect(legal['planB'], 'Portage salarial');
    expect(recommendation['statut'], 'SASU de secours');
    expect(recommendation['why'], 'Justification juridique de secours');
    expect(recommendation['planB'], 'Portage salarial');
    expect(plan30, hasLength(1));
    expect(plan30.single['label'], 'Valider le cumul');
    expect(alerts, <String>['Conserver l autorisation écrite']);
    expect(summary['recommendedPath'], 'Création progressive');
    expect(summary['vigilanceLevel'], 'Moyen');
  });

  test('retombe sur la recommandation quand le fallback juridique est absent',
      () {
    final derived = mapFonctionnaireFicheToDerivedData(
      fiche: ficheSansRecommandation,
      region: 'Martinique',
      currentStatus: 'Agent public',
      fallback: <String, dynamic>{
        'recommendation': <String, dynamic>{
          'statut': 'Micro-entreprise de secours',
          'why': 'Démarrage progressif',
          'planB': 'Coopérative d activité',
        },
      },
    );

    final legal =
        (derived['recommendedLegalStatus'] as Map).cast<String, dynamic>();
    final costs = (derived['costs'] as Map).cast<String, dynamic>();

    expect(legal['recommended'], 'Micro-entreprise de secours');
    expect(legal['justification'], 'Démarrage progressif');
    expect(legal['planB'], 'Coopérative d activité');
    expect(derived['plan30'], isEmpty);
    expect(costs['formalitesEstimees'], <String, dynamic>{
      'min': 0,
      'max': 120,
    });
  });
}
