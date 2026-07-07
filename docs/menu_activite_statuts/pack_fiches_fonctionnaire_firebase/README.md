# Pack fiches parcours — Statut Fonctionnaire

Ce ZIP contient 102 fiches générées à partir du fichier `statut_fonctionnaire.md`.

## Contenu

- `markdown/` : une fiche complète lisible par activité, au format identique au modèle fourni.
- `json/` : une fiche structurée par activité, exploitable dans Firebase.
- `firebase/parcours_fiches_fonctionnaire.json` : toutes les fiches dans un seul tableau JSON.
- `firebase/parcours_fiches_fonctionnaire.jsonl` : une fiche par ligne.
- `firebase/seed_parcours_fiches_fonctionnaire.js` : script Node.js d'import Firestore.
- `README_SCHEMA_FIRESTORE.md` : schéma et requête Flutter.

## Collection Firestore recommandée

`parcoursFiches`

## Clé de document

`id_fiche`

## Exemple de document

`fonctionnaire_service_en_salle`

## Note juridique

Le pack reprend un socle officiel : cumul agent public/micro-entreprise, seuils micro 2026, TVA, CFE, SAP, BTP, restauration, ambulant, spectacle, transport et CNAPS. Les activités sensibles comportent des alertes pour contrôle final avant mise en production.
