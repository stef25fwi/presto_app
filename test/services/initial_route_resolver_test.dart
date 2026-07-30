import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/initial_route_resolver.dart';

void main() {
  group('normalizeInitialRoutePath', () {
    test('normalizes empty and root locations', () {
      expect(normalizeInitialRoutePath(null), '/');
      expect(normalizeInitialRoutePath(''), '/');
      expect(normalizeInitialRoutePath('/'), '/');
    });

    test('removes a trailing slash and preserves the path', () {
      expect(normalizeInitialRoutePath('/account/'), '/account');
      expect(
        normalizeInitialRoutePath('https://ilipresto.fr/messages/thread-1/'),
        '/messages/thread-1',
      );
    });
  });

  group('resolveInitialRoute', () {
    test('routes the root directly to home', () {
      final result = resolveInitialRoute('/');

      expect(result.kind, InitialRouteKind.home);
      expect(result.normalizedPath, '/');
      expect(result.deepLinkTarget, isNull);
    });

    test('routes account and publish without a splash redirect', () {
      expect(resolveInitialRoute('/account').kind, InitialRouteKind.account);
      expect(resolveInitialRoute('/publish').kind, InitialRouteKind.publish);
    });

    test('preserves offer deep links', () {
      final result = resolveInitialRoute('/offers/offer-42');

      expect(result.kind, InitialRouteKind.offer);
      expect(result.deepLinkTarget?.offerId, 'offer-42');
      expect(result.deepLinkTarget?.preferMarketplace, isFalse);
    });

    test('preserves marketplace listing deep links', () {
      final result = resolveInitialRoute('/listings/listing-42');

      expect(result.kind, InitialRouteKind.offer);
      expect(result.deepLinkTarget?.offerId, 'listing-42');
      expect(result.deepLinkTarget?.preferMarketplace, isTrue);
    });

    test('preserves profile deep links', () {
      final result = resolveInitialRoute('/profil/user-7');

      expect(result.kind, InitialRouteKind.profile);
      expect(result.deepLinkTarget?.userId, 'user-7');
    });

    test('preserves message thread and draft parameters', () {
      final result = resolveInitialRoute('/messages/thread-9?draft=Bonjour');

      expect(result.kind, InitialRouteKind.messages);
      expect(result.deepLinkTarget?.conversationId, 'thread-9');
      expect(result.deepLinkTarget?.initialDraftText, 'Bonjour');
    });

    test('falls back safely to home for an unknown route', () {
      final result = resolveInitialRoute('/route-inconnue');

      expect(result.kind, InitialRouteKind.home);
      expect(result.normalizedPath, '/route-inconnue');
      expect(result.deepLinkTarget, isNull);
    });
  });
}
