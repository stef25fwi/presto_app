import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/config/app_check_state.dart';

void main() {
  setUp(() {
    appCheckActivationAttempted = false;
    appCheckActivationSucceeded = false;
    appCheckActivationError = null;
    appCheckActivationStackTrace = null;
    appCheckLastTokenRefreshAt = null;
    appCheckLastTokenRefreshError = null;
  });

  test('known production hosts are classified as prod', () {
    for (final host in kAppCheckKnownProdHosts) {
      expect(appCheckWebHostClass(host), 'prod');
    }
  });

  test('local hosts are detected and classified', () {
    for (final host in <String>['localhost', '127.0.0.1', '0.0.0.0']) {
      expect(isLocalAppCheckWebHost(host), isTrue);
      expect(appCheckWebHostClass(host), 'local');
    }
    expect(isLocalAppCheckWebHost('localhost.localdomain'), isFalse);
  });

  test('preview hosts are detected from supported patterns', () {
    expect(isPreviewAppCheckWebHost('workspace.app.github.dev'), isTrue);
    expect(isPreviewAppCheckWebHost('workspace.github.dev'), isTrue);
    expect(isPreviewAppCheckWebHost('feature-preview.example.com'), isTrue);
    expect(isPreviewAppCheckWebHost('example.com'), isFalse);

    expect(appCheckWebHostClass('workspace.app.github.dev'), 'preview');
    expect(appCheckWebHostClass('feature-preview.example.com'), 'preview');
  });

  test('classification normalizes input and handles unknown hosts', () {
    expect(appCheckWebHostClass('  ILIPRESTO.FR  '), 'prod');
    expect(appCheckWebHostClass(''), 'unknown');
    expect(appCheckWebHostClass('   '), 'unknown');
    expect(appCheckWebHostClass('staging.ilipresto.fr'), 'custom');
  });

  test('activation state globals can represent success and failure', () {
    final error = StateError('activation failed');
    final stackTrace = StackTrace.current;
    final refreshAt = DateTime.utc(2026, 7, 15, 10, 30);

    appCheckActivationAttempted = true;
    appCheckActivationSucceeded = true;
    appCheckActivationError = error;
    appCheckActivationStackTrace = stackTrace;
    appCheckLastTokenRefreshAt = refreshAt;
    appCheckLastTokenRefreshError = error;

    expect(appCheckActivationAttempted, isTrue);
    expect(appCheckActivationSucceeded, isTrue);
    expect(appCheckActivationError, same(error));
    expect(appCheckActivationStackTrace, same(stackTrace));
    expect(appCheckLastTokenRefreshAt, refreshAt);
    expect(appCheckLastTokenRefreshError, same(error));
  });

  test('web provider configuration stays explicit', () {
    expect(kAppCheckWebRecaptchaProviderLabel, 'enterprise');
    expect(kAppCheckWebRecaptchaSiteKey, isA<String>());
  });

  test('non-web runtime returns empty host and hint', () {
    expect(currentAppCheckWebHost(), isEmpty);
    expect(appCheckWebHostHint(), isEmpty);
    expect(appCheckWebHostClass(), 'unknown');
  });
}
