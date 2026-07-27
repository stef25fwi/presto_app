import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/subscriptions/subscription_credit_service.dart';

/// Cache local du dernier parcours explicitement sauvegardé.
const String kLocalSavedJourneyPrefsKey = 'toolbox.saved_journey.latest';

/// Historique local du dernier parcours généré, toujours écrasé.
const String kLocalHistoryJourneyPrefsKey = 'toolbox.saved_journey.history';

typedef JourneySaveCaller = Future<String> Function(
  Map<String, dynamic> snapshot, {
  String? journeyId,
});
typedef JourneyListCaller = Future<List<SavedJourneyRecord>> Function();
typedef JourneyDeleteCaller = Future<void> Function(String journeyId);

/// Bibliothèque de parcours synchronisée dans Firestore.
///
/// Le dernier parcours reste mis en cache pour conserver la reprise immédiate
/// et la compatibilité avec les écrans historiques. La source de vérité des
/// sauvegardes explicites est toutefois `users/{uid}/savedJourneys`.
class JourneyLocalStorageService {
  const JourneyLocalStorageService({
    JourneySaveCaller? saveJourneyCaller,
    JourneyListCaller? listJourneysCaller,
    JourneyDeleteCaller? deleteJourneyCaller,
  })  : _saveJourneyCaller = saveJourneyCaller,
        _listJourneysCaller = listJourneysCaller,
        _deleteJourneyCaller = deleteJourneyCaller;

  static final SubscriptionCreditService _credits =
      SubscriptionCreditService();

  final JourneySaveCaller? _saveJourneyCaller;
  final JourneyListCaller? _listJourneysCaller;
  final JourneyDeleteCaller? _deleteJourneyCaller;

  Future<void> saveSnapshot(Map<String, dynamic> snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final currentCache = await loadSnapshot();
    final identity = _journeyIdentity(snapshot);
    final cachedIdentity = '${currentCache?['_journeyIdentity'] ?? ''}';
    final cachedCloudId = '${currentCache?['_cloudJourneyId'] ?? ''}'.trim();
    final journeyId = identity == cachedIdentity && cachedCloudId.isNotEmpty
        ? cachedCloudId
        : null;

    final saveJourney = _saveJourneyCaller ?? _credits.saveJourney;
    final cloudId = await saveJourney(
      _withoutLocalMetadata(snapshot),
      journeyId: journeyId,
    );
    final cache = <String, dynamic>{
      ...snapshot,
      '_cloudJourneyId': cloudId,
      '_journeyIdentity': identity,
    };
    await prefs.setString(kLocalSavedJourneyPrefsKey, jsonEncode(cache));
  }

  Future<Map<String, dynamic>?> loadSnapshot() async {
    return _load(kLocalSavedJourneyPrefsKey);
  }

  /// Efface uniquement le cache de reprise. Les éléments de la bibliothèque
  /// sont supprimés explicitement via [deleteLibraryJourney].
  Future<void> clearSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kLocalSavedJourneyPrefsKey);
  }

  Future<List<SavedJourneyRecord>> loadLibrary() {
    final listJourneys = _listJourneysCaller ?? _credits.listJourneys;
    return listJourneys();
  }

  Future<void> deleteLibraryJourney(String journeyId) async {
    final deleteJourney = _deleteJourneyCaller ?? _credits.deleteJourney;
    await deleteJourney(journeyId);
    final cached = await loadSnapshot();
    if ('${cached?['_cloudJourneyId'] ?? ''}' == journeyId) {
      await clearSnapshot();
    }
  }

  Future<void> saveHistorySnapshot(Map<String, dynamic> snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLocalHistoryJourneyPrefsKey, jsonEncode(snapshot));
  }

  Future<Map<String, dynamic>?> loadHistorySnapshot() async {
    return _load(kLocalHistoryJourneyPrefsKey);
  }

  Future<Map<String, dynamic>?> _load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _journeyIdentity(Map<String, dynamic> snapshot) {
    final summary = snapshot['summary'] is Map
        ? Map<String, dynamic>.from(snapshot['summary'] as Map)
        : const <String, dynamic>{};
    final project = '${snapshot['projectLabel'] ?? summary['title'] ?? ''}'
        .trim()
        .toLowerCase();
    final activity =
        '${snapshot['selectedActivity'] ?? summary['activity'] ?? ''}'
            .trim()
            .toLowerCase();
    final status = '${snapshot['currentStatus'] ?? summary['currentStatus'] ?? ''}'
        .trim()
        .toLowerCase();
    final region = '${snapshot['region'] ?? summary['region'] ?? ''}'
        .trim()
        .toLowerCase();
    return '$project|$activity|$status|$region';
  }

  static Map<String, dynamic> _withoutLocalMetadata(
    Map<String, dynamic> snapshot,
  ) {
    return <String, dynamic>{
      for (final entry in snapshot.entries)
        if (!entry.key.startsWith('_')) entry.key: entry.value,
    };
  }
}
