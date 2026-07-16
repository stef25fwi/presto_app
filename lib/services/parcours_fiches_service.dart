import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class ParcoursFichesService {
  ParcoursFichesService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<Map<String, dynamic>?> loadFonctionnaireDerivedData({
    required String activity,
    required String region,
    required String currentStatus,
    required Map<String, dynamic> fallback,
  }) async {
    final normalizedActivity = activity.trim();
    if (normalizedActivity.isEmpty) {
      return null;
    }

    final snapshot = await _firestore
        .collection('parcoursFiches')
        .where('statut_utilisateur', isEqualTo: 'fonctionnaire')
        .where('activite', isEqualTo: normalizedActivity)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final rawFiche = Map<String, dynamic>.from(snapshot.docs.first.data());
    if ('${rawFiche['markdown_content'] ?? ''}'.trim().isEmpty) {
      final bundledMarkdown = await _loadBundledMarkdownContent(rawFiche);
      if (bundledMarkdown.isNotEmpty) {
        rawFiche['markdown_content'] = bundledMarkdown;
      }
    }

    final fiche = _FonctionnaireParcoursFiche.fromMap(rawFiche);
    return fiche.toDerivedData(
      region: region,
      currentStatus: currentStatus,
      fallback: fallback,
    );
  }

  Future<String> _loadBundledMarkdownContent(Map<String, dynamic> fiche) async {
    final ficheId = '${fiche['id_fiche'] ?? ''}'.trim();
    if (ficheId.isEmpty) {
      return '';
    }

    final assetPath =
        'docs/menu_activite_statuts/pack_fiches_fonctionnaire_firebase/markdown/$ficheId.md';
    try {
      return await rootBundle.loadString(assetPath);
    } catch (_) {
      return '';
    }
  }
}

Map<String, dynamic> mapFonctionnaireFicheToDerivedData({
  required Map<String, dynamic> fiche,
  required String region,
  required String currentStatus,
  Map<String, dynamic> fallback = const <String, dynamic>{},
}) {
  return _FonctionnaireParcoursFiche.fromMap(fiche).toDerivedData(
    region: region,
    currentStatus: currentStatus,
    fallback: fallback,
  );
}

class _FonctionnaireParcoursFiche {
  _FonctionnaireParcoursFiche({required this.raw});

  factory _FonctionnaireParcoursFiche.fromMap(Map<String, dynamic> raw) {
    return _FonctionnaireParcoursFiche(raw: raw);
  }

  final Map<String, dynamic> raw;
  late final _MarkdownOutline _markdownOutline = _MarkdownOutline.parse(
    markdownContent,
  );

  String get activity => _string('activite');
  String get category => _string('categorie');
  String get vigilance => _string('niveau_vigilance');
  String get qualificationRules => _string('qualification_regles');
  String get markdownContent => _string('markdown_content');
  String get currentFrame => _stringFromMap(_map('parcours'), '3_cadre');
  String get personalSituation =>
      _stringFromMap(_map('parcours'), '2_situation_personnelle');
  String get legalReviewStatus => _string('legal_review_status');
  String get recommendedStatus => _string('statut_recommande');
  String get fiscalNature => _string('nature_fiscale_probable');
  String get cumulBody => _string('organisme_cumul');
  bool get isRegulated => raw['activite_reglementee'] == true;
  bool get hasMarkdownContent => markdownContent.isNotEmpty;

  List<String> get alerts => _stringList('alertes');
  List<String> get documents => _stringList('documents_a_collecter');
  List<String> get supports => _stringList('organismes_accompagnement');
  List<String> get assurances => _stringList('assurances');
  List<String> get alternateStatuses => _stringList('statut_alternatif');
  List<String> get officialSources => _stringList('sources_officielles');
  List<String> get indicativeCosts => _stringList('couts_indicatifs');
  List<String> get actionPlan =>
      _stringListFromMap(_map('parcours'), '7_plan_30_jours');
  List<String> get aids => _stringListFromMap(_map('parcours'), '5_aides');
  List<String> get processSteps =>
      _stringListFromMap(_map('parcours'), '4_demarches');

  Map<String, dynamic> get fiscality => _map('fiscalite');

