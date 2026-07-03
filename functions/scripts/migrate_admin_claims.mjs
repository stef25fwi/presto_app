#!/usr/bin/env node
/**
 * Migration des rôles admin/superadmin/moderator vers les custom claims
 * Firebase Auth (champ canonique : `roles: [...]`).
 *
 * Objectif : permettre à terme de simplifier firestore.rules pour ne tester
 * QUE `request.auth.token.roles` (0 lecture Firestore par vérification),
 * au lieu des fallbacks actuels users/{uid}, admins/{uid}, adminUsers/{uid}
 * (jusqu'à 3 get() facturés par requête refusée).
 *
 * Sources de vérité scannées (mêmes variantes que firestore.rules) :
 *   1. admins/{uid}      (enabled != false, expiresAt absent ou > now)
 *   2. adminUsers/{uid}  (idem)
 *   3. users/{uid}       role/primaryRole/adminRole == admin|superadmin,
 *                        admin/isAdmin/superadmin/superAdmin == true,
 *                        moderator/isModerator == true,
 *                        roles (liste OU map) contenant admin|superadmin|moderator
 *
 * Usage :
 *   node scripts/migrate_admin_claims.mjs                     # dry-run (défaut)
 *   node scripts/migrate_admin_claims.mjs --apply             # pose les claims
 *   node scripts/migrate_admin_claims.mjs --apply --revoke-tokens
 *                                                             # + force re-login
 *   node scripts/migrate_admin_claims.mjs --verify            # post-migration :
 *       vérifie que chaque admin détecté par documents possède bien les claims,
 *       et liste les claims orphelins (claim sans document source).
 *   node scripts/migrate_admin_claims.mjs --project=presto-app-74abe ...
 *
 * Prérequis : credentials Admin SDK (gcloud auth application-default login
 * ou GOOGLE_APPLICATION_CREDENTIALS) avec les rôles Firebase Auth Admin +
 * lecture Firestore.
 *
 * Propagation : les claims sont pris en compte au prochain refresh du token
 * ID (≤ 1 h), ou immédiatement après re-login. --revoke-tokens invalide les
 * refresh tokens pour forcer la reconnexion des comptes migrés.
 */

import admin from 'firebase-admin';

const ROLE_ADMIN = 'admin';
const ROLE_SUPERADMIN = 'superadmin';
const ROLE_MODERATOR = 'moderator';
const KNOWN_ROLES = [ROLE_SUPERADMIN, ROLE_ADMIN, ROLE_MODERATOR];

function parseArgs(argv) {
  const opts = {
    apply: false,
    verify: false,
    revokeTokens: false,
    projectId: process.env.GCLOUD_PROJECT || 'presto-app-74abe',
  };
  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--apply') opts.apply = true;
    else if (arg === '--dry-run') opts.apply = false;
    else if (arg === '--verify') opts.verify = true;
    else if (arg === '--revoke-tokens') opts.revokeTokens = true;
    else if (arg.startsWith('--project=')) {
      opts.projectId = arg.slice('--project='.length).trim();
    } else {
      console.error(`Argument inconnu : ${arg}`);
      process.exit(1);
    }
  }
  return opts;
}

function isDocActive(data, now) {
  if (!data) return false;
  if (data.enabled === false) return false;
  const expiresAt = data.expiresAt;
  if (expiresAt && typeof expiresAt.toMillis === 'function') {
    return expiresAt.toMillis() > now;
  }
  return true;
}

/** Rôles portés par un document users/{uid}, toutes variantes des rules. */
function rolesFromUserDoc(d) {
  const roles = new Set();
  const add = (role) => roles.add(role);

  const rawRoles = d.roles;
  if (Array.isArray(rawRoles)) {
    for (const r of rawRoles) {
      if (KNOWN_ROLES.includes(r)) add(r);
    }
  } else if (rawRoles && typeof rawRoles === 'object') {
    if (rawRoles.admin === true) add(ROLE_ADMIN);
    if (rawRoles.superadmin === true || rawRoles.superAdmin === true) {
      add(ROLE_SUPERADMIN);
    }
    if (rawRoles.moderator === true) add(ROLE_MODERATOR);
  }

  for (const field of ['role', 'primaryRole', 'adminRole']) {
    const v = d[field];
    if (v === ROLE_ADMIN) add(ROLE_ADMIN);
    if (v === ROLE_SUPERADMIN) add(ROLE_SUPERADMIN);
    if (v === ROLE_MODERATOR) add(ROLE_MODERATOR);
  }

  if (d.admin === true || d.isAdmin === true) add(ROLE_ADMIN);
  if (d.superadmin === true || d.superAdmin === true) add(ROLE_SUPERADMIN);
  if (d.moderator === true || d.isModerator === true) add(ROLE_MODERATOR);

  return roles;
}

