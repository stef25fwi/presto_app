import 'package:presto_app/services/region_resources_service.dart';

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
}

class JourneyChecklistItem {
  final String id;
  final String label;

  const JourneyChecklistItem({required this.id, required this.label});
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
  final List<String> details;
  final List<JourneyResourceLink> resources;
  final bool isBlocking;

  const JourneyStage({
    required this.id,
    required this.order,
    required this.title,
    required this.objective,
    required this.estimatedMinutes,
    required this.explanation,
    required this.personalizedSummary,
    this.warnings = const [],
    this.checklist = const [],
    this.documents = const [],
    this.details = const [],
    this.resources = const [],
    this.isBlocking = false,
  });
}

class GuidedJourneyProgress {
  final String activeStageId;
  final Set<String> completedStageIds;
  final Map<String, Set<String>> checklistDone;

  const GuidedJourneyProgress({
    required this.activeStageId,
    required this.completedStageIds,
    required this.checklistDone,
  });

  factory GuidedJourneyProgress.fromMap(
    Map<String, dynamic> raw,
    List<JourneyStage> stages,
  ) {
    final completed = (raw['completedStageIds'] as List?)
            ?.map((value) => '$value')
            .where((value) => stages.any((stage) => stage.id == value))
            .toSet() ??
        <String>{};
    final checklistRaw = raw['checklistDone'];
    final checklist = <String, Set<String>>{};
    if (checklistRaw is Map) {
      for (final entry in checklistRaw.entries) {
        checklist['${entry.key}'] = (entry.value as List?)
                ?.map((value) => '$value')
                .toSet() ??
            <String>{};
      }
    }
    final requested = '${raw['activeStageId'] ?? ''}';
    final fallback = stages
        .firstWhere(
          (stage) => !completed.contains(stage.id),
          orElse: () => stages.first,
        )
        .id;
    return GuidedJourneyProgress(
      activeStageId:
          stages.any((stage) => stage.id == requested) ? requested : fallback,
      completedStageIds: completed,
      checklistDone: checklist,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'activeStageId': activeStageId,
        'completedStageIds': completedStageIds.toList(),
        'checklistDone': <String, dynamic>{
          for (final entry in checklistDone.entries)
            entry.key: entry.value.toList(),
        },
        'percent': completedStageIds.length / 8,
      };
}

class GuidedJourneyContentFactory {
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

  const GuidedJourneyContentFactory({
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
  });

  String get _activity => selectedActivity.trim().isNotEmpty
      ? selectedActivity.trim()
      : projectLabel.trim();

