const admin = require('../functions/node_modules/firebase-admin');

const PROJECT_ID = 'presto-app-74abe';
const EMAIL = (process.env.ADMIN_TARGET_EMAIL || '').trim().toLowerCase();
const UID = (process.env.ADMIN_TARGET_UID || '').trim();
const LEGACY_UID = (process.env.ADMIN_LEGACY_UID || '').trim();
const LISTING_SAMPLE_LIMIT = Number.parseInt(
  process.env.LISTING_SAMPLE_LIMIT || '5',
  10,
);

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

function normalizeRoles(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry) => String(entry || '').trim().toLowerCase())
    .filter(Boolean);
}

function normalizeText(value) {
  const text = String(value || '').trim();
  return text.length ? text : null;
}

function serializeValue(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  if (
    typeof value === 'string' ||
    typeof value === 'number' ||
    typeof value === 'boolean'
  ) {
    return value;
  }
  return String(value);
}

function compactObject(value) {
  if (Array.isArray(value)) return value.map(compactObject);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(
    Object.entries(value)
      .filter(([, entry]) => entry !== null && entry !== undefined)
      .map(([key, entry]) => [key, compactObject(entry)]),
  );
}

function summarizeProfileData(data) {
  if (!data) return null;
  return compactObject({
    uid: normalizeText(data.uid),
    email: normalizeText(data.email),
    pseudo: normalizeText(data.pseudo),
    displayName: normalizeText(data.displayName),
    city: normalizeText(data.city || data.ville || data.commune || data.locality),
    postalCode: normalizeText(
      data.postalCode || data.codePostal || data.zipCode || data.cp,
    ),
    phone: normalizeText(data.phone),
    roles: normalizeRoles(data.roles),
    primaryRole: normalizeText(data.primaryRole),
    admin: data.admin === true,
    superadmin: data.superadmin === true,
    accountType: normalizeText(data.accountType),
    profileCompleted: data.profileCompleted === true,
    updatedAt: serializeValue(data.updatedAt),
    createdAt: serializeValue(data.createdAt),
  });
}

function summarizeAdminData(data) {
  if (!data) return null;
  return compactObject({
    uid: normalizeText(data.uid),
    email: normalizeText(data.email),
    displayName: normalizeText(data.displayName),
    enabled: data.enabled !== false,
    roles: normalizeRoles(data.roles),
    primaryRole: normalizeText(data.primaryRole),
    grantedBy: normalizeText(data.grantedBy),
    grantedAt: serializeValue(data.grantedAt),
    updatedAt: serializeValue(data.updatedAt),
    expiresAt: serializeValue(data.expiresAt),
  });
}

async function resolveTargetUser() {
  if (UID) return admin.auth().getUser(UID);
  return admin.auth().getUserByEmail(EMAIL);
}

async function readDoc(collection, uid, summarize) {
  const snap = await db.collection(collection).doc(uid).get();
  return {
    path: `${collection}/${uid}`,
    exists: snap.exists,
    data: summarize(snap.exists ? snap.data() : null),
  };
}

async function auditListingsForUid(uid) {
  const snapshot = await db
    .collection('listings')
    .where('ownerId', '==', uid)
    .limit(Math.max(LISTING_SAMPLE_LIMIT, 1))
    .get();

  return {
    ownerId: uid,
    sampleCount: snapshot.size,
    sample: snapshot.docs.map((doc) => {
      const data = doc.data() || {};
      return compactObject({
        id: doc.id,
        status: normalizeText(data.status),
        visibility: normalizeText(data.visibility),
        title: normalizeText(data.title),
        displayName: normalizeText(data.displayName || data.advertiserName),
        updatedAt: serializeValue(data.updatedAt),
        publishedAt: serializeValue(data.publishedAt),
      });
    }),
  };
}

async function auditUid(uid, label) {
  const [users, profiles, admins, adminUsers, listings] = await Promise.all([
    readDoc('users', uid, summarizeProfileData),
    readDoc('profiles', uid, summarizeProfileData),
    readDoc('admins', uid, summarizeAdminData),
    readDoc('adminUsers', uid, summarizeAdminData),
    auditListingsForUid(uid),
  ]);

  return compactObject({
    label,
    uid,
    profileDocumentCount: [users, profiles, admins, adminUsers].filter(
      (entry) => entry.exists,
    ).length,
    documents: { users, profiles, admins, adminUsers },
    listings,
  });
}

async function main() {
  const authUser = await resolveTargetUser();
  const currentUid = authUser.uid;
  const targets = [{ uid: currentUid, label: 'current-auth-uid' }];

  if (LEGACY_UID && LEGACY_UID !== currentUid) {
    targets.push({ uid: LEGACY_UID, label: 'legacy-uid' });
  }

  const uidAudits = await Promise.all(
    targets.map((entry) => auditUid(entry.uid, entry.label)),
  );

  console.log(
    JSON.stringify(
      compactObject({
        projectId: PROJECT_ID,
        lookup: {
          email: authUser.email || EMAIL || null,
          currentUid,
          legacyUid: LEGACY_UID || null,
        },
        auth: {
          uid: authUser.uid,
          email: authUser.email || null,
          displayName: authUser.displayName || null,
          disabled: authUser.disabled === true,
          customClaims: authUser.customClaims || {},
          tokenRoles: normalizeRoles(authUser.customClaims?.roles),
        },
        uidAudits,
      }),
      null,
      2,
    ),
  );
}

main().catch((error) => {
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});