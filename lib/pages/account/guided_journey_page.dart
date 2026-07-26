import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:presto_app/features/subscriptions/journey_entitlements_service.dart';
import 'package:presto_app/services/journey_local_storage_service.dart';
import 'package:presto_app/services/journey_pdf_export_service.dart';
import 'package:presto_app/services/region_resources_service.dart';
import 'package:presto_app/services/screen_capture_protection_service.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _kJourneyOrange = Color(0xFFFF6600);
const Color _kJourneyBlue = Color(0xFF1A73E8);
const Color _kJourneyBackground = Color(0xFFF6F7FB);
const Color _kJourneyText = Color(0xFF071B4D);
const Color _kJourneyMuted = Color(0xFF66728A);

enum JourneyStageStatus { todo, doing, done }

class JourneyResourceLink {
  final String label;
  final String description;
  final String url;
  final String organization;
  final String category;
  final String region;
  final int priority;
  final bool isOfficial;

  const JourneyResourceLink({
    required this.label,
    required this.description,
    required this.url,
    this.organization = '',
    this.category = 'Ressource utile',
    this.region = '',
    this.priority = 100,
    this.isOfficial = true,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'label': label,
        'description': description,
        'url': url,
        'organization': organization,
        'category': category,
        'region': region,
        'priority': priority,
        'isOfficial': isOfficial,
      };
}

class JourneyChecklistItem {
  final String id;
  final String label;
  bool done;

  JourneyChecklistItem({
    required this.id,
    required this.label,
    this.done = false,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'label': label,
        'done': done,
      };
}

class JourneyStage {
  final String id;
  final int order;
  final String title;
  final String objective;
  final int estimatedMinutes;
  final String explanation;
  final String personalizedSummary;
  final List<String> warnings;
  final List<JourneyChecklistItem> checklist;
  final List<String> documents;
  final List<String> detailedInformation;
  final List<JourneyResourceLink> links;
  final bool isBlocking;
  JourneyStageStatus status;

  JourneyStage({
    required this.id,
    required this.order,
    required this.title,
    required this.objective,
    required this.estimatedMinutes,
    required this.explanation,
    required this.personalizedSummary,
    this.warnings = const <String>[],
    this.checklist = const <JourneyChecklistItem>[],
    this.documents = const <String>[],
    this.detailedInformation = const <String>[],
    this.links = const <JourneyResourceLink>[],
    this.isBlocking = false,
    this.status = JourneyStageStatus.todo,
  });

  bool get isComplete => status == JourneyStageStatus.done;
  int get completedChecklistCount => checklist.where((item) => item.done).length;
}

/// Renderer commun des parcours générés, repris et sauvegardés.
///
/// Toutes les fiches activité/statut utilisent ce même guide : aperçu global,
/// une étape active à la fois, checklist, documents, détails repliables,
/// ressources cliquables et reprise de progression.
class GuidedJourneyPage extends StatefulWidget {
  final String projectLabel;
  final String region;
  final String currentStatus;
  final String selectedActivity;
  final Map<String, dynamic> recommendation;
  final List<String> blockingAlerts;
  final Map<String, dynamic> costs;
  final List<Map<String, dynamic>> aides;
  final List<Map<String, dynamic>> plan30;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> regulationTutorial;
  final List<Map<String, dynamic>> statusWarnings;
  final Map<String, dynamic> recommendedLegalStatus;
  final List<Map<String, dynamic>> steps;
  final Map<String, dynamic> guidedProgress;
  final String? savedAt;

  const GuidedJourneyPage({
    super.key,
    required this.projectLabel,
    required this.region,
    required this.currentStatus,
    required this.selectedActivity,
    required this.recommendation,
    required this.blockingAlerts,
    required this.costs,
    required this.aides,
    required this.plan30,
    required this.summary,
    required this.regulationTutorial,
    required this.statusWarnings,
    required this.recommendedLegalStatus,
    required this.steps,
    this.guidedProgress = const <String, dynamic>{},
    this.savedAt,
  });

  @override
  State<GuidedJourneyPage> createState() => _GuidedJourneyPageState();
}

class _GuidedJourneyPageState extends State<GuidedJourneyPage> {
  static const JourneyLocalStorageService _storage =
      JourneyLocalStorageService();
  static const JourneyPdfExportService _pdf = JourneyPdfExportService();
  static final JourneyEntitlementsService _entitlements =
      JourneyEntitlementsService();

  late final List<JourneyStage> _stages;
  int _activeIndex = -1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _stages = _buildStages();
    _restoreProgress();
    unawaited(
      ScreenCaptureProtection.enable().catchError((Object error) {
        debugPrint('[GuidedJourney] screen protection unavailable: $error');
      }),
    );
  }

  @override
  void dispose() {
    unawaited(
      ScreenCaptureProtection.disable().catchError((Object error) {
        debugPrint('[GuidedJourney] screen protection reset failed: $error');
      }),
    );
    super.dispose();
  }

  String get _activity {
    final fromSummary = '${widget.summary['activity'] ?? ''}'.trim();
    if (fromSummary.isNotEmpty) return fromSummary;
    if (widget.selectedActivity.trim().isNotEmpty) {
      return widget.selectedActivity.trim();
    }
    return widget.projectLabel.trim().isNotEmpty
        ? widget.projectLabel.trim()
        : 'votre activité';
  }

  String get _region {
    final fromSummary = '${widget.summary['region'] ?? ''}'.trim();
    return fromSummary.isNotEmpty ? fromSummary : widget.region.trim();
  }

  String get _status {
    final fromSummary = '${widget.summary['currentStatus'] ?? ''}'.trim();
    return fromSummary.isNotEmpty ? fromSummary : widget.currentStatus.trim();
  }

