import admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { ENFORCE_APP_CHECK, MARKETPLACE_REPORT_REVIEW_THRESHOLD, PROJECT_REGION } from "../../../config/env";
import { db } from "../../../core/firestore";
import { canProceedRateLimited } from "../../../core/rate_limit";
import { logger } from "../../../core/logger";
import { COLLECTIONS } from "../../../shared/constants";
import { sha256 } from "../../../utils/hash";
import { createInAppNotification } from "../../notifications/push";
import { readConversationParticipants } from "../../messaging/participants";
import { trackProductEventBackend } from "../services/analytics";
import { toHttpsError } from "../services/errors";
import { shouldHardRejectForRecaptcha, verifyRecaptchaAssessment } from "../services/recaptcha";
import { validateConversationReportPayload, validateListingReportPayload } from "../validators/listings";

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

function firstNameFromDisplayName(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) return "";
  return trimmed.split(/\s+/)[0] || "";
}

interface AdminRecipient {
  userId: string;
  email: string;
  firstName: string;
}

async function queryUsersSafely(
  queryFactory: () => FirebaseFirestore.Query<FirebaseFirestore.DocumentData>,
): Promise<FirebaseFirestore.QueryDocumentSnapshot<FirebaseFirestore.DocumentData>[]> {
  try {
    const snap = await queryFactory().limit(200).get();
    return snap.docs;
  } catch (error) {
    logger.warn("marketplace_report_admin_query_failed", {
      error: error instanceof Error ? error.message : String(error),
    });
    return [];
  }
}

async function findModerationRecipients(): Promise<AdminRecipient[]> {
  const [roleArrayDocs, roleFieldDocs, adminDocs, isAdminDocs, superAdminDocs] = await Promise.all([
    queryUsersSafely(() => db.collection(COLLECTIONS.users).where("roles", "array-contains-any", ["moderator", "admin", "superadmin"])),
    queryUsersSafely(() => db.collection(COLLECTIONS.users).where("role", "in", ["moderator", "admin", "superadmin"])),
    queryUsersSafely(() => db.collection(COLLECTIONS.users).where("admin", "==", true)),
    queryUsersSafely(() => db.collection(COLLECTIONS.users).where("isAdmin", "==", true)),
    queryUsersSafely(() => db.collection(COLLECTIONS.users).where("superadmin", "==", true)),
  ]);

  const byId = new Map<string, AdminRecipient>();
  for (const snap of [
    ...roleArrayDocs,
    ...roleFieldDocs,
    ...adminDocs,
    ...isAdminDocs,
    ...superAdminDocs,
  ]) {
    const userId = snap.id;
    const data = (snap.data() ?? {}) as Record<string, unknown>;
    const email = normalizeString(data.email);
    if (!email) {
      continue;
    }

    const displayName = normalizeString(
      data.displayName || data.display_name || data.userName || data.name,
    );
    byId.set(userId, {
      userId,
      email,
      firstName: firstNameFromDisplayName(displayName),
    });
  }

  return Array.from(byId.values());
}

async function enqueueAdminReportAlertEmails({
  listingId,
  listingTitle,
  reportId,
  reasonCode,
  reasonText,
  reporterId,
}: {
  listingId: string;
  listingTitle: string;
  reportId: string;
  reasonCode: string;
  reasonText: string;
  reporterId: string;
}): Promise<number> {
  const [recipients, reporterSnap] = await Promise.all([
    findModerationRecipients(),
    db.collection(COLLECTIONS.users).doc(reporterId).get().catch(() => null),
  ]);

  if (recipients.length === 0) {
    return 0;
  }

  const reporterData = (reporterSnap?.data() ?? {}) as Record<string, unknown>;
  const reporterName = normalizeString(
    reporterData.displayName || reporterData.display_name || reporterData.userName || reporterData.name,
  ) || "Utilisateur PRESTO";
  const reporterEmail = normalizeString(reporterData.email);

  const now = Date.now();
  const listingUrl = `https://ilipresto.fr/listings/${encodeURIComponent(listingId)}`;
  const reportUrl = `https://ilipresto.fr/admin/reports/${encodeURIComponent(reportId)}`;

  await Promise.all(recipients.map((recipient) => {
    const eventId = `evt_listing_report_admin_alert_${reportId}_${recipient.userId}`;
    return db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
      event_id: eventId,
      event_name: "listing.reported.admin_alert",
      source_collection: COLLECTIONS.listingReports,
      source_id: reportId,
      actor_user_id: reporterId,
      recipient_user_id: recipient.userId,
      dedupe_key: sha256(`listing.reported.admin_alert:${reportId}:${recipient.userId}`),
      occurred_at: now,
      payload: {
        recipient_email: recipient.email,
        firstName: recipient.firstName,
        listingId,
        listingTitle: listingTitle || listingId,
        reportId,
        reportReason: reasonCode,
        reportReasonText: reasonText || "(aucun detail fourni)",
        reporterId,
        reporterName,
        reporterEmail,
        listingUrl,
        reportUrl,
      },
      status: "created",
    }, { merge: true });
  }));

  return recipients.length;
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
    let listingTitle = "";

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
      listingTitle = normalizeString(listingData.title);
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

    const adminAlertRecipients = await enqueueAdminReportAlertEmails({
      listingId: validated.listingId,
      listingTitle,
      reportId,
      reasonCode: validated.reasonCode,
      reasonText: validated.reasonText || "",
      reporterId,
    }).catch((error) => {
      logger.warn("marketplace_listing_report_admin_alert_failed", {
        listingId: validated.listingId,
        reportId,
        error: error instanceof Error ? error.message : String(error),
      });
      return 0;
    });

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
      adminAlertRecipients,
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

