import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/config/app_check_state.dart';
import 'package:presto_app/services/app_check_bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    appCheckActivationAttempted = false;
    appCheckActivationSucceeded = false;
    appCheckActivationError = null;
    appCheckActivationStackTrace = null;
    appCheckLastTokenRefreshAt = null;
    appCheckLastTokenRefreshError = null;
  });

  test('refuse un refresh tant que App Check n a pas ete active', () async {
    await expectLater(
      refreshAppCheckToken(reason: 'coverage-before-bootstrap'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('app_check_not_activated_for_token_refresh'),
        ),
      ),
    );

    expect(appCheckActivationAttempted, isFalse);
    expect(appCheckActivationSucceeded, isFalse);
    expect(appCheckLastTokenRefreshAt, isNull);
  });

  test('bootstrap capture proprement l indisponibilite du plugin App Check',
      () async {
    await bootstrapAppCheck();

    expect(appCheckActivationAttempted, isTrue);
    expect(appCheckActivationSucceeded, isFalse);
    expect(appCheckActivationError, isNotNull);
    expect(appCheckActivationStackTrace, isNotNull);
    expect(appCheckLastTokenRefreshAt, isNull);
  });

  test('un second refresh apres echec reste protege et restitue l erreur',
      () async {
    await bootstrapAppCheck();

    await expectLater(
      refreshAppCheckToken(
        reason: 'coverage-after-bootstrap',
        forceRefresh: true,
      ),
      throwsA(anything),
    );

    expect(appCheckActivationAttempted, isTrue);
    expect(appCheckActivationSucceeded, isFalse);
    expect(appCheckLastTokenRefreshAt, isNull);
  });

  test('de-duplique les refresh concurrents et libere le verrou apres echec',
      () async {
    appCheckActivationAttempted = true;

    final first = refreshAppCheckToken(
      reason: 'coverage-concurrent',
      forceRefresh: true,
    );
    final second = refreshAppCheckToken(
      reason: 'coverage-concurrent-duplicate',
    );

    expect(identical(first, second), isTrue);
    await expectLater(first, throwsA(anything));
    expect(appCheckActivationSucceeded, isFalse);
    expect(appCheckActivationError, isNotNull);
    expect(appCheckLastTokenRefreshError, isNotNull);

    final third = refreshAppCheckToken(reason: 'coverage-after-release');
    expect(identical(first, third), isFalse);
    await expectLater(third, throwsA(anything));
  });

  test('bootstrap remet a zero un etat App Check obsolet avant tentative',
      () async {
    appCheckActivationAttempted = true;
    appCheckActivationSucceeded = true;
    appCheckActivationError = StateError('stale-error');
    appCheckActivationStackTrace = StackTrace.current;
    appCheckLastTokenRefreshAt = DateTime(2020, 1, 1);
    appCheckLastTokenRefreshError = StateError('stale-refresh-error');

    await bootstrapAppCheck();

    expect(appCheckActivationAttempted, isTrue);
    expect(appCheckActivationSucceeded, isFalse);
    expect(appCheckActivationError, isNotNull);
    expect(appCheckActivationError.toString(), isNot(contains('stale-error')));
    expect(appCheckActivationStackTrace, isNotNull);
    expect(appCheckLastTokenRefreshAt, isNull);
  });
}