  List<JourneyStage> _buildStages() {
    final resources = getRegionResources(_region);
    final legalStatus =
        '${widget.recommendedLegalStatus['recommended'] ?? widget.recommendation['statut'] ?? 'le cadre conseillé'}';
    final legalWhy =
        '${widget.recommendedLegalStatus['justification'] ?? widget.recommendation['why'] ?? ''}'
            .trim();
    final legalPlanB =
        '${widget.recommendedLegalStatus['planB'] ?? widget.recommendation['planB'] ?? ''}'
            .trim();

    final regulationDetails = <String>[
      for (final item in widget.regulationTutorial)
        _joinNonEmpty(<String>[
          '${item['title'] ?? ''}'.trim(),
          '${item['description'] ?? ''}'.trim(),
        ]),
    ].where((item) => item.isNotEmpty).toList();

    final statusDetails = <String>[
      for (final item in widget.statusWarnings)
        _joinNonEmpty(<String>[
          '${item['title'] ?? ''}'.trim(),
          '${item['description'] ?? ''}'.trim(),
          ..._stringList(item['checks']),
        ]),
    ].where((item) => item.isNotEmpty).toList();

    final prepareTodos = _todosMatching(
      <String>['prépar', 'document', 'dossier', 'information'],
    );
    final declareTodos = _todosMatching(
      <String>['déclar', 'formalit', 'guichet', 'immatric'],
    );
    final secureTodos = _todosMatching(
      <String>['assurance', 'banque', 'facture', 'devis', 'gestion', 'protection'],
    );

    final relevantAides = widget.aides
        .where((item) => (item['relevant'] ?? true) == true)
        .toList();
    final costDetails = _costDetails();

    return <JourneyStage>[
      JourneyStage(
        id: 'rules',
        order: 1,
        title: 'Comprendre les règles de mon activité',
        objective:
            'Identifier les obligations, qualifications et assurances avant de commencer.',
        estimatedMinutes: 6,
        explanation:
            'Cette première étape évite de lancer une activité sans avoir vérifié les règles essentielles. Les informations ci-dessous sont adaptées à votre activité.',
        personalizedSummary:
            'Vous souhaitez exercer $_activity${_region.isEmpty ? '' : ' en $_region'}. Vérifiez d’abord si cette activité est libre, réglementée ou soumise à une assurance particulière.',
        warnings: List<String>.from(widget.blockingAlerts),
        checklist: _checklist(
          regulationDetails.isEmpty
              ? <String>[
                  'Vérifier si mon activité est réglementée',
                  'Identifier les qualifications ou autorisations nécessaires',
                  'Vérifier les assurances obligatoires ou recommandées',
                ]
              : widget.regulationTutorial
                  .map((item) => '${item['title'] ?? 'Vérification réglementaire'}')
                  .toList(),
          'rules',
        ),
        documents: const <String>[
          'Description précise de l’activité exercée',
          'Diplômes, attestations ou justificatifs d’expérience si nécessaires',
          'Devis ou proposition d’assurance professionnelle',
        ],
        detailedInformation: regulationDetails,
        links: _selectResources(
          resources,
          <String>['cma', 'artisanat', 'cci', 'urssaf'],
          extraTexts: regulationDetails,
          category: 'Réglementation',
        ),
        isBlocking: widget.blockingAlerts.isNotEmpty,
      ),
      JourneyStage(
        id: 'personal-status',
        order: 2,
        title: 'Vérifier ma situation personnelle',
        objective:
            'Contrôler les règles de cumul, droits et précautions liés à votre statut actuel.',
        estimatedMinutes: 5,
        explanation:
            'Votre statut actuel peut modifier les démarches à effectuer, les autorisations à demander et certaines aides disponibles.',
        personalizedSummary:
            'Votre situation actuelle est « ${_status.isEmpty ? 'non renseignée' : _status} ». Le guide met en avant les contrôles utiles avant toute déclaration.',
        checklist: _checklist(
          _statusChecklist(),
          'personal-status',
        ),
        documents: _statusDocuments(),
        detailedInformation: statusDetails,
        links: _selectResources(
          resources,
          _status.toLowerCase().contains('demandeur')
              ? <String>['france travail', 'urssaf', 'bge']
              : <String>['bge', 'cci', 'artisanat'],
          extraTexts: statusDetails,
          category: 'Situation personnelle',
        ),
        warnings: statusDetails,
        isBlocking: _status.toLowerCase().contains('fonctionnaire'),
      ),
      JourneyStage(
        id: 'legal-frame',
        order: 3,
        title: 'Choisir mon cadre de lancement',
        objective:
            'Comprendre la recommandation de statut et savoir quand demander une validation.',
        estimatedMinutes: 5,
        explanation:
            'Le statut recommandé est une orientation de départ. Il doit rester cohérent avec vos charges, votre chiffre d’affaires visé et votre besoin de protection.',
        personalizedSummary:
            'Pour démarrer, le parcours propose : $legalStatus.${legalWhy.isEmpty ? '' : ' $legalWhy'}',
        checklist: _checklist(
          <String>[
            'Comparer la recommandation avec mes besoins réels',
            'Vérifier le régime fiscal et social associé',
            'Faire valider le choix en cas de doute ou d’investissement important',
          ],
          'legal-frame',
        ),
        documents: const <String>[
          'Estimation du chiffre d’affaires',
          'Liste des dépenses professionnelles prévues',
          'Hypothèses de développement ou d’association',
        ],
        detailedInformation: <String>[
          if (legalWhy.isNotEmpty) legalWhy,
          if (legalPlanB.isNotEmpty) 'Alternative si le projet évolue : $legalPlanB',
          '${widget.recommendedLegalStatus['disclaimer'] ?? ''}'.trim(),
        ].where((item) => item.isNotEmpty).toList(),
        links: _selectResources(
          resources,
          <String>['urssaf', 'cci', 'bge', 'artisanat'],
          category: 'Choix du statut',
        ),
      ),
      JourneyStage(
        id: 'prepare-file',
        order: 4,
        title: 'Préparer mon dossier',
        objective:
            'Réunir les informations et justificatifs avant d’ouvrir la formalité.',
        estimatedMinutes: 10,
        explanation:
            'Préparer le dossier en amont réduit les interruptions et les erreurs pendant la déclaration en ligne.',
        personalizedSummary:
            'Votre dossier doit décrire clairement l’activité « $_activity » et contenir les justificatifs liés à votre situation.',
        checklist: _checklist(
          prepareTodos.isEmpty
              ? <String>[
                  'Rassembler mes informations personnelles et mon adresse',
                  'Rédiger une description précise de mon activité principale',
                  'Préparer les justificatifs, diplômes et autorisations utiles',
                  'Noter mes choix fiscaux et sociaux à vérifier',
                ]
              : prepareTodos,
          'prepare-file',
        ),
        documents: <String>[
          'Pièce d’identité et justificatif d’adresse',
          'Description de l’activité principale et des activités secondaires',
          'Diplômes, attestations ou autorisations selon le métier',
          if (_status.toLowerCase().contains('fonctionnaire'))
            'Autorisation ou demande écrite liée au cumul d’activités',
        ],
        detailedInformation: _stepDetailsMatching(
          <String>['prépar', 'document', 'dossier'],
        ),
        links: _selectResources(
          resources,
          <String>['cci', 'artisanat', 'bge'],
          category: 'Préparation du dossier',
        ),
      ),
      JourneyStage(
        id: 'declare',
        order: 5,
        title: 'Déclarer mon activité',
        objective:
            'Réaliser la formalité dans le bon ordre et conserver les justificatifs.',
        estimatedMinutes: 15,
        explanation:
            'La déclaration officielle s’effectue sur le guichet compétent. Avancez écran par écran et relisez toutes les informations avant l’envoi.',
        personalizedSummary:
            'Votre activité « $_activity » est prête à être déclarée dès que les étapes précédentes sont validées.',
        checklist: _checklist(
          declareTodos.isEmpty
              ? <String>[
                  'Ouvrir le guichet unique officiel',
                  'Créer ou utiliser mon compte',
                  'Choisir la formalité de création adaptée',
                  'Renseigner les informations et joindre les documents',
                  'Relire, déposer et conserver l’accusé de réception',
                ]
              : declareTodos,
          'declare',
        ),
        documents: const <String>[
          'Dossier préparé à l’étape précédente',
          'Choix du statut de lancement',
          'Moyen de paiement si des frais sont demandés',
          'Copie de l’accusé de dépôt après validation',
        ],
        detailedInformation: _stepDetailsMatching(
          <String>['déclar', 'formalit', 'guichet', 'immatric'],
        ),
        links: _selectResources(
          resources,
          <String>['guichet unique', 'inpi', 'urssaf'],
          category: 'Formalités officielles',
        ),
      ),
      JourneyStage(
        id: 'secure-launch',
        order: 6,
        title: 'Sécuriser mon lancement',
        objective:
            'Mettre en place les protections, documents commerciaux et outils de gestion.',
        estimatedMinutes: 10,
        explanation:
            'Une activité déclarée doit aussi être protégée et organisée. Cette étape rassemble les actions à terminer avant les premières prestations.',
        personalizedSummary:
            'Pour $_activity, vérifiez en priorité l’assurance, les devis et factures, ainsi que le suivi des recettes et dépenses.',
        checklist: _checklist(
          secureTodos.isEmpty
              ? <String>[
                  'Souscrire l’assurance professionnelle utile',
                  'Préparer mes modèles de devis et facture',
                  'Organiser le suivi des recettes, dépenses et justificatifs',
                  'Ouvrir un compte dédié si nécessaire',
                  'Vérifier mes mentions obligatoires et conditions de vente',
                ]
              : secureTodos,
          'secure-launch',
        ),
        documents: const <String>[
          'Attestation d’assurance',
          'Modèle de devis',
          'Modèle de facture',
          'Tableau ou outil de suivi de gestion',
        ],
        detailedInformation: <String>[
          ..._stepDetailsMatching(
            <String>['assurance', 'banque', 'facture', 'devis', 'gestion'],
          ),
          ...costDetails.where(
            (item) => item.toLowerCase().contains('assurance') ||
                item.toLowerCase().contains('banque'),
          ),
        ],
        links: _selectResources(
          resources,
          <String>['cci', 'artisanat', 'bpifrance', 'urssaf'],
          category: 'Sécurisation',
        ),
      ),
      JourneyStage(
        id: 'aids-budget',
        order: 7,
        title: 'Identifier les aides et mon budget',
        objective:
            'Vérifier les aides réellement pertinentes et anticiper les coûts de démarrage.',
        estimatedMinutes: 8,
        explanation:
            'Les aides ne sont utiles que si les conditions et le calendrier sont respectés. Les coûts affichés restent indicatifs et doivent être confirmés.',
        personalizedSummary:
            '${relevantAides.length} aide(s) pertinente(s) et ${costDetails.length} poste(s) de coût ont été identifiés pour votre parcours.',
        checklist: _checklist(
          <String>[
            for (final aid in relevantAides)
              'Vérifier mon éligibilité à ${aid['name'] ?? 'cette aide'}',
            'Confirmer les coûts obligatoires avant de payer',
            'Établir mon budget de lancement',
          ],
          'aids-budget',
        ),
        documents: const <String>[
          'Budget prévisionnel simple',
          'Devis des principales dépenses',
          'Justificatifs demandés par les organismes financeurs',
          'Calendrier des demandes d’aide',
        ],
        detailedInformation: <String>[
          for (final aid in relevantAides)
            '${aid['name'] ?? 'Aide'} : ${aid['desc'] ?? ''}',
          ...costDetails,
        ],
        links: _selectResources(
          resources,
          <String>[
            'aides-territoires',
            'bpifrance',
            'france travail',
            'initiative',
            'région',
            'collectivité',
            'lodeom',
          ],
          category: 'Aides et financements',
        ),
      ),
      JourneyStage(
        id: 'plan-30',
        order: 8,
        title: 'Suivre mon plan d’action sur 30 jours',
        objective:
            'Passer de la préparation au lancement avec une feuille de route hebdomadaire.',
        estimatedMinutes: 5,
        explanation:
            'Le plan sur 30 jours transforme le parcours en actions concrètes. Avancez semaine par semaine et cochez chaque tâche terminée.',
        personalizedSummary:
            '${widget.plan30.length} action(s) sont planifiées pour lancer progressivement votre activité.',
        checklist: _checklist(
          widget.plan30.isEmpty
              ? <String>[
                  'Semaine 1 — Comprendre et vérifier',
                  'Semaine 2 — Préparer',
                  'Semaine 3 — Déclarer et sécuriser',
                  'Semaine 4 — Lancer et ajuster',
                ]
              : widget.plan30
                  .map(
                    (item) =>
                        '${item['week'] ?? 'À planifier'} — ${item['label'] ?? ''}',
                  )
                  .toList(),
          'plan-30',
        ),
        documents: const <String>[
          'Calendrier personnel des actions',
          'Liste des organismes à contacter',
          'Liste des premiers clients ou partenaires à approcher',
        ],
        detailedInformation: <String>[
          for (final item in widget.plan30)
            '${item['week'] ?? ''} : ${item['label'] ?? ''}',
        ],
        links: _selectResources(
          resources,
          const <String>[],
          category: 'Organismes à contacter',
          limit: 10,
        ),
      ),
    ];
  }

