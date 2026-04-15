"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onUserUpdated = exports.onUserCreated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const env_1 = require("../../config/env");
const firestore_2 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
function extractFirstName(data) {
    return String(data?.displayName || data?.display_name || "").trim().split(" ")[0] || "";
}
function extractEmail(data) {
    return String(data?.email || "").trim().toLowerCase();
}
function readBoolean(...values) {
    for (const value of values) {
        if (typeof value === "boolean")
            return value;
        if (typeof value === "number")
            return value !== 0;
        if (typeof value === "string") {
            const normalized = value.trim().toLowerCase();
            if (normalized === "true" || normalized === "1")
                return true;
            if (normalized === "false" || normalized === "0" || normalized === "")
                return false;
        }
    }
    return false;
}
function readTimestampMs(...values) {
    for (const value of values) {
        if (typeof value === "number" && Number.isFinite(value) && value > 0)
            return value;
        if (value instanceof Date)
            return value.getTime();
        if (typeof value === "object" && value && "toMillis" in value) {
            const candidate = value.toMillis?.();
            if (typeof candidate === "number" && Number.isFinite(candidate) && candidate > 0)
                return candidate;
        }
    }
    return 0;
}
function normalizeStatus(value) {
    return String(value || "").trim().toLowerCase();
}
async function emitUserLifecycleEvent({ eventId, eventName, userId, dedupeKey, occurredAt, payload, }) {
    await firestore_2.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: eventName,
        source_collection: constants_1.COLLECTIONS.users,
        source_id: userId,
        recipient_user_id: userId,
        dedupe_key: dedupeKey,
        occurred_at: occurredAt,
        payload,
        status: "created",
    }, { merge: true });
}
/**
 * Fires when a new document is created in the `users` collection.
 * The legacy `onAuthUserCreated` in index.js already creates the doc,
 * so this trigger handles:
 *  - notification_preferences initialisation
 *  - welcome email event
 */
