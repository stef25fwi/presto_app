# Restrictions des clés API — relevé du 17/08/2026

Contrôle : `api-keys-restricted` (`quality/security-controls.json`).
Projet : `presto-app-74abe`. Relevé effectué par l'administrateur du projet
depuis Cloud Shell, sortie brute analysée dans cette session.

## Statut : le contrôle échoue

**Aucune des 7 clés API du projet ne porte de restriction d'application.**
Le contrôle exige les deux axes ; seul l'axe « restriction d'API » est
satisfait.

## Méthode, rejouable

```
gcloud services api-keys list --project=presto-app-74abe --format=json
```

Cette commande ne renvoie pas le matériel des clés (`get-key-string` est
un appel distinct), sa sortie est donc archivable sans exposer de secret.
La colonne « Restrictions » de la console GCP n'affiche **que** l'axe API :
elle ne suffit pas à vérifier ce contrôle et donne une fausse impression de
conformité. Passer par `gcloud` est la seule lecture complète.

## Relevé

| Clé | Créée | Restriction d'application | Restriction d'API |
|---|---|---|---|
| `Clé API 1` (liée au SA `vertex-express`) | 25/07/2026 | **absente** — aucun champ | `aiplatform` (1) |
| `iOS key (auto created by Firebase)` | 08/05/2026 | `iosKeyRestrictions: {}` — **liste vide** | 27 services |
| `Gemini Developer API key (auto created by Firebase)` | 07/05/2026 | **absente** — aucun champ | `generativelanguage` (1) |
| `Browser key (auto created by Firebase)` | 15/04/2026 | `browserKeyRestrictions: {}` — **liste vide** | 27 services |
| `places-server-prod-2026-01.` | 02/01/2026 | **absente** — pas d'allowlist IP | `places-backend` (1) |
| `Android key (auto created by Firebase)` | 01/12/2025 | `androidKeyRestrictions: {}` — **liste vide** | 27 services |
| `Browser key (auto created by Firebase)` | 22/11/2025 | `browserKeyRestrictions: {}` — **liste vide** | 26 services |

La console affiche « 25 API » / « 24 API » là où la sortie JSON liste 27 et
26 services : la console exclut quelques entrées de son décompte. C'est la
sortie `gcloud` qui fait foi.

### Lecture de `{}`

Trois clés portent un objet de restriction d'application **vide** :
l'allowlist (`allowedReferrers`, `allowedBundleIds`,
`allowedApplications`) ne contient aucune entrée. Quelle que soit la façon
dont GCP résout une liste vide à l'exécution, deux faits sont établis :

1. Le contrôle exige des allowlists **renseignées** (« origines HTTP pour
   le Web, nom de package + empreinte SHA pour Android, bundle ID pour
   iOS »). Aucune ne l'est.
2. Empiriquement, rien n'est appliqué : `ilipresto.fr` fonctionne en
   production avec la clé navigateur et une liste de référents vide. Si la
   liste vide valait « tout refuser », le site serait cassé. Il ne l'est
   pas.

## Portée réelle du risque

Une clé Firebase client est publique par construction — elle est dans le
bundle web et dans l'APK. Ce n'est pas le secret qui protège, ce sont les
restrictions et App Check. Or App Check **est** appliqué sur Firestore,
Storage et les callables Functions (contrôles `app-check-*`, tous
`verified`). Le socle de protection des données tient donc.

Ce que les restrictions absentes exposent malgré tout :

- **`identitytoolkit` et `securetoken`** (Firebase Auth) figurent dans
  l'allowlist des 4 clés client et ne sont pas couverts par l'enforcement
  App Check listé dans les contrôles vérifiés. Une clé recopiée depuis le
  bundle permet de solliciter les flux d'authentification depuis n'importe
  quelle origine — création de comptes, consommation de quota.
- **Trois APIs facturées à l'usage sans aucune restriction** :
  `places-backend` (clé serveur, sans allowlist IP), `generativelanguage`
  (Gemini) et `aiplatform` (Vertex). C'est le risque le plus concret :
  facture, pas fuite de données.