  Map<String, dynamic> toDerivedData({
    required String region,
    required String currentStatus,
    required Map<String, dynamic> fallback,
  }) {
    final fallbackRecommendation =
        (fallback['recommendation'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final fallbackCosts =
        (fallback['costs'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final fallbackSummary =
        (fallback['summary'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final fallbackLegalStatus =
        (fallback['recommendedLegalStatus'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    final generatedRegulationTutorial = <Map<String, dynamic>>[
      {
        'title': 'Activité libre ou réglementée',
        'description': isRegulated
            ? 'Cette activité est à considérer comme réglementée pour un agent public. $qualificationRules'
            : (qualificationRules.isNotEmpty
                  ? qualificationRules
                  : 'Aucune contrainte réglementaire forte n’est remontée, mais une vérification reste recommandée.'),
      },
      {
        'title': 'Cumul et obligations d’agent public',
        'description': personalSituation.isNotEmpty
            ? personalSituation
            : 'Vérifiez les règles de cumul, votre temps de travail et l’absence de conflit d’intérêts avant toute immatriculation.',
      },
      {
        'title': 'Protections et assurances',
        'description': assurances.isNotEmpty
            ? 'Assurances à prévoir : ${assurances.join(', ')}.'
            : 'Vérifiez la RC Pro et les protections adaptées à votre activité avant lancement.',
      },
      if (officialSources.isNotEmpty)
        {
          'title': 'Sources officielles à vérifier',
          'description':
              'Des références officielles sont disponibles pour '
              'sécuriser cette activité avant lancement '
              '(${officialSources.length} source(s) recensée(s)).',
        },
    ];
    final markdownRegulationTutorial = _buildMarkdownRegulationTutorial();
    final regulationTutorial = <Map<String, dynamic>>[
      ...(markdownRegulationTutorial.isNotEmpty
          ? markdownRegulationTutorial
          : generatedRegulationTutorial),
      if (markdownRegulationTutorial.isNotEmpty)
        for (final source in officialSources)
          <String, dynamic>{
            'title': 'Source officielle',
            'description': source,
          },
    ];

    final generatedStatusWarnings = <Map<String, dynamic>>[
      {
        'title': 'Cumul fonction publique à sécuriser',
        'description': personalSituation.isNotEmpty
            ? personalSituation
            : 'Demandez une validation écrite avant de démarrer l’activité et vérifiez les règles internes à votre administration.',
        'checks': _dedupePreserveOrder([
          if (cumulBody.isNotEmpty) 'Contacter $cumulBody',
          'Demander une autorisation écrite de cumul',
          'Vérifier le risque de conflit d’intérêts',
          ...documents.take(3).map((item) => 'Préparer : $item'),
        ]),
      },
    ];
    final statusWarnings = _buildMarkdownStatusWarnings();

    final planB = alternateStatuses.isNotEmpty
        ? 'Alternative(s) à envisager : ${alternateStatuses.join(', ')}.'
        : '${fallbackLegalStatus['planB'] ?? fallbackRecommendation['planB'] ?? ''}';

    final legalDisclaimer = legalReviewStatus.isNotEmpty
        ? legalReviewStatus
        : 'La fiche fournit un socle métier. Une validation finale par l’administration employeur ou l’organisme compétent reste recommandée.';

    final recommendedLegalStatus =
        _buildMarkdownRecommendedLegalStatus(
          fallbackLegalStatus: fallbackLegalStatus,
          fallbackRecommendation: fallbackRecommendation,
          fallbackPlanB: planB,
          fallbackDisclaimer: legalDisclaimer,
        ) ??
        <String, dynamic>{
          'recommended': recommendedStatus.isNotEmpty
              ? recommendedStatus
              : (fallbackLegalStatus['recommended'] ??
                    fallbackRecommendation['statut'] ??
                    ''),
          'justification': currentFrame.isNotEmpty
              ? currentFrame
              : (fallbackLegalStatus['justification'] ??
                    fallbackRecommendation['why'] ??
                    ''),
          'planB': planB,
          'disclaimer': legalDisclaimer,
        };

    final recommendation = <String, dynamic>{
      ...fallbackRecommendation,
      'statut': recommendedLegalStatus['recommended'],
      'why': recommendedLegalStatus['justification'],
      'planB': recommendedLegalStatus['planB'],
      'priorites': _dedupePreserveOrder([
        'Autorisation de cumul',
        if (isRegulated) 'Réglementation métier',
        if (assurances.isNotEmpty) 'Assurance professionnelle',
        if (supports.isNotEmpty) supports.first,
      ]),
    };

    final costs = <String, dynamic>{
      ...fallbackCosts,
      'formalitesEstimees': _estimateFormalites(recommendedStatus),
      'ficheCoutsIndicatifs': _dedupePreserveOrder([
        ...indicativeCosts,
        ..._buildFiscalityLines(),
      ]),
      'note': _buildCostNote(),
    };

    final plan30 = actionPlan.isNotEmpty
        ? _buildPlan30(actionPlan)
        : (fallback['plan30'] as List?)
                  ?.map((e) => (e as Map).cast<String, dynamic>())
                  .toList() ??
              <Map<String, dynamic>>[];

    final blockingAlerts = _dedupePreserveOrder([
      ...((fallback['blockingAlerts'] as List?)?.map((e) => '$e').toList() ??
          const <String>[]),
      ...alerts,
      if (isRegulated)
        'Activité réglementée ou sensible : vérification préalable recommandée avant immatriculation.',
    ]);

    final summary = <String, dynamic>{
      ...fallbackSummary,
      'region': region,
      'currentStatus': currentStatus,
      'activity': activity,
      'vigilanceLevel': _normalizeVigilance(vigilance),
      'recommendedPath': category.isNotEmpty
          ? 'Parcours $category'
          : 'Création progressive',
      'recommendedLegalStatus': recommendedLegalStatus['recommended'],
    };

    final markdownTutorialSteps = _buildMarkdownTutorialSteps();
    final markdownAids = _buildMarkdownAids();

    return {
      ...fallback,
      'recommendation': recommendation,
      'blockingAlerts': blockingAlerts,
      'costs': costs,
      'plan30': plan30,
      'aides': markdownAids.isNotEmpty ? markdownAids : _buildAids(),
      'summary': summary,
      'regulationTutorial': regulationTutorial,
      'statusWarnings': statusWarnings.isNotEmpty
          ? statusWarnings
          : generatedStatusWarnings,
      'recommendedLegalStatus': recommendedLegalStatus,
      'steps': markdownTutorialSteps.isNotEmpty
          ? markdownTutorialSteps
          : _buildTutorialSteps(),
    };
  }

  List<Map<String, dynamic>> _buildMarkdownRegulationTutorial() {
    if (!hasMarkdownContent) {
      return const <Map<String, dynamic>>[];
    }
    return _markdownOutline
        .subsectionsForSectionPrefix('1.')
        .map(
          (subsection) => {
            'title': subsection.title,
            'description': subsection.fullText,
          },
        )
        .where((item) => (item['description'] ?? '').trim().isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _buildMarkdownStatusWarnings() {
    if (!hasMarkdownContent) {
      return const <Map<String, dynamic>>[];
    }
    return _markdownOutline
        .subsectionsForSectionPrefix('2.')
        .map(
          (subsection) => {
            'title': subsection.title,
            'description': subsection.prose.isNotEmpty
                ? subsection.prose
                : subsection.fullText,
            'checks': subsection.bullets,
          },
        )
        .where(
          (item) =>
              '${item['description'] ?? ''}'.trim().isNotEmpty ||
              ((item['checks'] as List?)?.isNotEmpty ?? false),
        )
        .toList();
  }

  Map<String, dynamic>? _buildMarkdownRecommendedLegalStatus({
    required Map<String, dynamic> fallbackLegalStatus,
    required Map<String, dynamic> fallbackRecommendation,
    required String fallbackPlanB,
    required String fallbackDisclaimer,
  }) {
    if (!hasMarkdownContent) {
      return null;
    }

    final recommendationSection = _markdownOutline.findSubsection(
      '3.',
      'Recommandation principale',
    );
    final whySection = _markdownOutline.findSubsection(
      '3.',
      'Pourquoi ce statut est adapté',
    );
    final limitsSection = _markdownOutline.findSubsection(
      '3.',
      'Limites du statut',
    );
    final fiscalSection = _markdownOutline.findSubsection(
      '3.',
      'Fiscalité, cotisations et TVA',
    );

    if (recommendationSection == null &&
        whySection == null &&
        limitsSection == null &&
        fiscalSection == null) {
      return null;
    }

    final extractedRecommended = _extractFirstBoldValue(
      recommendationSection?.fullText ?? '',
    );
    final justification = _joinNonEmpty([
      recommendationSection?.fullText ?? '',
      whySection?.fullText ?? '',
    ]);
    final planB = limitsSection?.fullText.trim().isNotEmpty == true
        ? limitsSection!.fullText
        : fallbackPlanB;
    final disclaimer = _joinNonEmpty([
      fiscalSection?.fullText ?? '',
      fallbackDisclaimer,
    ]);

    return <String, dynamic>{
      'recommended': extractedRecommended.isNotEmpty
          ? extractedRecommended
          : (recommendedStatus.isNotEmpty
                ? recommendedStatus
                : (fallbackLegalStatus['recommended'] ??
                      fallbackRecommendation['statut'] ??
                      '')),
      'justification': justification.isNotEmpty
          ? justification
          : (fallbackLegalStatus['justification'] ??
                fallbackRecommendation['why'] ??
                ''),
      'planB': planB,
      'disclaimer': disclaimer.isNotEmpty ? disclaimer : fallbackDisclaimer,
    };
  }

  List<Map<String, dynamic>> _buildMarkdownTutorialSteps() {
    if (!hasMarkdownContent) {
      return const <Map<String, dynamic>>[];
    }

    final subsections = _markdownOutline
        .subsectionsForSectionPrefix('4.')
        .where((item) => item.title.toLowerCase().startsWith('étape '))
        .toList();
    if (subsections.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    return [
      for (var index = 0; index < subsections.length; index += 1)
        _tutorialStep(
          id: _canonicalMarkdownStepId(subsections[index].title, index),
          order: index + 1,
          title: subsections[index].title,
          objective: subsections[index].prose.isNotEmpty
              ? subsections[index].prose
              : subsections[index].fullText,
          todos: subsections[index].bullets,
        ),
    ];
  }

  String _canonicalMarkdownStepId(String title, int index) {
    final normalized = title.toLowerCase();
    if (normalized.contains('cumul') ||
        normalized.contains('situation personnelle')) {
      return 'situation';
    }
    if (normalized.contains('lancer') ||
        normalized.contains('première offre') ||
        normalized.contains('premières offres')) {
      return 'lancement';
    }
    if (normalized.contains('offre') ||
        normalized.contains('budget') ||
        normalized.contains('prix')) {
      return 'offres';
    }
    if (normalized.contains('aide')) {
      return 'aides';
    }
    if (normalized.contains('statut') || normalized.contains('cadre')) {
      return 'statut_lancement';
    }
    if (normalized.contains('dossier')) {
      return 'preparation';
    }
    if (normalized.contains('déclar') || normalized.contains('formalité')) {
      return 'declaration';
    }
    if (normalized.contains('protection') || normalized.contains('assurance')) {
      return 'protections';
    }
    if (normalized.contains('gestion') ||
        normalized.contains('obligation récurrente')) {
      return 'gestion';
    }
    if (normalized.contains('activité') ||
        normalized.contains('règle') ||
        normalized.contains("droit d'exercer")) {
      return 'reglementation';
    }

    const fallbackIds = <String>[
      'reglementation',
      'situation',
      'offres',
      'aides',
      'statut_lancement',
      'preparation',
      'declaration',
      'protections',
      'gestion',
      'lancement',
    ];
    return index < fallbackIds.length
        ? fallbackIds[index]
        : 'markdown_${index + 1}';
  }

  List<Map<String, dynamic>> _buildMarkdownAids() {
    if (!hasMarkdownContent) {
      return const <Map<String, dynamic>>[];
    }

    final subsections = _markdownOutline.subsectionsForSectionPrefix('5.');
    if (subsections.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    final items = <Map<String, dynamic>>[];
    for (final subsection in subsections) {
      if (subsection.title == 'Aides à prévoir dans la base') {
        for (final bullet in subsection.bullets) {
          items.add({
            'name': bullet,
            'desc': 'Mentionnée explicitement dans la fiche métier.',
            'relevant': true,
            'status': 'à checker',
          });
        }
        continue;
      }

      items.add({
        'name': subsection.title,
        'desc': subsection.fullText,
        'relevant': true,
        'status': 'à checker',
      });
    }
    return _dedupeMapsByName(items);
  }

  String _extractFirstBoldValue(String value) {
    final match = RegExp(r'\*\*(.+?)\*\*').firstMatch(value);
    return match == null ? '' : match.group(1)?.trim() ?? '';
  }

  String _joinNonEmpty(List<String> values) {
    return values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .join('\n\n');
  }

  List<Map<String, dynamic>> _buildAids() {
    final items = <Map<String, dynamic>>[];
    for (final name in aids) {
      items.add({
        'name': name,
        'desc':
            'Aide ou accompagnement à vérifier selon votre situation et votre territoire.',
        'relevant': true,
        'status': 'à checker',
      });
    }
    for (final name in supports.take(3)) {
      items.add({
        'name': name,
        'desc':
            'Organisme utile pour valider vos démarches ou obtenir un accompagnement.',
        'relevant': true,
        'status': 'à contacter',
      });
    }
    return _dedupeMapsByName(items);
  }

  List<Map<String, dynamic>> _buildPlan30(List<String> rawPlan) {
    final items = <Map<String, dynamic>>[];
    for (var index = 0; index < rawPlan.length; index++) {
      final entry = rawPlan[index];
      final parts = entry.split(':');
      final firstPart = parts.first.trim();
      final label = parts.length > 1
          ? parts.sublist(1).join(':').trim()
          : entry.trim();
      final week = firstPart.toLowerCase().startsWith('semaine')
          ? _capitalize(firstPart)
          : 'Semaine ${index + 1}';
      items.add({'week': week, 'label': label, 'done': false});
    }
    return items;
  }

  List<Map<String, dynamic>> _buildTutorialSteps() {
    return [
      _tutorialStep(
        id: 'reglementation',
        order: 1,
        title: 'Vérifier la réglementation métier',
        objective:
            'Confirmer que l’activité peut être exercée dans votre contexte.',
        todos: _dedupePreserveOrder([
          if (qualificationRules.isNotEmpty) qualificationRules,
          ...alerts.take(2),
        ]),
      ),
      _tutorialStep(
        id: 'situation',
        order: 2,
        title: 'Sécuriser votre situation d’agent public',
        objective: 'Valider le cumul et conserver les accords utiles.',
        todos: _dedupePreserveOrder([
          if (cumulBody.isNotEmpty) 'Contacter $cumulBody',
          'Demander une autorisation écrite de cumul',
          ...documents.take(2).map((item) => 'Préparer : $item'),
        ]),
      ),
      _tutorialStep(
        id: 'cadre',
        order: 3,
        title: 'Choisir le cadre de démarrage',
        objective:
            'Sélectionner le statut le plus adapté à la phase de lancement.',
        todos: _dedupePreserveOrder([
          if (recommendedStatus.isNotEmpty)
            'Vérifier le statut recommandé : $recommendedStatus',
          ...alternateStatuses.map((item) => 'Comparer avec : $item'),
          if (fiscalNature.isNotEmpty)
            'Contrôler la nature fiscale : $fiscalNature',
        ]),
      ),
      _tutorialStep(
        id: 'formalites',
        order: 4,
        title: 'Préparer et déposer les formalités',
        objective: 'Avancer de façon ordonnée jusqu’à la déclaration.',
        todos: processSteps.isNotEmpty
            ? processSteps
            : const [
                'Décrire l’activité',
                'Déclarer au guichet unique',
                'Conserver les justificatifs',
              ],
      ),
      _tutorialStep(
        id: 'protections',
        order: 5,
        title: 'Mettre en place les protections',
        objective: 'Couvrir les risques principaux avant le lancement.',
        todos: assurances.isNotEmpty
            ? assurances
            : const [
                'Vérifier la RC Pro',
                'Contrôler les mentions légales utiles',
              ],
      ),
      _tutorialStep(
        id: 'aides',
        order: 6,
        title: 'Identifier les aides et appuis',
        objective: 'Ne pas démarrer sans vérifier les leviers disponibles.',
        todos: _dedupePreserveOrder([...aids.take(4), ...supports.take(2)]),
      ),
      _tutorialStep(
        id: 'lancement',
        order: 7,
        title: 'Lancer sur 30 jours',
        objective: 'Passer de la validation à l’exécution.',
        todos: actionPlan.isNotEmpty
            ? actionPlan
            : const ['Planifier 4 semaines de lancement'],
      ),
    ];
  }

  List<String> _buildFiscalityLines() {
    const labels = <String, String>{
      'seuil_micro_service_2026':
          'Seuil micro-fiscal prestations de services 2026',
      'cotisations_micro_bic_service_2026':
          'Cotisations micro-sociales BIC services 2026',
      'tva_franchise_service_base_2026': 'Franchise en base de TVA - seuil',
      'tva_franchise_service_majore_2026':
          'Franchise en base de TVA - seuil majoré',
      'tva_franchise_service_base': 'Franchise en base de TVA - seuil',
      'tva_franchise_service_majore': 'Franchise en base de TVA - seuil majoré',
      'compte_dedie': 'Compte bancaire dédié',
      'cfe': 'Cotisation foncière des entreprises',
    };
    final lines = <String>[];
    for (final entry in fiscality.entries) {
      final value = '${entry.value}'.trim();
      if (value.isEmpty) continue;
      final label = labels[entry.key] ?? entry.key.replaceAll('_', ' ');
      lines.add('$label : $value');
    }
    return _dedupePreserveOrder(lines);
  }

  String _buildCostNote() {
    final parts = <String>[];
    if (indicativeCosts.isNotEmpty) {
      parts.add(indicativeCosts.join(' | '));
    }
    if (fiscality.isNotEmpty) {
      final thresholds = <String>[];
      final serviceThreshold = '${fiscality['seuil_micro_service_2026'] ?? ''}'
          .trim();
      if (serviceThreshold.isNotEmpty) {
        thresholds.add('Seuil micro service 2026 : $serviceThreshold');
      }
      final vatThreshold = '${fiscality['tva_franchise_service_base'] ?? ''}'
          .trim();
      if (vatThreshold.isNotEmpty) {
        thresholds.add('Franchise TVA base : $vatThreshold');
      }
      if (thresholds.isNotEmpty) {
        parts.add(thresholds.join(' | '));
      }
    }
    return parts.join(' ');
  }

  Map<String, dynamic> _tutorialStep({
    required String id,
    required int order,
    required String title,
    required String objective,
    required List<String> todos,
  }) {
    return {
      'id': id,
      'order': order,
      'title': title,
      'objective': objective,
      'todos': todos,
      'status': 'todo',
    };
  }

  Map<String, dynamic> _estimateFormalites(String statusLabel) {
    final normalized = statusLabel.toLowerCase();
    if (normalized.contains('micro')) {
      return {'min': 0, 'max': 50};
    }
    if (normalized.contains('entreprise individuelle') ||
        normalized.contains('ei')) {
      return {'min': 0, 'max': 80};
    }
    if (normalized.contains('sas') ||
        normalized.contains('eurl') ||
        normalized.contains('sarl')) {
      return {'min': 120, 'max': 350};
    }
    return {'min': 0, 'max': 120};
  }

  String _normalizeVigilance(String value) {
    switch (value.trim().toLowerCase()) {
      case 'élevé':
      case 'eleve':
        return 'Élevé';
      case 'moyen':
        return 'Moyen';
      case 'faible':
        return 'Faible';
      default:
        return value.trim().isEmpty ? 'Moyen' : value.trim();
    }
  }

  Map<String, dynamic> _map(String key) {
    final value = raw[key];
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  String _string(String key) {
    return '${raw[key] ?? ''}'.trim();
  }

  String _stringFromMap(Map<String, dynamic> map, String key) {
    return '${map[key] ?? ''}'.trim();
  }

  List<String> _stringList(String key) {
    final value = raw[key];
    if (value is List) {
      return value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  List<String> _stringListFromMap(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is List) {
      return value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  List<String> _dedupePreserveOrder(List<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) {
        continue;
      }
      result.add(trimmed);
    }
    return result;
  }

  List<Map<String, dynamic>> _dedupeMapsByName(
    List<Map<String, dynamic>> values,
  ) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final value in values) {
      final name = '${value['name'] ?? ''}'.trim();
      if (name.isEmpty || !seen.add(name)) {
        continue;
      }
      result.add(value);
    }
    return result;
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _MarkdownOutline {
  _MarkdownOutline({required this.sections});

  factory _MarkdownOutline.parse(String markdown) {
    if (markdown.trim().isEmpty) {
      return _MarkdownOutline(sections: const <_MarkdownSection>[]);
    }

    final sections = <_MarkdownSection>[];
    String? currentSectionTitle;
    String? currentSubsectionTitle;
    final currentLines = <String>[];
    final currentSubsections = <_MarkdownSubsection>[];

    void flushSubsection() {
      if (currentSubsectionTitle == null) {
        currentLines.clear();
        return;
      }
      currentSubsections.add(
        _MarkdownSubsection(
          title: currentSubsectionTitle,
          rawLines: List<String>.from(currentLines),
        ),
      );
      currentLines.clear();
    }

    void flushSection() {
      flushSubsection();
      if (currentSectionTitle != null) {
        sections.add(
          _MarkdownSection(
            title: currentSectionTitle,
            subsections: List<_MarkdownSubsection>.from(currentSubsections),
          ),
        );
      }
      currentSubsections.clear();
    }

    for (final rawLine in markdown.split('\n')) {
      final line = rawLine.trimRight();
      final trimmed = line.trim();

      if (trimmed.startsWith('## ')) {
        flushSection();
        currentSectionTitle = trimmed.substring(3).trim();
        currentSubsectionTitle = null;
        continue;
      }

      if (trimmed.startsWith('### ')) {
        flushSubsection();
        currentSubsectionTitle = trimmed.substring(4).trim();
        continue;
      }

      if (trimmed == '---' || trimmed.startsWith('# ')) {
        continue;
      }

      if (currentSubsectionTitle != null) {
        currentLines.add(line);
      }
    }

    flushSection();
    return _MarkdownOutline(sections: sections);
  }

  final List<_MarkdownSection> sections;

  List<_MarkdownSubsection> subsectionsForSectionPrefix(String prefix) {
    for (final section in sections) {
      if (section.title.startsWith(prefix)) {
        return section.subsections;
      }
    }
    return const <_MarkdownSubsection>[];
  }

  _MarkdownSubsection? findSubsection(String sectionPrefix, String title) {
    for (final subsection in subsectionsForSectionPrefix(sectionPrefix)) {
      if (subsection.title == title) {
        return subsection;
      }
    }
    return null;
  }
}

class _MarkdownSection {
  const _MarkdownSection({required this.title, required this.subsections});

  final String title;
  final List<_MarkdownSubsection> subsections;
}

class _MarkdownSubsection {
  _MarkdownSubsection({required this.title, required List<String> rawLines})
    : _rawLines = rawLines;

  final String title;
  final List<String> _rawLines;

  List<String> get bullets => _rawLines
      .map((line) => line.trim())
      .where((line) => line.startsWith('* ') || line.startsWith('- '))
      .map((line) => line.substring(2).trim())
      .where((line) => line.isNotEmpty)
      .toList();

  String get prose {
    final paragraphs = <String>[];
    final buffer = <String>[];

    void flush() {
      final paragraph = buffer.join(' ').trim();
      if (paragraph.isNotEmpty) {
        paragraphs.add(paragraph);
      }
      buffer.clear();
    }

    for (final rawLine in _rawLines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        flush();
        continue;
      }
      if (line.startsWith('* ') || line.startsWith('- ')) {
        flush();
        continue;
      }
      buffer.add(line);
    }
    flush();

    return paragraphs.join('\n\n');
  }

  String get fullText {
    final parts = <String>[];
    if (prose.isNotEmpty) {
      parts.add(prose);
    }
    if (bullets.isNotEmpty) {
      parts.add(bullets.map((item) => '* $item').join('\n'));
    }
    return parts.join('\n\n').trim();
  }
}
