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

function normalizeRoles(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry) => String(entry || '').trim().toLowerCase())
    .filter(Boolean);
}

function summarizeAdminAccess({ authUser, userData, adminDocExists, adminData }) {
  const claims = authUser.customClaims || {};
  const claimRoles = normalizeRoles(claims.roles);
  const tokenHasAdmin =
    claimRoles.includes('admin') ||
    claimRoles.includes('superadmin') ||
    claims.admin === true ||
    claims.superadmin === true;

  const userRoles = normalizeRoles(userData?.roles);
  const primaryRole = String(userData?.primaryRole || '').trim().toLowerCase();
  const userHasAdmin =
    userRoles.includes('admin') ||
    userRoles.includes('superadmin') ||
    primaryRole === 'admin' ||
    primaryRole === 'superadmin' ||
    userData?.admin === true ||
    userData?.superadmin === true;

  const adminDocEnabled = adminDocExists && adminData?.enabled !== false;

  return {
    tokenHasAdmin,
    tokenRoles: claimRoles,
    userHasAdmin,
    userRoles,
    primaryRole: primaryRole || null,
    adminDocEnabled,
    finalShouldPassAssertIsAdmin: tokenHasAdmin || userHasAdmin || adminDocEnabled,
  };
}

async function main() {
  const [authUser, userSnap, adminSnap] = await Promise.all([
    admin.auth().getUser(UID),
    db.collection('users').doc(UID).get(),
    db.collection('admins').doc(UID).get(),
  ]);

  const userData = userSnap.exists ? userSnap.data() : null;
  const adminData = adminSnap.exists ? adminSnap.data() : null;
  const summary = summarizeAdminAccess({
    authUser,
    userData,
    adminDocExists: adminSnap.exists,
    adminData,
  });

  console.log(
    JSON.stringify(
      {
        uid: authUser.uid,
        email: authUser.email || null,
        displayName: authUser.displayName || null,
        disabled: authUser.disabled,
        customClaims: authUser.customClaims || {},
        usersDocExists: userSnap.exists,
        usersDoc: userData,
        adminsDocExists: adminSnap.exists,
        adminsDoc: adminData,
        summary,
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