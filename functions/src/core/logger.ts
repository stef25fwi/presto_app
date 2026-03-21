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