/** Rôles déjà présents dans des custom claims (toutes variantes des rules). */
function rolesFromClaims(claims) {
  const roles = new Set();
  if (!claims) return roles;
  const add = (role) => roles.add(role);

  if (Array.isArray(claims.roles)) {
    for (const r of claims.roles) {
      if (KNOWN_ROLES.includes(r)) add(r);
    }
  }
  for (const field of ['role', 'primaryRole', 'adminRole']) {
    const v = claims[field];
    if (v === ROLE_ADMIN) add(ROLE_ADMIN);
    if (v === ROLE_SUPERADMIN) add(ROLE_SUPERADMIN);
  }
  if (claims.admin === true || claims.isAdmin === true) add(ROLE_ADMIN);
  if (claims.superadmin === true || claims.superAdmin === true) {
    add(ROLE_SUPERADMIN);
  }
  return roles;
}

/** Collecte uid -> { roles: Set, sources: Set } depuis Firestore. */
async function collectExpectedAdmins(db) {
  const now = Date.now();
  /** @type {Map<string, {roles: Set<string>, sources: Set<string>}>} */
  const expected = new Map();
  const record = (uid, roles, source) => {
    if (!uid || roles.size === 0) return;
    const entry = expected.get(uid) || { roles: new Set(), sources: new Set() };
    for (const r of roles) entry.roles.add(r);
    entry.sources.add(source);
    expected.set(uid, entry);
  };

  for (const collection of ['admins', 'adminUsers']) {
    const snap = await db.collection(collection).get();
    for (const doc of snap.docs) {
      const data = doc.data();
      if (!isDocActive(data, now)) continue;
      const roles = rolesFromUserDoc(data);
      // Un document admins/adminUsers actif vaut au minimum 'admin'.
      roles.add(data.role === ROLE_SUPERADMIN ? ROLE_SUPERADMIN : ROLE_ADMIN);
      record(doc.id, roles, collection);
    }
  }

  // users/ : requêtes ciblées par variante (pas de full scan).
  const userQueries = [
    ['roles', 'array-contains-any', KNOWN_ROLES],
    ['roles.admin', '==', true],
    ['roles.superadmin', '==', true],
    ['roles.superAdmin', '==', true],
    ['roles.moderator', '==', true],
    ['role', 'in', KNOWN_ROLES],
    ['primaryRole', 'in', [ROLE_ADMIN, ROLE_SUPERADMIN]],
    ['adminRole', 'in', [ROLE_ADMIN, ROLE_SUPERADMIN]],
    ['admin', '==', true],
    ['isAdmin', '==', true],
    ['superadmin', '==', true],
    ['superAdmin', '==', true],
    ['moderator', '==', true],
    ['isModerator', '==', true],
  ];
  for (const [field, op, value] of userQueries) {
    let snap;
    try {
      snap = await db.collection('users').where(field, op, value).get();
    } catch (error) {
      // Requête invalide sur ce dataset (ex: champ jamais indexé) : on ignore,
      // les autres variantes couvrent le reste.
      console.warn(`  (users where ${field} ${op} ignoré : ${error.message})`);
      continue;
    }
    for (const doc of snap.docs) {
      record(doc.id, rolesFromUserDoc(doc.data()), `users.${field}`);
    }
  }

  return expected;
}

/** Liste tous les comptes Auth portant déjà un rôle en claim. */
async function collectClaimHolders(auth) {
  /** @type {Map<string, {roles: Set<string>, email: string, claims: object}>} */
  const holders = new Map();
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const user of page.users) {
      const roles = rolesFromClaims(user.customClaims);
      if (roles.size > 0) {
        holders.set(user.uid, {
          roles,
          email: user.email || '(sans email)',
          claims: user.customClaims || {},
        });
      }
    }
    pageToken = page.pageToken;
  } while (pageToken);
  return holders;
}

