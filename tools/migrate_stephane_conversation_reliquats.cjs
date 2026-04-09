const admin = require('../functions/node_modules/firebase-admin');
const {
  buildConversationMirrorFields,
  readConversationMirrorData,
} = require('../functions/lib/modules/messaging/mirror.js');
const {
  mergeUniqueParticipantIds,
  normalizeParticipantBooleanMap,
  normalizeParticipantNumberMap,
  normalizeParticipantUnknownMap,
} = require('../functions/lib/modules/messaging/repair.js');
const {
  refreshUnreadMessageCount,
} = require('../functions/lib/modules/notifications/counters.js');

const PROJECT_ID = 'presto-app-74abe';
const OLD_UID = process.env.LEGACY_STEPHANE_UID || 'modRxXduO8TnMlD6MFxobuKigVy2';
const TARGET_EMAIL = process.env.STEPHANE_EMAIL || 'sahai.stephane@gmail.com';
const TARGET_UID = process.env.STEPHANE_UID || '';
const PARTICIPANT_QUERY_FIELDS = ['participants', 'participant_ids', 'participantIds'];
const APPLY = process.argv.includes('--apply');

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: PROJECT_ID,
    serviceAccountId: `${PROJECT_ID}@appspot.gserviceaccount.com`,
  });
}

const db = admin.firestore();

function logStep(label, payload) {
  console.log(`\n[${label}]`);
  if (payload !== undefined) {
    console.log(typeof payload === 'string' ? payload : JSON.stringify(payload, null, 2));
  }
}

function normalizeString(value) {
  return String(value ?? '').trim();
}

function canonicalConversationId({ offerId, participantA, participantB }) {
  return `offer_${offerId.replaceAll('/', '_')}__${[participantA, participantB]
    .map((value) => value.replaceAll('/', '_'))
    .sort()
    .join('__')}`;
}

function readMap(data, keys) {
  for (const key of keys) {
    const value = data[key];
    if (value && typeof value === 'object') return value;
  }
  return {};
}

function isTimestampLike(value) {
  return value && typeof value === 'object' && typeof value.toMillis === 'function';
}

function toMillis(value) {
  if (!value) return Number.NaN;
  if (isTimestampLike(value)) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const parsed = Date.parse(String(value));
  return Number.isNaN(parsed) ? Number.NaN : parsed;
}

function chooseLatestValue(...values) {
  let selected = undefined;
  let bestMs = Number.NEGATIVE_INFINITY;
  for (const value of values) {
    const ms = toMillis(value);
    if (Number.isNaN(ms)) continue;
    if (ms > bestMs) {
      bestMs = ms;
      selected = value;
    }
  }
  return selected;
}

function chooseEarliestValue(...values) {
  let selected = undefined;
  let bestMs = Number.POSITIVE_INFINITY;
  for (const value of values) {
    const ms = toMillis(value);
    if (Number.isNaN(ms)) continue;
    if (ms < bestMs) {
      bestMs = ms;
      selected = value;
    }
  }
  return selected;
}

function remapParticipantKey(participantId, oldUid, newUid) {
  return normalizeString(participantId) === oldUid ? newUid : normalizeString(participantId);
}

function remapStringMap(input, oldUid, newUid) {
  const result = {};
  for (const [key, value] of Object.entries(input || {})) {
    const nextKey = remapParticipantKey(key, oldUid, newUid);
    const nextValue = normalizeString(value);
    if (!nextKey || !nextValue) continue;
    result[nextKey] = nextValue;
  }
  return result;
}

function mergeParticipantNames(targetNames, sourceNames, targetUid, targetName, otherUid, otherName) {
  const merged = {
    ...remapStringMap(sourceNames, OLD_UID, targetUid),
    ...remapStringMap(targetNames, OLD_UID, targetUid),
  };
  if (targetName) merged[targetUid] = targetName;
  if (otherUid && otherName) merged[otherUid] = otherName;
  return merged;
}

function remapBooleanMap(input, participants, oldUid, newUid) {
  const remapped = {};
  for (const [key, value] of Object.entries(input || {})) {
    const nextKey = remapParticipantKey(key, oldUid, newUid);
    if (!nextKey) continue;
    remapped[nextKey] = remapped[nextKey] === true || value === true;
  }
  return normalizeParticipantBooleanMap(participants, remapped);
}