exports.onUserCreated = (0, firestore_1.onDocumentCreated)(`${constants_1.COLLECTIONS.users}/{userId}`, async (event) => {
    const data = event.data?.data();
    if (!data)
        return;
    const userId = event.params.userId;
    const now = Date.now();
    await event.data?.ref.set({
        inboxCounts: {
            unreadMessages: 0,
            unreadNotifications: 0,
            totalUnread: 0,
            updatedAt: now,
        },
    }, { merge: true });
    const email = String(data.email || "").trim();
    if (!email)
        return;
    // Idempotence : ne crée les préférences que si elles n'existent pas encore
    const prefsRef = firestore_2.db.collection(constants_1.COLLECTIONS.notificationPreferences).doc(userId);
    const prefsSnap = await prefsRef.get();
    if (!prefsSnap.exists) {
        await prefsRef.set({
            user_id: userId,
            locale: "fr",
            timezone: null, // sera résolu depuis le device lors du premier appel
            quiet_hours: { enabled: true, start_local: "22:00", end_local: "08:00" },
            email: {
                account: { enabled: true },
                messaging: { mode: "immediate" },
                listings: { mode: "immediate" },
                saved_searches: { mode: "daily" },
                favorites: { enabled: true },
                support: { enabled: true },
                marketing: { enabled: false, frequency_cap_per_week: 2 },
            },
            push: {
                messaging: { enabled: true },
                listings: { enabled: true },
                saved_searches: { enabled: true },
                favorites: { enabled: true },
                support: { enabled: true },
            },
            created_at: now,
            updated_at: now,
        });
    }
    // Emit email event pour l'email de bienvenue (idempotent via document ID)
    const eventId = `evt_user_created_${userId}`;
    const eventRef = firestore_2.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId);
    const eventSnap = await eventRef.get();
    if (!eventSnap.exists) {
        await eventRef.set({
            event_id: eventId,
            event_name: "user.created",
            source_collection: constants_1.COLLECTIONS.users,
            source_id: userId,
            recipient_user_id: userId,
            dedupe_key: (0, hash_1.sha256)(`user.created:${userId}`),
            occurred_at: now,
            payload: {
                recipient_email: email,
                firstName: String(data.displayName || data.display_name || "").split(" ")[0] ?? "",
                dashboardUrl: `${env_1.APP_BASE_URL}/mon-compte`,
            },
            status: "created",
        });
    }
});
exports.onUserUpdated = (0, firestore_1.onDocumentUpdated)(`${constants_1.COLLECTIONS.users}/{userId}`, async (event) => {
    const before = (event.data?.before.data() ?? {});
    const after = (event.data?.after.data() ?? {});
    if (!after || Object.keys(after).length === 0)
        return;
    const userId = String(event.params.userId || "");
    if (!userId)
        return;
    const recipientEmail = extractEmail(after) || extractEmail(before);
    if (!recipientEmail)
        return;
    const firstName = extractFirstName(after) || extractFirstName(before);
    const now = Date.now();
    const beforeVerified = readBoolean(before.email_verified, before.emailVerified, before.isEmailVerified);
    const afterVerified = readBoolean(after.email_verified, after.emailVerified, after.isEmailVerified);
    if (!beforeVerified && afterVerified) {
        const eventId = `evt_profile_verified_${userId}`;
        await emitUserLifecycleEvent({
            eventId,
            eventName: "profile.verified",
            userId,
            dedupeKey: (0, hash_1.sha256)(`profile.verified:${userId}`),
            occurredAt: now,
            payload: {
                recipient_email: recipientEmail,
                firstName,
                dashboardUrl: `${env_1.APP_BASE_URL}/mon-compte`,
            },
        });
    }
    const beforeDeletionRequestedAt = readTimestampMs(before.accountDeletionRequestedAt, before.account_deletion_requested_at, before.deletionRequestedAt, before.deletion_requested_at);
    const afterDeletionRequestedAt = readTimestampMs(after.accountDeletionRequestedAt, after.account_deletion_requested_at, after.deletionRequestedAt, after.deletion_requested_at);
    if (beforeDeletionRequestedAt <= 0 && afterDeletionRequestedAt > 0) {
        const effectiveAt = readTimestampMs(after.accountDeletionEffectiveAt, after.account_deletion_effective_at, after.deletionEffectiveAt, after.deletion_effective_at, after.deleteAt, after.delete_at) || afterDeletionRequestedAt;
        const eventId = `evt_user_account_deletion_requested_${userId}_${Math.floor(afterDeletionRequestedAt / 1000)}`;
        await emitUserLifecycleEvent({
            eventId,
            eventName: "user.account.deletion.requested",
            userId,
            dedupeKey: (0, hash_1.sha256)(`user.account.deletion.requested:${userId}:${Math.floor(afterDeletionRequestedAt / 1000)}`),
            occurredAt: now,
            payload: {
                recipient_email: recipientEmail,
                firstName,
                deletionDate: new Date(effectiveAt).toLocaleDateString("fr-FR"),
                cancelDeletionUrl: `${env_1.APP_BASE_URL}/mon-compte`,
                supportUrl: `${env_1.APP_BASE_URL}/support`,
            },
        });
    }
    const beforeStatus = normalizeStatus(before.status);
    const afterStatus = normalizeStatus(after.status);
    const beforeDeletedAt = readTimestampMs(before.deletedAt, before.deleted_at);
    const afterDeletedAt = readTimestampMs(after.deletedAt, after.deleted_at);
    if ((beforeStatus !== "deleted" && afterStatus === "deleted") || (beforeDeletedAt <= 0 && afterDeletedAt > 0)) {
        const deletedAt = afterDeletedAt || now;
        const eventId = `evt_user_account_deleted_${userId}_${Math.floor(deletedAt / 1000)}`;
        await emitUserLifecycleEvent({
            eventId,
            eventName: "user.account.deleted",
            userId,
            dedupeKey: (0, hash_1.sha256)(`user.account.deleted:${userId}:${Math.floor(deletedAt / 1000)}`),
            occurredAt: deletedAt,
            payload: {
                recipient_email: recipientEmail,
                firstName,
                feedbackUrl: `${env_1.APP_BASE_URL}/contact`,
                supportUrl: `${env_1.APP_BASE_URL}/support`,
            },
        });
    }
});
//# sourceMappingURL=triggers.js.map