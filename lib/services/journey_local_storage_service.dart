import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Clé SharedPreferences du parcours "véritablement sauvegardé" par
/// l'utilisateur (action explicite sur le bouton "Sauvegarder"). Cette
/// sauvegarde est disponible pour tous les abonnements (Gratuit inclus),
/// avec un quota mensuel géré par `JourneyEntitlementsService`. Elle n'est
/// remplacée que par une nouvelle sauvegarde explicite.
const String kLocalSavedJourneyPrefsKey = 'toolbox.saved_journey.latest';

/// Clé SharedPreferences de l'historique : le dernier parcours généré,
/// mis à jour automatiquement à chaque parcours terminé, sans quota et
/// sans action de l'utilisateur. Toujours écrasé par le parcours suivant,
/// indépendamment du parcours "véritablement sauvegardé".
const String kLocalHistoryJourneyPrefsKey = 'toolbox.saved_journey.history';

/// Sauvegarde/lecture du parcours personnalisé stocké localement sur
/// l'appareil (aucune synchronisation cloud pour ces copies).
///
/// Deux emplacements distincts sont gérés :
/// - [saveSnapshot]/[loadSnapshot] : le parcours explicitement sauvegardé
///   par l'utilisateur (limité par le quota mensuel de l'abonnement).
/// - [saveHistorySnapshot]/[loadHistorySnapshot] : le dernier parcours
///   généré, toujours écrasé automatiquement, sans limite.
class JourneyLocalStorageService {
  const JourneyLocalStorageService();

  Future<void> saveSnapshot(Map<String, dynamic> snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLocalSavedJourneyPrefsKey, jsonEncode(snapshot));
  }

  Future<Map<String, dynamic>?> loadSnapshot() async {
    return _load(kLocalSavedJourneyPrefsKey);
  }

  Future<void> clearSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kLocalSavedJourneyPrefsKey);
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
}
