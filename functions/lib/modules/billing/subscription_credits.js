"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.listMyJourneys = exports.deleteMyJourney = exports.saveMyJourney = exports.refundSubscriptionCredit = exports.consumeSubscriptionCredit = exports.getMySubscriptionCredits = exports.UNLIMITED_SUBSCRIPTION_CREDIT = void 0;
exports.normalizeSubscriptionCreditPlan = normalizeSubscriptionCreditPlan;
exports.subscriptionCreditPeriod = subscriptionCreditPeriod;
exports.subscriptionCreditLimitsForPlan = subscriptionCreditLimitsForPlan;
exports.isSubscriptionCreditActiveListing = isSubscriptionCreditActiveListing;
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
const firestore_2 = require("../../core/firestore");
exports.UNLIMITED_SUBSCRIPTION_CREDIT = 999999;
const MAX_JOURNEY_SNAPSHOT_BYTES = 700_000;
const LIMITS_BY_PLAN = {
    free: {
        journeys: 2,
        pdf: 0,
        voiceAi: 1,
        textAi: 2,
        activeOffers: 3,
    },
    ilipresto_plus: {
        journeys: 5,
        pdf: 5,
        voiceAi: 5,
        textAi: exports.UNLIMITED_SUBSCRIPTION_CREDIT,
        activeOffers: 10,
    },
    ilipro: {
        journeys: 10,
        pdf: 10,
        voiceAi: exports.UNLIMITED_SUBSCRIPTION_CREDIT,
        textAi: exports.UNLIMITED_SUBSCRIPTION_CREDIT,
        activeOffers: 30,
    },
};
const USAGE_FIELD_BY_KIND = {
    pdf: "pdfExportsUsed",
    voiceAi: "voiceAiUsed",
    textAi: "textAiUsed",
};
function requireUid(auth) {
    const uid = String(auth?.uid ?? "").trim();
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Connectez-vous pour consulter vos crédits.");
    }
    return uid;
}
function asMap(value) {
    return value && typeof value === "object" && !Array.isArray(value)
        ? value
        : {};
}
function asString(value) {
    return String(value ?? "").trim();
}
function asInt(value) {
    const parsed = Number(value ?? 0);
    if (!Number.isFinite(parsed))
        return 0;
    return Math.max(0, Math.floor(parsed));
}
function normalizeSubscriptionCreditPlan(value) {
    const raw = asString(value).toLowerCase().replace(/[\s-]/g, "_");
    if (raw === "ilipresto_plus" || raw === "iliprestoplus" || raw === "ilipresto+") {
        return "ilipresto_plus";
    }
    if (raw === "ilipro")
        return "ilipro";
    return "free";
}
function subscriptionCreditPeriod(now = new Date()) {
    return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}`;
}
function nextResetAt(now = new Date()) {
    return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1)).toISOString();
}
function sanitizeOperationId(value) {
    const raw = asString(value);
    if (!raw)
        throw new https_1.HttpsError("invalid-argument", "operationId est requis.");
    return raw.replace(/[^a-zA-Z0-9._-]/g, "_").slice(0, 160);
}
function normalizeMeteredKind(value) {
    const raw = asString(value);
    if (raw === "pdf" || raw === "voiceAi" || raw === "textAi")
        return raw;
    throw new https_1.HttpsError("invalid-argument", "Type de crédit invalide.");
}
function subscriptionCreditLimitsForPlan(plan, freeAccessMode) {
    if (freeAccessMode) {
        return {
            journeys: exports.UNLIMITED_SUBSCRIPTION_CREDIT,
            pdf: exports.UNLIMITED_SUBSCRIPTION_CREDIT,
            voiceAi: exports.UNLIMITED_SUBSCRIPTION_CREDIT,
            textAi: exports.UNLIMITED_SUBSCRIPTION_CREDIT,
            activeOffers: exports.UNLIMITED_SUBSCRIPTION_CREDIT,
        };
    }
    return LIMITS_BY_PLAN[plan];
}
async function loadSubscriptionContext(uid) {
    const [userSnap, configSnap] = await Promise.all([
        firestore_2.db.collection("users").doc(uid).get(),
        firestore_2.db.collection("app_config").doc("subscriptions").get(),
    ]);
    const user = userSnap.data() ?? {};
    const config = configSnap.data() ?? {};
    const plan = normalizeSubscriptionCreditPlan(user.subscriptionPlan ?? user.plan);
    const freeAccessMode = config.freeAccessMode !== false;
    return {
        plan,
        freeAccessMode,
        limits: subscriptionCreditLimitsForPlan(plan, freeAccessMode),
    };
}
function isSubscriptionCreditActiveListing(data) {
    const status = asString(data.status).toLowerCase();
    const excludedStatuses = new Set([
        "archived",
        "deleted",
        "closed",
        "expired",
        "rejected",
        "refused",
        "declined",
    ]);
    if (excludedStatuses.has(status) ||
        data.isArchived === true ||
        data.isDeleted === true ||
        data.deletedAt != null ||
        data.archivedAt != null) {
        return false;
    }
    const visibility = data.visibility;
    const visibilityMap = asMap(visibility);
    const visibilityText = asString(visibility).toLowerCase();
    const isPublic = visibilityMap.isPublic === true || visibilityText === "public";
    return data.isPublished === true ||
        data.isActive === true ||
        status === "published" ||
        status === "active" ||
        isPublic;
}
async function countActiveOffers(uid) {
    const fields = ["userId", "uid", "ownerId"];
    const snapshots = await Promise.all(fields.map(async (field) => {
        try {
            return await firestore_2.db.collection("listings").where(field, "==", uid).limit(150).get();
        }
        catch (error) {
            console.warn("SUBSCRIPTION_CREDITS_LISTINGS_QUERY_FAILED", { uid, field, error });
            return null;
        }
    }));
    const activeIds = new Set();
    for (const snapshot of snapshots) {
        if (!snapshot)
            continue;
        for (const doc of snapshot.docs) {
            if (isSubscriptionCreditActiveListing(doc.data()))
                activeIds.add(doc.id);
        }
    }
    return activeIds.size;
}
async function countSavedJourneys(uid) {
    const snap = await firestore_2.db.collection("users").doc(uid).collection("savedJourneys").limit(100).get();
    return snap.size;
}
function creditPayload(used, limit) {
    const unlimited = limit >= exports.UNLIMITED_SUBSCRIPTION_CREDIT;
    return {
        used,
        limit,
        unlimited,
        remaining: unlimited ? exports.UNLIMITED_SUBSCRIPTION_CREDIT : Math.max(0, limit - used),
        exhausted: !unlimited && used >= limit,
    };
}
async function buildCreditSnapshot(uid) {
    const now = new Date();
    const period = subscriptionCreditPeriod(now);
    const context = await loadSubscriptionContext(uid);
    const usageRef = firestore_2.db.collection("users").doc(uid).collection("subscriptionUsage").doc(period);
    const [usageSnap, savedJourneys, activeOffers] = await Promise.all([
        usageRef.get(),
        countSavedJourneys(uid),
        countActiveOffers(uid),
    ]);
    const usage = usageSnap.data() ?? {};
    return {
        plan: context.plan,
        freeAccessMode: context.freeAccessMode,
        period,
        nextResetAt: nextResetAt(now),
        credits: {
            journeys: creditPayload(savedJourneys, context.limits.journeys),
            pdf: creditPayload(asInt(usage.pdfExportsUsed), context.limits.pdf),
            voiceAi: creditPayload(asInt(usage.voiceAiUsed), context.limits.voiceAi),
            textAi: creditPayload(asInt(usage.textAiUsed), context.limits.textAi),
            activeOffers: creditPayload(activeOffers, context.limits.activeOffers),
        },
    };
}
exports.getMySubscriptionCredits = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK, timeoutSeconds: 30 }, async (request) => buildCreditSnapshot(requireUid(request.auth)));
exports.consumeSubscriptionCredit = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK, timeoutSeconds: 30 }, async (request) => {
    const uid = requireUid(request.auth);
    const data = asMap(request.data);
    const kind = normalizeMeteredKind(data.kind);
    const operationId = sanitizeOperationId(data.operationId);
    const period = subscriptionCreditPeriod();
    const context = await loadSubscriptionContext(uid);
    const limit = context.limits[kind];
    const counted = limit < exports.UNLIMITED_SUBSCRIPTION_CREDIT;
    const usageField = USAGE_FIELD_BY_KIND[kind];
    const userRef = firestore_2.db.collection("users").doc(uid);
    const usageRef = userRef.collection("subscriptionUsage").doc(period);
    const operationRef = userRef.collection("subscriptionCreditOperations").doc(operationId);
    const result = await firestore_2.db.runTransaction(async (transaction) => {
        const usageSnap = await transaction.get(usageRef);
        const operationSnap = await transaction.get(operationRef);
        const usage = usageSnap.data() ?? {};
        const currentUsed = asInt(usage[usageField]);
        const operation = (operationSnap.data() ?? {});
        if (operationSnap.exists && operation.status === "consumed") {
            return { used: currentUsed, alreadyConsumed: true };
        }
        if (counted && currentUsed >= limit) {
            throw new https_1.HttpsError("resource-exhausted", "Votre crédit est épuisé pour cette période. Consultez les offres pour augmenter votre quota.", { kind, used: currentUsed, limit, upgradeRequired: true });
        }
        const nextUsed = counted ? currentUsed + 1 : currentUsed;
        transaction.set(usageRef, {
            period,
            [usageField]: nextUsed,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        transaction.set(operationRef, {
            kind,
            period,
            counted,
            status: "consumed",
            consumedAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        return { used: nextUsed, alreadyConsumed: false };
    });
    return {
        ok: true,
        kind,
        period,
        limit,
        unlimited: !counted,
        ...result,
    };
});
exports.refundSubscriptionCredit = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK, timeoutSeconds: 30 }, async (request) => {
    const uid = requireUid(request.auth);
    const data = asMap(request.data);
    const kind = normalizeMeteredKind(data.kind);
    const operationId = sanitizeOperationId(data.operationId);
    const userRef = firestore_2.db.collection("users").doc(uid);
    const operationRef = userRef.collection("subscriptionCreditOperations").doc(operationId);
    return firestore_2.db.runTransaction(async (transaction) => {
        const operationSnap = await transaction.get(operationRef);
        if (!operationSnap.exists)
            return { ok: true, refunded: false };
        const operation = (operationSnap.data() ?? {});
        if (operation.status !== "consumed" || operation.kind !== kind) {
            return { ok: true, refunded: false };
        }
        if (operation.counted === true) {
            const period = asString(operation.period) || subscriptionCreditPeriod();
            const usageField = USAGE_FIELD_BY_KIND[kind];
            const usageRef = userRef.collection("subscriptionUsage").doc(period);
            const usageSnap = await transaction.get(usageRef);
            const currentUsed = asInt((usageSnap.data() ?? {})[usageField]);
            transaction.set(usageRef, {
                [usageField]: Math.max(0, currentUsed - 1),
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        transaction.set(operationRef, {
            status: "refunded",
            refundedAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        return { ok: true, refunded: true };
    });
});
function journeyMetadata(snapshot) {
    const summary = asMap(snapshot.summary);
    return {
        title: asString(snapshot.title ?? summary.title ?? summary.activity) || "Mon parcours personnalisé",
        activity: asString(snapshot.activity ?? summary.activity),
        currentStatus: asString(snapshot.currentStatus ?? summary.currentStatus),
        region: asString(snapshot.region ?? summary.region),
    };
}
exports.saveMyJourney = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK, timeoutSeconds: 30 }, async (request) => {
    const uid = requireUid(request.auth);
    const data = asMap(request.data);
    const snapshot = asMap(data.snapshot);
    if (Object.keys(snapshot).length === 0) {
        throw new https_1.HttpsError("invalid-argument", "Le parcours à sauvegarder est vide.");
    }
    if (Buffer.byteLength(JSON.stringify(snapshot), "utf8") > MAX_JOURNEY_SNAPSHOT_BYTES) {
        throw new https_1.HttpsError("invalid-argument", "Le parcours est trop volumineux pour être sauvegardé.");
    }
    const context = await loadSubscriptionContext(uid);
    const requestedId = asString(data.journeyId).replace(/[^a-zA-Z0-9_-]/g, "").slice(0, 120);
    const userRef = firestore_2.db.collection("users").doc(uid);
    const journeyRef = requestedId
        ? userRef.collection("savedJourneys").doc(requestedId)
        : userRef.collection("savedJourneys").doc();
    const usageRef = userRef.collection("subscriptionUsage").doc("library");
    const actualCount = await countSavedJourneys(uid);
    const metadata = journeyMetadata(snapshot);
    await firestore_2.db.runTransaction(async (transaction) => {
        const journeySnap = await transaction.get(journeyRef);
        const usageSnap = await transaction.get(usageRef);
        const storedCount = usageSnap.exists
            ? asInt((usageSnap.data() ?? {}).savedJourneysCount)
            : actualCount;
        const isNew = !journeySnap.exists;
        if (isNew &&
            context.limits.journeys < exports.UNLIMITED_SUBSCRIPTION_CREDIT &&
            storedCount >= context.limits.journeys) {
            throw new https_1.HttpsError("resource-exhausted", "Votre bibliothèque de parcours est pleine. Supprimez un parcours ou choisissez une offre supérieure.", {
                kind: "journeys",
                used: storedCount,
                limit: context.limits.journeys,
                upgradeRequired: true,
            });
        }
        transaction.set(journeyRef, {
            ownerId: uid,
            snapshot,
            ...metadata,
            createdAt: journeySnap.exists
                ? (journeySnap.data()?.createdAt ?? firestore_1.FieldValue.serverTimestamp())
                : firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        transaction.set(usageRef, {
            savedJourneysCount: isNew ? storedCount + 1 : storedCount,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
    });
    return { ok: true, journeyId: journeyRef.id };
});
exports.deleteMyJourney = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK, timeoutSeconds: 30 }, async (request) => {
    const uid = requireUid(request.auth);
    const journeyId = asString(asMap(request.data).journeyId)
        .replace(/[^a-zA-Z0-9_-]/g, "")
        .slice(0, 120);
    if (!journeyId)
        throw new https_1.HttpsError("invalid-argument", "journeyId est requis.");
    const userRef = firestore_2.db.collection("users").doc(uid);
    const journeyRef = userRef.collection("savedJourneys").doc(journeyId);
    const usageRef = userRef.collection("subscriptionUsage").doc("library");
    const actualCount = await countSavedJourneys(uid);
    await firestore_2.db.runTransaction(async (transaction) => {
        const journeySnap = await transaction.get(journeyRef);
        const usageSnap = await transaction.get(usageRef);
        if (!journeySnap.exists)
            return;
        const current = usageSnap.exists
            ? asInt((usageSnap.data() ?? {}).savedJourneysCount)
            : actualCount;
        transaction.delete(journeyRef);
        transaction.set(usageRef, {
            savedJourneysCount: Math.max(0, current - 1),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
    });
    return { ok: true };
});
function timestampToMillis(value) {
    return value instanceof firestore_1.Timestamp ? value.toMillis() : null;
}
exports.listMyJourneys = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK, timeoutSeconds: 30 }, async (request) => {
    const uid = requireUid(request.auth);
    const snap = await firestore_2.db.collection("users").doc(uid).collection("savedJourneys")
        .orderBy("updatedAt", "desc")
        .limit(50)
        .get();
    return {
        journeys: snap.docs.map((doc) => {
            const data = doc.data();
            return {
                id: doc.id,
                title: asString(data.title),
                activity: asString(data.activity),
                currentStatus: asString(data.currentStatus),
                region: asString(data.region),
                createdAtMillis: timestampToMillis(data.createdAt),
                updatedAtMillis: timestampToMillis(data.updatedAt),
                snapshot: asMap(data.snapshot),
            };
        }),
    };
});
//# sourceMappingURL=subscription_credits.js.map