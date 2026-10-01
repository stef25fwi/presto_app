import admin from "../../../core/firebase_admin_compat";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../../config/env";
import { db } from "../../../core/firestore";
import { logger } from "../../../core/logger";
import { createInAppNotification } from "../../notifications/push";
import { toHttpsError } from "../services/errors";
import { extractRolesFromAuthToken, requireAnyRole } from "../services/roles";

const REVIEWS_COLLECTION = "reviews";
const REVIEW_MODERATION_ACTIONS_COLLECTION = "review_moderation_actions";

type ReviewAdminDecision = "publish" | "hide" | "reject" | "request_correction";

function requireAuthUid(request: { auth?: { uid?: string } }): string {
  const uid = String(request.auth?.uid || "").trim();
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required");
  }
  return uid;
}

function normalizeString(value: unknown): string {
  return String(value ?? "").trim();
}

function assertDecision(value: unknown): ReviewAdminDecision {
  const decision = normalizeString(value);
  if (
    decision === "publish" ||
    decision === "hide" ||
    decision === "reject" ||
    decision === "request_correction"
  ) {
    return decision;
  }
  throw new HttpsError(
    "invalid-argument",
    "decision must be publish, hide, reject or request_correction",
  );
}

function patchForDecision(decision: ReviewAdminDecision, note: string): Record<string, unknown> {
  const now = admin.firestore.FieldValue.serverTimestamp();
  switch (decision) {
    case "publish":
      return {
        status: "published",
        visibleOnProfile: true,
        publishedAt: now,
        moderationStatus: "approved",
        adminModerationNote: note || null,
        updatedAt: now,
      };
    case "hide":
      return {
        status: "hidden",
        visibleOnProfile: false,
        moderationStatus: "hidden",
        adminModerationNote: note || null,
        updatedAt: now,
      };
    case "reject":
      return {
        status: "rejected",
        visibleOnProfile: false,
        moderationStatus: "rejected",
        adminModerationNote: note || null,
        updatedAt: now,
      };
    case "request_correction":
      return {
        status: "pending_moderation",
        visibleOnProfile: false,
        moderationStatus: "correction_requested",
        correctionRequested: true,
        correctionMessage: note || "Merci de modifier cet avis avant publication.",
        adminModerationNote: note || null,
        updatedAt: now,
      };
  }
}

function userNotificationForDecision(decision: ReviewAdminDecision): { title: string; message: string } {
  switch (decision) {
    case "publish":
      return {
        title: "Avis publié",
        message: "Un avis modéré a été publié sur iliprestō.",
      };
    case "hide":
      return {
        title: "Avis masqué",
        message: "Un avis a été masqué par l’équipe de modération.",
      };
    case "reject":
      return {
        title: "Avis rejeté",
        message: "Un avis a été rejeté car il ne respecte pas les règles iliprestō.",
      };
    case "request_correction":
      return {
        title: "Correction d’avis demandée",
        message: "L’équipe iliprestō demande une correction avant publication de l’avis.",
      };
  }
}

export const adminModerateReviewV2 = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const actorId = requireAuthUid(request);
    const actorRoles = extractRolesFromAuthToken(
      request.auth?.token as Record<string, unknown> | undefined,
    );
    requireAnyRole(
      actorRoles,
      ["moderator", "admin", "superadmin"],
      "Only moderators and admins can moderate reviews",
    );

    const reviewId = normalizeString(request.data?.reviewId);
    const decision = assertDecision(request.data?.decision);
    const note = normalizeString(request.data?.note).slice(0, 800);
    if (!reviewId) {
      throw new HttpsError("invalid-argument", "reviewId is required");
    }

    try {
      const reviewRef = db.collection(REVIEWS_COLLECTION).doc(reviewId);
      const reviewSnap = await reviewRef.get();
      if (!reviewSnap.exists) {
        throw new HttpsError("not-found", "Review not found");
      }

      const reviewData = (reviewSnap.data() ?? {}) as Record<string, unknown>;
      const reviewerId = normalizeString(reviewData.reviewerId);
      const reviewedUserId = normalizeString(reviewData.reviewedUserId);
      const offerId = normalizeString(reviewData.offerId);
      const actionRef = db.collection(REVIEW_MODERATION_ACTIONS_COLLECTION).doc();
      const now = admin.firestore.FieldValue.serverTimestamp();

      await db.runTransaction(async (transaction) => {
        transaction.set(reviewRef, {
          ...patchForDecision(decision, note),
          lastModeratedAt: now,
          lastModeratedBy: actorId,
          lastModerationDecision: decision,
        }, { merge: true });
        transaction.set(actionRef, {
          reviewId,
          decision,
          note: note || null,
          actorId,
          actorRoles,
          reviewerId: reviewerId || null,
          reviewedUserId: reviewedUserId || null,
          offerId: offerId || null,
          createdAt: now,
        });
      });

      const notification = userNotificationForDecision(decision);
      await Promise.all(
        Array.from(new Set([reviewerId, reviewedUserId]))
          .filter(Boolean)
          .map((userId) => createInAppNotification({
            notificationId: `review_moderation_${reviewId}_${decision}_${userId}`,
            userId,
            title: notification.title,
            message: notification.message,
            type: "review_moderation_decision",
            routeName: decision === "request_correction"
              ? "/account/mes-avis"
              : `/profile/${encodeURIComponent(userId)}` ,
            offerId: offerId || undefined,
            data: { reviewId, decision },
          })),
      );

      logger.info("marketplace_review_admin_moderated", {
        reviewId,
        decision,
        actorId,
        reviewerId,
        reviewedUserId,
        offerId,
      });

      return { ok: true, reviewId, decision };
    } catch (error) {
      throw toHttpsError(error, "Unable to moderate review v2");
    }
  },
);
