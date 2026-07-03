# Migration des rôles admin vers les custom claims

**Objectif** : que `firestore.rules` (et `storage.rules`) n'aient plus qu'à
lire `request.auth.token.roles` pour vérifier admin/superadmin/moderator —
zéro lecture Firestore par vérification, au lieu des fallbacks actuels
`users/{uid}`, `admins/{uid}`, `adminUsers/{uid}` (jusqu'à 3 `get()`
facturés et ~30 ms ajoutés par requête refusée).

⚠️ **Ordre impératif** : poser les claims (phase 1) et les vérifier **avant**
de simplifier les rules (phase 2). L'inverse bloquerait l'accès admin en prod.

## Phase 1 — poser les claims

Depuis `functions/` avec des credentials Admin SDK
(`gcloud auth application-default login`) :

```bash
# 1. Inventaire sans rien écrire (montre uid, email, rôles cible, sources)
npm run admin:claims:dry-run

# 2. Pose des claims (fusionne : seul le champ `roles` est écrit,
#    les autres claims existants sont préservés)
npm run admin:claims:apply

# Variante : force la reconnexion immédiate des comptes migrés
npm run admin:claims:apply:revoke

# 3. Contrôle : chaque admin « documents » doit avoir ses claims,
#    et les claims orphelins (sans document source) sont listés
npm run admin:claims:verify
```

Le script scanne **toutes les variantes** reconnues par les rules :
`admins/*` et `adminUsers/*` actifs (enabled ≠ false, expiresAt non échu),
et `users/*` via requêtes ciblées (roles liste/map, role, primaryRole,
adminRole, admin, isAdmin, superadmin, superAdmin, moderator, isModerator).

**Propagation** : sans `--revoke-tokens`, les claims sont pris en compte au
prochain refresh du token ID (≤ 1 h) ou à la prochaine connexion.

## Phase 2 — simplifier les rules (après `verify` ✅)

Attendre que `npm run admin:claims:verify` sorte
`✅ Claims et documents alignés`, puis laisser passer 1 h (ou avoir utilisé
`--revoke-tokens`), et vérifier qu'un admin réel accède toujours à
l'espace admin.

### firestore.rules

Remplacer les corps de `isAdmin()`, `hasAdminClaim()` et supprimer les
fallbacks documents :

```
function isAdmin() {
  return isSignedIn()
    && (request.auth.token.roles is list)
    && request.auth.token.roles.hasAny(['admin', 'superadmin']);
}

function isMarketplaceModerator() {
  return isAdmin()
    || (isSignedIn()
      && (request.auth.token.roles is list)
      && request.auth.token.roles.hasAny(['moderator']));
}
```

À supprimer une fois ces deux fonctions en place :
- `hasAdminClaim()` (variantes role/primaryRole/adminRole/admin/isAdmin/…)
- `hasUserDocAdminRole()`, `hasEnabledAdminDoc()`, `hasEnabledAdminUserDoc()`
- `hasUserDocRole()` (et son usage dans `isMarketplaceModerator`)
- `isAdminClaim()` → remplacer ses usages par `isAdmin()`

### storage.rules

Mêmes simplifications : remplacer `isMarketplaceAdmin()` /
`isMarketplaceModerator()` par les versions claims-only ci-dessus et
supprimer `hasUserDocRole()` + `hasAdminDocAccess()` (chacun coûte un
`firestore.get()` cross-service, encore plus cher).

### Garder la source de vérité

Les documents `admins/*` / `adminUsers/*` restent la **source
administrative** (audit, expiration) : toute création/modification d'admin
doit être suivie d'un `npm run admin:claims:apply`. Pour automatiser,
brancher un trigger Functions `onDocumentWritten('admins/{uid}')` qui
appelle `setCustomUserClaims` — à ajouter au moment de la phase 2.

## Rollback

Les rules actuelles acceptent déjà les claims (`hasAdminClaim()` teste
`roles` en premier) : la phase 1 est donc **sans risque et réversible** —
en cas de problème, il suffit de ne pas faire la phase 2. Pour retirer un
claim : `admin.auth().setCustomUserClaims(uid, { ...claims, roles: [] })`.
