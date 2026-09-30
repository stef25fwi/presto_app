# Restrictions des clés API — 30 septembre 2026

Projet : `presto-app-74abe`. Auteur : Codex. Contrôle : `api-keys-restricted`.
**Statut : pending — collecte réelle nécessaire.**

Le fichier de preuve était absent. Aucun accès GCP authentifié n'est disponible
ici. La présence d'une clé cliente dans les fichiers Firebase ne démontre pas
ses restrictions côté serveur ; aucune configuration n'est attestée ici.

## Collecte en lecture seule depuis Cloud Shell

Dans le dépôt contenant les correctifs de la PR #1464 :

```bash
python3 tools/security/collect_external_evidence.py --github
```

Sans `gh` disponible et authentifié, omettre `--github` pour collecter GCP.
Le code 2 signifie collecte partielle ; les résultats obtenus sont conservés
sous `quality_reports/security-external/metadata.json`. Le collecteur liste
et décrit les clés sans appeler `get-key-string`, sans modifier les clés et
sans changer le registre. Les valeurs secrètes sont exclues de la sortie.

| Usage | Vérification requise |
|---|---|
| Web | Origines de production effectives, aucune origine universelle, API explicitement autorisées |
| Android | Package `fr.ilipresto.app`, empreintes de signature effectives, y compris signature Play si distribuée par Play |
| iOS | Bundle du binaire signé correspondant à Firebase et aux restrictions |
| Serveur / Places / VEO | Inventaire complet, APIs autorisées, restrictions compatibles avec l'exécution serveur |

Pour chaque clé, relever identifiant de ressource (jamais valeur), usage,
restrictions d'application, APIs autorisées, auteur et date. Réconcilier
les applications Firebase avec `GOOGLE_PLACES_API_KEY` et `VEO_API_KEY`.
Un export vide ou un refus IAM ne prouve pas la conformité. Ne pas appliquer
une restriction Web à une clé serveur. Après tout changement, valider Auth,
App Check et Places sur Web/Android/iOS avant attestation.

Lorsque le relevé réel est complet, remplacer cette preuve provisoire et
mettre ce seul contrôle à `verified` dans `quality/security-controls.json`.

Références :
- https://cloud.google.com/sdk/gcloud/reference/services/api-keys/list
- https://cloud.google.com/sdk/gcloud/reference/services/api-keys/describe