  void _restoreProgress() {
    final completedIds = _stringList(widget.guidedProgress['completedStageIds'])
        .toSet();
    final activeId = '${widget.guidedProgress['activeStageId'] ?? ''}';
    final checklistDone = widget.guidedProgress['checklistDone'] is Map
        ? Map<String, dynamic>.from(widget.guidedProgress['checklistDone'] as Map)
        : const <String, dynamic>{};

    for (final stage in _stages) {
      if (completedIds.contains(stage.id)) {
        stage.status = JourneyStageStatus.done;
      }
      final doneIds = _stringList(checklistDone[stage.id]).toSet();
      for (final item in stage.checklist) {
        item.done = doneIds.contains(item.id);
      }
    }

    final active = _stages.indexWhere((stage) => stage.id == activeId);
    if (active >= 0 && !_stages[active].isComplete) {
      _activeIndex = active;
      _stages[active].status = JourneyStageStatus.doing;
    }
  }

  List<JourneyChecklistItem> _checklist(List<String> labels, String prefix) {
    final clean = labels
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    return <JourneyChecklistItem>[
      for (var i = 0; i < clean.length; i++)
        JourneyChecklistItem(id: '$prefix-${i + 1}', label: clean[i]),
    ];
  }

  List<String> _statusChecklist() {
    final status = _status.toLowerCase();
    if (status.contains('fonctionnaire') || status.contains('agent public')) {
      return <String>[
        'Vérifier les règles de cumul applicables à mon poste',
        'Adresser une demande écrite ou une information à mon administration',
        'Conserver la réponse et les justificatifs',
        'Vérifier la compatibilité des horaires et l’absence de conflit d’intérêts',
      ];
    }
    if (status.contains('salari')) {
      return <String>[
        'Relire mon contrat de travail',
        'Vérifier les clauses d’exclusivité et de non-concurrence',
        'Vérifier la compatibilité des horaires et mon obligation de loyauté',
      ];
    }
    if (status.contains('demandeur')) {
      return <String>[
        'Prendre rendez-vous avec France Travail avant les démarches sensibles',
        'Comparer maintien de l’ARE et ARCE',
        'Vérifier le calendrier de l’ACRE',
        'Préparer mon actualisation mensuelle',
      ];
    }
    if (status.contains('étudiant') || status.contains('etudiant')) {
      return <String>[
        'Vérifier la compatibilité avec mes études et ma bourse',
        'Vérifier les règles liées à mon âge ou à mon titre de séjour',
        'Anticiper les conséquences fiscales et sociales',
      ];
    }
    return <String>[
      'Vérifier mes droits et obligations liés à ma situation',
      'Identifier les aides ou limites applicables',
      'Conserver les réponses obtenues auprès des organismes',
    ];
  }