  List<JourneyStage> build() {
    final regulatedDetails = _mapDetails(regulationTutorial);
    final personalDetails = _mapDetails(statusWarnings);
    final legalDetails = <String>[
      ..._mapEntries(recommendedLegalStatus),
      ..._mapEntries(recommendation),
    ];
    final documentSteps = _stepDetails(<String>[
      'prépar',
      'document',
      'dossier',
      'information',
    ]);
    final declarationSteps = _stepDetails(<String>[
      'déclar',
      'formalit',
      'guichet',
      'immatric',
      'inpi',
    ]);
    final securitySteps = _stepDetails(<String>[
      'assurance',
      'banque',
      'facture',
      'devis',
      'gestion',
      'protection',
    ]);
    final assignedTitles = <String>{
      ...documentSteps.map((item) => item.split(' — ').first),
      ...declarationSteps.map((item) => item.split(' — ').first),
      ...securitySteps.map((item) => item.split(' — ').first),
    };
    final remainingSteps = _mapDetails(steps)
        .where((item) => !assignedTitles.contains(item.split(' — ').first))
        .toList();
    final aidDetails = aides
        .where((item) => item['relevant'] != false)
        .map(_describeMapItem)
        .where((item) => item.isNotEmpty)
        .toList();
    final planDetails = plan30
        .map(_describeMapItem)
        .where((item) => item.isNotEmpty)
        .toList();

    return <JourneyStage>[
      JourneyStage(
        id: 'rules',
        order: 1,
        title: 'Comprendre les règles de mon activité',
        objective: 'Savoir ce qui est autorisé avant de commencer.',
        estimatedMinutes: 6,
        explanation:
            'Cette première étape rassemble les règles, qualifications, assurances et autorisations liées à votre activité.',
        personalizedSummary:
            'Pour une activité de $_activity en $region, commencez par vérifier les règles métier avant toute déclaration.',
        warnings: blockingAlerts,
        checklist: _checklistFromDetails(
          'rules',
          regulatedDetails,
          fallback: 'Vérifier si mon activité est libre ou réglementée',
        ),
        documents: const [
          'Description précise de l’activité envisagée',
          'Diplômes, qualifications ou justificatifs d’expérience disponibles',
          'Liste des assurances déjà détenues',
        ],
        details: regulatedDetails,
        resources: _resources(<String>[
          'inpi',
          'urssaf',
          'cci',
          'artisanat',
          'bge',
          'région',
          'collectivité',
        ], includeAll: true),
        isBlocking: blockingAlerts.isNotEmpty,
      ),
      JourneyStage(
        id: 'personal-status',
        order: 2,
        title: 'Vérifier ma situation personnelle',
        objective: 'Identifier les règles liées à mon statut actuel.',
        estimatedMinutes: 5,
        explanation:
            'Votre statut personnel peut imposer une autorisation, une vérification contractuelle ou un calendrier particulier.',
        personalizedSummary:
            'Vous avez indiqué être $currentStatus. Les contrôles ci-dessous sont adaptés à cette situation.',
        warnings: personalDetails.isEmpty ? blockingAlerts : const [],
        checklist: _statusChecklist(personalDetails),
        documents: _statusDocuments(),
        details: personalDetails,
        resources: _resources(_statusResourcePatterns()),
        isBlocking: currentStatus.toLowerCase().contains('fonctionnaire'),
      ),
      JourneyStage(
        id: 'legal-frame',
        order: 3,
        title: 'Choisir mon cadre de lancement',
        objective: 'Comprendre le statut conseillé et ses limites.',
        estimatedMinutes: 7,
        explanation:
            'La recommandation est une orientation de démarrage. Elle doit rester cohérente avec vos frais, votre chiffre d’affaires et votre projet.',
        personalizedSummary:
            'Option proposée : ${_value(recommendedLegalStatus['recommended'] ?? recommendation['statut'], fallback: 'cadre à confirmer')}.',
        checklist: const <JourneyChecklistItem>[
          JourneyChecklistItem(
            id: 'legal-frame-1',
            label: 'Comparer la recommandation avec mes besoins réels',
          ),
          JourneyChecklistItem(
            id: 'legal-frame-2',
            label: 'Noter les points à faire confirmer par un professionnel',
          ),
        ],
        documents: const [
          'Estimation de chiffre d’affaires',
          'Liste des dépenses professionnelles prévues',
          'Objectifs de développement à 12 mois',
        ],
        details: legalDetails,
        resources: _resources(<String>['urssaf', 'cci', 'bge', 'artisanat']),
      ),
      JourneyStage(
        id: 'prepare-file',
        order: 4,
        title: 'Préparer mon dossier',
        objective: 'Réunir les informations avant d’ouvrir la formalité.',
        estimatedMinutes: 10,
        explanation:
            'Un dossier préparé à l’avance réduit les erreurs et évite d’interrompre la déclaration pour chercher une pièce.',
        personalizedSummary:
            'Préparez maintenant les éléments nécessaires pour $_activity en $region.',
        checklist: _checklistFromDetails(
          'prepare-file',
          <String>[...documentSteps, ...remainingSteps],
          fallback: 'Réunir mes informations personnelles et professionnelles',
        ),
        documents: const [
          'Pièce d’identité',
          'Justificatif de domicile ou d’adresse professionnelle',
          'Description de l’activité principale',
          'Diplômes ou autorisations si l’activité l’exige',
          'Coordonnées bancaires et moyens de contact',
        ],
        details: <String>[...documentSteps, ...remainingSteps],
        resources: _resources(<String>['cci', 'artisanat', 'bge']),
      ),
      JourneyStage(
        id: 'declare',
        order: 5,
        title: 'Déclarer mon activité',
        objective: 'Effectuer la formalité dans le bon ordre.',
        estimatedMinutes: 12,
        explanation:
            'La déclaration se réalise sur le guichet compétent. Préparez les pièces, vérifiez le récapitulatif puis conservez le justificatif de dépôt.',
        personalizedSummary:
            'Pour votre projet, le guichet unique doit être utilisé au moment où votre dossier est complet.',
        checklist: _checklistFromDetails(
          'declare',
          declarationSteps,
          fallback: 'Ouvrir le guichet unique et préparer la formalité',
        ),
        documents: const [
          'Toutes les pièces préparées à l’étape précédente',
          'Choix du statut et des options utiles',
          'Moyen de paiement si des frais sont demandés',
        ],
        details: declarationSteps,
        resources: _resources(<String>['inpi', 'urssaf']),
        isBlocking: true,
      ),
      JourneyStage(
        id: 'secure',
        order: 6,
        title: 'Sécuriser mon lancement',
        objective: 'Mettre en place les protections et outils essentiels.',
        estimatedMinutes: 9,
        explanation:
            'Avant les premières prestations, vérifiez les assurances, les documents commerciaux et l’organisation de votre gestion.',
        personalizedSummary:
            'Les protections doivent correspondre aux risques réels de l’activité $_activity.',
        warnings: blockingAlerts,
        checklist: _checklistFromDetails(
          'secure',
          securitySteps,
          fallback: 'Vérifier mon assurance et mes documents commerciaux',
        ),
        documents: const [
          'Attestation d’assurance professionnelle si nécessaire',
          'Modèles de devis et de facture',
          'Tableau de suivi des recettes et dépenses',
          'Conditions de vente ou d’intervention',
        ],
        details: <String>[...securitySteps, ..._mapEntries(costs)],
        resources: _resources(<String>['cci', 'artisanat', 'bpifrance']),
      ),
      JourneyStage(
        id: 'aids-budget',
        order: 7,
        title: 'Identifier les aides et mon budget',
        objective: 'Savoir quoi demander et combien prévoir.',
        estimatedMinutes: 8,
        explanation:
            'Les aides et les coûts varient selon le statut, le territoire et l’activité. Vérifiez les conditions avant d’engager une dépense.',
        personalizedSummary:
            '${aidDetails.length} aide(s) pertinente(s) ont été identifiée(s) pour votre parcours.',
        checklist: _checklistFromDetails(
          'aids-budget',
          aidDetails,
          fallback: 'Vérifier les aides et construire mon budget de départ',
        ),
        documents: const [
          'Budget prévisionnel simple',
          'Devis des principaux achats',
          'Justificatifs demandés par les organismes',
          'Calendrier de création et de demande des aides',
        ],
        details: <String>[...aidDetails, ..._mapEntries(costs)],
        resources: _resources(<String>[
          'aides',
          'france travail',
          'bpifrance',
          'initiative',
          'région',
          'collectivité',
          'outre-mer',
        ]),
      ),
      JourneyStage(
        id: 'plan-30',
        order: 8,
        title: 'Suivre mon plan sur 30 jours',
        objective: 'Passer de la préparation au lancement réel.',
        estimatedMinutes: 10,
        explanation:
            'Avancez semaine après semaine. Chaque action terminée rapproche votre projet de ses premières prestations ou ventes.',
        personalizedSummary:
            'Votre feuille de route contient ${planDetails.length} action(s) répartie(s) sur les quatre premières semaines.',
        checklist: _checklistFromDetails(
          'plan-30',
          planDetails,
          fallback: 'Planifier ma première action de lancement',
        ),
        documents: const [
          'Calendrier des quatre semaines',
          'Liste de premiers clients ou partenaires',
          'Offre et tarif de lancement',
          'Indicateurs simples à suivre',
        ],
        details: planDetails,
        resources: _resources(<String>[
          'bge',
          'cci',
          'artisanat',
          'initiative',
          'réseau entreprendre',
          'région',
        ]),
      ),
    ];
  }

