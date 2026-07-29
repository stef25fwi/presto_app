export type LogLevel = "INFO" | "WARN" | "ERROR";

export interface LogContext {
  eventId?: string;
  jobId?: string;
  providerMessageId?: string;
  traceId?: string;
  [key: string]: unknown;
}

const SENSITIVE_KEY_PATTERN =
  /(?:email|phone|displayname|name|avatarurl|photourl|prompt|content|transcript|transcription|audiobase64|imagebase64|base64|authorization|token|secret|password)/i;
const MAX_LOG_STRING_LENGTH = 500;

function sanitizeValue(value: unknown, depth = 0): unknown {
  if (depth > 5) return "[TRUNCATED_DEPTH]";
  if (typeof value === "string") {
    return value.length > MAX_LOG_STRING_LENGTH
      ? `${value.slice(0, MAX_LOG_STRING_LENGTH)}…[TRUNCATED]`
      : value;
  }
  if (Array.isArray(value)) {
    return value.slice(0, 50).map((item) => sanitizeValue(item, depth + 1));
  }
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .filter(([key]) => !SENSITIVE_KEY_PATTERN.test(key))
        .map(([key, item]) => [key, sanitizeValue(item, depth + 1)]),
    );
  }
  return value;
}

export function sanitizeLogContext(context: LogContext = {}): LogContext {
  return sanitizeValue(context) as LogContext;
}

function log(level: LogLevel, message: string, context: LogContext = {}): void {
  const payload = {
    level,
    message,
    ts: new Date().toISOString(),
    ...sanitizeLogContext(context),
  };
  console.log(JSON.stringify(payload));
}

export const logger = {
  info: (message: string, context?: LogContext) => log("INFO", message, context),
  warn: (message: string, context?: LogContext) => log("WARN", message, context),
  error: (message: string, context?: LogContext) => log("ERROR", message, context),
};

/**
 * Backward-compatible explicit sanitizer. The base logger now applies the same
 * recursive redaction to every structured log entry.
 */
export function logSanitized(
  level: "info" | "warn" | "error",
  message: string,
  data: Record<string, unknown>,
): void {
  logger[level](message, data);
}
