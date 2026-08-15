# Plan de mise à niveau pré-production — 2026-08-15

Complète l'[audit complet du 2026-08-14](audit-complet-2026-08-14.md). Ce
document répond à une question simple : que faut-il pour que le pré-prod soit
sans réserve, et qui peut faire quoi.

## Le point le plus important à comprendre

Les portes de qualité de `quality/*.json` ne sont **pas** des vérifications
automatiques. Lecture faite de `tools/quality/check_production_go_live_readiness.mjs`
(l. 13-30), un contrôleur vérifie trois choses :

1. que le statut appartient à `verified` / `pending` / `blocked` ;
2. qu'un contrôle `verified` référence au moins une preuve ;
3. que les fichiers de preuve référencés **existent**.

Il ne vérifie jamais que le travail sous-jacent est fait. Le statut est une
**attestation humaine**.

Conséquence directe : on peut afficher 10/10 partout en basculant des statuts,
sans avoir rien amélioré. C'est précisément ce que la politique du dépôt
interdit — `docs/audit/README.md` : « Un seuil ne doit jamais être abaissé pour
faire passer une PR. » **Ce plan ne propose donc aucune bascule de statut qui ne
soit adossée à une vérification réelle.**

## État mesuré

102 contrôles en attente, répartis en trois familles très différentes :

| Famille | Nombre | Ce que ça signifie |
|---|---:|---|
| Toutes les preuves existent déjà | 29 | Le travail est peut-être fait, l'attestation jamais posée. **Lot à revoir en priorité.** |
| Preuves référencées mais absentes | 20 | Le livrable de preuve reste à produire. |
| Aucune preuve référencée | 53 | Périmètre à définir avant tout travail. |

Par registre :

| Registre | Vérifiés / total |
|---|---:|
| `product-readiness` | 5/5 ✅ |
| `stripe-readiness` | 7/7 ✅ |
| `seo-monitoring-readiness` | 12/12 ✅ |
| `seo-programmatic-local-readiness` | 6/10 |
| `ai-readiness` | 7/15 |
| `accessibility_ux_readiness` | 3/8 |
| `observability_slo` | 3/6 |
| `architecture-readiness` | 2/7 |
| `security-controls` | 5/9 (2/9 avant les attestations du 15/08) |
| `seo_acquisition_readiness` | 3/12 |
| `rgpd_readiness` | 1/7 |
| `mobile_readiness` | 1/8 |
| `production_go_live_readiness` | 1/10 |
| `scalability_resilience_readiness` | 1/11 |
| `messaging-readiness` | 0/12 |
| `18-point-completion` | point 2/18 actif (séquentiel, voir plus bas) |

## La cause profonde de la dérive : des contrôles sans énoncé

**Rectification du 15/08.** Une première version de ce document annonçait 108
contrôles sur 157 (68 %) sans description. Le chiffre était faux : le script de
mesure ne cherchait que `description`, `label` et `title`, alors que plusieurs
registres portent leur énoncé dans `name`, `objective` ou `doneWhen`. Après
correction, le compte réel est de **71 contrôles sur 157 (45 %)**, et sept
registres sont concernés au lieu de dix.

| Registre | Contrôles sans énoncé |
|---|---:|
| `messaging-readiness` | 12/12 |
| `seo-monitoring-readiness` | 12/12 |
| `seo_acquisition_readiness` | 12/12 |
| `scalability_resilience_readiness` | 11/11 |
| `seo-programmatic-local-readiness` | 10/10 |
| `architecture-readiness` | 7/7 |
| `stripe-readiness` | 7/7 |

Sont au contraire correctement énoncés : `18-point-completion` (objectif,
critères `doneWhen`, fichiers requis et commandes de validation par point),
`ai-readiness`, `mobile_readiness`, `rgpd_readiness`, `observability_slo`,
`accessibility_ux_readiness`, `product-readiness`, ainsi que
`security-controls` et `production_go_live_readiness` depuis leur reprise du
15/08.

