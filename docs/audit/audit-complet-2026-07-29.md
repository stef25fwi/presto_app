# Audit complet iliprestō — 2026-07-29

## Périmètre et méthode

Audit du dépôt à partir de `main` (`b4c7b8f`), suivi de la remédiation des
constats. Toutes les vérifications ont été exécutées, pas seulement relues :

- SDK Flutter `3.44.6` (version des workflows CI) installé pour exécuter
  `flutter analyze --fatal-infos` et `flutter test --coverage` ;
- build TypeScript (`tsc`) et suite de tests Node des Cloud Functions ;
- `npm audit` sur les deux espaces npm (racine et `functions/`) ;
- barrières qualité du dépôt (`tools/quality/*`) ;
- revue manuelle de `firestore.rules` (885 lignes) et revue OWASP Top 10 du
  code serveur ;
- recherche de secrets en dur ;
- historique GitHub Actions sur `main`.

## Résultat

| # | Constat initial | Sévérité | État |
|---|---|---|---|
| 1 | 7 des 9 contrôles de sécurité obligatoires `pending`, aucune preuve déposée | P0 | **6/9 vérifiés** — 3 restants hors de portée du dépôt |
| 2 | 13 vulnérabilités npm (6 hautes, 7 modérées) ; rapport périmé annonçant 9 modérées / 0 haute | P1 | **Corrigé — 0 vulnérabilité** |
| 3 | Échéance des exceptions App Check jamais appliquée | P1 | **Corrigé** |
| 4 | SSRF latente : jeton `cloud-platform` envoyable à un hôte arbitraire | P1 | **Corrigé** |
| 5 | `storagePath` client non contraint au bucket du projet | P1 | **Corrigé** |
| 6 | Cliquet de couverture resté à 12,2 % pour 51,95 % mesurés | P2 | **Corrigé — relevé à 40 %** |
| 7 | Dette structurelle : 19 fichiers > 1200 lignes | P2 | Inchangé — voir plus bas |

État final des barrières :

```
flutter analyze --fatal-infos          → aucun problème
flutter test --coverage                → 1986 tests, tous passants, 51,95 %
npm --prefix functions run build       → OK
npm --prefix functions test            → 235/235
npm audit (racine et functions)        → 0 vulnérabilité
node tools/quality/check_security_controls.mjs → ready, 6/9 vérifiés
```

## 1. Contrôles de sécurité — de 2 à 6 vérifiés, et surtout prouvés

Le vérificateur `check_security_controls.mjs` ne contrôlait que deux choses :
« le champ `status` vaut `verified` » et « un fichier de preuve existe ». Un
contrôle pouvait donc être marqué vérifié sans que quoi que ce soit ne soit
vérifié — c'était du déclaratif, trivialement contournable.

Le vérificateur exécute désormais une commande pour les contrôles de nature
`automated`, et **dérive** leur statut du code de sortie. Trois contrôles ont
basculé dans cette catégorie :

| Contrôle | Commande exécutée |
|---|---|
| `app-check-functions-enforced` | `check_functions_app_check.mjs` — 79 callables, 0 violation |
| `secrets-inventory-current` | `check_secrets_inventory.mjs` — 10 secrets, 0 écart |
| `dependency-audit-clean` | `generate_dependency_audit.mjs --verify-report` |

`owasp-review-complete` a été fermé par une revue réelle du Top 10 documentée
dans `docs/evidence/security/owasp-review.md` — c'est elle qui a produit les
constats 4 et 5.

**Les 3 contrôles restants (`app-check-firestore-enforced`,
`app-check-storage-enforced`, `api-keys-restricted`) ne peuvent pas être fermés
depuis le dépôt** : ce sont des réglages des consoles Firebase et Google Cloud.
Ils restent honnêtement en `pending`, chacun avec un runbook prêt à l'emploi
sous `docs/evidence/security/`. C'est le seul reliquat avant go-live.

⚠️ Le runbook Firestore porte un avertissement important : le SDK Flutter Web
n'attache pas de jeton App Check aux requêtes Firestore. Basculer Firestore sur
`Enforced` sans traiter ce point **coupera le client web**.

## 2. Dépendances — 13 vulnérabilités → 0

Les 13 remontées ne portaient en réalité que **deux avis** ; tout le reste
n'était que propagation transitive :

- `brace-expansion <=5.0.7` (haute) — déni de service par expansion non bornée ;
- `uuid <11.1.1` (modérée) — absence de contrôle de bornes du buffer.

Trois changements, sans imposer de version majeure aux dépendances directes :

1. `@google-cloud/vertexai` retiré de `functions/package.json` — **déclaré mais
   importé nulle part**, et unique source de `google-auth-library@9 → gaxios@6.7.1` ;
2. `@google-cloud/vision` et `firebase-functions` retirés de la `package.json`
   racine — jamais importés (74 paquets en moins) ;
3. overrides sur les deux seules racines vulnérables, dans les deux espaces.

`firebase-admin` reste en `^13.10.0` : le correctif proposé par
`npm audit fix --force` était un downgrade cassant vers 10.3.0, et
`firebase-functions@7` plafonne de toute façon à `firebase-admin@13.x`.

