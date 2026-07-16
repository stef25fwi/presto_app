import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../config/env";
import { db } from "../../core/firestore";

type SubscriptionPlan = "free" | "ilipresto_plus" | "ilipro";
type MeteredCreditKind = "pdf" | "voiceAi" | "textAi";
type CreditKind = MeteredCreditKind | "journeys" | "activeOffers";

type CreditLimits = Record<CreditKind, number>;

type CreditOperationData = {
  kind?: unknown;
  period?: unknown;
  status?: unknown;
};

const UNLIMITED = 999999;
const MAX_JOURNEY_SNAPSHOT_BYTES = 700_000;

const LIMITS_BY_PLAN: Record<SubscriptionPlan, CreditLimits> = {
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
    textAi: UNLIMITED,
    activeOffers: 10,
  },
  ilipro: {
    journeys: 10,
    pdf: 10,
    voiceAi: UNLIMITED,
    textAi: UNLIMITED,
    activeOffers: 30,
  },
};

const USAGE_FIELD_BY_KIND: Record<MeteredCreditKind, string> = {
  pdf: "pdfExportsUsed",
  voiceAi: "voiceAiUsed",
  textAi: "textAiUsed",
};

function requireUid(auth: { uid?: string } | undefined): string {
  const uid = String(auth?.uid ?? "").trim();
  if (!uid) {
    throw new HttpsError("unauthenticated", "Connectez-vous pour consulter vos crédits.");
  }
  return uid;
}

