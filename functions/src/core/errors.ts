export class AppError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly retryable = false,
  ) {
    super(message);
    this.name = "AppError";
  }
}
