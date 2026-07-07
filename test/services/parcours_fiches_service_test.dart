import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/parcours_fiches_service.dart';

void main() {
  group('mapFonctionnaireFicheToDerivedData', () {
    test('mappe une activité réglementée de restauration', () {
      final derived = mapFonctionnaireFicheToDerivedData(
        fiche: _serviceEnSalle,
        region: 'Île-de-France',
        currentStatus: 'Fonctionnaire / agent public',
      );

      final regulationTutorial =
          (derived['regulationTutorial'] as List).cast<Map<String, dynamic>>();
      final summary = (derived['summary'] as Map).cast<String, dynamic>();
      final blockingAlerts = (derived['blockingAlerts'] as List).cast<String>();

      expect(regulationTutorial, hasLength(4));
      expect(
        '${regulationTutorial.first['description']}',
        contains('hygiène alimentaire'),
      );
      expect(
        '${regulationTutorial[1]['title']}',
        'Cumul et obligations d’agent public',
      );
      expect(summary['vigilanceLevel'], 'Élevé');
      expect(
        blockingAlerts.any((item) => item.contains('alcool')),
        isTrue,
      );
    });

    test('mappe une activité non réglementée de type informatique', () {
      final derived = mapFonctionnaireFicheToDerivedData(
        fiche: _informatiqueDepannage,
        region: 'Occitanie',
        currentStatus: 'Fonctionnaire / agent public',
      );

      final regulationTutorial =
          (derived['regulationTutorial'] as List).cast<Map<String, dynamic>>();
      final blockingAlerts = (derived['blockingAlerts'] as List).cast<String>();
      final costs = (derived['costs'] as Map).cast<String, dynamic>();

      expect(regulationTutorial, hasLength(4));
      expect(
        '${regulationTutorial.first['description']}',
        contains('activités accessoires pouvant être autorisées'),
      );
      expect(
        '${regulationTutorial.last['description']}',
        contains('source(s) recensée(s)'),
      );
      expect(
        blockingAlerts.any((item) => item.contains('Activité réglementée')),
        isFalse,
      );
      expect('${costs['note']}', contains('Seuil micro service 2026'));
    });

    test('mappe une activité SAP/comptable avec alertes sensibles', () {
      final derived = mapFonctionnaireFicheToDerivedData(
        fiche: _aideAdministrativeComptable,
        region: 'Martinique',
        currentStatus: 'Fonctionnaire / agent public',
      );

      final regulationTutorial =
          (derived['regulationTutorial'] as List).cast<Map<String, dynamic>>();
      final statusWarnings =
          (derived['statusWarnings'] as List).cast<Map<String, dynamic>>();
      final steps = (derived['steps'] as List).cast<Map<String, dynamic>>();
      final aids = (derived['aides'] as List).cast<Map<String, dynamic>>();

      expect(
        '${regulationTutorial.first['description']}',
        contains('services à la personne'),
      );
      expect(
        '${statusWarnings.first['description']}',
        contains('autorisation hiérarchique'),
      );
      expect(steps, isNotEmpty);
      expect('${steps[3]['title']}', 'Préparer et déposer les formalités');
      expect(
        aids.any((item) => '${item['name']}' == 'Nova SAP'),
        isTrue,
      );
    });
  });
}