function remapNumberMapSum(inputs, participants, oldUid, newUid) {
  const remapped = {};
  for (const input of inputs) {
    for (const [key, value] of Object.entries(input || {})) {
      const nextKey = remapParticipantKey(key, oldUid, newUid);
      const nextValue = typeof value === 'number' ? value : Number.parseInt(String(value ?? ''), 10);
      if (!nextKey || Number.isNaN(nextValue)) continue;
      remapped[nextKey] = Math.max(0, Math.floor((remapped[nextKey] || 0) + nextValue));
    }
  }
  return normalizeParticipantNumberMap(participants, remapped);
}

function remapLatestUnknownMap(inputs, participants, oldUid, newUid) {
  const remapped = {};
  for (const input of inputs) {
    for (const [key, value] of Object.entries(input || {})) {
      const nextKey = remapParticipantKey(key, oldUid, newUid);
      if (!nextKey) continue;
      remapped[nextKey] = chooseLatestValue(remapped[nextKey], value) ?? value;
    }
  }
  return normalizeParticipantUnknownMap(participants, remapped);
}

function remapMessageData(data, oldUid, newUid, newDisplayName) {
  const senderId = normalizeString(data.senderId || data.sender_id);
  const nextSenderId = senderId === oldUid ? newUid : senderId;
  const nextSenderName = senderId === oldUid
    ? newDisplayName
    : normalizeString(data.senderName || data.sender_name);

  return {
    ...data,
    senderId: nextSenderId,
    sender_id: nextSenderId,
    senderName: nextSenderName,
    sender_name: nextSenderName,
  };
}

function buildMessageDescriptor(id, data) {
  return {
    id,
    data,
    createdAt: data.createdAt || data.created_at || null,
    senderId: normalizeString(data.senderId || data.sender_id),
    senderName: normalizeString(data.senderName || data.sender_name),
    text: normalizeString(data.text || data.body),
  };
}

function pickLatestMessage(messages) {
  let latest = null;
  for (const message of messages) {
    const currentMs = toMillis(message.createdAt);
    const latestMs = latest ? toMillis(latest.createdAt) : Number.NEGATIVE_INFINITY;
    if (latest == null || currentMs > latestMs || (currentMs === latestMs && message.id > latest.id)) {
      latest = message;
    }
  }
  return latest;
}

async function resolveTargetAuthUser() {
  if (normalizeString(TARGET_UID)) {
    return admin.auth().getUser(normalizeString(TARGET_UID));
  }
  return admin.auth().getUserByEmail(normalizeString(TARGET_EMAIL).toLowerCase());
}

async function getUserDisplayName(userId, fallback) {
  const normalizedUserId = normalizeString(userId);
  if (!normalizedUserId) return normalizeString(fallback);

  const [userSnap, authUser] = await Promise.all([
    db.collection('users').doc(normalizedUserId).get().catch(() => null),
    admin.auth().getUser(normalizedUserId).catch(() => null),
  ]);

  const userData = userSnap && userSnap.exists ? userSnap.data() || {} : {};
  return normalizeString(
    userData.displayName ||
    userData.display_name ||
    userData.pseudo ||
    authUser?.displayName ||
    authUser?.email ||
    fallback ||
    normalizedUserId
  );
}

async function loadLegacyConversations(oldUid) {
  const seen = new Map();

  for (const field of PARTICIPANT_QUERY_FIELDS) {
    const snapshot = await db.collection('conversations').where(field, 'array-contains', oldUid).get();
    for (const doc of snapshot.docs) {
      if (!seen.has(doc.id)) {
        seen.set(doc.id, { doc, sources: [] });
      }
      seen.get(doc.id).sources.push(field);
    }
  }

  return Array.from(seen.values()).sort((left, right) => left.doc.id.localeCompare(right.doc.id));
}

async function findReferencingDocs(collectionName, field, oldConversationId) {
  const snapshot = await db.collection(collectionName).where(field, '==', oldConversationId).get();
  return snapshot.docs;
}

