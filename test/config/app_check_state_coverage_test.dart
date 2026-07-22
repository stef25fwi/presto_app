import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/config/app_check_state.dart';

void main() {
  test('classe tous les types d hôtes App Check', () {
    expect(appCheckWebHostClass(''), 'unknown');
    expect(appCheckWebHostClass(' ILIPRESTO.FR '), 'prod');
    expect(appCheckWebHostClass('www.ilipresto.fr'), 'prod');
    expect(appCheckWebHostClass('localhost'), 'local');
    expect(appCheckWebHostClass('127.0.0.1'), 'local');
    expect(appCheckWebHostClass('0.0.0.0'), 'local');
    expect(appCheckWebHostClass('abc.app.github.dev'), 'preview');
    expect(appCheckWebHostClass('abc.github.dev'), 'preview');
    expect(appCheckWebHostClass('my-preview-host.example'), 'preview');
    expect(appCheckWebHostClass('custom.example'), 'custom');
  });

  test('détecte séparément les hôtes locaux et preview', () {
    expect(isLocalAppCheckWebHost('localhost'), isTrue);
    expect(isLocalAppCheckWebHost('example.com'), isFalse);
    expect(isPreviewAppCheckWebHost('space.app.github.dev'), isTrue);
    expect(isPreviewAppCheckWebHost('space.github.dev'), isTrue);
    expect(isPreviewAppCheckWebHost('preview.example.com'), isTrue);
    expect(isPreviewAppCheckWebHost('ilipresto.fr'), isFalse);
  });

  test('expose la configuration App Check attendue', () {
    expect(kAppCheckKnownProdHosts, contains('ilipresto.fr'));
    expect(kAppCheckKnownProdHosts, contains('presto-app-74abe.web.app'));
    expect(kAppCheckWebRecaptchaProviderLabel, 'enterprise');

    appCheckActivationAttempted = true;
    appCheckActivationSucceeded = false;
    appCheckActivationError = StateError('activation');
    appCheckActivationStackTrace = StackTrace.current;
    appCheckLastTokenRefreshAt = DateTime.utc(2026, 7, 22);
    appCheckLastTokenRefreshError = StateError('refresh');

    expect(appCheckActivationAttempted, isTrue);
    expect(appCheckActivationSucceeded, isFalse);
    expect(appCheckActivationError, isA<StateError>());
    expect(appCheckActivationStackTrace, isNotNull);
    expect(appCheckLastTokenRefreshAt, DateTime.utc(2026, 7, 22));
    expect(appCheckLastTokenRefreshError, isA<StateError>());
  });
}
