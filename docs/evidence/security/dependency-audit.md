# Preuve — Audit des dépendances sans vulnérabilité critique ni haute

Contrôle : `dependency-audit-clean` (`quality/security-controls.json`).

## Nature de la preuve

Reproductible par commande, en CI comme en local. Aucune console ni action
manuelle n'est nécessaire.

## Résultat

```
$ npm --prefix functions audit
found 0 vulnerabilities

$ npm audit          # racine du dépôt
found 0 vulnerabilities
```

Les deux périmètres du dépôt sont à **0 critique, 0 haute, 0 modérée, 0
faible**. `docs/DEPENDENCY_AUDIT.md` a été régénéré à la même date avec la
logique exacte du workflow `dependency-audit-report.yml`, et rapporte les
mêmes compteurs.

## Comment le résultat a été obtenu

Le contrôle exigeait 0 critique et 0 haute, en précisant qu'aucune correction
ne devait imposer de downgrade majeur de `firebase-admin`. C'est précisément
ce que `npm audit fix --force` proposait : un retour de `firebase-admin` 13/14
vers 10.3.0, soit trois versions majeures en arrière. Cette voie a été écartée
lors des audits des 14 et 15/08, laissant les vulnérabilités ouvertes.

La chaîne complète (9 modérées à la racine, 7 dans `functions/`) remontait à
une cause racine unique : **`uuid@9.0.1`**
([GHSA-w5hq-g745-h8pq](https://github.com/advisories/GHSA-w5hq-g745-h8pq) —
absence de vérification des bornes du buffer dans `v3`/`v5`/`v6` lorsqu'un
`buf` est fourni). Les huit autres entrées n'étaient que la propagation
transitive de celle-ci à travers `gaxios`, `google-gax`, `teeny-request`,
`retry-request`, `@google-cloud/storage`, `@google-cloud/firestore`,
`firebase-admin` et `firebase-functions`.

Un `overrides` npm sur `uuid` (`^11.1.1`) traite donc la cause plutôt que ses
effets, **sans toucher à `firebase-admin`** :

- racine : `overrides: { "uuid": "^11.1.1" }` ajouté à `package.json` ;
- `functions/` : même entrée ajoutée au bloc `overrides` existant, qui
  contenait déjà `@grpc/grpc-js` — le mécanisme était donc déjà en usage dans
  ce dépôt.

## Vérifications effectuées

| Vérification | Résultat |
|---|---|
| `npm audit` (racine et `functions/`) | 0 vulnérabilité dans les deux périmètres |
| Version de `firebase-admin` | **inchangée** : 13.10.0 à la racine, 14.2.0 dans `functions/` — aucun downgrade |
| Version d'`uuid` résolue | 11.1.1, en copie unique — aucun `uuid` imbriqué, l'override s'applique à tout l'arbre |
| API d'`uuid` réellement consommée par les SDK | `uuid.v4()` uniquement (`gaxios/build/src/gaxios.js` l. 417, `teeny-request/build/src/index.js` l. 135, `google-gax/build/src/util.js` l. 108) — frontières multipart et identifiants aléatoires |
| Chargement des modules | `uuid`, `firebase-admin`, `firebase-functions`, `@google-cloud/storage`, `@google-cloud/firestore`, `gaxios` chargent sans erreur |
| Suite de tests `functions/` | **308/308 passent**, 0 échec (`npm --prefix functions test`, qui inclut `tsc`) |

Le point le plus important de ce tableau est l'avant-dernière ligne : `v4` est
la seule fonction utilisée par les consommateurs, sa signature est identique
entre `uuid` 9 et 11, et **elle ne fait pas partie des fonctions visées par
l'avis de sécurité** (qui porte sur `v3`/`v5`/`v6` avec `buf`). La montée de
version ferme donc une exposition qui, dans ce projet précis, n'était
vraisemblablement pas atteignable — le gain réel est la disparition d'un bruit
permanent dans les rapports d'audit, pas la fermeture d'une brèche exploitée.
Cette nuance est volontairement consignée ici pour qu'une lecture future ne
surestime pas la portée du correctif.

## Comment rejouer

```bash
npm audit
npm --prefix functions audit
npm --prefix functions test
```

## Limite

Ces commandes ont été exécutées dans l'environnement d'audit, pas en CI. La
confirmation définitive revient au workflow `dependency-audit-report.yml` et à
la suite de validation complète sur `main`. La mise à jour d'`uuid` étant une
substitution de dépendance transitive, un comportement runtime non couvert par
les 308 tests reste théoriquement possible ; le périmètre d'usage constaté
(`v4` seul) rend ce risque faible.

Vérifié le 2026-08-16.