function asMap(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function asString(value: unknown): string {
  return String(value ?? "").trim();
}

function asInt(value: unknown): number {
  const parsed = Number(value ?? 0);
  if (!Number.isFinite(parsed)) return 0;
  return Math.max(0, Math.floor(parsed));
}

function normalizePlan(value: unknown): SubscriptionPlan {
  const raw = asString(value).toLowerCase().replace(/[\s-]/g, "_");
  if (raw === "ilipresto_plus" || raw === "iliprestoplus" || raw === "ilipresto+") {
    return "ilipresto_plus";
  }
  if (raw === "ilipro") return "ilipro";
  return "free";
}

function currentPeriod(now = new Date()): string {
  return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}`;
}

function nextResetAt(now = new Date()): string {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1)).toISOString();
}

function sanitizeOperationId(value: unknown): string {
  const raw = asString(value);
  if (!raw) {
    throw new HttpsError("invalid-argument", "operationId est requis.");
  }
  return raw.replace(/[^a-zA-Z0-9._-]/g, "_").slice(0, 160);
}

function normalizeMeteredKind(value: unknown): MeteredCreditKind {
  const raw = asString(value);
  if (raw === "pdf" || raw === "voiceAi" || raw === "textAi") return raw;
  throw new HttpsError("invalid-argument", "Type de crédit invalide.");
}

function limitsFor(plan: SubscriptionPlan, freeAccessMode: boolean): CreditLimits {
  if (freeAccessMode) {
    return {
      journeys: UNLIMITED,
      pdf: UNLIMITED,
      voiceAi: UNLIMITED,
      textAi: UNLIMITED,
      activeOffers: UNLIMITED,
    };
  }
  return LIMITS_BY_PLAN[plan];
}

async function loadSubscriptionContext(uid: string): Promise<{
  plan: SubscriptionPlan;
  freeAccessMode: boolean;
  limits: CreditLimits;
}> {
  const [userSnap, configSnap] = await Promise.all([
    db.collection("users").doc(uid).get(),
    db.collection("app_config").doc("subscriptions").get(),
  ]);
  const user = userSnap.data() ?? {};
  const config = configSnap.data() ?? {};
  const plan = normalizePlan(user.subscriptionPlan ?? user.plan);
  const freeAccessMode = config.freeAccessMode !== false;
  return { plan, freeAccessMode, limits: limitsFor(plan, freeAccessMode) };
}

function isActiveListing(data: Record<string, unknown>): boolean {
  const status = asString(data.status).toLowerCase();
  const visibility = data.visibility;
  const visibilityMap = asMap(visibility);
  const visibilityText = asString(visibility).toLowerCase();
  const isPublic = visibilityMap.isPublic === true || visibilityText === "public";
  return data.isPublished === true || data.isActive === true ||
    status === "published" || status === "active" || isPublic;
}

async function countActiveOffers(uid: string): Promise<number> {
  const fields = ["userId", "uid", "ownerId"];
  const snapshots = await Promise.all(fields.map(async (field) => {
    try {
      return await db.collection("listings").where(field, "==", uid).limit(150).get();
    } catch (error) {
      console.warn("SUBSCRIPTION_CREDITS_LISTINGS_QUERY_FAILED", { uid, field, error });
      return null;
    }
  }));
  const activeIds = new Set<string>();
  for (const snapshot of snapshots) {
    if (!snapshot) continue;
    for (const doc of snapshot.docs) {
      if (isActiveListing(doc.data())) activeIds.add(doc.id);
    }
  }
  return activeIds.size;
}

async function countSavedJourneys(uid: string): Promise<number> {
  const snap = await db.collection("users").doc(uid).collection("savedJourneys").limit(100).get();
  return snap.size;
}

function creditPayload(used: number, limit: number): Record<string, unknown> {
  const unlimited = limit >= UNLIMITED;
  return {
    used,
    limit,
    unlimited,
    remaining: unlimited ? UNLIMITED : Math.max(0, limit - used),
    exhausted: !unlimited && used >= limit,
  };
}

async function buildCreditSnapshot(uid: string): Promise<Record<string, unknown>> {
  const now = new Date();
  const period = currentPeriod(now);
  const context = await loadSubscriptionContext(uid);
  const usageRef = db.collection("users").doc(uid).collection("subscriptionUsage").doc(period);
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

export const getMySubscriptionCredits = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK, timeoutSeconds: 30 },
  async (request) => buildCreditSnapshot(requireUid(request.auth)),
);

export const consumeSubscriptionCredit = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK, timeoutSeconds: 30 },
  async (request) => {
    const uid = requireUid(request.auth);
    const data = asMap(request.data);
    const kind = normalizeMeteredKind(data.kind);
    const operationId = sanitizeOperationId(data.operationId);
    const period = currentPeriod();
    const context = await loadSubscriptionContext(uid);
    const limit = context.limits[kind];
    const usageField = USAGE_FIELD_BY_KIND[kind];
    const userRef = db.collection("users").doc(uid);
    const usageRef = userRef.collection("subscriptionUsage").doc(period);
    const operationRef = userRef.collection("subscriptionCreditOperations").doc(operationId);

    const result = await db.runTransaction(async (transaction) => {
      const [usageSnap, operationSnap] = await Promise.all([
        transaction.get(usageRef),
        transaction.get(operationRef),
      ]);
      const usage = usageSnap.data() ?? {};
      const currentUsed = asInt(usage[usageField]);
      const operation = (operationSnap.data() ?? {}) as CreditOperationData;

      if (operationSnap.exists && operation.status === "consumed") {
        return { used: currentUsed, alreadyConsumed: true };
      }

      if (limit < UNLIMITED && currentUsed >= limit) {
        throw new HttpsError(
          "resource-exhausted",
          "Votre crédit est épuisé pour cette période. Consultez les offres pour augmenter votre quota.",
          { kind, used: currentUsed, limit, upgradeRequired: true },
        );
      }

      const nextUsed = limit >= UNLIMITED ? currentUsed : currentUsed + 1;
      transaction.set(usageRef, {
        period,
        [usageField]: nextUsed,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      transaction.set(operationRef, {
        kind,
        period,
        status: "consumed",
        consumedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      return { used: nextUsed, alreadyConsumed: false };
    });

    return {
      ok: true,
      kind,
      period,
      limit,
      unlimited: limit >= UNLIMITED,
      ...result,
    };
  },
);

export const refundSubscriptionCredit = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK, timeoutSeconds: 30 },
  async (request) => {
    const uid = requireUid(request.auth);
    const data = asMap(request.data);
    const kind = normalizeMeteredKind(data.kind);
    const operationId = sanitizeOperationId(data.operationId);
    const userRef = db.collection("users").doc(uid);
    const operationRef = userRef.collection("subscriptionCreditOperations").doc(operationId);

    return db.runTransaction(async (transaction) => {
      const operationSnap = await transaction.get(operationRef);
      if (!operationSnap.exists) return { ok: true, refunded: false };
      const operation = (operationSnap.data() ?? {}) as CreditOperationData;
      if (operation.status !== "consumed" || operation.kind !== kind) {
        return { ok: true, refunded: false };
      }
      const period = asString(operation.period) || currentPeriod();
      const usageField = USAGE_FIELD_BY_KIND[kind];
      const usageRef = userRef.collection("subscriptionUsage").doc(period);
      const usageSnap = await transaction.get(usageRef);
      const currentUsed = asInt((usageSnap.data() ?? {})[usageField]);
      transaction.set(usageRef, {
        [usageField]: Math.max(0, currentUsed - 1),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      transaction.set(operationRef, {
        status: "refunded",
        refundedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      return { ok: true, refunded: true };
    });
  },
);

function journeyMetadata(snapshot: Record<string, unknown>): Record<string, string> {
  const summary = asMap(snapshot.summary);
  return {
    title: asString(snapshot.title ?? summary.title ?? summary.activity) || "Mon parcours personnalisé",
    activity: asString(snapshot.activity ?? summary.activity),
    currentStatus: asString(snapshot.currentStatus ?? summary.currentStatus),
    region: asString(snapshot.region ?? summary.region),
  };
}

export const saveMyJourney = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK, timeoutSeconds: 30 },
  async (request) => {
    const uid = requireUid(request.auth);
    const data = asMap(request.data);
    const snapshot = asMap(data.snapshot);
    if (Object.keys(snapshot).length === 0) {
      throw new HttpsError("invalid-argument", "Le parcours à sauvegarder est vide.");
    }
    const serialized = JSON.stringify(snapshot);
    if (Buffer.byteLength(serialized, "utf8") > MAX_JOURNEY_SNAPSHOT_BYTES) {
      throw new HttpsError("invalid-argument", "Le parcours est trop volumineux pour être sauvegardé.");
    }

    const context = await loadSubscriptionContext(uid);
    const requestedId = asString(data.journeyId).replace(/[^a-zA-Z0-9_-]/g, "").slice(0, 120);
    const userRef = db.collection("users").doc(uid);
    const journeyRef = requestedId
      ? userRef.collection("savedJourneys").doc(requestedId)
      : userRef.collection("savedJourneys").doc();
    const usageRef = userRef.collection("subscriptionUsage").doc("library");
    const actualCount = await countSavedJourneys(uid);
    const metadata = journeyMetadata(snapshot);

    await db.runTransaction(async (transaction) => {
      const [journeySnap, usageSnap] = await Promise.all([
        transaction.get(journeyRef),
        transaction.get(usageRef),
      ]);
      const storedCount = usageSnap.exists
        ? asInt((usageSnap.data() ?? {}).savedJourneysCount)
        : actualCount;
      const isNew = !journeySnap.exists;
      if (isNew && context.limits.journeys < UNLIMITED && storedCount >= context.limits.journeys) {
        throw new HttpsError(
          "resource-exhausted",
          "Votre bibliothèque de parcours est pleine. Supprimez un parcours ou choisissez une offre supérieure.",
          {
            kind: "journeys",
            used: storedCount,
            limit: context.limits.journeys,
            upgradeRequired: true,
          },
        );
      }

      transaction.set(journeyRef, {
        ownerId: uid,
        snapshot,
        ...metadata,
        createdAt: journeySnap.exists
          ? (journeySnap.data()?.createdAt ?? FieldValue.serverTimestamp())
          : FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      transaction.set(usageRef, {
        savedJourneysCount: isNew ? storedCount + 1 : storedCount,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    });

    return { ok: true, journeyId: journeyRef.id };
  },
);

export const deleteMyJourney = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK, timeoutSeconds: 30 },
  async (request) => {
    const uid = requireUid(request.auth);
    const journeyId = asString(asMap(request.data).journeyId)
      .replace(/[^a-zA-Z0-9_-]/g, "")
      .slice(0, 120);
    if (!journeyId) throw new HttpsError("invalid-argument", "journeyId est requis.");
    const userRef = db.collection("users").doc(uid);
    const journeyRef = userRef.collection("savedJourneys").doc(journeyId);
    const usageRef = userRef.collection("subscriptionUsage").doc("library");

    await db.runTransaction(async (transaction) => {
      const [journeySnap, usageSnap] = await Promise.all([
        transaction.get(journeyRef),
        transaction.get(usageRef),
      ]);
      if (!journeySnap.exists) return;
      const current = usageSnap.exists
        ? asInt((usageSnap.data() ?? {}).savedJourneysCount)
        : await countSavedJourneys(uid);
      transaction.delete(journeyRef);
      transaction.set(usageRef, {
        savedJourneysCount: Math.max(0, current - 1),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    });
    return { ok: true };
  },
);

function timestampToMillis(value: unknown): number | null {
  return value instanceof Timestamp ? value.toMillis() : null;
}

export const listMyJourneys = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK, timeoutSeconds: 30 },
  async (request) => {
    const uid = requireUid(request.auth);
    const snap = await db.collection("users").doc(uid).collection("savedJourneys")
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
  },
);