async function buildMigrationPlanEntry(entry, oldUid, targetUid, targetDisplayName) {
  const oldSnap = entry.doc;
  const oldData = oldSnap.data() || {};
  const oldMirror = readConversationMirrorData(oldData);
  const participants = oldMirror.participants;
  const otherUserId = participants.find((value) => normalizeString(value) !== oldUid) || '';
  const offerId = normalizeString(oldMirror.offerId);
  const targetConversationId = offerId && otherUserId
    ? canonicalConversationId({ offerId, participantA: targetUid, participantB: otherUserId })
    : '';

  const [targetSnap, oldMessageSnap, otherDisplayName] = await Promise.all([
    targetConversationId ? db.collection('conversations').doc(targetConversationId).get() : null,
    oldSnap.ref.collection('messages').orderBy('createdAt').get(),
    getUserDisplayName(otherUserId, oldMirror.otherUserName),
  ]);

  const targetData = targetSnap && targetSnap.exists ? targetSnap.data() || {} : {};
  const targetMirror = targetSnap && targetSnap.exists ? readConversationMirrorData(targetData) : null;
  const targetMessageSnap = targetSnap && targetSnap.exists
    ? await targetSnap.ref.collection('messages').orderBy('createdAt').get()
    : null;

  const oldMessages = oldMessageSnap.docs.map((doc) =>
    buildMessageDescriptor(doc.id, remapMessageData(doc.data() || {}, oldUid, targetUid, targetDisplayName))
  );
  const targetMessages = targetMessageSnap
    ? targetMessageSnap.docs.map((doc) => buildMessageDescriptor(doc.id, doc.data() || {}))
    : [];

  const mergedById = new Map();
  for (const message of targetMessages) mergedById.set(message.id, message);
  for (const message of oldMessages) {
    if (!mergedById.has(message.id)) {
      mergedById.set(message.id, message);
    }
  }

  const mergedMessages = Array.from(mergedById.values());
  const latestMessage = pickLatestMessage(mergedMessages);
  const mergedParticipants = mergeUniqueParticipantIds(
    [targetUid, otherUserId],
    ...(targetMirror ? [targetMirror.participants] : []),
  );
  const mergedParticipantNames = mergeParticipantNames(
    targetMirror?.participantNames || {},
    oldMirror.participantNames || {},
    targetUid,
    targetDisplayName,
    otherUserId,
    otherDisplayName,
  );
  const mergedUnreadCount = remapNumberMapSum(
    [oldMirror.unreadCount || {}, targetMirror?.unreadCount || {}],
    mergedParticipants,
    oldUid,
    targetUid,
  );
  const mergedArchivedBy = remapBooleanMap(
    { ...(oldMirror.archivedBy || {}), ...(targetMirror?.archivedBy || {}) },
    mergedParticipants,
    oldUid,
    targetUid,
  );
  const mergedBlockedBy = remapBooleanMap(
    { ...(oldMirror.blockedBy || {}), ...(targetMirror?.blockedBy || {}) },
    mergedParticipants,
    oldUid,
    targetUid,
  );
  const mergedLastReadAt = remapLatestUnknownMap(
    [
      readMap(oldData, ['lastReadAt', 'last_read_at']),
      readMap(targetData, ['lastReadAt', 'last_read_at']),
    ],
    mergedParticipants,
    oldUid,
    targetUid,
  );

  const earliestCreatedAt = chooseEarliestValue(
    oldMirror.createdAt,
    targetMirror?.createdAt,
    ...mergedMessages.map((message) => message.createdAt),
  );
  const latestMessageAt = chooseLatestValue(
    latestMessage?.createdAt,
    oldMirror.lastMessageAt,
    targetMirror?.lastMessageAt,
  );

  const allArchived = mergedParticipants.length > 0 && mergedParticipants.every((participantId) => mergedArchivedBy[participantId] === true);
  const anyBlocked = mergedParticipants.some((participantId) => mergedBlockedBy[participantId] === true);
  const status = anyBlocked ? 'closed' : allArchived ? 'archived' : 'open';

  const notifications = [
    ...(await findReferencingDocs('notifications', 'conversationId', oldSnap.id)),
    ...(await findReferencingDocs('notifications', 'conversation_id', oldSnap.id)),
  ];
  const emailEvents = await findReferencingDocs('email_events', 'source_id', oldSnap.id);

  return {
    oldConversationId: oldSnap.id,
    targetConversationId,
    sources: entry.sources,
    otherUserId,
    otherDisplayName,
    offerId,
    offerTitle: normalizeString(targetMirror?.offerTitle || oldMirror.offerTitle),
    targetExists: Boolean(targetSnap && targetSnap.exists),
    oldMessageCount: oldMessages.length,
    targetMessageCount: targetMessages.length,
    mergedMessageCount: mergedMessages.length,
    notificationsCount: notifications.length,
    emailEventsCount: emailEvents.length,
    latestMessage,
    oldSnap,
    oldData,
    targetSnap,
    targetData,
    oldMessages,
    targetMessages,
    mergedParticipants,
    mergedParticipantNames,
    mergedUnreadCount,
    mergedArchivedBy,
    mergedBlockedBy,
    mergedLastReadAt,
    earliestCreatedAt,
    latestMessageAt,
    status,
    notifications,
    emailEvents,
  };
}