  List<JourneyChecklistItem> _statusChecklist(List<String> details) {
    if (details.isNotEmpty) {
      return _checklistFromDetails('personal-status', details);
    }
    final status = currentStatus.toLowerCase();
    if (status.contains('fonctionnaire') || status.contains('agent public')) {
      return const <JourneyChecklistItem>[
        JourneyChecklistItem(
          id: 'personal-status-1',
          label: 'Vérifier les règles de cumul applicables à mon emploi',
        ),
        JourneyChecklistItem(
          id: 'personal-status-2',
          label: 'Préparer une demande écrite si une autorisation est nécessaire',
        ),
      ];
    }
    if (status.contains('salari')) {
      return const <JourneyChecklistItem>[
        JourneyChecklistItem(
          id: 'personal-status-1',
          label: 'Relire mon contrat et les clauses particulières',
        ),
      ];
    }
    return const <JourneyChecklistItem>[
      JourneyChecklistItem(
        id: 'personal-status-1',
        label: 'Vérifier mes droits et obligations avant la création',
      ),
    ];
  }

  List<String> _statusDocuments() {
    final status = currentStatus.toLowerCase();
    if (status.contains('fonctionnaire') || status.contains('agent public')) {
      return const <String>[
        'Statut ou règlement applicable à mon emploi',
        'Description de l’activité accessoire',
        'Projet de demande écrite à la hiérarchie',
        'Réponse ou autorisation à conserver',
      ];
    }
    if (status.contains('salari')) {
      return const <String>[
        'Contrat de travail',
        'Clauses d’exclusivité ou de non-concurrence',
        'Description de l’activité envisagée',
      ];
    }
    if (status.contains('demandeur')) {
      return const <String>[
        'Notification de droits France Travail',
        'Calendrier prévisionnel de création',
        'Documents nécessaires aux demandes ACRE ou ARCE',
      ];
    }
    return const <String>[
      'Justificatif de situation actuelle',
      'Description du projet',
    ];
  }