const Map<String, dynamic> _serviceEnSalle = <String, dynamic>{
  'activite': 'Service en salle',
  'categorie': 'Restauration / Extra',
  'niveau_vigilance': 'élevé',
  'qualification_regles':
      'Vérifier hygiène alimentaire. En restauration commerciale, au moins une personne de l\'établissement doit avoir suivi la formation hygiène alimentaire de 14 h minimum. Si manipulation de denrées animales ou d\'origine animale, déclaration sanitaire préalable. Si alcool, licence, permis d\'exploitation et déclaration préalable selon le cas.',
  'organisme_cumul': 'Administration employeur / autorité hiérarchique',
  'activite_reglementee': true,
  'statut_recommande':
      'micro-entrepreneur / entreprise individuelle sous réserve d\'autorisation de cumul',
  'statut_alternatif': <String>['EI réel', 'EURL', 'SASU'],
  'assurances': <String>[
    'RC pro restauration/événementiel',
    'Assurance intoxication alimentaire',
  ],
  'documents_a_collecter': <String>[
    'demande écrite d\'autorisation de cumul',
    'réponse écrite de l\'administration',
    'pièce d\'identité',
  ],
  'alertes': <String>[
    'Ne pas vendre d\'alcool sans licence/déclaration adaptée',
    'Ne pas manipuler de denrées animales sans vérifier la déclaration sanitaire',
  ],
  'sources_officielles': <String>[
    'https://entreprendre.service-public.gouv.fr/vosdroits/F36610',
    'https://www.service-public.fr/particuliers/vosdroits/F1648',
  ],
  'fiscalite': <String, dynamic>{
    'seuil_micro_service_2026': '83 600 €',
    'tva_franchise_service_base': '37 500 €',
  },
  'couts_indicatifs': <String>[
    'Formalités micro-entreprise généralement gratuites',
  ],
  'organismes_accompagnement': <String>[
    'Administration employeur',
    'Guichet unique INPI',
    'Urssaf',
  ],
  'parcours': <String, dynamic>{
    '2_situation_personnelle':
        'Vérifier fonction publique, temps de travail, poste, conflit d\'intérêts, autorisation hiérarchique, devoir de neutralité et justificatifs.',
    '3_cadre':
        'Micro-entreprise conseillée pour activité accessoire simple, sous réserve d\'autorisation et de seuils ; basculer vers EI réel/société si projet lourd.',
    '4_demarches': <String>[
      'décrire l\'activité',
      'demander autorisation ou déclaration',
      'vérifier qualification',
    ],
    '5_aides': <String>['ACRE', 'CMA/CCI/BGE'],
    '7_plan_30_jours': <String>[
      'semaine 1 : droit d\'exercer et offre',
      'semaine 2 : autorisation/formalités',
    ],
  },
  'legal_review_status':
      'socle officiel intégré ; contrôle final recommandé par CMA/administration/organisme compétent selon activité avant mise en production',
};

const Map<String, dynamic> _informatiqueDepannage = <String, dynamic>{
  'activite': 'Informatique / dépannage',
  'categorie': 'Autre',
  'niveau_vigilance': 'moyen',
  'qualification_regles':
      'L\'enseignement/formation fait partie des activités accessoires pouvant être autorisées pour un agent public. Pour le coaching sportif rémunéré, vérifier diplôme, carte professionnelle d\'éducateur sportif et obligations d\'affichage/assurance. Pour soutien scolaire à domicile, vérifier SAP/Nova si avantage fiscal client recherché.',
  'organisme_cumul': 'Administration employeur / autorité hiérarchique',
  'activite_reglementee': false,
  'nature_fiscale_probable': 'prestation_services_bnc_ou_bic',
  'statut_recommande':
      'micro-entrepreneur / entreprise individuelle sous réserve d\'autorisation de cumul',
  'statut_alternatif': <String>['EI réel', 'EURL', 'SASU'],
  'assurances': <String>['RC pro formation/coaching'],
  'documents_a_collecter': <String>[
    'demande écrite d\'autorisation de cumul',
    'réponse écrite de l\'administration',
  ],
  'alertes': <String>[
    'Ne pas utiliser les moyens, fichiers ou informations de l\'administration',
  ],
  'sources_officielles': <String>[
    'https://entreprendre.service-public.gouv.fr/vosdroits/F36610',
    'https://entreprendre.service-public.gouv.fr/vosdroits/F23633',
  ],
  'fiscalite': <String, dynamic>{
    'seuil_micro_service_2026': '83 600 €',
    'tva_franchise_service_base': '37 500 €',
  },
  'couts_indicatifs': <String>['Supports pédagogiques : 20 à 300 €'],
  'organismes_accompagnement': <String>[
    'Administration employeur',
    'Guichet unique INPI',
    'Urssaf',
  ],
  'parcours': <String, dynamic>{
    '2_situation_personnelle':
        'Vérifier fonction publique, temps de travail, poste, conflit d\'intérêts, autorisation hiérarchique, devoir de neutralité et justificatifs.',
    '3_cadre':
        'Micro-entreprise conseillée pour activité accessoire simple, sous réserve d\'autorisation et de seuils ; basculer vers EI réel/société si projet lourd.',
    '4_demarches': <String>[
      'décrire l\'activité',
      'déclarer au Guichet unique'
    ],
    '5_aides': <String>['ACRE', 'Région'],
    '7_plan_30_jours': <String>['semaine 1 : droit d\'exercer et offre'],
  },
  'legal_review_status':
      'socle officiel intégré ; contrôle final recommandé par CMA/administration/organisme compétent selon activité avant mise en production',
};

