// audit_conversations.mjs
//
// Audit READ-ONLY de la collection `conversations` : detecte les documents
// qui ne se chargeront PAS dans la page "Mes messages".
//
// La requete de la page est :
//   .where('participantIds', arrayContains: <uid>)
//   .orderBy('updatedAt', descending: true)
//
// Un document est donc INVISIBLE si :
//   - il n'a pas de champ `updatedAt` (exclu par orderBy), ou
//   - il n'a pas de tableau `participantIds` non vide (exclu par where).
//
// Usage:
//   PROJECT_ID=presto-app-74abe \
//   GOOGLE_APPLICATION_CREDENTIALS=/chemin/vers/serviceAccount.json \
//   node scripts/audit_conversations.mjs
//
import admin from 'firebase-admin';

const projectId = process.env.PROJECT_ID;
if (!projectId) throw new Error('PROJECT_ID manquant');

admin.initializeApp({ projectId });
const db = admin.firestore();

const LEGACY_PARTICIPANT_FIELDS = [
  'participants',
  'participant_ids',
  'memberIds',
  'users',
  'userIds',
];
const UPDATED_AT_FALLBACKS = ['updated_at', 'createdAt', 'created_at'];

const hasNonEmptyArray = (value) => Array.isArray(value) && value.length > 0;
const sample = (arr, n = 8) => arr.slice(0, n);

const stats = {
  total: 0,
  canonicalOk: 0,
  missingUpdatedAt: 0,
  missingUpdatedAtButHasFallback: 0,
  missingParticipantIds: 0,
  missingParticipantIdsButHasLegacy: 0,
  atRisk: 0,
};
const legacyFieldUsage = {};
const sampleMissingUpdatedAt = [];
const sampleMissingParticipantIds = [];

let lastDoc = null;
const PAGE = 500;

for (;;) {
  let query = db.collection('conversations').orderBy('__name__').limit(PAGE);
  if (lastDoc) query = query.startAfter(lastDoc);
  const snap = await query.get();
  if (snap.empty) break;

  for (const doc of snap.docs) {
    stats.total += 1;
    const data = doc.data();

    const hasParticipantIds = hasNonEmptyArray(data.participantIds);
    const hasUpdatedAt = data.updatedAt !== undefined && data.updatedAt !== null;

    if (!hasUpdatedAt) {
      stats.missingUpdatedAt += 1;
      const fallback = UPDATED_AT_FALLBACKS.find(
        (f) => data[f] !== undefined && data[f] !== null,
      );
      if (fallback) stats.missingUpdatedAtButHasFallback += 1;
      if (sampleMissingUpdatedAt.length < 8) {
        sampleMissingUpdatedAt.push({ id: doc.id, fallback: fallback ?? null });
      }
    }

    if (!hasParticipantIds) {
      stats.missingParticipantIds += 1;
      const legacy = LEGACY_PARTICIPANT_FIELDS.filter((f) =>
        hasNonEmptyArray(data[f]),
      );
      if (legacy.length > 0) {
        stats.missingParticipantIdsButHasLegacy += 1;
        for (const f of legacy) {
          legacyFieldUsage[f] = (legacyFieldUsage[f] ?? 0) + 1;
        }
      }
      if (sampleMissingParticipantIds.length < 8) {
        sampleMissingParticipantIds.push({ id: doc.id, legacyFields: legacy });
      }
    }

    if (hasParticipantIds && hasUpdatedAt) {
      stats.canonicalOk += 1;
    } else {
      stats.atRisk += 1;
    }
  }

  lastDoc = snap.docs[snap.docs.length - 1];
  if (snap.size < PAGE) break;
}

const pct = (n) =>
  stats.total === 0 ? '0%' : `${((n / stats.total) * 100).toFixed(1)}%`;

console.log(JSON.stringify({
  projectId,
  total: stats.total,
  canonicalOk: `${stats.canonicalOk} (${pct(stats.canonicalOk)})`,
  atRisk: `${stats.atRisk} (${pct(stats.atRisk)})`,
  missingUpdatedAt: stats.missingUpdatedAt,
  missingUpdatedAtButHasFallback: stats.missingUpdatedAtButHasFallback,
  missingParticipantIds: stats.missingParticipantIds,
  missingParticipantIdsButHasLegacy: stats.missingParticipantIdsButHasLegacy,
  legacyParticipantFieldUsage: legacyFieldUsage,
  sampleMissingUpdatedAt: sample(sampleMissingUpdatedAt),
  sampleMissingParticipantIds: sample(sampleMissingParticipantIds),
}, null, 2));

console.log(
  stats.atRisk === 0
    ? '\nOK : toutes les conversations sont canoniques (participantIds + updatedAt).'
    : `\nATTENTION : ${stats.atRisk} conversation(s) ne se chargeront pas dans "Mes messages".`,
);
