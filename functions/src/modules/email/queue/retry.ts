import { EMAIL_RETRY_MINUTES } from "../../../shared/constants";

export function computeRetryDelayMs(attempt: number): number {
  const idx = Math.max(0, Math.min(attempt, EMAIL_RETRY_MINUTES.length - 1));
  return EMAIL_RETRY_MINUTES[idx] * 60_000;
}
