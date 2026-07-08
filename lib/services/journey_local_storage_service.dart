import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Clé SharedPreferences utilisée pour la sauvegarde locale du dernier
/// "parcours personnalisé" validé par l'utilisateur. Cette sauvegarde est
/// disponible pour tous les abonnements (Gratuit inclus), avec un quota
/// mensuel géré par `JourneyEntitlementsService`.
const String kLocalSavedJourneyPrefsKey = 'toolbox.saved_journey.latest';

/// Sauvegarde/lecture du parcours personnalisé stocké localement sur
/// l'appareil (aucune synchronisation cloud pour cette copie).
class JourneyLocalStorageService {
  const JourneyLocalStorageService();

  Future<void> saveSnapshot(Map<String, dynamic> snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLocalSavedJourneyPrefsKey, jsonEncode(snapshot));
  }

  Future<Map<String, dynamic>?> loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kLocalSavedJourneyPrefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kLocalSavedJourneyPrefsKey);
  }
}
