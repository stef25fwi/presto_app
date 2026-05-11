import admin from 'firebase-admin';

const projectId = process.env.PROJECT_ID;
const email = process.env.ADMIN_EMAIL;

if (!projectId) throw new Error('PROJECT_ID manquant');
if (!email) throw new Error('ADMIN_EMAIL manquant');

admin.initializeApp({ projectId });

const auth = admin.auth();
const db = admin.firestore();

const canonicalRoles = ['user', 'admin', 'superadmin'];

const user = await auth.getUserByEmail(email);

const currentClaims = user.customClaims || {};
const nextClaims = {
  ...currentClaims,
  roles: canonicalRoles,
  primaryRole: 'superadmin',
  marketplaceAccess: true,
  admin: true,
  superadmin: true,
  isAdmin: true,
  superAdmin: true,
  role: 'superadmin',
  moderator: currentClaims.moderator === true,
  pro: currentClaims.pro === true,
};

await auth.setCustomUserClaims(user.uid, nextClaims);

await db.collection('users').doc(user.uid).set({
  uid: user.uid,
  email: user.email,
  role: 'superadmin',
  roles: canonicalRoles,
  primaryRole: 'superadmin',
  admin: true,
  superadmin: true,
  isAdmin: true,
  superAdmin: true,
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
}, { merge: true });

await db.collection('userRoles').doc(user.uid).set({
  uid: user.uid,
  email: user.email,
  role: 'superadmin',
  roles: canonicalRoles,
  primaryRole: 'superadmin',
  admin: true,
  superadmin: true,
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
}, { merge: true });

console.log(JSON.stringify({
  ok: true,
  uid: user.uid,
  email: user.email,
  claims: nextClaims,
}, null, 2));