  List<String> _statusDocuments() {
    final status = _status.toLowerCase();
    if (status.contains('fonctionnaire') || status.contains('agent public')) {
      return const <String>[
        'Demande écrite de cumul ou d’autorisation',
        'Description précise de l’activité accessoire',
        'Réponse de l’administration',
      ];
    }
    if (status.contains('salari')) {
      return const <String>[
        'Contrat de travail et avenants',
        'Clauses d’exclusivité ou de non-concurrence',
        'Description de l’activité envisagée',
      ];
    }
    if (status.contains('demandeur')) {
      return const <String>[
        'Notification de droits France Travail',
        'Simulation ARE ou ARCE',
        'Calendrier prévisionnel de création',
      ];
    }
    return const <String>[
      'Justificatif de situation actuelle',
      'Description du projet',
      'Notes prises auprès des organismes compétents',
    ];
  }

  List<String> _todosMatching(List<String> patterns) {
    final values = <String>[];
    for (final step in widget.steps) {
      final haystack = <String>[
        '${step['title'] ?? ''}',
        '${step['objective'] ?? ''}',
        ..._stringList(step['todos']),
      ].join(' ').toLowerCase();
      if (!patterns.any(haystack.contains)) continue;
      values.addAll(_stringList(step['todos']));
      if (_stringList(step['todos']).isEmpty) {
        values.add('${step['title'] ?? step['objective'] ?? ''}');
      }
    }
    return values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> _stepDetailsMatching(List<String> patterns) {
    return <String>[
      for (final step in widget.steps)
        if (patterns.any(
          (pattern) => <String>[
            '${step['title'] ?? ''}',
            '${step['objective'] ?? ''}',
            ..._stringList(step['todos']),
          ].join(' ').toLowerCase().contains(pattern),
        ))
          _joinNonEmpty(<String>[
            '${step['title'] ?? ''}',
            '${step['objective'] ?? ''}',
            ..._stringList(step['todos']),
          ]),
    ].where((item) => item.isNotEmpty).toList();
  }

  List<String> _costDetails() {
    final details = <String>[];
    final formalities = widget.costs['formalitesEstimees'];
    if (formalities is Map) {
      details.add(
        'Frais de formalités : environ ${formalities['min'] ?? 0} € à ${formalities['max'] ?? 0} €',
      );
    }
    void addCost(String key, String label, {String suffix = '€'}) {
      final value = widget.costs[key];
      if (value == null) return;
      details.add('$label : environ $value $suffix');
    }

    addCost('annonceLegale', 'Annonce légale');
    addCost('assuranceProAn', 'Assurance professionnelle annuelle');
    addCost('comptableAn', 'Comptabilité annuelle');
    addCost('banqueOutilsAn', 'Banque et outils annuels');
    final note = '${widget.costs['note'] ?? ''}'.trim();
    if (note.isNotEmpty) details.add(note);
    details.addAll(_stringList(widget.costs['ficheCoutsIndicatifs']));
    return details;
  }

  List<JourneyResourceLink> _selectResources(
    List<RegionResource> resources,
    List<String> patterns, {
    List<String> extraTexts = const <String>[],
    String category = 'Ressource utile',
    int limit = 7,
  }) {
    final selected = <JourneyResourceLink>[];
    for (final resource in resources) {
      final haystack = '${resource.name} ${resource.description}'.toLowerCase();
      if (patterns.isNotEmpty && !patterns.any(haystack.contains)) continue;
      selected.add(
        JourneyResourceLink(
          label: resource.name,
          description: resource.description,
          url: resource.url,
          organization: resource.name,
          category: category,
          region: _region,
          priority: selected.length,
          isOfficial: true,
        ),
      );
    }

    for (final text in extraTexts) {
      for (final url in _extractUrls(text)) {
        if (selected.any((item) => item.url == url)) continue;
        selected.add(
          JourneyResourceLink(
            label: _hostLabel(url),
            description: 'Ressource mentionnée dans votre fiche personnalisée',
            url: url,
            category: category,
            region: _region,
            priority: selected.length + 20,
            isOfficial: true,
          ),
        );
      }
    }

    selected.sort((a, b) => a.priority.compareTo(b.priority));
    final deduped = <JourneyResourceLink>[];
    for (final item in selected) {
      if (deduped.any((current) => current.url == item.url)) continue;
      deduped.add(item);
      if (deduped.length >= limit) break;
    }
    return deduped;
  }

  List<String> _extractUrls(String value) {
    final matches = RegExp(r'https?://[^\s;,)]+', caseSensitive: false)
        .allMatches(value);
    return matches
        .map((match) => match.group(0) ?? '')
        .map((url) => url.replaceAll(RegExp(r'[.!?]+$'), ''))
        .where((url) => url.isNotEmpty)
        .toList();
  }

  String _hostLabel(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host.replaceFirst('www.', '') ?? url;
    return host.isEmpty ? 'Ouvrir la ressource' : host;
  }

  String _joinNonEmpty(List<String> values) => values
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .join(' — ');

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value == null) return const <String>[];
    final text = '$value'.trim();
    return text.isEmpty ? const <String>[] : <String>[text];
  }

