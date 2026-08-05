import admin from "../../../core/firebase_admin_compat";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../../config/env";
import { db } from "../../../core/firestore";
import { COLLECTIONS } from "../../../shared/constants";
import { createInAppNotification } from "../../notifications/push";
import { writeAdminActionLog } from "../services/admin_audit";
import { extractRolesFromAuthToken, requireAnyRole, syncMarketplaceClaims } from "../services/roles";
import { toHttpsError } from "../services/errors";
import { sendListingModerationSystemMessage } from "../services/system_messages";
import { validateRoleAssignment } from "../validators/listings";
import type { UserRole } from "../constants/enums";

function requireAuthUid(request: { auth?: { uid?: string } }): string {
  const uid = String(request.auth?.uid || "").trim();
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required");
  }
  return uid;
}

function resolveActorRole(actorRoles: readonly UserRole[]): UserRole {
  const ordered: UserRole[] = ["superadmin", "admin", "moderator", "pro", "user"];
  return ordered.find((role) => actorRoles.includes(role)) ?? "user";
}

function normalizeString(value: unknown): string {
  return String(value ?? "").trim();
}

function readInt(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value)
    ? Math.trunc(value)
    : Number.parseInt(String(value ?? "0"), 10) || 0;
}

function readStringList(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((entry) => normalizeString(entry))
    .filter(Boolean)
    .filter((entry, index, all) => all.indexOf(entry) === index);
}

function removeFromList(values: string[], target: string): string[] {
  return values.filter((value) => value !== target);
}

export function buildListingPatchForPhotoReview({
  decision,
  listingData,
  imageUrl,
  reason,
}: {
  decision: "approved" | "rejected";
  listingData: Record<string, unknown>;
  imageUrl: string;
  reason: string;
}): Record<string, unknown> {
  const moderation = (listingData.moderation ?? {}) as Record<string, unknown>;
  const imageCount = readInt(listingData.imageCount) || readStringList(listingData.imageUrls).length;
  const approvedImageCount = readInt(listingData.approvedImageCount);
  const rejectedImageCount = readInt(listingData.rejectedImageCount);
  const pendingHumanReviewCount = readInt(listingData.pendingHumanReviewCount);
  const pendingReviewImages = removeFromList(readStringList(listingData.pendingReviewImages), imageUrl);
  const approvedImageUrls = readStringList(listingData.approvedImageUrls);
  const rejectedImages = readStringList(listingData.rejectedImages);
  const textStatus = normalizeString(moderation.textStatus);
  // Treat missing or "pending" textStatus as approved: text scan may not have
  // run yet (e.g. text-only listing) and should not block photo review publication.
  const textStatusOk = textStatus === "" || textStatus === "approved" || textStatus === "pending";

  if (decision === "approved") {
    const nextApprovedImageUrls = imageUrl
      ? Array.from(new Set([...approvedImageUrls, imageUrl]))
      : approvedImageUrls;
    const nextApprovedImageCount = approvedImageCount + (imageUrl && !approvedImageUrls.includes(imageUrl) ? 1 : 0);
    const nextPendingCount = Math.max(0, pendingHumanReviewCount - 1);
    const canPublish = nextPendingCount === 0 &&
      rejectedImageCount === 0 &&
      (imageCount === 0 || nextApprovedImageCount >= imageCount) &&
      textStatusOk;

    return {
      approvedImageCount: nextApprovedImageCount,
      pendingHumanReviewCount: nextPendingCount,
      pendingReviewImages,
      approvedImageUrls: nextApprovedImageUrls,
      status: canPublish ? "active" : "pending",
      visibility: canPublish ? "public" : "private",
      moderationStatus: canPublish ? "approved" : "manual_review",
      publishedAt: canPublish ? admin.firestore.FieldValue.serverTimestamp() : null,
      rejectionReason: null,
      moderation: {
        ...moderation,
        imageStatus: nextPendingCount === 0 ? "approved" : "needs_review",
        finalDecision: canPublish ? "approved" : "needs_review",
        reviewedReason: null,
        checkedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    };
  }

  const nextRejectedImages = imageUrl
    ? Array.from(new Set([...rejectedImages, imageUrl]))
    : rejectedImages;

  return {
    rejectedImageCount: rejectedImageCount + 1,
    pendingHumanReviewCount: Math.max(0, pendingHumanReviewCount - 1),
    pendingReviewImages,
    rejectedImages: nextRejectedImages,
    status: "rejected",
    visibility: "hidden",
    moderationStatus: "rejected",
    autoPublishAfter: null,
    rejectionReason: reason,
    moderationReason: reason,
    moderation: {
      ...moderation,
      imageStatus: "rejected",
      finalDecision: "rejected",
      userMessage: reason,
      reviewedReason: reason,
      checkedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  };
}

export const applyUserRoleClaims = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const actorId = requireAuthUid(request);
  const actorRoles = extractRolesFromAuthToken(request.auth?.token as Record<string, unknown> | undefined);
  requireAnyRole(actorRoles, ["admin", "superadmin"], "Admin role required");

  try {
    const targetUserId = String(request.data?.targetUserId || "").trim();
    const roles = validateRoleAssignment(request.data?.roles);
    const actorRole = resolveActorRole(actorRoles);

    if (!targetUserId) {
      throw new HttpsError("invalid-argument", "targetUserId is required");
    }
    if (roles.includes("superadmin") && !actorRoles.includes("superadmin")) {
      throw new HttpsError("permission-denied", "Only a superadmin can grant the superadmin role");
    }

    await syncMarketplaceClaims({
      targetUserId,
      roles,
    });

    await writeAdminActionLog({
      actorId,
      actorRole,
      actionType: "apply_user_role_claims",
      targetType: "user",
      targetId: targetUserId,
      after: {
        roles,
      },
      metadata: {
        reason: String(request.data?.reason || "").trim() || null,
      },
    });

    return {
      ok: true,
      targetUserId,
      roles,
    };
  } catch (error) {
    throw toHttpsError(error, "Unable to apply user role claims");
  }
});

