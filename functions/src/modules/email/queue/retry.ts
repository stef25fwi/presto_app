import { EMAIL_RETRY_MINUTES } from "../../../shared/constants";

export function computeRetryDelayMs(attempt: number): number {
  const idx = Math.max(0, Math.min(attempt, EMAIL_RETRY_MINUTES.length - 1));
  const minutes = EMAIL_RETRY_MINUTES[idx] ?? EMAIL_RETRY_MINUTES[EMAIL_RETRY_MINUTES.length - 1] ?? 480;
  return minutes * 60_000;
}
