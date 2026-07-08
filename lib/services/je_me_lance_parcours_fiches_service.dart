import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../utils/keyword_suggester.dart';

/// Charge et indexe les fiches parcours par statut (ex. `fonctionnaire`,
/// `retraité`, `étudiant`) et activité, générées à partir des packs
/// `parcours_fiches_*`.
///
/// Collection Firestore de référence : `parcoursFiches` (voir
/// README_SCHEMA_FIRESTORE.md des packs). Ici les fiches sont embarquées
/// comme assets locaux pour un accès synchrone et hors-ligne dans le
/// parcours.
class JeMeLanceParcoursFichesService {
  JeMeLanceParcoursFichesService._();

  static final JeMeLanceParcoursFichesService instance =
      JeMeLanceParcoursFichesService._();

  // Un asset par pack statut. Ajouter une entrée ici suffit à brancher un
  // nouveau pack (ex. futur pack "salarié", "étudiant"...).
  static const _assetPaths = <String>[
    'assets/data/parcours_fiches_fonctionnaire.json',
    'assets/data/parcours_fiches_retraite.json',
    'assets/data/parcours_fiches_etudiant.json',
    'assets/data/parcours_fiches_salarie.json',
    'assets/data/parcours_fiches_independant.json',
    'assets/data/parcours_fiches_demandeur_emploi.json',
  ];

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
    final map = <String, Map<String, dynamic>>{};
    for (final assetPath in _assetPaths) {
      try {
        final raw = await rootBundle.loadString(assetPath);
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final item in decoded) {
          final fiche = (item as Map).cast<String, dynamic>();
          final statut = '${fiche['statut_utilisateur'] ?? ''}';
          final activite = '${fiche['activite'] ?? ''}';
          if (statut.isEmpty || activite.isEmpty) continue;
          map[_key(statut, activite)] = fiche;
        }
      } catch (_) {
        // Pack absent/corrompu : les autres packs restent utilisables et le
        // parcours retombe sur la logique générique pour ce statut.
      }
    }
    _byKey = map;
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