- **`sqladmin.googleapis.com`** (Cloud SQL Admin) figure dans l'allowlist
  API des 4 clés client. C'est le gabarit par défaut de Firebase, et le
  projet n'expose pas d'instance Cloud SQL — sans effet aujourd'hui, mais
  cette API n'a rien à faire dans la portée d'une clé publique.

## Constats liés, relevés à la même date

### Empreintes Android asymétriques

`android/app/google-services.json` enregistre deux packages avec un nombre
d'empreintes différent :

| Package | Empreintes SHA-1 |
|---|---|
| `com.presto.app` (ancien) | `37c41a39…dd62` **et** `94598104…0006` |
| `fr.ilipresto.app` (**actuel**, = `applicationId`) | `37c41a39…dd62` seulement |

Le package effectivement livré est `fr.ilipresto.app`, et c'est celui qui
n'a qu'une empreinte. C'est le motif exact que l'énoncé du contrôle
signale (« les empreintes Android doivent inclure celle de la clé de
signature Play, pas seulement celle d'upload »). Déterminer laquelle des
deux est l'upload et laquelle la signature Play exige Play Console →
Configuration → Intégrité de l'app → Signature de l'app.

Urgence atténuée : `PLAY_SERVICE_ACCOUNT_JSON` n'existe pas encore
(`docs/deployment/playstore-launch-checklist.md`, ligne 1.2), la
publication Play n'est donc pas faite. À corriger **avant** publication
plutôt qu'en réaction à une panne.

### Clé navigateur périmée publiée dans un artefact de build

Deux `Browser key` coexistent. L'app web en production utilise
`AIzaSyCXzhQcvF…` (`lib/firebase_options.dart`). L'autre,
`AIzaSyB-Oo_86V…`, apparaît dans `docs/firebase-messaging-sw.js` — au sein
d'un build Flutter web complet commité sous `docs/` (94 Mo :
`main.dart.js`, `canvaskit/`, `flutter_service_worker.js`, `assets/`).

Soit une clé sans restriction, publiée dans le dépôt, dont plus rien
n'atteste l'usage. Même catégorie que `functions/lib/` retiré du suivi le
17/08 : un artefact de build versionné qui dérive.

## Remédiation, par ordre de valeur

1. **Restreindre les deux clés serveur facturées, ou les supprimer.**
   Aucune référence à `places-backend` ni à `generativelanguage` n'a été
   trouvée dans `functions/src`, `lib`, `tools` — `google_api.ts` passe par
   `GoogleAuth`/OAuth, pas par une clé API. Si ces clés ne servent plus, les
   supprimer ferme le risque sans configuration. Si elles servent depuis un
   appelant externe, poser une allowlist IP.
2. **Supprimer la `Browser key` périmée** et retirer le build web de
   `docs/` du suivi git (`.gitignore`, comme `functions/lib/`).
3. **Poser les restrictions d'application sur les 3 clés client** :
   référents HTTP pour la clé navigateur, package + SHA-1 pour Android,
   bundle ID pour iOS.
4. **Ajouter l'empreinte de signature Play** à `fr.ilipresto.app`, avant
   publication.
5. **Restreindre l'allowlist API** des clés client : 27 services est le
   gabarit Firebase, pas un périmètre réfléchi. Retirer au minimum
   `sqladmin`.

### Avertissement d'exploitation sur le point 3

Poser des référents HTTP sur la clé navigateur casse la production si la
liste est incomplète. Doivent y figurer `ilipresto.fr` et ses
sous-domaines, **et** le domaine du gestionnaire d'authentification
Firebase (`presto-app-74abe.firebaseapp.com`) si un flux OAuth par
popup/redirection l'emprunte encore — `authDomain` vaut `ilipresto.fr`
dans `firebase_options.dart`, mais le domaine par défaut peut rester
sollicité. À changer hors heure de pointe, avec vérification immédiate
d'une connexion Google réelle.

## Ce qui reste hors d'atteinte d'une session de code

Toutes les actions ci-dessus se font en console GCP / Play Console. Ce
document établit le constat, le rend rejouable et priorise le travail ; il
ne peut pas passer le contrôle à `verified`. Le contrôle ne changera de
statut qu'une fois les restrictions effectivement posées et un nouveau
relevé daté déposé ici.
