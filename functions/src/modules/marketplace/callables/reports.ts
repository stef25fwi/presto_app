import admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { ENFORCE_APP_CHECK, MARKETPLACE_REPORT_REVIEW_THRESHOLD, PROJECT_REGION } from "../../../config/env";
import { db } from "../../../core/firestore";
import { canProceedRateLimited } from "../../../core/rate_limit";
import { logger } from "../../../core/logger";
import { COLLECTIONS } from "../../../shared/constants";
import { createInAppNotification } from "../../notifications/push";
import { trackProductEventBackend } from "../services/analytics";
import { toHttpsError } from "../services/errors";
import { shouldHardRejectForRecaptcha, verifyRecaptchaAssessment } from "../services/recaptcha";
import { validateListingReportPayload } from "../validators/listings";

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

export const reportListing = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const reporterId = requireAuthUid(request);
  const recaptchaToken = normalizeString(request.data?.recaptchaToken);

  const rateAllowed = await canProceedRateLimited("listing_report", reporterId, 15, 24 * 60 * 60 * 1000);
  if (!rateAllowed) {
    throw new HttpsError("resource-exhausted", "Too many reports today");
  }

  const recaptcha = await verifyRecaptchaAssessment({
    token: recaptchaToken,
    expectedAction: "listing_report",
    userId: reporterId,
  });
  if (shouldHardRejectForRecaptcha(recaptcha)) {
    throw new HttpsError("permission-denied", "reCAPTCHA rejected the report");
  }
  if (!recaptcha.allowed) {
    logger.warn("marketplace_listing_report_recaptcha_non_blocking", {
      reporterId,
      score: recaptcha.score,
      reasons: recaptcha.reasons,
      action: recaptcha.action,
      assessed: recaptcha.assessed,
    });
  }

  try {
    const validated = validateListingReportPayload((request.data ?? {}) as Record<string, unknown>);
    const listingRef = db.collection(COLLECTIONS.listings).doc(validated.listingId);
    const reportId = `${validated.listingId}__${reporterId}`;
    const reportRef = db.collection(COLLECTIONS.listingReports).doc(reportId);
    const moderationRef = db.collection(COLLECTIONS.listingModeration).doc(validated.listingId);

    let reviewTriggered = false;
    let ownerId = "";

    await db.runTransaction(async (transaction) => {
      const [listingSnap, reportSnap, moderationSnap] = await Promise.all([
        transaction.get(listingRef),
        transaction.get(reportRef),
        transaction.get(moderationRef),
      ]);

      if (!listingSnap.exists) {
        throw new HttpsError("not-found", "Listing not found");
      }
      if (reportSnap.exists) {
        throw new HttpsError("already-exists", "You have already reported this listing");
      }

      const listingData = (listingSnap.data() ?? {}) as Record<string, unknown>;
      ownerId = normalizeString(listingData.ownerId);
      if (ownerId === reporterId) {
        throw new HttpsError("failed-precondition", "You cannot report your own listing");
      }

      const newReportCount = Number(listingData.reportCount || 0) + 1;
      transaction.set(reportRef, {
        id: reportId,
        reporterId,
        listingId: validated.listingId,
        reasonCode: validated.reasonCode,
        reasonText: validated.reasonText || null,
        status: "open",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.set(listingRef, {
        reportCount: newReportCount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      if (newReportCount >= MARKETPLACE_REPORT_REVIEW_THRESHOLD) {
        reviewTriggered = true;
        const currentAutoFlags = Array.isArray(moderationSnap.data()?.autoFlags)
          ? moderationSnap.data()?.autoFlags as string[]
          : [];

        transaction.set(listingRef, {
          status: "pending",
          moderationStatus: "manual_review",
          visibility: "private",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        transaction.set(moderationRef, {
          id: validated.listingId,
          listingId: validated.listingId,
          ownerId,
          moderationDecision: "manual_review",
          moderationReason: "report_threshold_reached",
          autoFlags: Array.from(new Set([...currentAutoFlags, "report_threshold_exceeded"])),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
    });

    if (reviewTriggered && ownerId) {
      await createInAppNotification({
        notificationId: `listing_reported_${validated.listingId}`,
        userId: ownerId,
        title: "Annonce en revue",
        message: "Votre annonce a atteint le seuil de signalements et passe en revue manuelle.",
        type: "listing_reported",
        routeName: `/listings/${encodeURIComponent(validated.listingId)}`,
        offerId: validated.listingId,
      });
    }

    await trackProductEventBackend({
      eventName: "listing_reported",
      userId: reporterId,
      listingId: validated.listingId,
      params: {
        reason_code: validated.reasonCode,
        threshold_triggered: reviewTriggered,
      },
    });

    logger.info("marketplace_listing_reported", {
      listingId: validated.listingId,
      reporterId,
      reasonCode: validated.reasonCode,
      reviewTriggered,
    });

    return {
      ok: true,
      reportId,
      reviewTriggered,
    };
  } catch (error) {
    throw toHttpsError(error, "Unable to report listing");
  }
});