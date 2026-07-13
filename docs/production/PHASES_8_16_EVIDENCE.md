# Preuves de préparation production — phases 8 à 16

Ce registre évite de confondre présence de code, documentation et validation réelle en production. Une phase n'est considérée prête que lorsque chaque preuve déclarée dans `quality/production_readiness.json` existe et contient un résultat exploitable.

## Utilisation

Inventaire non bloquant :

```bash
node tools/quality/check_production_readiness.mjs
```

Contrôle bloquant avant go-live :

```bash
node tools/quality/check_production_readiness.mjs --enforce
```

Le rapport est écrit dans `quality_reports/production-readiness/report.json`.

## Règles de preuve

- Une documentation décrit le processus, les responsabilités, les seuils et le rollback.
- Un rapport JSON contient une exécution datée, son environnement, son résultat et les écarts détectés.
- Un fichier vide, un placeholder ou une checklist non exécutée ne constitue pas une preuve valide au sens opérationnel, même si le contrôle automatique vérifie actuellement seulement la présence et le contenu non vide.
- Les preuves générées à partir de secrets ou de données personnelles ne doivent jamais contenir les valeurs sensibles.
- Le mode `--enforce` est réservé à la décision go-live. Le workflow de PR reste en mode inventaire pour permettre la progression incrémentale.

## Séquence recommandée

1. Phase 8 : terminer App Check, inventaire des secrets, restriction des clés, audit dépendances et revue OWASP.
2. Phase 9 : produire les SLO, alertes, identifiants de corrélation, tests synthétiques et matrice d'escalade.
3. Phase 10 : valider registre RGPD, conservation, export, suppression, consentements et purges.
4. Phase 11 : exécuter les scénarios Stripe Test Mode et la réconciliation Stripe–Firestore.
5. Phase 12 : produire les builds signés Android/iOS et les preuves de conformité stores.
6. Phase 13 : finaliser le design system, l'audit WCAG AA et les tests responsive.
7. Phase 14 : valider SEO, attribution, consentement CRM et tunnel d'acquisition.
8. Phase 15 : exécuter tests de charge, budgets coûts et exercice réel de restauration.
9. Phase 16 : lancer smoke tests, support/SLA et revues J+1, J+7 et J+30.

## Décision de mise en production

Le go-live est refusé lorsqu'une preuve obligatoire manque. La présence de toutes les preuves ne remplace pas la revue humaine finale : les rapports doivent être récents, cohérents avec la version candidate et approuvés par les responsables désignés.
