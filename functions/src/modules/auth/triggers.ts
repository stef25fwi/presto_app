import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";

/**
 * Fires when a new document is created in the `users` collection.
 * The legacy `onAuthUserCreated` in index.js already creates the doc,
 * so this trigger handles:
 *  - notification_preferences initialisation
 *  - welcome email event
 */
export const onUserCreated = onDocumentCreated(`${COLLECTIONS.users}/{userId}`, async (event) => {
  const data = event.data?.data();
  if (!data) return;

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
  if (!email) return;

  // Idempotence : ne crée les préférences que si elles n'existent pas encore
  const prefsRef = db.collection(COLLECTIONS.notificationPreferences).doc(userId);
  const prefsSnap = await prefsRef.get();

  if (!prefsSnap.exists) {
    await prefsRef.set({
      user_id: userId,
      locale: "fr",
      timezone: "America/Guadeloupe",
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
  const eventRef = db.collection(COLLECTIONS.emailEvents).doc(eventId);
  const eventSnap = await eventRef.get();
  if (!eventSnap.exists) {
    await eventRef.set({
      event_id: eventId,
      event_name: "user.created",
      source_collection: COLLECTIONS.users,
      source_id: userId,
      recipient_user_id: userId,
      dedupe_key: sha256(`user.created:${userId}`),
      occurred_at: now,
      payload: {
        recipient_email: email,
        firstName: String(data.displayName || data.display_name || "").split(" ")[0] ?? "",
        dashboardUrl: "https://presto.app/mon-compte",
      },
      status: "created",
    });
  }
});
