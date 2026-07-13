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

Inventaire non bloquant :

```bash
node tools/quality/check_security_controls.mjs
```

Validation stricte avant go-live :

```bash
node tools/quality/check_security_controls.mjs --enforce
```

Le rapport est généré dans `quality_reports/security/security-controls.json`.

Les preuves externes doivent être déposées sous `docs/evidence/security/` puis leur statut doit être passé à `verified` dans `quality/security-controls.json`.
