import { db } from "../../../core/firestore";
import { COLLECTIONS } from "../../../shared/constants";
import { CommunicationPreferences, EmailType } from "../contracts";

const defaultPreferences: CommunicationPreferences = {
  locale: "fr",
  timezone: "Europe/Paris",
  transactionalEmailEnabled: true,
  lifecycleEmailEnabled: true,
  marketingEmailEnabled: false,
  messageEmailEnabled: true,
  nearbyListingsEnabled: false,
  referralEnabled: false,
};

export class EmailPreferenceService {
  async getCommunicationPreferences(
    userId?: string,
  ): Promise<CommunicationPreferences> {
    if (!userId) return defaultPreferences;

    const snap = await db
      .collection(COLLECTIONS.notificationPreferences)
      .doc(userId)
      .get();
    if (!snap.exists) return defaultPreferences;

    const data = snap.data() ?? {};
    const email = (data.email ?? {}) as Record<string, unknown>;
    const marketing = (email.marketing ?? {}) as Record<string, unknown>;
    const messaging = (email.messages ?? {}) as Record<string, unknown>;

    return {
      locale: String(data.locale || "fr") === "en" ? "en" : "fr",
      timezone: String(data.timezone || "Europe/Paris"),
      transactionalEmailEnabled: true,
      lifecycleEmailEnabled: true,
      marketingEmailEnabled: marketing.enabled === true,
      messageEmailEnabled: messaging.enabled !== false,
      nearbyListingsEnabled:
        ((email.saved_searches ?? {}) as Record<string, unknown>).mode !== "off",
      referralEnabled: marketing.enabled === true,
      unsubscribeToken:
        String((data.unsubscribe_token ?? data.unsubscribeToken ?? "") || "") ||
        undefined,
    };
  }

  canSendEmailType(
    preferences: CommunicationPreferences,
    type: EmailType,
  ): boolean {
    switch (type) {
      case "transactional":
        return preferences.transactionalEmailEnabled;
      case "lifecycle":
        return preferences.lifecycleEmailEnabled;
      case "marketing":
        return preferences.marketingEmailEnabled;
    }
  }
}