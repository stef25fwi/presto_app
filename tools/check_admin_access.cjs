const admin = require('../functions/node_modules/firebase-admin');

const PROJECT_ID = 'presto-app-74abe';
const EMAIL = (process.env.ADMIN_TARGET_EMAIL || '').trim().toLowerCase();
const UID = (process.env.ADMIN_TARGET_UID || '').trim();

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
  const tokenHasSuperadmin =
    claimRoles.includes('superadmin') || claims.superadmin === true;

  const userRoles = normalizeRoles(userData?.roles);
  const primaryRole = String(userData?.primaryRole || '').trim().toLowerCase();
  const userHasAdmin =
    userRoles.includes('admin') ||
    userRoles.includes('superadmin') ||
    primaryRole === 'admin' ||
    primaryRole === 'superadmin' ||
    userData?.admin === true ||
    userData?.superadmin === true;
  const userHasSuperadmin =
    userRoles.includes('superadmin') ||
    primaryRole === 'superadmin' ||
    userData?.superadmin === true;

  const adminDocEnabled = adminDocExists && adminData?.enabled !== false;
  const adminDocHasSuperadmin =
    adminDocEnabled &&
    (normalizeRoles(adminData?.roles).includes('superadmin') ||
      String(adminData?.primaryRole || '').trim().toLowerCase() === 'superadmin');

  return {
    tokenHasAdmin,
    tokenHasSuperadmin,
    tokenRoles: claimRoles,
    userHasAdmin,
    userHasSuperadmin,
    userRoles,
    primaryRole: primaryRole || null,
    adminDocEnabled,
    adminDocHasSuperadmin,
    finalShouldPassAssertIsAdmin: tokenHasAdmin || userHasAdmin || adminDocEnabled,
    finalShouldPassAssertIsSuperadmin:
      tokenHasSuperadmin || userHasSuperadmin || adminDocHasSuperadmin,
  };
}

async function main() {
  const authUser = await resolveTargetUser();
  const targetUid = authUser.uid;
  const [userSnap, adminSnap] = await Promise.all([
    db.collection('users').doc(targetUid).get(),
    db.collection('admins').doc(targetUid).get(),
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
        lookup: {
          email: authUser.email || EMAIL || null,
          uid: targetUid,
        },
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