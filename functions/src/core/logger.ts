export type LogLevel = "INFO" | "WARN" | "ERROR";

export interface LogContext {
  eventId?: string;
  jobId?: string;
  providerMessageId?: string;
  traceId?: string;
  [key: string]: unknown;
}

function log(level: LogLevel, message: string, context: LogContext = {}): void {
  const payload = {
    level,
    message,
    ts: new Date().toISOString(),
    ...context,
  };
  console.log(JSON.stringify(payload));
}

export const logger = {
  info: (message: string, context?: LogContext) => log("INFO", message, context),
  warn: (message: string, context?: LogContext) => log("WARN", message, context),
  error: (message: string, context?: LogContext) => log("ERROR", message, context),
};

const PII_FIELDS = ["email", "phone", "displayName", "name", "avatarUrl", "photoURL"];

/**
 * Log structured data with PII fields automatically stripped.
 */
export function logSanitized(
  level: "info" | "warn" | "error",
  message: string,
  data: Record<string, unknown>,
): void {
  const sanitized = Object.fromEntries(
    Object.entries(data).filter(([key]) => !PII_FIELDS.includes(key)),
  );
  logger[level](message, sanitized);
}
