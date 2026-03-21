import { db } from "../../../core/firestore";
import { COLLECTIONS } from "../../../shared/constants";
import { NotificationPreferences } from "../../../types/models";
import { isMandatoryChannel, PreferenceDecision } from "./rules";

/** Compute sendAtMs respecting quiet hours [22h-08h local time]. */
function computeSendAtMs(timezone: string | undefined): number | undefined {
  const tz = timezone || "UTC";
  const now = new Date();

  try {
    // Current hour in user's timezone (0-23)
    const hourStr = now.toLocaleString("en-US", { timeZone: tz, hour: "numeric", hour12: false });
    const hour = parseInt(hourStr, 10);

    // Quiet hours: 22:00 → 08:00 local time
    const inQuietHours = hour >= 22 || hour < 8;
    if (!inQuietHours) return undefined; // send now

    // Next 08:00 in the user's timezone
    const morning = new Date(now.toLocaleString("en-US", { timeZone: tz }));
    morning.setHours(8, 0, 0, 0);
    if (morning.getTime() <= now.getTime()) {
      morning.setDate(morning.getDate() + 1);
    }
    return morning.getTime();
  } catch {
    return undefined;
  }
}

export async function resolvePreferenceDecision(
  userId: string | undefined,
  channel: "transactionnel" | "produit" | "marketing",
): Promise<PreferenceDecision> {
  if (!userId) {
    return {
      allowed: channel === "transactionnel",
      reason: channel === "transactionnel" ? "mandatory_without_user" : "missing_user_id",
    };
  }

  if (isMandatoryChannel(channel)) {
    return { allowed: true, reason: "mandatory_channel" };
  }

  const doc = await db.collection(COLLECTIONS.notificationPreferences).doc(userId).get();
  if (!doc.exists) {
    return { allowed: channel !== "marketing", reason: "default_policy" };
  }

  const prefs = doc.data() as NotificationPreferences;

  if (channel === "marketing") {
    const allowed = Boolean(prefs?.email?.marketing?.enabled);
    return { allowed, reason: allowed ? "marketing_opt_in" : "marketing_opt_out" };
  }

  if (channel === "produit") {
    const mode = prefs?.email?.messaging?.mode || "immediate";
    if (mode === "off") return { allowed: false, reason: "product_mode_off" };

    const timezone = (prefs as unknown as Record<string, unknown>).timezone as string | undefined;
    const sendAtMs = computeSendAtMs(timezone);
    return { allowed: true, reason: `product_mode_${mode}`, sendAtMs };
  }

  return { allowed: true, reason: "fallback_allow" };
}
