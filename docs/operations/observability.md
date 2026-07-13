# Observabilité production

## Objectif

Détecter une régression avant qu’elle ne soit signalée massivement par les utilisateurs, relier chaque erreur à une version et mesurer l’impact technique et commercial.

## Indicateurs de service

| Domaine | Indicateur | Objectif initial |
|---|---|---:|
| Stabilité | sessions sans crash | > 99,5 % |
| Disponibilité | parcours principal disponible | 99,9 % |
| Interface | interaction locale p95 | < 200 ms |
| Functions hors IA | latence p95 | < 800 ms |
| Publication | soumissions réussies | > 99 % |
| Paiement | traitements confirmés | > 99,5 % |
| Notifications | envois acceptés | > 98 % |
| Web | affichage initial p75 | < 2,5 s |

## Sources

- Crashlytics : erreurs fatales et non fatales par version ;
- Firebase Performance : démarrage, réseau et traces métier ;
- Cloud Logging : Functions et webhooks ;
- Analytics : tunnel et rétention après consentement ;
- Stripe : paiements, renouvellements, remboursements et échecs ;
- Firestore : lectures, écritures, index, refus de règles et coût ;
- GitHub Actions : commit, artifact, tests et déploiement.

## Journaux structurés

Chaque log backend important doit inclure :

- `event` ;
- `severity` ;
- `environment` ;
- `function_name` ;
- `release_sha` si disponible ;
- `correlation_id` non personnel ;
- `duration_ms` ;
- `result` et code d’erreur normalisé.

Ne jamais enregistrer de jeton, contenu de message, transcription, moyen de paiement ou donnée personnelle non indispensable.

## Alertes minimales

- hausse des erreurs Functions ou Crashlytics ;
- taux de paiement échoué supérieur au seuil ;
- webhook Stripe non traité ou en retard ;
- publication ou messagerie sous le SLO ;
- quota Firestore ou Storage approchant ;
- hausse brutale des lectures par utilisateur actif ;
- build ou déploiement de production échoué ;
- App Check ou Auth refusant anormalement les requêtes.

## Tableau de bord technique

Afficher au minimum :

- version déployée ;
- sessions sans crash ;
- erreurs par parcours ;
- latence p50/p95/p99 ;
- disponibilité ;
- coût Firestore et Functions ;
- lectures par MAU ;
- paiement et webhook ;
- temps de génération IA ;
- taille du bundle web.

## Corrélation produit

Les métriques techniques doivent pouvoir être rapprochées, sans identifier l’utilisateur, de :

- taux d’inscription ;
- délai avant première valeur ;
- annonce vers contact ;
- conversion abonnement ;
- rétention J7/J30 ;
- churn et MRR.

Une baisse de conversion après une hausse de latence doit devenir visible dans le même cycle de revue.

## Revue

- quotidienne au lancement : erreurs, paiements, publication, messagerie ;
- hebdomadaire : SLO, coût, performance et funnel ;
- mensuelle : capacité, dette, churn, CAC/LTV et priorités.

Toute alerte récurrente doit devenir une action suivie, pas être simplement acquittée.
