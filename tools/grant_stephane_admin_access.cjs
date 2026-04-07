const admin = require('../functions/node_modules/firebase-admin');

const PROJECT_ID = 'presto-app-74abe';
const UID = process.env.STEPHANE_UID || 'modRxXduO8TnMlD6MFxobuKigVy2';

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: PROJECT_ID,
    serviceAccountId: `${PROJECT_ID}@appspot.gserviceaccount.com`,
  });
}

const db = admin.firestore();

function mergeRoles(...roleLists) {
  const merged = new Set(['user']);
  for (const roles of roleLists) {
    if (!Array.isArray(roles)) continue;
    for (const role of roles) {
      const normalized = String(role || '').trim().toLowerCase();
      if (normalized) {
        merged.add(normalized);
      }
    }
  }
  merged.add('admin');
  return Array.from(merged);
}

async function main() {
  const [authUser, userSnap, adminSnap] = await Promise.all([
    admin.auth().getUser(UID),
    db.collection('users').doc(UID).get(),
    db.collection('admins').doc(UID).get(),
  ]);

  const existingClaims = authUser.customClaims || {};
  const userData = userSnap.exists ? userSnap.data() : {};
  const mergedRoles = mergeRoles(existingClaims.roles, userData.roles);

  await admin.auth().setCustomUserClaims(UID, {
    ...existingClaims,
    roles: mergedRoles,
    primaryRole: 'admin',
    marketplaceAccess: true,
    admin: true,
    superadmin: existingClaims.superadmin === true,
    moderator: existingClaims.moderator === true || mergedRoles.includes('moderator'),
    pro: existingClaims.pro === true || mergedRoles.includes('pro'),
  });

  await db.collection('users').doc(UID).set(
    {
      roles: mergedRoles,
      primaryRole: 'admin',
      admin: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastRoleSyncAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await db.collection('admins').doc(UID).set(
    {
      enabled: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const refreshed = await admin.auth().getUser(UID);
  const refreshedUserDoc = await db.collection('users').doc(UID).get();
  const refreshedAdminDoc = await db.collection('admins').doc(UID).get();

  console.log(
    JSON.stringify(
      {
        uid: refreshed.uid,
        email: refreshed.email || null,
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