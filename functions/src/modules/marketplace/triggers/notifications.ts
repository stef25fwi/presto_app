import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../../../core/firestore";
import { logger } from "../../../core/logger";
import { COLLECTIONS } from "../../../shared/constants";
import { createInAppNotification } from "../../notifications/push";
import { trackProductEventBackend } from "../services/analytics";

function normalizeString(value: unknown): string {
  return String(value ?? "").trim();
}

export const notifyListingApproved = onDocumentUpdated("listings/{listingId}", async (event) => {
  const before = (event.data?.before.data() ?? {}) as Record<string, unknown>;
  const after = (event.data?.after.data() ?? {}) as Record<string, unknown>;
  const listingId = event.params.listingId;
  if (!after) return;

  const beforeStatus = normalizeString(before.status).toLowerCase();
  const afterStatus = normalizeString(after.status).toLowerCase();
  if (beforeStatus === afterStatus || afterStatus !== "active") {
    return;
  }

  const ownerId = normalizeString(after.ownerId);
  if (!ownerId) return;

  await createInAppNotification({
    notificationId: `listing_approved_${listingId}`,
    userId: ownerId,
    title: "Annonce approuvee",
    message: normalizeString(after.title) || "Votre annonce est en ligne.",
    type: "listing_approved",
    routeName: `/listings/${encodeURIComponent(listingId)}`,
    offerId: listingId,
  });

  await trackProductEventBackend({
    eventName: "listing_published",
    userId: ownerId,
    listingId,
    params: {
      source: "trigger",
    },
  });

  logger.info("marketplace_listing_approved_notified", { listingId, ownerId });
});

export const notifyListingRejected = onDocumentUpdated("listings/{listingId}", async (event) => {
  const before = (event.data?.before.data() ?? {}) as Record<string, unknown>;
  const after = (event.data?.after.data() ?? {}) as Record<string, unknown>;
  const listingId = event.params.listingId;
  if (!after) return;

  const beforeStatus = normalizeString(before.status).toLowerCase();
  const afterStatus = normalizeString(after.status).toLowerCase();
  if (beforeStatus === afterStatus || afterStatus !== "rejected") {
    return;
  }

  const ownerId = normalizeString(after.ownerId);
  if (!ownerId) return;
  const moderation = after.moderation && typeof after.moderation === "object"
    ? after.moderation as Record<string, unknown>
    : {};
  const rejectionMessage = normalizeString(after.rejectionReason) ||
    normalizeString(moderation.userMessage) ||
    normalizeString(after.moderationReason) ||
    "Votre annonce a ete rejetee.";

  await createInAppNotification({
    notificationId: `listing_rejected_${listingId}`,
    userId: ownerId,
    title: "Annonce rejetee",
    message: rejectionMessage,
    type: "listing_rejected",
    routeName: `/listings/${encodeURIComponent(listingId)}`,
    offerId: listingId,
  });

  await trackProductEventBackend({
    eventName: "listing_rejected",
    userId: ownerId,
    listingId,
    params: {
      source: "trigger",
    },
  });

  logger.info("marketplace_listing_rejected_notified", { listingId, ownerId });
});