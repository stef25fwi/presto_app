#!/usr/bin/env python3
"""Transforme et fusionne le pack "complément statuts x activités"
(Agriculteur / Influenceur / Créateur de contenu digital) dans les
fichiers assets/data/parcours_fiches_<statut>.json existants.

Le pack source utilise un schéma `parcours` plus riche/imbriqué que celui
consommé par `_applyFicheToRecommendation` (toolbox_je_me_lance_page.dart),
qui attend des clés plates : 2_situation_personnelle, 3_cadre, 4_demarches,
5_aides, 7_plan_30_jours (+ 0_identite/1_regles/6_couts, non lus mais
conservés pour la cohérence du schéma). Ce script aplatit donc chaque
fiche source vers ce schéma avant de l'ajouter au pack de son statut.
"""
import json
import sys
from pathlib import Path

SRC_DIR = Path(
    "/tmp/claude-0/-home-user-presto-app/27fe871a-7881-5307-af6a-eb24b91012e3"
    "/scratchpad/fiches_parcours_zip/pack_fiches_complement_statuts_activites_firebase/json"
)
ASSETS_DIR = Path("assets/data")

# statut_key (pack) -> nom de fichier asset existant
STATUT_TO_ASSET = {
    "sans_activite": "parcours_fiches_sans_activite.json",
    "salarie": "parcours_fiches_salarie.json",
    "fonctionnaire": "parcours_fiches_fonctionnaire.json",
    "demandeur_emploi": "parcours_fiches_demandeur_emploi.json",
    "etudiant": "parcours_fiches_etudiant.json",
    "retraite": "parcours_fiches_retraite.json",
    "independant": "parcours_fiches_independant.json",
}

# statut_key -> valeur canonique de statut_utilisateur telle qu'utilisée
# par les fiches déjà en production (référence : premier élément de
# chaque asset existant). Le pack source utilise parfois un intitulé
# différent (ex. "fonctionnaire / agent public"), qui ne matcherait pas
# la clé de lookup côté Dart (_ficheStatutParSituation).
CANONICAL_STATUT_UTILISATEUR = {
    "sans_activite": "sans activité",
    "salarie": "salarié",
    "fonctionnaire": "fonctionnaire",
    "demandeur_emploi": "demandeur d’emploi",
    "etudiant": "étudiant",
    "retraite": "retraité",
    "independant": "indépendant",
}


def flatten_parcours(fiche: dict) -> dict:
    p = fiche["parcours"]

    identite = (
        f"Activité {fiche.get('activite', '')}, statut "
        f"{fiche.get('statut_utilisateur', '')}, catégorie "
        f"{fiche.get('categorie', '')}, code APE indicatif "
        f"{fiche.get('code_ape_indicatif', '')}."
    )

    situation_personnelle = fiche.get("regles_statut", {}).get("resume", "") or p.get(
        "2_verifier_situation_personnelle", {}
    ).get("resume", "")

    cadre = p["3_choisir_cadre"].get("recommandation", "")

    demarches: list[str] = []
    for etape in p["4_demarches_etape_par_etape"].get("etapes", []):
        for action in etape.get("actions", []):
            if action not in demarches:
                demarches.append(action)

    aides_block = p["5_identifier_aides"]
    aides: list[str] = []
    for aide in aides_block.get("aides_statut", []) + aides_block.get(
        "aides_metier", []
    ):
        if aide not in aides:
            aides.append(aide)

    couts = list(fiche.get("couts_indicatifs", []))

    plan_semaines = list(p["7_plan_action_30_jours"].items())
    if len(plan_semaines) != 4:
        raise ValueError(f"Attendu 4 semaines, trouvé {len(plan_semaines)}")
    plan_30_jours = []
    for i, (_label, actions) in enumerate(plan_semaines, start=1):
        plan_30_jours.append(f"semaine {i} : " + ", ".join(actions))

    return {
        "0_identite": identite,
        "1_regles": fiche.get("qualification_regles", ""),
        "2_situation_personnelle": situation_personnelle,
        "3_cadre": cadre,
        "4_demarches": demarches,
        "5_aides": aides,
        "6_couts": couts,
        "7_plan_30_jours": plan_30_jours,
    }


def transform(fiche: dict) -> dict:
    statut_key = fiche["statut_key"]
    fiche["statut_utilisateur"] = CANONICAL_STATUT_UTILISATEUR[statut_key]
    fiche["parcours"] = flatten_parcours(fiche)
    fiche.pop("regles_metier", None)
    fiche.pop("bloc_base_de_donnees", None)
    return fiche


def main() -> int:
    source_files = sorted(SRC_DIR.glob("*.json"))
    if len(source_files) != 21:
        print(f"ERREUR: attendu 21 fiches source, trouvé {len(source_files)}")
        return 1

    by_statut: dict[str, list[dict]] = {k: [] for k in STATUT_TO_ASSET}
    for src in source_files:
        fiche = json.loads(src.read_text(encoding="utf-8"))
        statut_key = fiche["statut_key"]
        if statut_key not in STATUT_TO_ASSET:
            print(f"ERREUR: statut_key inconnu '{statut_key}' dans {src.name}")
            return 1
        by_statut[statut_key].append(transform(fiche))

    for statut_key, new_fiches in by_statut.items():
        asset_path = ASSETS_DIR / STATUT_TO_ASSET[statut_key]
        existing = json.loads(asset_path.read_text(encoding="utf-8"))

        existing_ids = {f.get("id_fiche") for f in existing}
        for fiche in new_fiches:
            if fiche["id_fiche"] in existing_ids:
                print(f"ERREUR: id_fiche déjà présent: {fiche['id_fiche']}")
                return 1

        merged = existing + new_fiches
        asset_path.write_text(
            json.dumps(merged, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        print(
            f"{asset_path}: {len(existing)} -> {len(merged)} fiches "
            f"(+{len(new_fiches)})"
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
