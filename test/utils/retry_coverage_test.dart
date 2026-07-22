import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/utils/retry.dart';

void main() {
  test('retry retourne immédiatement le premier succès', () async {
    var attempts = 0;

    final value = await retry<int>(() async {
      attempts += 1;
      return 42;
    });

    expect(value, 42);
    expect(attempts, 1);
  });

  test('retry relance les erreurs autorisées jusqu au succès', () async {
    var attempts = 0;

    final value = await retry<String>(
      () async {
        attempts += 1;
        if (attempts < 3) {
          throw TimeoutException('temporaire');
        }
        return 'ok';
      },
      maxAttempts: 3,
      initialDelay: Duration.zero,
      maxDelay: Duration.zero,
      retryIf: isRetryableTimeoutOrNetwork,
    );

    expect(value, 'ok');
    expect(attempts, 3);
  });

  test('retry propage immédiatement une erreur non relançable', () async {
    var attempts = 0;
    final error = StateError('définitif');

    await expectLater(
      retry<void>(
        () async {
          attempts += 1;
          throw error;
        },
        maxAttempts: 4,
        initialDelay: Duration.zero,
        retryIf: (_) => false,
      ),
      throwsA(same(error)),
    );

    expect(attempts, 1);
  });

  test('retry respecte le nombre maximal de tentatives', () async {
    var attempts = 0;

    await expectLater(
      retry<void>(
        () async {
          attempts += 1;
          throw TimeoutException('toujours indisponible');
        },
        maxAttempts: 3,
        initialDelay: Duration.zero,
        maxDelay: Duration.zero,
        backoffFactor: 3,
        retryIf: (_) => true,
      ),
      throwsA(isA<TimeoutException>()),
    );

    expect(attempts, 3);
  });

  test('classification des erreurs réseau reste dépendance-free', () {
    expect(
      isRetryableTimeoutOrNetwork(TimeoutException('timeout')),
      isTrue,
    );
    expect(isRetryableTimeoutOrNetwork(Exception('autre')), isFalse);
  });
}
