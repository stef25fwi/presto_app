import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/utils/retry.dart';

void main() {
  test('retourne immédiatement quand l opération réussit', () async {
    var calls = 0;

    final result = await retry<int>(() async {
      calls++;
      return 42;
    });

    expect(result, 42);
    expect(calls, 1);
  });

  test('réessaie une erreur transitoire puis réussit', () async {
    var calls = 0;

    final result = await retry<String>(
      () async {
        calls++;
        if (calls < 3) throw TimeoutException('temporaire');
        return 'ok';
      },
      maxAttempts: 3,
      initialDelay: Duration.zero,
      maxDelay: Duration.zero,
      retryIf: isRetryableTimeoutOrNetwork,
    );

    expect(result, 'ok');
    expect(calls, 3);
  });

  test('ne réessaie pas lorsque le prédicat refuse', () async {
    var calls = 0;

    await expectLater(
      retry<void>(
        () async {
          calls++;
          throw StateError('fatal');
        },
        maxAttempts: 3,
        initialDelay: Duration.zero,
        retryIf: (_) => false,
      ),
      throwsStateError,
    );

    expect(calls, 1);
  });

  test('relance la dernière erreur après le nombre maximal de tentatives', () async {
    var calls = 0;

    await expectLater(
      retry<void>(
        () async {
          calls++;
          throw TimeoutException('toujours indisponible');
        },
        maxAttempts: 2,
        initialDelay: Duration.zero,
        maxDelay: Duration.zero,
        backoffFactor: 3,
        retryIf: isRetryableTimeoutOrNetwork,
      ),
      throwsA(isA<TimeoutException>()),
    );

    expect(calls, 2);
  });

  test('identifie uniquement les timeouts par défaut', () {
    expect(isRetryableTimeoutOrNetwork(TimeoutException('x')), isTrue);
    expect(isRetryableTimeoutOrNetwork(StateError('x')), isFalse);
  });
}
