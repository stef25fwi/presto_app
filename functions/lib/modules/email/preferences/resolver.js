"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.resolvePreferenceDecision = resolvePreferenceDecision;
const firestore_1 = require("../../../core/firestore");
const constants_1 = require("../../../shared/constants");
const rules_1 = require("./rules");
/** Compute sendAtMs respecting quiet hours [22h-08h local time]. */
function computeSendAtMs(timezone, quietHoursEnabled) {
    if (!quietHoursEnabled)
        return undefined;
    const tz = timezone || "UTC";
    const now = new Date();
    try {
        // Current hour in user's timezone (0-23)
        const hourStr = now.toLocaleString("en-US", { timeZone: tz, hour: "numeric", hour12: false });
        const hour = parseInt(hourStr, 10);
        // Quiet hours: 22:00 → 08:00 local time
        const inQuietHours = hour >= 22 || hour < 8;
        if (!inQuietHours)
            return undefined; // send now
        // Next 08:00 in the user's timezone
        const morning = new Date(now.toLocaleString("en-US", { timeZone: tz }));
        morning.setHours(8, 0, 0, 0);
        if (morning.getTime() <= now.getTime()) {
            morning.setDate(morning.getDate() + 1);
        }
        return morning.getTime();
    }
    catch {
        return undefined;
    }
}
async function resolvePreferenceDecision(userId, channel, topic = "other") {
    if (!userId) {
        return {
            allowed: channel === "transactionnel",
            reason: channel === "transactionnel" ? "mandatory_without_user" : "missing_user_id",
            locale: "fr",
        };
    }
    const doc = await firestore_1.db.collection(constants_1.COLLECTIONS.notificationPreferences).doc(userId).get();
    if (!doc.exists) {
        return { allowed: channel !== "marketing", reason: "default_policy", locale: "fr" };
    }
    const prefs = doc.data();
    const locale = prefs?.locale || "fr";
    if ((0, rules_1.isMandatoryChannel)(channel)) {
        return { allowed: true, reason: "mandatory_channel", locale };
    }
    if (channel === "marketing") {
        const allowed = Boolean(prefs?.email?.marketing?.enabled);
        return { allowed, reason: allowed ? "marketing_opt_in" : "marketing_opt_out", locale };
    }
    if (channel === "produit") {
        const timezone = prefs.timezone;
        const quietHoursEnabled = Boolean(prefs?.quiet_hours?.enabled);
        if (topic === "messaging") {
            const mode = prefs?.email?.messaging?.mode || "immediate";
            if (mode === "off")
                return { allowed: false, reason: "messaging_mode_off", locale };
            const sendAtMs = computeSendAtMs(timezone, quietHoursEnabled);
            return { allowed: true, reason: `messaging_mode_${mode}`, sendAtMs, locale };
        }
        if (topic === "listings") {
            const mode = prefs?.email?.listings?.mode || "immediate";
            if (mode === "off")
                return { allowed: false, reason: "listings_mode_off", locale };
            const sendAtMs = computeSendAtMs(timezone, quietHoursEnabled);
            return { allowed: true, reason: `listings_mode_${mode}`, sendAtMs, locale };
        }
        if (topic === "saved_search") {
            const mode = prefs?.email?.saved_searches?.mode || "daily";
            if (mode === "off")
                return { allowed: false, reason: "saved_search_mode_off", locale };
            const sendAtMs = computeSendAtMs(timezone, quietHoursEnabled);
            return { allowed: true, reason: `saved_search_mode_${mode}`, sendAtMs, locale };
        }
        return { allowed: true, reason: "product_default_allow", locale };
    }
    return { allowed: true, reason: "fallback_allow", locale };
}
//# sourceMappingURL=resolver.js.map