export const logAdminAction = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const actorId = requireAuthUid(request);
  const actorRoles = extractRolesFromAuthToken(request.auth?.token as Record<string, unknown> | undefined);
  requireAnyRole(actorRoles, ["admin", "superadmin", "moderator"], "Moderator role required");

  try {
    const actorRole = resolveActorRole(actorRoles);
    const actionType = String(request.data?.actionType || "").trim();
    const targetType = String(request.data?.targetType || "").trim();
    const targetId = String(request.data?.targetId || "").trim();

    if (!actionType || !targetType || !targetId) {
      throw new HttpsError("invalid-argument", "actionType, targetType and targetId are required");
    }

    const adminActionId = await writeAdminActionLog({
      actorId,
      actorRole,
      actionType,
      targetType,
      targetId,
      before: request.data?.before as Record<string, unknown> | undefined,
      after: request.data?.after as Record<string, unknown> | undefined,
      metadata: request.data?.metadata as Record<string, unknown> | undefined,
    });

    return {
      ok: true,
      adminActionId,
    };
  } catch (error) {
    throw toHttpsError(error, "Unable to log admin action");
  }
});

export const reviewListingPhoto = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const actorId = requireAuthUid(request);
  const actorRoles = extractRolesFromAuthToken(request.auth?.token as Record<string, unknown> | undefined);
  requireAnyRole(actorRoles, ["moderator", "admin", "superadmin"], "Moderator role required");

  try {
    const actorRole = resolveActorRole(actorRoles);
    const reviewId = normalizeString(request.data?.reviewId);
    const decision = normalizeString(request.data?.decision);
    const reason = normalizeString(request.data?.reason);

    if (!reviewId || (decision !== "approved" && decision !== "rejected")) {
      throw new HttpsError("invalid-argument", "reviewId and a valid decision are required");
    }
    if (decision === "rejected" && !reason) {
      throw new HttpsError("invalid-argument", "reason is required when rejecting a photo");
    }

    const reviewRef = db.collection(COLLECTIONS.listingPhotoReviews).doc(reviewId);

    let ownerId = "";
    let listingId = "";
    let listingTitle = "";
    let imageUrl = "";

    await db.runTransaction(async (transaction) => {
      const reviewSnap = await transaction.get(reviewRef);
      if (!reviewSnap.exists) {
        throw new HttpsError("not-found", "Photo review not found");
      }

      const reviewData = (reviewSnap.data() ?? {}) as Record<string, unknown>;
      if (normalizeString(reviewData.status) !== "pending") {
        throw new HttpsError("failed-precondition", "Photo review is not pending anymore");
      }

      listingId = normalizeString(reviewData.listingId);
      ownerId = normalizeString(reviewData.ownerId);
      imageUrl = normalizeString(reviewData.imageUrl);
      if (!listingId || !ownerId) {
        throw new HttpsError("failed-precondition", "Photo review payload is incomplete");
      }

      const listingRef = db.collection(COLLECTIONS.listings).doc(listingId);
      const moderationRef = db.collection(COLLECTIONS.listingModeration).doc(listingId);
      const [listingSnap, moderationSnap] = await Promise.all([
        transaction.get(listingRef),
        transaction.get(moderationRef),
      ]);

      if (!listingSnap.exists) {
        throw new HttpsError("not-found", "Listing not found");
      }

      const listingData = (listingSnap.data() ?? {}) as Record<string, unknown>;
      listingTitle = normalizeString(listingData.title);
      const listingPatch = buildListingPatchForPhotoReview({
        decision: decision as "approved" | "rejected",
        listingData,
        imageUrl,
        reason: reason || "Photo validee par moderation manuelle.",
      });
      const moderationData = (moderationSnap.data() ?? {}) as Record<string, unknown>;

      transaction.set(reviewRef, {
        status: decision,
        reason: reason || null,
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        reviewedBy: actorId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      transaction.set(listingRef, {
        ...listingPatch,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      transaction.set(moderationRef, {
        id: listingId,
        listingId,
        ownerId,
        moderationDecision: decision === "approved"
          ? normalizeString(listingPatch.moderationStatus) === "approved"
            ? "approved"
            : "manual_review"
          : "rejected",
        moderationReason: decision === "approved"
          ? "manual_photo_review_approved"
          : "manual_photo_review_rejected",
        userMessage: decision === "approved"
          ? normalizeString((moderationData.userMessage ?? "").toString())
          : reason,
        source: "hybrid",
        reviewedBy: actorId,
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    });

    await writeAdminActionLog({
      actorId,
      actorRole,
      actionType: decision === "approved" ? "approve_listing_photo" : "reject_listing_photo",
      targetType: "listingPhotoReview",
      targetId: reviewId,
      metadata: {
        listingId,
        ownerId,
        reason: reason || null,
      },
    });

    if (ownerId) {
      if (decision === "rejected") {
        await sendListingModerationSystemMessage({
          ownerId,
          listingId,
          listingTitle,
          body: "Bonjour, après vérification par notre équipe, une image ajoutée à votre annonce ne respecte pas les règles de publication ilipresto. Merci de modifier votre annonce avec une photo conforme avant une nouvelle soumission.",
        });
      }

      await createInAppNotification({
        notificationId: `${decision}_listing_photo_${reviewId}`,
        userId: ownerId,
        title: decision === "approved" ? "Photo validee" : "Photo refusee",
        message: decision === "approved"
          ? "Une photo de votre annonce a ete validee par l'equipe ilipresto."
          : (reason || "Une photo de votre annonce a ete refusee par l'equipe ilipresto."),
        type: decision === "approved" ? "listing_approved" : "listing_rejected",
        routeName: `/listings/${encodeURIComponent(listingId)}`,
        offerId: listingId,
      });
    }

    return {
      ok: true,
      reviewId,
      listingId,
      listingTitle,
      decision,
    };
  } catch (error) {
    throw toHttpsError(error, "Unable to review listing photo");
  }
});