import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";

type LegalSettings = {
  current_version?: string;
  effective_date?: string;
  terms_url?: string;
  privacy_url?: string;
  status?: string;
};

async function emitTermsUpdatedEvents(version: string, effectiveDate: string, termsUrl: string): Promise<void> {
  let lastDocId: string | undefined;

  while (true) {
    let query = db.collection(COLLECTIONS.users).orderBy("__name__").limit(200);
    if (lastDocId) {
      query = query.startAfter(lastDocId);
    }

    const snap = await query.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      lastDocId = doc.id;
      const user = doc.data() ?? {};
      const recipientEmail = String(user.email || "").trim().toLowerCase();
      if (!recipientEmail) continue;

      const eventId = `evt_legal_terms_updated_${version}_${doc.id}`;
      await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: "legal.terms.updated",
        source_collection: COLLECTIONS.systemSettings,
        source_id: "legal_terms",
        recipient_user_id: doc.id,
        dedupe_key: sha256(`legal.terms.updated:${version}:${doc.id}`),
        occurred_at: Date.now(),
        payload: {
          recipient_email: recipientEmail,
          firstName: String(user.displayName || user.display_name || "").split(" ")[0] || "",
          effectiveDate,
          termsUrl,
        },
        status: "created",
      }, { merge: true });
    }

    if (snap.size < 200) break;
  }
}

export const onLegalTermsSettingsUpdated = onDocumentUpdated(`${COLLECTIONS.systemSettings}/legal_terms`, async (event) => {
  const before = (event.data?.before.data() ?? {}) as LegalSettings;
  const after = (event.data?.after.data() ?? {}) as LegalSettings;
  const nextVersion = String(after.current_version || "").trim();
  const previousVersion = String(before.current_version || "").trim();
  const effectiveDate = String(after.effective_date || "").trim();
  const termsUrl = String(after.terms_url || "").trim();
  const status = String(after.status || "draft").trim().toLowerCase();

  if (!nextVersion || nextVersion === previousVersion) return;
  if (status !== "published") return;
  if (!effectiveDate || !termsUrl) return;

  await emitTermsUpdatedEvents(nextVersion, effectiveDate, termsUrl);
});

async function emitPrivacyUpdatedEvents(version: string, effectiveDate: string, privacyUrl: string): Promise<void> {
  let lastDocId: string | undefined;

  while (true) {
    let query = db.collection(COLLECTIONS.users).orderBy("__name__").limit(200);
    if (lastDocId) {
      query = query.startAfter(lastDocId);
    }

    const snap = await query.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      lastDocId = doc.id;
      const user = doc.data() ?? {};
      const recipientEmail = String(user.email || "").trim().toLowerCase();
      if (!recipientEmail) continue;

      const eventId = `evt_legal_privacy_updated_${version}_${doc.id}`;
      await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: "legal.privacy.updated",
        source_collection: COLLECTIONS.systemSettings,
        source_id: "legal_privacy",
        recipient_user_id: doc.id,
        dedupe_key: sha256(`legal.privacy.updated:${version}:${doc.id}`),
        occurred_at: Date.now(),
        payload: {
          recipient_email: recipientEmail,
          firstName: String(user.displayName || user.display_name || "").split(" ")[0] || "",
          effectiveDate,
          privacyUrl,
        },
        status: "created",
      }, { merge: true });
    }

    if (snap.size < 200) break;
  }
}

export const onLegalPrivacySettingsUpdated = onDocumentUpdated(`${COLLECTIONS.systemSettings}/legal_privacy`, async (event) => {
  const before = (event.data?.before.data() ?? {}) as LegalSettings;
  const after = (event.data?.after.data() ?? {}) as LegalSettings;
  const nextVersion = String(after.current_version || "").trim();
  const previousVersion = String(before.current_version || "").trim();
  const effectiveDate = String(after.effective_date || "").trim();
  const privacyUrl = String(after.privacy_url || after.terms_url || "").trim();
  const status = String(after.status || "draft").trim().toLowerCase();

  if (!nextVersion || nextVersion === previousVersion) return;
  if (status !== "published") return;
  if (!effectiveDate || !privacyUrl) return;

  await emitPrivacyUpdatedEvents(nextVersion, effectiveDate, privacyUrl);
});