  Map<String, dynamic> _progressMap() => <String, dynamic>{
        'activeStageId': _activeIndex >= 0 ? _stages[_activeIndex].id : '',
        'completedStageIds': _stages
            .where((stage) => stage.status == JourneyStageStatus.done)
            .map((stage) => stage.id)
            .toList(),
        'checklistDone': <String, dynamic>{
          for (final stage in _stages)
            stage.id: stage.checklist
                .where((item) => item.done)
                .map((item) => item.id)
                .toList(),
        },
        'percent': _progress,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  Map<String, dynamic> _snapshot() => <String, dynamic>{
        'savedAt': widget.savedAt ?? DateTime.now().toIso8601String(),
        'projectLabel': widget.projectLabel,
        'region': widget.region,
        'currentStatus': widget.currentStatus,
        'selectedActivity': widget.selectedActivity,
        'recommendation': widget.recommendation,
        'blockingAlerts': widget.blockingAlerts,
        'costs': widget.costs,
        'aides': widget.aides,
        'plan30': widget.plan30,
        'summary': widget.summary,
        'regulationTutorial': widget.regulationTutorial,
        'statusWarnings': widget.statusWarnings,
        'recommendedLegalStatus': widget.recommendedLegalStatus,
        'steps': widget.steps,
        'guidedProgress': _progressMap(),
      };

  double get _progress {
    if (_stages.isEmpty) return 0;
    return _stages.where((stage) => stage.isComplete).length / _stages.length;
  }

  int get _completedCount => _stages.where((stage) => stage.isComplete).length;

  int get _nextIncompleteIndex {
    final index = _stages.indexWhere((stage) => !stage.isComplete);
    return index < 0 ? _stages.length - 1 : index;
  }

  Future<void> _persistProgress() async {
    try {
      await _storage.saveHistorySnapshot(_snapshot());
    } catch (error) {
      debugPrint('[GuidedJourney] progress save failed: $error');
    }
  }

  void _openStage(int index) {
    setState(() {
      _activeIndex = index.clamp(0, _stages.length - 1).toInt();
      final stage = _stages[_activeIndex];
      if (stage.status == JourneyStageStatus.todo) {
        stage.status = JourneyStageStatus.doing;
      }
    });
    unawaited(_persistProgress());
  }

  void _toggleChecklist(JourneyChecklistItem item, bool? value) {
    setState(() => item.done = value ?? false);
    unawaited(_persistProgress());
  }

  Future<void> _completeStage() async {
    if (_activeIndex < 0) return;
    final stage = _stages[_activeIndex];
    final unchecked = stage.checklist.where((item) => !item.done).length;
    if (unchecked > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Terminer cette étape ?'),
          content: Text(
            '$unchecked action(s) ne sont pas encore cochée(s). Vous pourrez revenir sur cette étape plus tard.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Continuer la vérification'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Terminer quand même'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() {
      stage.status = JourneyStageStatus.done;
      if (_activeIndex < _stages.length - 1) {
        _activeIndex += 1;
        if (_stages[_activeIndex].status == JourneyStageStatus.todo) {
          _stages[_activeIndex].status = JourneyStageStatus.doing;
        }
      } else {
        _activeIndex = -1;
      }
    });
    await _persistProgress();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _completedCount == _stages.length
              ? 'Parcours terminé. Toutes les étapes sont validées.'
              : 'Étape terminée. La prochaine action est prête.',
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir ce lien.')),
      );
    }
  }

  Future<void> _saveJourney() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final decision = await _entitlements.evaluateLocalSave();
      if (!decision.allowed) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Limite de sauvegarde atteinte'),
            content: Text(
              'Votre formule permet ${decision.entitlements.maxLocalSavesPerMonth} sauvegarde(s). Vous pouvez continuer à consulter ce parcours sur cet appareil.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
        return;
      }

      await _storage.saveSnapshot(_snapshot());
      await _entitlements.recordLocalSave();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parcours et progression sauvegardés.')),
      );
    } catch (error) {
      debugPrint('[GuidedJourney] save failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La sauvegarde est temporairement indisponible.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final decision = await _entitlements.evaluatePdfExport();
      if (!decision.allowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision.requiresUpgrade
                  ? 'L’export PDF est disponible avec IliPresto+ ou ilipro.'
                  : 'La limite d’exports PDF est atteinte.',
            ),
          ),
        );
        return;
      }
      final downloaded = await _pdf.downloadJourneyPdf(_snapshot());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? 'PDF téléchargé avec le parcours complet.'
                : 'Téléchargement PDF annulé.',
          ),
        ),
      );
    } catch (error) {
      debugPrint('[GuidedJourney] pdf failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('L’export PDF a échoué.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = _activeIndex >= 0 ? _stages[_activeIndex] : null;
    return Scaffold(
      backgroundColor: _kJourneyBackground,
      appBar: AppBar(
        backgroundColor: _kJourneyOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          stage == null
              ? 'Mon parcours personnalisé'
              : 'Étape ${stage.order} sur ${_stages.length}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Vue d’ensemble',
            onPressed: () => setState(() => _activeIndex = -1),
            icon: const Icon(Icons.route_outlined),
          ),
        ],
      ),
      body: stage == null ? _buildOverview() : _buildStage(stage),
      bottomNavigationBar: stage == null ? null : _buildStageNavigation(stage),
    );
  }

  Widget _buildOverview() {
    final nextIndex = _nextIncompleteIndex;
    final nextStage = _stages[nextIndex];
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 28),
      children: [
        _JourneyOverviewHero(
          activity: _activity,
          region: _region,
          status: _status,
          completed: _completedCount,
          total: _stages.length,
          progress: _progress,
        ),
        const SizedBox(height: 12),
        _NextActionCard(
          completed: _completedCount == _stages.length,
          title: _completedCount == _stages.length
              ? 'Votre parcours est terminé'
              : nextStage.title,
          objective: _completedCount == _stages.length
              ? 'Vous pouvez relire une étape, enregistrer le parcours ou exporter le PDF.'
              : nextStage.objective,
          buttonLabel: _completedCount == 0
              ? 'Commencer l’étape 1'
              : _completedCount == _stages.length
                  ? 'Relire le parcours'
                  : 'Reprendre mon parcours',
          onPressed: () => _openStage(
            _completedCount == _stages.length ? 0 : nextIndex,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Aperçu du parcours',
          style: TextStyle(
            color: _kJourneyText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Ouvrez une étape pour voir uniquement les informations et actions utiles à ce moment.',
          style: TextStyle(
            color: _kJourneyMuted,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _stages.length; i++)
          _StageOverviewTile(
            stage: _stages[i],
            onTap: () => _openStage(i),
          ),
        const SizedBox(height: 12),
        _SaveShareCard(
          saving: _saving,
          onSave: _saveJourney,
          onExport: _exportPdf,
        ),
      ],
    );
  }

  Widget _buildStage(JourneyStage stage) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      children: [
        _StageHeaderCard(
          stage: stage,
          total: _stages.length,
          globalProgress: _progress,
        ),
        const SizedBox(height: 12),
        _GuidanceSection(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Pourquoi cette étape est importante',
          child: _LinkifiedText(text: stage.explanation, onOpen: _openUrl),
        ),
        const SizedBox(height: 12),
        _GuidanceSection(
          icon: Icons.person_pin_circle_outlined,
          title: 'Ce qui vous concerne personnellement',
          child: _LinkifiedText(
            text: stage.personalizedSummary,
            onOpen: _openUrl,
          ),
        ),
        if (stage.warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          _WarningsCard(warnings: stage.warnings),
        ],
        const SizedBox(height: 12),
        _ChecklistSection(
          items: stage.checklist,
          onChanged: _toggleChecklist,
        ),
        const SizedBox(height: 12),
        _ExpandableListSection(
          icon: Icons.folder_copy_outlined,
          title: 'Documents à préparer',
          items: stage.documents,
          emptyLabel: 'Aucun document particulier n’est identifié.',
        ),
        const SizedBox(height: 12),
        _ExpandableListSection(
          icon: Icons.menu_book_outlined,
          title: 'Comprendre cette étape en détail',
          items: stage.detailedInformation,
          emptyLabel:
              'Les informations principales de cette étape sont déjà affichées.',
          linkOpener: _openUrl,
        ),
        const SizedBox(height: 12),
        _ResourceAccordion(
          links: stage.links,
          onOpen: (link) => _openUrl(link.url),
        ),
        const SizedBox(height: 12),
        _StageResultCard(stage: stage),
      ],
    );
  }

  Widget _buildStageNavigation(JourneyStage stage) {
    final isFirst = _activeIndex == 0;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Row(
          children: [
            IconButton.outlined(
              tooltip: isFirst ? 'Vue d’ensemble' : 'Étape précédente',
              onPressed: () {
                if (isFirst) {
                  setState(() => _activeIndex = -1);
                } else {
                  _openStage(_activeIndex - 1);
                }
              },
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _completeStage,
                style: FilledButton.styleFrom(
                  backgroundColor: _kJourneyBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  stage.isComplete
                      ? 'Continuer vers l’étape suivante'
                      : 'J’ai terminé cette étape',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyOverviewHero extends StatelessWidget {
  final String activity;
  final String region;
  final String status;
  final int completed;
  final int total;
  final double progress;

  const _JourneyOverviewHero({
    required this.activity,
    required this.region,
    required this.status,
    required this.completed,
    required this.total,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFFF3EA), Colors.white],
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
              color: _kJourneyOrange,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Créer une activité de $activity${region.isEmpty ? '' : ' en $region'}',
            style: const TextStyle(
              color: _kJourneyText,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.16,
            ),
          ),
          if (status.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Situation actuelle : $status',
              style: const TextStyle(
                color: _kJourneyMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(_kJourneyOrange),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$completed étape(s) terminée(s) sur $total — ${(progress * 100).round()} %',
            style: const TextStyle(
              color: _kJourneyMuted,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextActionCard extends StatelessWidget {
  final bool completed;
  final String title;
  final String objective;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _NextActionCard({
    required this.completed,
    required this.title,
    required this.objective,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final tone = completed ? const Color(0xFF0F766E) : _kJourneyBlue;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            completed ? 'PARCOURS TERMINÉ' : 'VOTRE PROCHAINE ACTION',
            style: TextStyle(
              color: tone,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: _kJourneyText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            objective,
            style: const TextStyle(
              color: _kJourneyMuted,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: tone,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _StageOverviewTile extends StatelessWidget {
  final JourneyStage stage;
  final VoidCallback onTap;

  const _StageOverviewTile({required this.stage, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = switch (stage.status) {
      JourneyStageStatus.done => const Color(0xFF0F766E),
      JourneyStageStatus.doing => _kJourneyBlue,
      JourneyStageStatus.todo => const Color(0xFF9CA3AF),
    };
    final label = switch (stage.status) {
      JourneyStageStatus.done => 'Terminée',
      JourneyStageStatus.doing => 'En cours',
      JourneyStageStatus.todo => 'À faire',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: tone.withValues(alpha: 0.20)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.11),
                  shape: BoxShape.circle,
                ),
                child: stage.status == JourneyStageStatus.done
                    ? Icon(Icons.check_rounded, color: tone)
                    : Text(
                        '${stage.order}',
                        style: TextStyle(
                          color: tone,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.title,
                      style: const TextStyle(
                        color: _kJourneyText,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: tone,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _kJourneyMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageHeaderCard extends StatelessWidget {
  final JourneyStage stage;
  final int total;
  final double globalProgress;

  const _StageHeaderCard({
    required this.stage,
    required this.total,
    required this.globalProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _kJourneyOrange.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Étape ${stage.order} sur $total',
                  style: const TextStyle(
                    color: _kJourneyOrange,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.schedule_rounded,
                  size: 17, color: _kJourneyMuted),
              const SizedBox(width: 5),
              Text(
                'Environ ${stage.estimatedMinutes} min',
                style: const TextStyle(
                  color: _kJourneyMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            stage.title,
            style: const TextStyle(
              color: _kJourneyText,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            stage.objective,
            style: const TextStyle(
              color: _kJourneyMuted,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: globalProgress,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(_kJourneyOrange),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidanceSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _GuidanceSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _kJourneyBlue, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _kJourneyText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _WarningsCard extends StatelessWidget {
  final List<String> warnings;

  const _WarningsCard({required this.warnings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Points de vigilance avant de continuer',
                  style: TextStyle(
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(
                '• $warning',
                style: const TextStyle(
                  color: Color(0xFF78350F),
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChecklistSection extends StatelessWidget {
  final List<JourneyChecklistItem> items;
  final void Function(JourneyChecklistItem item, bool? value) onChanged;

  const _ChecklistSection({required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final done = items.where((item) => item.done).length;
    return _GuidanceSection(
      icon: Icons.checklist_rounded,
      title: 'Ce que vous devez faire maintenant — $done/${items.length}',
      child: items.isEmpty
          ? const Text('Aucune action particulière n’est requise.')
          : Column(
              children: [
                for (final item in items)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: false,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: const Color(0xFF0F766E),
                    value: item.done,
                    onChanged: (value) => onChanged(item, value),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: _kJourneyText,
                        fontWeight: FontWeight.w700,
                        decoration:
                            item.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ExpandableListSection extends StatefulWidget {
  final IconData icon;
  final String title;
  final List<String> items;
  final String emptyLabel;
  final ValueChanged<String>? linkOpener;

  const _ExpandableListSection({
    required this.icon,
    required this.title,
    required this.items,
    required this.emptyLabel,
    this.linkOpener,
  });

  @override
  State<_ExpandableListSection> createState() =>
      _ExpandableListSectionState();
}

class _ExpandableListSectionState extends State<_ExpandableListSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        onExpansionChanged: (value) => setState(() => _expanded = value),
        tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
        childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
        leading: Icon(widget.icon, color: _kJourneyBlue),
        title: Text(
          '${widget.title} — ${widget.items.length} élément(s)',
          style: const TextStyle(
            color: _kJourneyText,
            fontWeight: FontWeight.w900,
          ),
        ),
        trailing: Icon(
          _expanded
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
          color: _kJourneyMuted,
        ),
        children: [
          if (widget.items.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.emptyLabel,
                style: const TextStyle(color: _kJourneyMuted),
              ),
            )
          else
            for (final item in widget.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: CircleAvatar(
                        radius: 3,
                        backgroundColor: _kJourneyOrange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _LinkifiedText(
                        text: item,
                        onOpen: widget.linkOpener ?? (_) {},
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _ResourceAccordion extends StatefulWidget {
  final List<JourneyResourceLink> links;
  final ValueChanged<JourneyResourceLink> onOpen;

  const _ResourceAccordion({required this.links, required this.onOpen});

  @override
  State<_ResourceAccordion> createState() => _ResourceAccordionState();
}

class _ResourceAccordionState extends State<_ResourceAccordion> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final visible = _showAll ? widget.links : widget.links.take(2).toList();
    final hidden = widget.links.length - visible.length;
    return _GuidanceSection(
      icon: Icons.link_rounded,
      title: 'Liens et organismes utiles — ${widget.links.length} ressource(s)',
      child: widget.links.isEmpty
          ? const Text(
              'Aucun lien spécifique n’est nécessaire pour cette étape.',
              style: TextStyle(color: _kJourneyMuted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final link in visible)
                  _ResourceLinkCard(
                    link: link,
                    onTap: () => widget.onOpen(link),
                  ),
                if (widget.links.length > 2)
                  TextButton.icon(
                    onPressed: () => setState(() => _showAll = !_showAll),
                    icon: Icon(
                      _showAll
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                    label: Text(
                      _showAll
                          ? 'Réduire la liste'
                          : 'Afficher les $hidden autre(s) ressource(s)',
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ResourceLinkCard extends StatelessWidget {
  final JourneyResourceLink link;
  final VoidCallback onTap;

  const _ResourceLinkCard({required this.link, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.open_in_new_rounded,
                    color: _kJourneyBlue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              link.label,
                              style: const TextStyle(
                                color: _kJourneyBlue,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (link.isOfficial)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Officiel',
                                style: TextStyle(
                                  color: _kJourneyBlue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        link.description,
                        style: const TextStyle(
                          color: _kJourneyMuted,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StageResultCard extends StatelessWidget {
  final JourneyStage stage;

  const _StageResultCard({required this.stage});

  @override
  Widget build(BuildContext context) {
    final text = switch (stage.id) {
      'rules' =>
        'Vous savez si vous pouvez commencer immédiatement ou si une vérification préalable est nécessaire.',
      'personal-status' =>
        'Vous connaissez les autorisations et précautions liées à votre situation.',
      'legal-frame' =>
        'Vous comprenez le cadre proposé et savez quand demander une validation professionnelle.',
      'prepare-file' => 'Votre dossier est prêt avant l’ouverture du guichet.',
      'declare' =>
        'Vous savez où effectuer la déclaration et dans quel ordre avancer.',
      'secure-launch' =>
        'Votre activité est organisée et protégée pour les premières prestations.',
      'aids-budget' =>
        'Vous connaissez votre budget de départ et les aides à vérifier.',
      _ =>
        'Vous disposez d’une feuille de route simple pour passer à l’action.',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.flag_outlined, color: Color(0xFF0F766E)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Résultat attendu',
                  style: TextStyle(
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF14532D),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveShareCard extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onExport;

  const _SaveShareCard({
    required this.saving,
    required this.onSave,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sauvegarde et partage',
            style: TextStyle(
              color: _kJourneyText,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'La sauvegarde conserve toutes les informations et votre progression. L’export PDF reprend le parcours complet.',
            style: TextStyle(
              color: _kJourneyMuted,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saving ? null : onSave,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Sauvegarder'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton.icon(
                  onPressed: saving ? null : onExport,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kJourneyBlue,
                    foregroundColor: Colors.white,
                  ),
                  icon: saving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Exporter PDF'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinkifiedText extends StatelessWidget {
  final String text;
  final ValueChanged<String> onOpen;

  const _LinkifiedText({required this.text, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final regex = RegExp(r'https?://[^\s;,)]+', caseSensitive: false);
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      final url = (match.group(0) ?? '').replaceAll(RegExp(r'[.!?]+$'), '');
      spans.add(
        TextSpan(
          text: url,
          style: const TextStyle(
            color: _kJourneyBlue,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w800,
          ),
          recognizer: TapGestureRecognizer()..onTap = () => onOpen(url),
        ),
      );
      start = match.end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));

    return Text.rich(
      TextSpan(
        style: const TextStyle(
          color: Color(0xFF374151),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.48,
        ),
        children: spans.isEmpty ? <InlineSpan>[TextSpan(text: text)] : spans,
      ),
    );
  }
}