export const reportConversationMessage = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const reporterId = requireAuthUid(request);
    const recaptchaToken = normalizeString(request.data?.recaptchaToken);

    const rateAllowed = await canProceedRateLimited(
      "message_report",
      reporterId,
      15,
      24 * 60 * 60 * 1000,
    );
    if (!rateAllowed) {
      throw new HttpsError("resource-exhausted", "Too many reports today");
    }

    const recaptcha = await verifyRecaptchaAssessment({
      token: recaptchaToken,
      expectedAction: "message_report",
      userId: reporterId,
    });
    if (shouldHardRejectForRecaptcha(recaptcha)) {
      throw new HttpsError("permission-denied", "reCAPTCHA rejected the report");
    }
    if (!recaptcha.allowed) {
      logger.warn("marketplace_message_report_recaptcha_non_blocking", {
        reporterId,
        score: recaptcha.score,
        reasons: recaptcha.reasons,
        action: recaptcha.action,
        assessed: recaptcha.assessed,
      });
    }

    try {
      const validated = validateConversationReportPayload(
        (request.data ?? {}) as Record<string, unknown>,
      );

      const conversationRef = db.collection(COLLECTIONS.conversations).doc(validated.conversationId);
      const conversationSnap = await conversationRef.get();
      if (!conversationSnap.exists) {
        throw new HttpsError("not-found", "Conversation not found");
      }

      const conversationData = (conversationSnap.data() ?? {}) as Record<string, unknown>;
      const participants = readConversationParticipants(conversationData, {
        conversationId: validated.conversationId,
      });
      if (!participants.includes(reporterId)) {
        throw new HttpsError("permission-denied", "You are not a participant of this conversation");
      }

      const reportedUserId = participants.find((id) => id !== reporterId) || "";
      if (!reportedUserId) {
        throw new HttpsError("failed-precondition", "Unable to determine the reported participant");
      }

      const reportId = validated.messageId
        ? `${validated.conversationId}__${validated.messageId}__${reporterId}`
        : `${validated.conversationId}__${reporterId}`;
      const reportRef = db.collection(COLLECTIONS.messageReports).doc(reportId);
      const moderationRef = db.collection(COLLECTIONS.userModeration).doc(reportedUserId);

      let reviewTriggered = false;

      await db.runTransaction(async (transaction) => {
        const [reportSnap, moderationSnap] = await Promise.all([
          transaction.get(reportRef),
          transaction.get(moderationRef),
        ]);

        if (reportSnap.exists) {
          throw new HttpsError("already-exists", "You have already reported this");
        }

        transaction.set(reportRef, {
          id: reportId,
          reporterId,
          reportedUserId,
          conversationId: validated.conversationId,
          messageId: validated.messageId || null,
          reasonCode: validated.reasonCode,
          reasonText: validated.reasonText || null,
          status: "open",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const moderationData = (moderationSnap.data() ?? {}) as Record<string, unknown>;
        const newReportCount = Number(moderationData.reportCount || 0) + 1;
        const currentAutoFlags = Array.isArray(moderationData.autoFlags)
          ? (moderationData.autoFlags as string[])
          : [];

        const moderationUpdate: Record<string, unknown> = {
          id: reportedUserId,
          userId: reportedUserId,
          reportCount: newReportCount,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (newReportCount >= MARKETPLACE_REPORT_REVIEW_THRESHOLD) {
          reviewTriggered = true;
          moderationUpdate.moderationDecision = "manual_review";
          moderationUpdate.moderationReason = "report_threshold_reached";
          moderationUpdate.autoFlags = Array.from(
            new Set([...currentAutoFlags, "report_threshold_exceeded"]),
          );
        }

        transaction.set(moderationRef, moderationUpdate, { merge: true });
      });

      if (reviewTriggered) {
        const recipients = await findModerationRecipients();
        await Promise.all(
          recipients.map((recipient) =>
            createInAppNotification({
              notificationId: `message_reported_${reportedUserId}_${recipient.userId}`,
              userId: recipient.userId,
              title: "Utilisateur signalé en messagerie",
              message:
                "Un utilisateur a atteint le seuil de signalements en messagerie et passe en revue manuelle.",
              type: "message_reported",
              routeName: "/admin",
              conversationId: validated.conversationId,
              data: { reportedUserId },
            }),
          ),
        );
      }

      await trackProductEventBackend({
        eventName: "message_reported",
        userId: reporterId,
        threadId: validated.conversationId,
        params: {
          reason_code: validated.reasonCode,
          threshold_triggered: reviewTriggered,
        },
      });

      logger.info("marketplace_message_reported", {
        conversationId: validated.conversationId,
        reporterId,
        reportedUserId,
        reasonCode: validated.reasonCode,
        reviewTriggered,
      });

      return {
        ok: true,
        reportId,
        reviewTriggered,
      };
    } catch (error) {
      throw toHttpsError(error, "Unable to report message");
    }
  },
);