async function applyPlanEntry(planEntry, targetUid, targetDisplayName) {
  const targetRef = db.collection('conversations').doc(planEntry.targetConversationId);
  const batch = db.batch();

  const mergedFields = {
    ...planEntry.oldData,
    ...planEntry.targetData,
    ...buildConversationMirrorFields({
      participants: planEntry.mergedParticipants,
      participantNames: planEntry.mergedParticipantNames,
      otherUserName: planEntry.otherDisplayName,
      offerId: planEntry.offerId,
      offerTitle: planEntry.offerTitle,
      lastMessage: planEntry.latestMessage?.text || '',
      lastSenderId: planEntry.latestMessage?.senderId || '',
      lastSenderName: planEntry.latestMessage?.senderName || (planEntry.latestMessage?.senderId === targetUid ? targetDisplayName : planEntry.otherDisplayName),
      unreadCount: planEntry.mergedUnreadCount,
      messageCount: planEntry.mergedMessageCount,
      createdAt: planEntry.earliestCreatedAt || admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessageAt: planEntry.latestMessageAt || admin.firestore.FieldValue.serverTimestamp(),
      lastReadAt: planEntry.mergedLastReadAt,
      archivedBy: planEntry.mergedArchivedBy,
      blockedBy: planEntry.mergedBlockedBy,
      status: planEntry.status,
    }),
  };

  batch.set(targetRef, mergedFields, { merge: true });

  for (const message of planEntry.oldMessages) {
    batch.set(targetRef.collection('messages').doc(message.id), message.data, { merge: true });
  }

  for (const doc of planEntry.notifications) {
    const data = doc.data() || {};
    const patch = {
      conversationId: planEntry.targetConversationId,
      conversation_id: planEntry.targetConversationId,
    };
    if (typeof data.routeName === 'string' && data.routeName.includes(planEntry.oldConversationId)) {
      patch.routeName = data.routeName.replaceAll(planEntry.oldConversationId, planEntry.targetConversationId);
    }
    batch.set(doc.ref, patch, { merge: true });
  }

  for (const doc of planEntry.emailEvents) {
    batch.set(doc.ref, { source_id: planEntry.targetConversationId }, { merge: true });
  }

  await batch.commit();
  await db.recursiveDelete(planEntry.oldSnap.ref);
  await Promise.all(planEntry.mergedParticipants.map((participantId) => refreshUnreadMessageCount(participantId)));
}

async function main() {
  const targetAuthUser = await resolveTargetAuthUser();
  const targetUid = normalizeString(targetAuthUser.uid);
  const targetDisplayName = await getUserDisplayName(targetUid, targetAuthUser.displayName || targetAuthUser.email || targetUid);
  const oldUid = normalizeString(OLD_UID);

  if (!oldUid || !targetUid) {
    throw new Error('Both old and target UIDs must be resolvable.');
  }

  if (oldUid === targetUid) {
    throw new Error('Old UID and target UID are identical.');
  }

  const legacyEntries = await loadLegacyConversations(oldUid);
  const plans = [];
  for (const entry of legacyEntries) {
    plans.push(await buildMigrationPlanEntry(entry, oldUid, targetUid, targetDisplayName));
  }

  logStep('summary', {
    apply: APPLY,
    oldUid,
    targetUid,
    targetDisplayName,
    conversationCount: plans.length,
    plans: plans.map((plan) => ({
      oldConversationId: plan.oldConversationId,
      targetConversationId: plan.targetConversationId,
      targetExists: plan.targetExists,
      oldMessageCount: plan.oldMessageCount,
      targetMessageCount: plan.targetMessageCount,
      mergedMessageCount: plan.mergedMessageCount,
      notificationsCount: plan.notificationsCount,
      emailEventsCount: plan.emailEventsCount,
    })),
  });

  if (!APPLY) {
    logStep('dryRun', 'No write performed. Re-run with --apply to migrate the conversations.');
    return;
  }

  for (const plan of plans) {
    logStep('applyConversation', {
      oldConversationId: plan.oldConversationId,
      targetConversationId: plan.targetConversationId,
      targetExists: plan.targetExists,
      oldMessageCount: plan.oldMessageCount,
      targetMessageCount: plan.targetMessageCount,
      mergedMessageCount: plan.mergedMessageCount,
    });
    await applyPlanEntry(plan, targetUid, targetDisplayName);
  }

  logStep('result', 'Conversation reliquats migrated to Stephane account.');
}

main().catch((error) => {
  console.error('\n[error]');
  console.error(error && error.stack ? error.stack : error);
  process.exitCode = 1;
});