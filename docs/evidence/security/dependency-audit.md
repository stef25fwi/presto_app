# Preuve — audit des dépendances sans vulnérabilité bloquante

**Contrôle** : `dependency-audit-clean`
**Nature** : `automated` — le rapport versionné est relu à chaque exécution.

## Commandes de vérification

```bash
# Valide le rapport versionné (sans node_modules) — utilisé par la matrice
node tools/quality/generate_dependency_audit.mjs --verify-report

# Régénère le rapport depuis les package-lock.json
node tools/quality/generate_dependency_audit.mjs

# Échoue si le rapport versionné est périmé ou si une vulnérabilité bloque
node tools/quality/generate_dependency_audit.mjs --check
```

## État mesuré au 2026-07-29 (commit `252f190`)

| Espace | Critiques | Hautes | Modérées | Faibles |
|---|---:|---:|---:|---:|
| racine | 0 | 0 | 0 | 0 |
| functions | 0 | 0 | 0 | 0 |

Point de départ : **13 vulnérabilités** (6 hautes, 7 modérées), et un
`docs/DEPENDENCY_AUDIT.md` qui n'en annonçait que 9 modérées et 0 haute.

## Correctifs appliqués

Les 13 remontées ne portaient en réalité que **deux avis de sécurité** ; tout
le reste (`gaxios`, `google-gax`, `glob`, `rimraf`, `minimatch`,
`teeny-request`, `retry-request`, `gcp-metadata`, `@google-cloud/*`,
`firebase-admin`, `firebase-functions`) n'était signalé que par propagation
transitive :

- `brace-expansion <=5.0.7` — déni de service par expansion non bornée (OOM) ;
- `uuid <11.1.1` — absence de contrôle de bornes du buffer en v3/v5/v6.

Trois changements, aucun majeur imposé aux dépendances directes :

1. **Suppression de `@google-cloud/vertexai`** de `functions/package.json` :
   dépendance déclarée mais importée nulle part. Elle était l'unique source de
   `google-auth-library@9 → gaxios@6.7.1` dans cet arbre.
2. **Suppression de `@google-cloud/vision` et `firebase-functions`** de la
   `package.json` racine : jamais importés par les scripts racine (74 paquets
   retirés).
3. **Overrides sur les deux seules racines réellement vulnérables**
   (`brace-expansion@^5.0.8`, `uuid@^11.1.1`), dans les deux espaces. Les deux
   versions cibles exposent CJS **et** ESM : aucun consommateur n'est cassé.

`firebase-admin` reste en `^13.10.0`. Le correctif proposé par
`npm audit fix --force` (downgrade cassant vers 10.3.0) a été écarté, et
`firebase-functions@7` plafonne de toute façon sa compatibilité à
`firebase-admin@13.x`.

## Vérifications de non-régression

```
node -e "require('uuid'); require('brace-expansion'); require('firebase-admin');
         require('google-gax'); require('@google-cloud/storage');
         require('@google-cloud/firestore')"
→ tous les modules se chargent
npm --prefix functions test  → 223/223
flutter analyze --fatal-infos → aucun problème
```

## Maintien dans le temps

Le rapport était périmé parce que
`.github/workflows/dependency-audit-report.yml` ne se déclenchait que sur la
branche `audit/prod-hardening-p0-p11` et y recommittait son résultat : `main`
n'était jamais audité. Le workflow s'exécute désormais sur `main`, sur chaque
PR et chaque lundi, et **échoue** si le rapport versionné est périmé ou si une
vulnérabilité haute ou critique apparaît.

## Limites

`npm audit` ne couvre que les avis publiés pour l'écosystème npm. Il ne couvre
ni les dépendances Dart/Flutter (`pubspec.lock`), ni les dépendances système de
l'image de déploiement.
