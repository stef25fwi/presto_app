import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/core/connectivity/connectivity_status.dart';

void main() {
  group('ConnectivityStatus', () {
    test('démarre une seule écoute et applique l’état initial hors ligne', () async {
      var listenCount = 0;
      var notificationCount = 0;
      final changes = StreamController<List<ConnectivityResult>>(
        sync: true,
        onListen: () => listenCount++,
      );
      addTearDown(changes.close);

      final status = ConnectivityStatus.forTesting(
        checkConnectivity: () async => const <ConnectivityResult>[
          ConnectivityResult.none,
        ],
        connectivityChanges: () => changes.stream,
      );
      addTearDown(status.dispose);
      status.addListener(() => notificationCount++);

      expect(status.isOnline, isTrue);

      status.start();
      status.start();
      await Future<void>.delayed(Duration.zero);

      expect(listenCount, 1);
      expect(status.isOnline, isFalse);
      expect(notificationCount, 1);
    });

    test('notifie uniquement lors des changements réels du flux', () async {
      var notificationCount = 0;
      final changes = StreamController<List<ConnectivityResult>>(sync: true);
      addTearDown(changes.close);

      final status = ConnectivityStatus.forTesting(
        checkConnectivity: () async => const <ConnectivityResult>[
          ConnectivityResult.wifi,
        ],
        connectivityChanges: () => changes.stream,
      );
      addTearDown(status.dispose);
      status.addListener(() => notificationCount++);
      status.start();
      await Future<void>.delayed(Duration.zero);

      expect(status.isOnline, isTrue);
      expect(notificationCount, 0);

      changes.add(const <ConnectivityResult>[ConnectivityResult.none]);
      expect(status.isOnline, isFalse);
      expect(notificationCount, 1);

      changes.add(const <ConnectivityResult>[ConnectivityResult.none]);
      expect(notificationCount, 1);

      changes.add(const <ConnectivityResult>[
        ConnectivityResult.none,
        ConnectivityResult.mobile,
      ]);
      expect(status.isOnline, isTrue);
      expect(notificationCount, 2);
    });

    test('conserve l’état en ligne quand la vérification initiale échoue', () async {
      final changes = StreamController<List<ConnectivityResult>>(sync: true);
      addTearDown(changes.close);
      var notificationCount = 0;

      final status = ConnectivityStatus.forTesting(
        checkConnectivity: () async => throw StateError('plugin indisponible'),
        connectivityChanges: () => changes.stream,
      );
      addTearDown(status.dispose);
      status.addListener(() => notificationCount++);

      status.start();
      await Future<void>.delayed(Duration.zero);

      expect(status.isOnline, isTrue);
      expect(notificationCount, 0);
    });

    test('annule l’abonnement lors de la libération', () async {
      final cancelled = Completer<void>();
      final changes = StreamController<List<ConnectivityResult>>(
        sync: true,
        onCancel: cancelled.complete,
      );
      addTearDown(changes.close);

      final status = ConnectivityStatus.forTesting(
        checkConnectivity: () async => const <ConnectivityResult>[
          ConnectivityResult.wifi,
        ],
        connectivityChanges: () => changes.stream,
      );

      status.start();
      await Future<void>.delayed(Duration.zero);
      status.dispose();
      await cancelled.future;

      expect(cancelled.isCompleted, isTrue);
    });
  });
}
