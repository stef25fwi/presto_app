import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Vérifie que **toutes** les fiches statut+activité des 7 packs officiels
/// (`assets/data/parcours_fiches_*.json`) sont complètes : chaque fiche doit
/// porter, non vides, tous les champs dont le pipeline du parcours
/// personnalisé (`_applyFicheToRecommendation`) se sert pour remplir les
/// sections affichées à l'écran.
///
/// C'est la garantie que « tous les parcours sont complétés avec les fiches »
/// pour l'intégralité du catalogue (~735 fiches = 7 statuts × ~105 activités),
/// sans avoir à dérouler un parcours widget par activité. Un test E2E de
/// rendu par statut (voir toolbox_je_me_lance_*_journey_test.dart) prouve en
/// complément que ces données complètes sont bien affichées.

const _packs = <String>[
  'assets/data/parcours_fiches_fonctionnaire.json',
  'assets/data/parcours_fiches_retraite.json',
  'assets/data/parcours_fiches_etudiant.json',
  'assets/data/parcours_fiches_salarie.json',
  'assets/data/parcours_fiches_independant.json',
  'assets/data/parcours_fiches_demandeur_emploi.json',
  'assets/data/parcours_fiches_sans_activite.json',
];

/// Champs texte obligatoires (non vides) sur toute fiche.
const _requiredStringFields = <String>[
  'id',
  'id_fiche',
  'titre',
  'statut_utilisateur',
  'categorie',
  'activite',
  'famille',
  'type_activite',
  'niveau_vigilance',
  'code_ape_indicatif',
  'nature_fiscale_probable',
  'statut_recommande',
  'organisme_formalite',
  'qualification_regles',
  'version',
  'legal_review_status',
];

/// Champs liste obligatoires (au moins un élément) sur toute fiche.
const _requiredListFields = <String>[
  'statut_alternatif',
  'organismes_accompagnement',
  'modes_exercice',
  'assurances',
  'documents_a_collecter',
  'alertes',
  'couts_indicatifs',
  'sources_officielles',
  'search_keys',
];

/// Champs map obligatoires (au moins une clé) sur toute fiche.
const _requiredMapFields = <String>[
  'fiscalite',
  'parcours',
];

/// Sous-clés obligatoires (non vides) du bloc `parcours`, qui alimentent
/// directement les sections numérotées du parcours affiché.
const _requiredParcoursKeys = <String>[
  '0_identite',
  '1_regles',
  '2_situation_personnelle',
  '3_cadre',
  '4_demarches',
  '5_aides',
  '6_couts',
  '7_plan_30_jours',
];

bool _isEmptyValue(dynamic v) {
  if (v == null) return true;
  if (v is String) return v.trim().isEmpty;
  if (v is Iterable) return v.isEmpty;
  if (v is Map) return v.isEmpty;
  return false; // bool / num : considéré présent
}

void main() {
  for (final packPath in _packs) {
    group('Complétude du pack ${packPath.split('/').last}', () {
      final file = File(packPath);

      test('le pack existe et contient des fiches', () {
        expect(file.existsSync(), isTrue,
            reason: 'Pack introuvable : $packPath');
        final list = jsonDecode(file.readAsStringSync()) as List<dynamic>;
        expect(list, isNotEmpty);
      });

      test('chaque fiche porte tous les champs requis, non vides', () {
        final list = jsonDecode(file.readAsStringSync()) as List<dynamic>;
        final problems = <String>[];

        for (final raw in list) {
          final fiche = (raw as Map).cast<String, dynamic>();
          final label =
              '${fiche['id_fiche'] ?? fiche['id'] ?? '??'} (${fiche['statut_utilisateur']} × ${fiche['activite']})';

          for (final f in _requiredStringFields) {
            if (_isEmptyValue(fiche[f])) problems.add('$label : champ "$f" manquant/vide');
          }
          for (final f in _requiredListFields) {
            if (fiche[f] is! List || _isEmptyValue(fiche[f])) {
              problems.add('$label : liste "$f" manquante/vide');
            }
          }
          for (final f in _requiredMapFields) {
            if (fiche[f] is! Map || _isEmptyValue(fiche[f])) {
              problems.add('$label : map "$f" manquante/vide');
            }
          }
          // activite_reglementee : booléen, doit être présent (true ou false).
          if (fiche['activite_reglementee'] is! bool) {
            problems.add('$label : "activite_reglementee" absent ou non booléen');
          }

          final parcours = fiche['parcours'];
          if (parcours is Map) {
            for (final k in _requiredParcoursKeys) {
              if (_isEmptyValue(parcours[k])) {
                problems.add('$label : parcours["$k"] manquant/vide');
              }
            }
          }
        }

        expect(
          problems,
          isEmpty,
          reason: 'Fiches incomplètes détectées :\n${problems.join('\n')}',
        );
      });

      test('la clé (statut_utilisateur|activite) est unique dans le pack', () {
        final list = jsonDecode(file.readAsStringSync()) as List<dynamic>;
        final seen = <String>{};
        final dups = <String>[];
        for (final raw in list) {
          final fiche = (raw as Map).cast<String, dynamic>();
          final key =
              '${fiche['statut_utilisateur']}|${fiche['activite']}'.toLowerCase();
          if (!seen.add(key)) dups.add(key);
        }
        expect(dups, isEmpty, reason: 'Doublons statut|activité : $dups');
      });
    });
  }
}
