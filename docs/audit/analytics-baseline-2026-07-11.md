# Baseline Analytics produit — 11 juillet 2026

Rapport généré par la PR #188 après correction des faux positifs.

## Résultats

| Indicateur | Valeur |
|---|---:|
| Événements bruts littéraux | 4 |
| Factories typées définies | 8 |
| Utilisations des factories typées | 0 |
| Paramètres PII détectés dans `logEvent` | 0 |

## Événements bruts existants

- `listing_reported` ;
- `listing_create_started` ;
- `listing_create_completed` ;
- `listing_submitted`.

## Factories du funnel disponibles

- acquisition de page de destination ;
- inscription terminée ;
- première valeur ;
- contact d’une annonce ;
- choix du plan ;
- checkout confirmé ;
- retour de rétention ;
- renouvellement d’abonnement.

## Décisions

- le contrôle des paramètres personnels devient bloquant dans GitHub Actions ;
- les nouveaux événements du tunnel doivent utiliser les factories typées ;
- les événements de revenu restent déclenchés depuis une confirmation backend ;
- l’instrumentation sera migrée progressivement pour éviter les doubles événements ;
- le consentement Analytics reste obligatoire.

## Prochaine étape

Instrumenter dans l’ordre : inscription, première valeur, contact, page abonnement, choix du plan, checkout confirmé et renouvellement. Chaque ajout doit inclure un test de non-régression et une règle de déduplication.