const Map<String, dynamic> _aideAdministrativeComptable = <String, dynamic>{
  'activite': 'Aide administrative / comptable',
  'categorie': 'Autre',
  'niveau_vigilance': 'moyen',
  'qualification_regles':
      'Vérifier si l\'activité relève des services à la personne. La déclaration SAP via Nova peut être nécessaire pour ouvrir droit aux avantages clients. L\'agrément est requis pour certaines activités auprès d\'enfants de moins de 3 ans ou d\'enfants handicapés ; l\'autorisation peut être requise pour certaines interventions auprès de personnes âgées ou handicapées en mode prestataire.',
  'organisme_cumul': 'Administration employeur / autorité hiérarchique',
  'activite_reglementee': true,
  'statut_recommande':
      'micro-entrepreneur / entreprise individuelle sous réserve d\'autorisation de cumul',
  'statut_alternatif': <String>['EI réel', 'EURL', 'SASU'],
  'assurances': <String>[
    'RC pro aide à domicile',
    'Protection juridique recommandée',
  ],
  'documents_a_collecter': <String>[
    'demande écrite d\'autorisation de cumul',
    'réponse écrite de l\'administration',
    'pièce d\'identité',
  ],
  'alertes': <String>[
    'Ne pas se présenter comme expert-comptable ou conseil juridique',
    'Limiter l\'aide comptable à de l\'assistance administrative ; ne pas exercer l\'expertise comptable réglementée sans inscription à l\'Ordre.',
  ],
  'sources_officielles': <String>[
    'https://entreprendre.service-public.gouv.fr/vosdroits/F36610',
    'https://entreprendre.service-public.gouv.fr/vosdroits/R19148',
  ],
  'fiscalite': <String, dynamic>{
    'seuil_micro_service_2026': '83 600 €',
    'tva_franchise_service_base': '37 500 €',
  },
  'couts_indicatifs': <String>[
    'Matériel de ménage ou organisation : 50 à 300 €'
  ],
  'organismes_accompagnement': <String>[
    'Administration employeur',
    'Nova SAP',
    'DDETS/DEETS',
  ],
  'parcours': <String, dynamic>{
    '2_situation_personnelle':
        'Vérifier fonction publique, temps de travail, poste, conflit d\'intérêts, autorisation hiérarchique, devoir de neutralité et justificatifs.',
    '3_cadre':
        'Micro-entreprise conseillée pour activité accessoire simple, sous réserve d\'autorisation et de seuils ; basculer vers EI réel/société si projet lourd.',
    '4_demarches': <String>[
      'décrire l\'activité',
      'déclarer au Guichet unique'
    ],
    '5_aides': <String>['ACRE', 'Région'],
    '7_plan_30_jours': <String>['semaine 1 : droit d\'exercer et offre'],
  },
  'legal_review_status':
      'socle officiel intégré ; contrôle final recommandé par CMA/administration/organisme compétent selon activité avant mise en production',
};
