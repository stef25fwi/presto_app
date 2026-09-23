# Phase 8 — matrice des contrôles sécurité

La phase 8 ne peut être clôturée que lorsque chaque contrôle obligatoire est marqué `verified` et dispose d'une preuve exploitable.

## Contrôles suivis

- App Check en mode Enforce pour Firestore, Storage et Functions ;
- restrictions des clés API par domaine, package et empreinte ;
- inventaire et rotation des secrets ;
- audit des dépendances ;
- revue OWASP ;
- blocage des previews Firebase vers la production ;
- analyse statique CodeQL.

## Exécution

Inventaire (ne vaut pas autorisation de mise en production) :

```bash
node tools/quality/check_security_controls.mjs
```

Validation stricte avant go-live :

```bash
node tools/quality/check_security_controls.mjs --enforce
```

Les rapports JSON et Markdown sont générés dans `quality_reports/security/`.
Le résumé GitHub Actions affiche explicitement `NOT READY` lorsqu'un contrôle
obligatoire est incomplet, même si l'inventaire a été exécuté avec succès.

Les champs du rapport distinguent :

- `inventoryValid` : registre valide, contrôles source obligatoires vérifiables ;
- `ready` : inventaire valide et tous les contrôles obligatoires documentés ;
- `passed` : résultat de la commande selon son mode ;
- `blockingControls` : contrôles obligatoires incomplets et raisons.

En mode inventaire, une preuve externe en attente produit `ready: false`, mais
un code de sortie 0 si le registre et les contrôles source sont valides. Avec
`--enforce`, le même état produit un code de sortie 2. Un registre vide, mal
formé ou un contrôle source obligatoire incomplet échoue dans les deux modes.
Une preuve vide ou un lien symbolique ne valide pas un contrôle.

Le workflow **Security controls inventory** conserve le mode inventaire sur
PR/main. Son lancement manuel applique le mode strict par défaut (`enforce`).
Les rapports sont joints même lorsque ce contrôle échoue. Ce workflow n'est
pas, à lui seul, une protection de branche ni un verrou de déploiement.

Les preuves externes doivent être déposées sous `docs/evidence/security/` puis leur statut doit être passé à `verified` dans `quality/security-controls.json`.

## Limites et suite de l'audit du 23 septembre 2026 (S04/S05)

Le checker vérifie le statut déclaré et l'existence d'un fichier non vide ; il
ne certifie ni la véracité, ni la fraîcheur des preuves, ni l'état actuel des
consoles de production. Aucun statut du registre n'est promu par ce correctif.
Restrictions des clés API, inventaire des secrets et revue OWASP restent des
preuves obligatoires incomplètes. Les attestations historiques App Check et
dépendances devront être renouvelées avant une décision de lancement.

S05 est donc traité partiellement : résultat honnête et validation stricte
disponible, mais intégration obligatoire à la livraison et renouvellement des
preuves encore à effectuer. S04 nécessite les droits d'administration GitHub
pour protéger `main` et définir les contrôles requis ; ces réglages ne sont
pas modifiés ici. Aucun secret ne doit être copié dans les preuves.

Ce lot ne change aucun fichier UI, le hero Home ou ses trois affiches.
