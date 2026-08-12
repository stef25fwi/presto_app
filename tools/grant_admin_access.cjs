const admin = require('../functions/node_modules/firebase-admin');

const PROJECT_ID = 'presto-app-74abe';
const EMAIL = (process.env.ADMIN_TARGET_EMAIL || '').trim().toLowerCase();
const UID = (process.env.ADMIN_TARGET_UID || '').trim();
const GRANT_SUPERADMIN =
  (process.env.GRANT_SUPERADMIN || 'false').trim().toLowerCase() === 'true';

if (!UID && !EMAIL) {
  throw new Error(
    'Missing admin target. Set ADMIN_TARGET_UID or ADMIN_TARGET_EMAIL before running this tool.',
  );
}

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: PROJECT_ID,
    serviceAccountId: `${PROJECT_ID}@appspot.gserviceaccount.com`,
  });
}

const db = admin.firestore();

async function resolveTargetUser() {
  if (UID) {
    return admin.auth().getUser(UID);
  }
  return admin.auth().getUserByEmail(EMAIL);
}

function mergeRoles(...roleLists) {
  const merged = new Set(['user']);
  for (const roles of roleLists) {
    if (!Array.isArray(roles)) continue;
    for (const role of roles) {
      const normalized = String(role || '').trim().toLowerCase();
      if (normalized) merged.add(normalized);
    }
  }
  merged.add('admin');
  if (GRANT_SUPERADMIN) merged.add('superadmin');
  return Array.from(merged);
}

async function main() {
  const authUser = await resolveTargetUser();
  const targetUid = authUser.uid;
  const normalizedEmail = (authUser.email || EMAIL).trim().toLowerCase();

  const [userSnap, adminSnap] = await Promise.all([
    db.collection('users').doc(targetUid).get(),
    db.collection('admins').doc(targetUid).get(),
  ]);

  const existingClaims = authUser.customClaims || {};
  const userData = userSnap.exists ? userSnap.data() : {};
  const mergedRoles = mergeRoles(existingClaims.roles, userData.roles);
  const hasSuperadmin =
    GRANT_SUPERADMIN ||
    existingClaims.superadmin === true ||
    mergedRoles.includes('superadmin');
  const hasModerator =
    existingClaims.moderator === true || mergedRoles.includes('moderator');
  const hasPro = existingClaims.pro === true || mergedRoles.includes('pro');
  const primaryRole = hasSuperadmin ? 'superadmin' : 'admin';

  await admin.auth().setCustomUserClaims(targetUid, {
    ...existingClaims,
    roles: mergedRoles,
    primaryRole,
    marketplaceAccess: true,
    admin: true,
    superadmin: hasSuperadmin,
    moderator: hasModerator,
    pro: hasPro,
  });

  await db.collection('users').doc(targetUid).set(
    {
      uid: targetUid,
      email: normalizedEmail,
      displayName: authUser.displayName || userData.displayName || null,
      roles: mergedRoles,
      primaryRole,
      admin: true,
      superadmin: hasSuperadmin,
      moderator: hasModerator,
      pro: hasPro,
      marketplaceAccess: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastRoleSyncAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await db.collection('admins').doc(targetUid).set(
    {
      uid: targetUid,
      email: normalizedEmail,
      displayName: authUser.displayName || userData.displayName || null,
      enabled: true,
      roles: mergedRoles,
      primaryRole,
      marketplaceAccess: true,
      grantedBy: 'tools/grant_admin_access.cjs',
      grantedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const refreshed = await admin.auth().getUser(targetUid);
  const refreshedUserDoc = await db.collection('users').doc(targetUid).get();
  const refreshedAdminDoc = await db.collection('admins').doc(targetUid).get();

  console.log(
    JSON.stringify(
      {
        lookup: {
          email: normalizedEmail,
          uid: targetUid,
          grantSuperadmin: GRANT_SUPERADMIN,
        },
        uid: refreshed.uid,
        email: refreshed.email || null,
        displayName: refreshed.displayName || null,
        customClaims: refreshed.customClaims || {},
        usersDoc: refreshedUserDoc.data() || null,
        adminsDoc: refreshedAdminDoc.data() || null,
      },
      null,
      2,
    ),
  );
}

main().catch((error) => {
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});