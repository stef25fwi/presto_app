import { Channel } from "../../../types/models";

export type ProductPreferenceTopic = "messaging" | "listings" | "saved_search" | "other";

export interface PreferenceDecision {
  allowed: boolean;
  reason: string;
  sendAtMs?: number;
  locale?: "fr" | "en";
}

export function isMandatoryChannel(channel: Channel): boolean {
  return channel === "transactionnel";
}
