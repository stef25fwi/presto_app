import 'guided_journey_models.dart';

/// Prépare le contenu réellement affiché dans une étape du parcours guidé.
///
/// Les fiches historiques peuvent contenir la même information dans plusieurs
/// champs (titre, tâche, détail, document ou ressource). Cette projection garde
/// toutes les précisions utiles, mais retire les répétitions visibles :
/// - doublons stricts dans une même section ;
/// - texte identique répété entre checklist, vigilance et documents ;
/// - titre déjà affiché dans la checklist répété au début d'un détail ;
/// - segments identiques répétés dans un même détail ;
/// - ressources pointant vers la même URL.
class GuidedJourneyVisibleContent {
  final List<JourneyChecklistItem> checklist;
  final List<String> warnings;
  final List<String> documents;
  final List<String> details;
  final List<JourneyResourceLink> resources;

  const GuidedJourneyVisibleContent({
    required this.checklist,
    required this.warnings,
    required this.documents,
    required this.details,
    required this.resources,
  });

  factory GuidedJourneyVisibleContent.fromStage(JourneyStage stage) {
    final checklist = _uniqueChecklist(stage.checklist);
    final checklistKeys = checklist
        .map((item) => _normalize(item.label))
        .where((item) => item.isNotEmpty)
        .toSet();

    final warnings = _uniqueStrings(
      stage.warnings,
      excludedKeys: checklistKeys,
    );
    final warningKeys = warnings
        .map(_normalize)
        .where((item) => item.isNotEmpty)
        .toSet();

    final documents = _uniqueStrings(
      stage.documents,
      excludedKeys: <String>{...checklistKeys, ...warningKeys},
    );
    final documentKeys = documents
        .map(_normalize)
        .where((item) => item.isNotEmpty)
        .toSet();

    final alreadyVisible = <String>{
      ...checklistKeys,
      ...warningKeys,
      ...documentKeys,
    };

    return GuidedJourneyVisibleContent(
      checklist: checklist,
      warnings: warnings,
      documents: documents,
      details: _cleanDetails(stage.details, alreadyVisible),
      resources: _uniqueResources(stage.resources),
    );
  }

  static List<JourneyChecklistItem> _uniqueChecklist(
    List<JourneyChecklistItem> values,
  ) {
    final seen = <String>{};
    final result = <JourneyChecklistItem>[];
    for (final item in values) {
      final key = _normalize(item.label);
      if (key.isEmpty || !seen.add(key)) continue;
      result.add(item);
    }
    return result;
  }

  static List<String> _uniqueStrings(
    List<String> values, {
    Set<String> excludedKeys = const <String>{},
  }) {
    final seen = <String>{...excludedKeys};
    final result = <String>[];
    for (final value in values) {
      final cleaned = value.trim();
      final key = _normalize(cleaned);
      if (key.isEmpty || !seen.add(key)) continue;
      result.add(cleaned);
    }
    return result;
  }

  static List<String> _cleanDetails(
    List<String> values,
    Set<String> alreadyVisible,
  ) {
    final seenDetails = <String>{};
    final result = <String>[];

    for (final raw in values) {
      final segmentKeys = <String>{};
      final keptSegments = <String>[];
      for (final segment in raw.split(RegExp(r'\s+—\s+'))) {
        final cleaned = segment.trim();
        final key = _normalize(cleaned);
        if (key.isEmpty ||
            alreadyVisible.contains(key) ||
            !segmentKeys.add(key)) {
          continue;
        }
        keptSegments.add(cleaned);
      }

      final cleanedDetail = keptSegments.join(' — ').trim();
      final detailKey = _normalize(cleanedDetail);
      if (detailKey.isEmpty || !seenDetails.add(detailKey)) continue;
      result.add(cleanedDetail);
    }

    return result;
  }

  static List<JourneyResourceLink> _uniqueResources(
    List<JourneyResourceLink> values,
  ) {
    final seen = <String>{};
    final result = <JourneyResourceLink>[];
    for (final resource in values) {
      final normalizedUrl = resource.url.trim().toLowerCase().replaceFirst(
        RegExp(r'/+$'),
        '',
      );
      final fallbackKey =
          '${_normalize(resource.label)}|${_normalize(resource.description)}';
      final key = normalizedUrl.isEmpty ? fallbackKey : normalizedUrl;
      if (key.isEmpty || !seen.add(key)) continue;
      result.add(resource);
    }
    return result;
  }

  static String _normalize(String value) {
    var normalized = value.toLowerCase().trim();
    const replacements = <String, String>{
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'á': 'a',
      'ã': 'a',
      'ç': 'c',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'œ': 'oe',
      '’': "'",
    };
    for (final entry in replacements.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    return normalized
        .replaceAll(RegExp(r'https?://\S+'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
