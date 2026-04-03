"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.EmailPreferenceService = void 0;
const firestore_1 = require("../../../core/firestore");
const constants_1 = require("../../../shared/constants");
const defaultPreferences = {
    locale: "fr",
    timezone: "Europe/Paris",
    transactionalEmailEnabled: true,
    lifecycleEmailEnabled: true,
    marketingEmailEnabled: false,
    messageEmailEnabled: true,
    nearbyListingsEnabled: false,
    referralEnabled: false,
};
class EmailPreferenceService {
    async getCommunicationPreferences(userId) {
        if (!userId)
            return defaultPreferences;
        const snap = await firestore_1.db
            .collection(constants_1.COLLECTIONS.notificationPreferences)
            .doc(userId)
            .get();
        if (!snap.exists)
            return defaultPreferences;
        const data = snap.data() ?? {};
        const email = (data.email ?? {});
        const marketing = (email.marketing ?? {});
        const messaging = (email.messages ?? {});
        return {
            locale: String(data.locale || "fr") === "en" ? "en" : "fr",
            timezone: String(data.timezone || "Europe/Paris"),
            transactionalEmailEnabled: true,
            lifecycleEmailEnabled: true,
            marketingEmailEnabled: marketing.enabled === true,
            messageEmailEnabled: messaging.enabled !== false,
            nearbyListingsEnabled: (email.saved_searches ?? {}).mode !== "off",
            referralEnabled: marketing.enabled === true,
            unsubscribeToken: String((data.unsubscribe_token ?? data.unsubscribeToken ?? "") || "") ||
                undefined,
        };
    }
    canSendEmailType(preferences, type) {
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
exports.EmailPreferenceService = EmailPreferenceService;
//# sourceMappingURL=EmailPreferenceService.js.map