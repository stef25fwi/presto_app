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

## Relevé Cloud Shell reçu le 30/09/2026

Source : export transmis par l'opérateur, collecté à
`2026-09-30T12:58:54.552838+00:00`, projet numérique `151421230024`.
Collecte sans erreur. Sept clés présentes, chacune avec une liste d'API
explicite. Aucune clé n'est attestée conforme par ce relevé.

| Clé / identifiant de ressource | Restrictions observées dans l'export |
|---|---|
| Clé API 1 — 69445b21-c1d7-4a51-94d8-18dc90869035 | API Vertex AI seule ; aucune restriction d'application exportée |
| iOS — 187a10af-5395-4c40-a949-6920e8905082 | Objet iOS vide ; liste de bundle IDs non renseignée dans l'export |
| Gemini — 200c59cd-42c3-4136-9c61-8f673b2ec9e6 | API generativelanguage seule ; aucune restriction d'application exportée |
| Browser — e489e9b6-ea2a-4634-9f48-1fd96ad6a19b | Objet Browser vide ; aucune origine exportée |
| Places serveur — 63c4c266-c0ec-44bf-b837-f39e33346749 | API places-backend seule ; aucune restriction d'application exportée |
| Android — 83512e8a-3c39-496f-b3a8-1dbddacdf97e | allowedApplications vide ; aucun couple package/empreinte exporté |
| Browser — 22d51620-5b04-490f-911e-9042a93a64a2 | Objet Browser vide ; aucune origine exportée |

Un second relevé direct des restrictions est requis pour confirmer que les
listes vides sont réellement la configuration et non une perte de projection.
Les champs camelCase du collecteur correspondent au schéma REST documenté.
Les fichiers Android, iOS et Firebase du dépôt déclarent `fr.ilipresto.app` ;
les empreintes de signature Android doivent venir des certificats réels,
notamment celui de Play si utilisé, jamais d'une valeur supposée.

Les trois clés serveur doivent être rapprochées de leurs usages. Une clé
serverless ne doit pas recevoir une restriction de referrer Web ou une IP
éphémère Cloud Shell : cela casserait Places/VEO. Conserver les scopes API
existants lors de l'ajout des restrictions clientes ; vérifier ensuite
Auth/App Check/Remote Config sur les plateformes concernées. Ne pas supprimer
les clés anciennes sans preuve qu'aucun client déployé ne les utilise.

**Décision : contrôle toujours pending.** L'accès de collecte est maintenant
prouvé par l'export opérateur, mais les restrictions attendues ne le sont pas.
