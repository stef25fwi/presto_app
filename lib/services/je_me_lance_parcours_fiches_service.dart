import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../utils/keyword_suggester.dart';

/// Charge et indexe les fiches parcours par statut (ex. `fonctionnaire`)
/// et activité, générées à partir du pack `parcours_fiches_fonctionnaire`.
///
/// Collection Firestore de référence : `parcoursFiches` (voir
/// README_SCHEMA_FIRESTORE.md du pack). Ici les fiches sont embarquées comme
/// asset local pour un accès synchrone et hors-ligne dans le parcours.
class JeMeLanceParcoursFichesService {
  JeMeLanceParcoursFichesService._();

  static final JeMeLanceParcoursFichesService instance =
      JeMeLanceParcoursFichesService._();

  static const _assetPath = 'assets/data/parcours_fiches_fonctionnaire.json';

  Map<String, Map<String, dynamic>>? _byKey;
  Future<void>? _loading;

  String _key(String statutUtilisateur, String activite) =>
      '${KeywordSuggester.normalize(statutUtilisateur)}|${KeywordSuggester.normalize(activite)}';

  /// À appeler une fois (ex. au bootstrap de la page) pour garantir que
  /// [find] pourra répondre de façon synchrone ensuite.
  Future<void> ensureLoaded() {
    if (_byKey != null) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(raw) as List<dynamic>;
      final map = <String, Map<String, dynamic>>{};
      for (final item in decoded) {
        final fiche = (item as Map).cast<String, dynamic>();
        final statut = '${fiche['statut_utilisateur'] ?? ''}';
        final activite = '${fiche['activite'] ?? ''}';
        if (statut.isEmpty || activite.isEmpty) continue;
        map[_key(statut, activite)] = fiche;
      }
      _byKey = map;
    } catch (_) {
      // Pack absent/corrompu : le parcours reste sur la logique générique.
      _byKey = const {};
    }
  }

  /// Retourne la fiche correspondant au statut + activité, ou `null` si le
  /// pack n'est pas encore chargé ou si aucune fiche ne correspond.
  Map<String, dynamic>? find({
    required String statutUtilisateur,
    required String activite,
  }) {
    if (statutUtilisateur.isEmpty || activite.isEmpty) return null;
    return _byKey?[_key(statutUtilisateur, activite)];
  }
}
