# Registre de dette technique — lot 3

## Règles

- **P0** : bloque sécurité, intégrité, lancement ou déploiement ; aucune clôture du lot 3 avec une dette P0 ouverte.
- **P1** : risque élevé de régression, performance ou maintenabilité ; doit avoir propriétaire, preuve et échéance.
- **P2** : amélioration planifiée non bloquante.

## État initial

| ID | Priorité | Sujet | État | Preuve de clôture attendue |
|---|---|---|---|---|
| ARCH-001 | P1 | Fichiers Flutter historiques au-dessus des budgets | ouvert | audit `tools/quality/audit_repository.py` et extractions sans régression |
| ARCH-002 | P1 | Couverture globale et modules critiques sous les objectifs finaux | suivi lot 13 | rapport LCOV réel et seuils atteints |
| ARCH-003 | P1 | Staging et rollback incomplets | suivi lots 14/18 | exécution de staging et rollback documentée |
| ARCH-004 | P1 | Matrice appareils réels incomplète | suivi lots 4/7/16 | preuves Web, Android et iOS associées à un SHA |

## Dettes P0

Aucune dette P0 n’est déclarée fermée par défaut. Avant promotion du lot 3, l’audit automatisé et la revue des flux sensibles doivent confirmer explicitement qu’aucune dette P0 n’est ouverte.

## Processus de clôture

Chaque dette fermée doit indiquer le commit, les tests, le contrôle CI et la preuve documentaire. Une dette ne peut pas être fermée uniquement parce que le code correspondant existe.
