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
| `security-controls` | 2/9 |
| `seo_acquisition_readiness` | 3/12 |
| `rgpd_readiness` | 1/7 |
| `mobile_readiness` | 1/8 |
| `production_go_live_readiness` | 1/10 |
| `scalability_resilience_readiness` | 1/11 |
| `messaging-readiness` | 0/12 |
| `18-point-completion` | 1/18 (16 `blocked`) |

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

- `app-check-functions-enforced` — seul contrôle App Check réellement non
  appliqué (Firestore et Storage le sont déjà, voir §3 de l'audit).
- `app-check-firestore-enforced`, `app-check-storage-enforced` — **déjà actifs
  en production**, il ne manque que la capture déposée dans
  `docs/evidence/security/`.
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

1. **Lancer le test fermé Play** (12 testeurs, 14 jours) — c'est le seul délai
   incompressible, tout le reste peut avancer en parallèle.
2. **Déposer les preuves App Check Firestore et Storage** — deux contrôles
   gagnés en quelques minutes, pour un travail déjà fait.
3. **Trancher `app-check-functions-enforced`** : l'activer, ou documenter
   formellement son report.
4. **Instruire le lot des 29** contrôles dont les preuves existent — c'est là
   que le ratio effort/résultat est le meilleur.
5. **Traiter `brace-expansion`** (`npm audit fix`, non cassant d'après le
   rapport régénéré) pour approcher `dependency-audit-clean`.
6. **Reprendre `18-point-completion`** : 16 contrôles y sont `blocked`, ce qui
   suggère une dépendance amont à lever avant tout le reste.

## Ce que ce plan ne prétend pas

Il ne fixe pas de date de go-live et ne déclare aucun contrôle vérifié. Un
pré-prod « 10/10 » obtenu en éditant des fichiers JSON n'aurait aucune valeur :
la leçon de l'audit du 14/08 est précisément qu'un indicateur au vert peut
masquer une fonction cassée depuis dix jours, et qu'un indicateur `pending` peut
masquer un contrôle en réalité déjà actif. Les deux erreurs coûtent cher, dans
les deux sens.