  List<String> _statusResourcePatterns() {
    final status = currentStatus.toLowerCase();
    if (status.contains('demandeur')) {
      return <String>['france travail', 'urssaf', 'bge'];
    }
    return <String>['cci', 'bge', 'artisanat'];
  }

  List<String> _stepDetails(List<String> patterns) {
    return steps
        .where((item) {
          final text = item.values.join(' ').toLowerCase();
          return patterns.any(text.contains);
        })
        .map(_describeMapItem)
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<JourneyChecklistItem> _checklistFromDetails(
    String stageId,
    List<String> details, {
    String fallback = 'Vérifier cette étape',
  }) {
    final source = details.isEmpty ? <String>[fallback] : details;
    return <JourneyChecklistItem>[
      for (var index = 0; index < source.length; index++)
        JourneyChecklistItem(
          id: '$stageId-${index + 1}',
          label: _shortAction(source[index]),
        ),
    ];
  }

  String _shortAction(String value) {
    final cleaned = value.replaceAll(RegExp(r'https?://\S+'), '').trim();
    final separator = cleaned.indexOf(' — ');
    final title = separator > 0 ? cleaned.substring(0, separator) : cleaned;
    if (title.length <= 110) return title;
    return '${title.substring(0, 107).trim()}…';
  }

  List<String> _mapDetails(List<Map<String, dynamic>> values) => values
      .map(_describeMapItem)
      .where((item) => item.isNotEmpty)
      .toList();

  String _describeMapItem(Map<String, dynamic> item) {
    final title = _value(
      item['title'] ?? item['label'] ?? item['name'] ?? item['week'],
    );
    final description = _value(
      item['description'] ??
          item['text'] ??
          item['summary'] ??
          item['desc'] ??
          item['objective'],
    );
    final extras = <String>[
      ..._stringList(item['todos']),
      ..._stringList(item['checks']),
    ];
    final parts = <String>[
      if (title.isNotEmpty) title,
      if (description.isNotEmpty) description,
      ...extras,
    ];
    if (parts.isEmpty) return '';
    return parts.join(' — ');
  }

  List<String> _mapEntries(Map<String, dynamic> map) {
    return map.entries
        .where((entry) => _value(entry.value).isNotEmpty)
        .map((entry) => '${_pretty(entry.key)} — ${_format(entry.value)}')
        .toList();
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value.map((item) => '$item'.trim()).where((item) => item.isNotEmpty).toList();
  }

  String _format(dynamic value) {
    if (value is Map) {
      return value.entries
          .map((entry) => '${_pretty('${entry.key}')} : ${entry.value}')
          .join(' · ');
    }
    if (value is List) return value.map((item) => '$item').join(' · ');
    return '$value';
  }

  String _pretty(String raw) {
    final spaced = raw
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match[1]} ${match[2]}')
        .trim();
    if (spaced.isEmpty) return 'Information';
    return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }

  String _value(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  List<JourneyResourceLink> _resources(
    List<String> patterns, {
    bool includeAll = false,
  }) {
    final resources = getRegionResources(region);
    final normalizedPatterns = patterns.map((item) => item.toLowerCase()).toList();
    final selected = resources.where((resource) {
      if (includeAll) return true;
      final haystack = '${resource.name} ${resource.description}'.toLowerCase();
      return normalizedPatterns.any(haystack.contains);
    }).toList();
    final fallback = selected.isEmpty ? resources.take(3).toList() : selected;
    return fallback
        .map(
          (resource) => JourneyResourceLink(
            label: resource.name,
            description: resource.description,
            url: resource.url,
            organization: resource.name,
            category: 'Organisme et source officielle',
            region: region,
            priority: resource.name.toLowerCase().contains(region.toLowerCase())
                ? 0
                : 10,
          ),
        )
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }
}
