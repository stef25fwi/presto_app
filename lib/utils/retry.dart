import 'dart:math';

/// Retry helper with exponential backoff + jitter.
///
/// Intended for transient runtime failures (network blips, deadline exceeded,
/// temporary unavailable).
Future<T> retry<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 500),
  double backoffFactor = 2.0,
  Duration maxDelay = const Duration(seconds: 6),
  bool Function(Object error)? retryIf,
}) async {
  assert(maxAttempts >= 1);

  Object? lastError;

  Duration delay = initialDelay;
  final rng = Random();

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (e) {
      lastError = e;
      // keep stack trace available for debugging in callers if needed
      // (we intentionally don't store it to avoid unused-local warnings)

      final shouldRetry = attempt < maxAttempts && (retryIf?.call(e) ?? false);
      if (!shouldRetry) {
        rethrow;
      }

      // jitter in [0.75..1.25]
      final jitter = 0.75 + (rng.nextDouble() * 0.5);
      final jittered = Duration(
        milliseconds: (delay.inMilliseconds * jitter).round(),
      );
      await Future<void>.delayed(jittered);

      final nextMs = (delay.inMilliseconds * backoffFactor).round();
      delay = Duration(milliseconds: min(nextMs, maxDelay.inMilliseconds));
    }
  }

  // Unreachable, but keeps analyzer happy.
  // ignore: only_throw_errors
  throw lastError ?? Exception('retry: failed') /* coverage */;
}