Non-régression vérifiée : chargement effectif de `uuid`, `brace-expansion`,
`firebase-admin`, `google-gax`, `@google-cloud/storage` et
`@google-cloud/firestore`, plus 235 tests Functions et `flutter analyze`.

**Cause racine du rapport périmé** : le workflow `dependency-audit-report.yml`
ne se déclenchait que sur la branche `audit/prod-hardening-p0-p11` et y
recommittait son résultat — `main` n'était jamais audité. Il s'exécute
désormais sur `main`, sur chaque PR et chaque lundi, et **échoue** si le
rapport versionné est périmé ou si une vulnérabilité haute apparaît. Son
générateur, jusqu'ici en heredoc dans le YAML (ni testable ni exécutable en
local), est devenu `tools/quality/generate_dependency_audit.mjs`, couvert par
7 tests.

## 3. Échéance des exceptions App Check — non appliquée

L'exception App Check de `functions/src/modules/messaging/callables.ts` portait
`reviewBy: '2026-08-31'`, mais cette date n'était **lue nulle part**. C'était un
commentaire : l'exception aurait survécu indéfiniment.

`check_functions_app_check.mjs` applique désormais l'échéance. Passé la date,
l'exception bascule en violation `expired-exception`, cesse de blanchir les
callables qu'elle couvrait, et fait échouer la barrière. 5 tests ajoutés.

## 4 et 5. Deux faiblesses SSRF trouvées par la revue OWASP

**`fetchGoogleApiJson` acceptait une URL arbitraire** tout en y attachant un
jeton OAuth de portée `cloud-platform`. Les deux appelants actuels n'utilisent
que des hôtes littéraux, mais la signature ouvrait la voie à l'exfiltration
d'un jeton très privilégié. Une liste blanche d'hôtes rejette désormais tout
autre hôte, tout schéma non `https:`, et les échappements par identifiants
d'URL (`https://hôte-autorisé@attaquant/`).

**`storagePath` était transmis tel quel à l'API Vision** lorsqu'il commençait
par `gs://`. Ce champ vient du client et n'est que normalisé à la publication :
un client pouvait faire lire la modération dans un bucket arbitraire avec les
identifiants du projet. `resolveModerationImageUri` n'accepte plus qu'un chemin
relatif au bucket du projet, ou un `gs://` désignant ce même bucket, et rejette
chemins absolus et remontées `..`.

11 tests ajoutés sur ces deux correctifs.

## 6. Cliquet de couverture jamais avancé

La politique du dépôt prévoit des paliers `[12.2, 25, 40, 55, 70]`, le seuil
devant monter au fur et à mesure. La couverture mesurée est de **51,95 %**
(23 098 / 44 464 lignes) mais `minimum_percent` était resté à **12,2 %** : la
couverture pouvait régresser de 40 points sans qu'aucune barrière ne réagisse.

Seuil relevé au palier atteint, soit **40 %**, ce qui verrouille le progrès
acquis en gardant de la marge sous les 51,95 % réels.

## 7. Dette structurelle — non traitée, délibérément

19 fichiers dépassent 1200 lignes, jusqu'à 7218 pour
`lib/pages/toolbox_je_me_lance_page.dart`. Ce constat est inchangé et reste
suivi dans `quality/technical-debt-register.md` (TECH-001 à TECH-054).

Ce n'est pas un oubli : découper des fichiers de cette taille est un
refactoring à fort risque de régression fonctionnelle, que ni `flutter analyze`
ni la suite de tests actuelle ne rattraperaient entièrement. Le faire au sein
du même lot que des correctifs de sécurité rendrait ces derniers impossibles à
relire et à revenir en arrière indépendamment. À traiter fichier par fichier,
dans des PR dédiées.

Le plan de traitement est détaillé dans
[`docs/architecture/refactoring-plan-oversized-files.md`](../architecture/refactoring-plan-oversized-files.md) :
31 % de cette dette est déplaçable sans aucun risque, preuve mécanique à
l'appui ; le reste demande d'abord des tests de caractérisation.

## Ce qui reste ouvert

1. **3 contrôles de console** (App Check Firestore et Storage, restrictions de
   clés API) — runbooks prêts, nécessitent un accès au projet
   `presto-app-74abe`. Traiter l'avertissement SDK Web avant toute bascule.
2. **Dette structurelle** — 19 fichiers > 1200 lignes, en PR dédiées.
3. **Couverture** — 51,95 % pour une cible de 70 % ; prochain palier 55 %.
4. **383 `debugPrint`** côté Flutter : revue ciblée des chemins susceptibles de
   journaliser des données personnelles.
5. **Exception App Check messagerie** — échéance au 2026-08-31, désormais
   réellement appliquée par la CI.

## Limites

Les tests Firestore contre l'émulateur (`npm run test:firestore`) n'ont pas été
exécutés : ils exigent l'émulateur Firebase. La revue OWASP est une analyse
statique — ni test d'intrusion, ni vérification des consoles Firebase et Google
Cloud. `npm audit` ne couvre ni les dépendances Dart (`pubspec.lock`), ni les
paquets système de l'image de déploiement.
