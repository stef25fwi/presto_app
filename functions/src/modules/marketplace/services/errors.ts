import { HttpsError } from "firebase-functions/v2/https";

export class ValidationError extends Error {
  readonly issues: string[];

  constructor(message: string, issues: string[] = [message]) {
    super(message);
    this.name = "ValidationError";
    this.issues = issues;
  }
}

export function toHttpsError(error: unknown, fallbackMessage = "internal error"): HttpsError {
  if (error instanceof HttpsError) {
    return error;
  }

  if (error instanceof ValidationError) {
    return new HttpsError("invalid-argument", error.message, { issues: error.issues });
  }

  if (error instanceof Error) {
    return new HttpsError("internal", error.message || fallbackMessage);
  }

  return new HttpsError("internal", fallbackMessage);
}