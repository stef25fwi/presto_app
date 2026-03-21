import { Channel } from "../../../types/models";

export interface PreferenceDecision {
  allowed: boolean;
  reason: string;
  sendAtMs?: number;
}

export function isMandatoryChannel(channel: Channel): boolean {
  return channel === "transactionnel";
}