function fmtRoles(roles) {
  return [...roles].sort().join(',') || '—';
}

async function main() {
  const opts = parseArgs(process.argv);
  admin.initializeApp({ projectId: opts.projectId });
  const db = admin.firestore();
  const auth = admin.auth();

  console.log(`Projet : ${opts.projectId}`);
  console.log(`Mode   : ${opts.verify ? 'VERIFY' : opts.apply ? 'APPLY' : 'DRY-RUN'}\n`);

  console.log('── Scan des sources Firestore (admins, adminUsers, users)…');
  const expected = await collectExpectedAdmins(db);
  console.log(`   ${expected.size} compte(s) avec rôle détecté par documents.\n`);

  console.log('── Scan des claims Auth existants…');
  const holders = await collectClaimHolders(auth);
  console.log(`   ${holders.size} compte(s) portant déjà un rôle en claim.\n`);

  if (opts.verify) {
    let missing = 0;
    for (const [uid, entry] of expected) {
      const claimRoles = holders.get(uid)?.roles ?? new Set();
      const lacking = [...entry.roles].filter((r) => !claimRoles.has(r));
      if (lacking.length > 0) {
        missing += 1;
        console.log(
          `❌ ${uid} — claims incomplets : manque [${lacking.join(',')}] ` +
            `(sources: ${[...entry.sources].join(', ')})`,
        );
      }
    }
    let stale = 0;
    for (const [uid, holder] of holders) {
      if (!expected.has(uid)) {
        stale += 1;
        console.log(
          `⚠️  ${uid} (${holder.email}) — claim [${fmtRoles(holder.roles)}] ` +
            'sans document source (claim orphelin à examiner)',
        );
      }
    }
    if (missing === 0 && stale === 0) {
      console.log('✅ Claims et documents alignés. Les rules peuvent être');
      console.log('   simplifiées (voir docs/admin_claims_migration.md, phase 2).');
    } else {
      console.log(`\nRésultat : ${missing} manquant(s), ${stale} orphelin(s).`);
      if (missing > 0) process.exitCode = 1;
    }
    return;
  }

  // DRY-RUN / APPLY : calcule les claims cibles.
  let toUpdate = 0;
  let upToDate = 0;
  for (const [uid, entry] of expected) {
    const targetRoles = [...entry.roles].sort();
    let user;
    try {
      user = await auth.getUser(uid);
    } catch {
      console.log(`⚠️  ${uid} — document trouvé mais compte Auth inexistant, ignoré`);
      continue;
    }
    const currentClaims = user.customClaims || {};
    const currentRoles = Array.isArray(currentClaims.roles)
      ? [...currentClaims.roles].sort()
      : [];
    const alreadyOk =
      currentRoles.length === targetRoles.length &&
      targetRoles.every((r, i) => currentRoles[i] === r);

    if (alreadyOk) {
      upToDate += 1;
      continue;
    }

    toUpdate += 1;
    console.log(
      `${opts.apply ? '✍️ ' : '→ '} ${uid} (${user.email || '(sans email)'})` +
        `\n     roles: [${currentRoles.join(',') || '—'}] → [${targetRoles.join(',')}]` +
        `   (sources: ${[...entry.sources].join(', ')})`,
    );

    if (opts.apply) {
      // Fusion : on remplace uniquement `roles`, on préserve tout autre claim.
      await auth.setCustomUserClaims(uid, { ...currentClaims, roles: targetRoles });
      if (opts.revokeTokens) {
        await auth.revokeRefreshTokens(uid);
      }
    }
  }

  console.log(`\nRésumé : ${expected.size} détecté(s), ${upToDate} déjà à jour, ` +
    `${toUpdate} ${opts.apply ? 'mis à jour' : 'à mettre à jour (dry-run)'}.`);
  if (opts.apply && opts.revokeTokens && toUpdate > 0) {
    console.log('Tokens révoqués : les comptes migrés devront se reconnecter.');
  }
  if (!opts.apply && toUpdate > 0) {
    console.log('\nRelance avec --apply pour poser les claims, puis --verify.');
  }
  if (opts.apply) {
    console.log('\nProchaine étape : node scripts/migrate_admin_claims.mjs --verify');
  }
}

main().catch((error) => {
  console.error('Échec migration claims admin :', error);
  process.exit(1);
});