Le constat de fond reste valable pour les sept registres restants : un contrôle
réduit à un identifiant n'est auditable que par son auteur, et seulement tant
qu'il s'en souvient. Le statut devient une opinion, et il dérive **dans les
deux sens** :

- `app-check-functions-enforced` était `pending` alors qu'il était satisfait
  depuis longtemps, faute que quiconque ait su où regarder (le code, pas la
  console) ;
- à l'inverse, un contrôle peut rester `verified` longtemps après avoir cessé
  d'être vrai, sans que rien ne le signale.

**Recommandation** : donner à chaque contrôle des sept registres restants un
énoncé vérifiable — quelle commande, quelle observation, quel seuil prouve
qu'il est satisfait. `18-point-completion` fournit le modèle à suivre, avec son
triplet `objective` / `doneWhen` / `validationCommands`.

## `18-point-completion` : un programme séquentiel, pas un registre bloqué

**Rectification du 15/08.** Ce document a d'abord présenté les 16 points
`blocked` comme « une dépendance amont à lever ». C'était une mauvaise lecture.
Le registre porte des règles explicites :

```json
"rules": {
  "singleActivePoint": true,
  "priorPointsMustBeVerified": true,
  "laterPointsMustRemainBlocked": true
}
```

`blocked` y est l'**état normal** d'un point pas encore atteint. Un seul point
est actif à la fois, et les suivants doivent rester bloqués par construction.
Il n'y a donc rien à débloquer : le programme est simplement au point 2 sur 18.

| Point | Nom | État |
|---|---|---|
| 1 | Cadrage produit | `verified` |
| 2 | UX/UI et design system | **`active`** |
| 3 → 18 | Architecture technique, … | `blocked` (en attente de leur tour) |

Le point 2 est donc le véritable front de travail. Ses critères sont explicites
— design system centralisé, contrastes, focus, lecteurs d'écran, cibles
tactiles, tailles 320 à 1440 px — et son registre de contrôle est
`quality/accessibility_ux_readiness.json`, qui doit passer intégralement à
`verified` pour promouvoir le point. C'est cohérent avec les 5 contrôles
d'accessibilité en attente, qui exigent un passage sur appareil avec lecteur
d'écran.

**Conséquence pour le go-live** : `all-prior-phases-reviewed` ne peut pas être
satisfait avant la fin des 18 points. Ce n'est pas un blocage à lever, c'est un
programme à dérouler — et l'accessibilité en est l'étape courante.

## Calibrage : tous les `pending` ne sont pas des déficits de preuve

Vérification faite sur `architecture-readiness`, dont deux contrôles figuraient
dans le lot « preuves présentes » :

```
$ python3 tools/quality/check_flutter_architecture_size.py
- lib/pages/user_offers_section.dart: 3429 lines > 500
- lib/widgets/je_me_lance_model_section.dart: 993 lines > 250
  … et de nombreux autres dépassements
```

`architecture-budgets` (`in_progress`) et `p0-debt` (`pending`) sont donc
**correctement déclarés** : le travail n'est réellement pas fait. Le registre
est honnête ici.

C'est un garde-fou utile contre la tentation de traiter le lot des 29 comme un
gisement de points faciles. Chaque contrôle demande une vérification propre, et
certains se solderont par « toujours pending, à juste titre ».

## Ce qui peut être clos depuis le dépôt

Ces contrôles sont vérifiables par exécution ou par lecture de code, sans accès
externe. Ce sont les seuls que je peux légitimement instruire moi-même.

