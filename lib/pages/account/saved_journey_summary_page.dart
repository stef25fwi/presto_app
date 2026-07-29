import 'package:flutter/material.dart';
import 'package:presto_app/pages/account/guided_journey_page.dart';

/// Ouvre un parcours sauvegardé avec exactement le même renderer guidé que le
/// parcours qui vient d’être généré. Les données historiques restent
/// compatibles et la progression guidée est restaurée lorsqu’elle existe.
class SavedJourneySummaryPage extends StatelessWidget {
  final Map<String, dynamic> snapshot;

  const SavedJourneySummaryPage({super.key, required this.snapshot});

  String _text(String key, {String fallback = ''}) {
    final value = snapshot[key];
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Map<String, dynamic> _map(String key) {
    final value = snapshot[key];
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  List<String> _stringList(String key) {
    final value = snapshot[key];
    if (value is List) return value.map((item) => '$item').toList();
    return const <String>[];
  }

  List<Map<String, dynamic>> _mapList(String key) {
    final value = snapshot[key];
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return GuidedJourneyPage(
      projectLabel: _text('projectLabel'),
      region: _text('region'),
      currentStatus: _text('currentStatus'),
      selectedActivity: _text('selectedActivity'),
      recommendation: _map('recommendation'),
      blockingAlerts: _stringList('blockingAlerts'),
      costs: _map('costs'),
      aides: _mapList('aides'),
      plan30: _mapList('plan30'),
      summary: _map('summary'),
      regulationTutorial: _mapList('regulationTutorial'),
      statusWarnings: _mapList('statusWarnings'),
      recommendedLegalStatus: _map('recommendedLegalStatus'),
      steps: _mapList('steps'),
      guidedProgress: _map('guidedProgress'),
      savedAt: _text('savedAt'),
    );
  }
}