| Contrôle | Registre | Comment le vérifier |
|---|---|---|
| `production-smoke-tests` | go-live | Étape 30 de `deploy.yml`, passée au vert le 15/08 sur `fe0fcdd` |
| `architecture-budgets` | architecture | `flutter-architecture-size.yml` + `quality/flutter_architecture_size_budget.json` |
| `p0-debt` | architecture | Mesurable via `audit_repository.py` — 18 fichiers > 1200 l., en baisse |
| `metrics-accumulation` | ai | `ai-metrics-accumulation.yml` et son historique de runs |
| `scheduled-evaluations` | ai | `ai-evaluations.yml`, planification et derniers runs |
| `validation-fallbacks` | ai | Couvert par le correctif de repli STT (PR #1382) |
| `text-messaging`, `photo-file-messaging`, `audio-messaging` | messaging | Tests existants dans `functions/src/modules/messaging` |
| `moderation-block-report` | messaging | Signalement et blocage vérifiés lors de l'audit (point 3.6 Play Store) |

**Réserve importante** : « vérifiable » ne veut pas dire « à basculer sans
regarder ». Chacun demande une revue de quelques minutes pour confirmer que la
preuve dit bien ce que le contrôle affirme. Je peux les instruire un par un et
documenter la justification dans le registre.

## Ce qui exige une action hors dépôt

Aucune de ces lignes ne peut être close depuis une session de code. Elles
constituent le vrai chemin critique du pré-prod.

### Console Firebase / GCP

- ~~Les trois contrôles App Check~~ — **clos le 15/08**. Firestore et Storage
  étaient appliqués en console, Functions l'était dans le code (83/83 callables,
  politique fail-closed). Preuves déposées dans `docs/evidence/security/`.
- `api-keys-restricted` — restreindre les clés par origine et par package.
- `secrets-inventory-current` — inventaire à produire.
- `monitoring-dashboards-live` — dashboards à constater.
- La révision Cloud Run de `microIaProcessAudio`, encore non élucidée (§1 de
  l'audit) : le déploiement de la PR #1383 servira de test décisif.

### Play Console

Tout le bloc `mobile_readiness` (7/8 en attente) et les sections 1 à 6 de
`docs/deployment/playstore-launch-checklist.md`. Le délai le plus long y est le
test fermé de 12 testeurs pendant 14 jours continus — **à lancer en premier**,
car il conditionne la date de mise en production quel que soit l'avancement du
reste.

### Décisions et actes humains

`go-no-go-decision-recorded`, `incident-contacts-confirmed`,
`rollback-plan-tested`, `release-candidate-tag`, `post-launch-review-scheduled`.
Le plan de rollback existe (`docs/deployment/rollback.md`) mais « testé » est une
affirmation qui demande un exercice réel.

### Accessibilité

Les 5 contrôles en attente (`keyboard-focus`, `screen-reader`,
`responsive-text-scale`, `states-consistency`, `accessibility-audit`) demandent
un passage sur appareil avec lecteur d'écran. Non bloquant pour Play, mais
visible dans le pre-launch report.

## Ordre conseillé

0. **Donner un énoncé vérifiable à chaque contrôle** — préalable à toute
   campagne d'attestation, sans quoi les statuts resteront des opinions.
1. **Lancer le test fermé Play** (12 testeurs, 14 jours) — c'est le seul délai
   incompressible, tout le reste peut avancer en parallèle.
2. ~~Déposer les preuves App Check~~ — **fait**, 2/9 → 5/9.
3. **Instruire le lot des 29** contrôles dont les preuves existent — c'est là
   que le ratio effort/résultat est le meilleur.
5. ~~Traiter `brace-expansion`~~ — **fait le 15/08** : le dépôt est passé de
   1 haute + 7 modérées à 0 haute + 7 modérées, sans changement cassant.
6. **Dérouler `18-point-completion`** à partir du point 2 (UX/UI et design
   system), actuellement actif. Son avancement conditionne
   `all-prior-phases-reviewed` côté go-live.

## Ce que ce plan ne prétend pas

Il ne fixe pas de date de go-live et ne déclare aucun contrôle vérifié. Un
pré-prod « 10/10 » obtenu en éditant des fichiers JSON n'aurait aucune valeur :
la leçon de l'audit du 14/08 est précisément qu'un indicateur au vert peut
masquer une fonction cassée depuis dix jours, et qu'un indicateur `pending` peut
masquer un contrôle en réalité déjà actif. Les deux erreurs coûtent cher, dans
les deux sens.
