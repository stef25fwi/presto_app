import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_checkout_policy.dart';

void main() {
  const policy = SubscriptionCheckoutPolicy();
  const nowMs = 1_800_000_000_000;

  test('SubscriptionCheckoutException expose son message', () {
    const exception = SubscriptionCheckoutException('paiement indisponible');

    expect(exception.message, 'paiement indisponible');
    expect(exception.toString(), 'paiement indisponible');
  });

  group('extractCheckoutUrl', () {
    test('accepte les alias directs', () {
      for (final key in <String>[
        'url',
        'checkoutUrl',
        'checkout_url',
        'sessionUrl',
        'session_url',
      ]) {
        expect(
          policy.extractCheckoutUrl(<String, dynamic>{
            key: 'https://checkout.stripe.com/c/pay/cs_test',
          }),
          'https://checkout.stripe.com/c/pay/cs_test',
          reason: key,
        );
      }
    });

    test('accepte une URL imbriquée dans session', () {
      expect(
        policy.extractCheckoutUrl(<String, dynamic>{
          'session': <String, dynamic>{
            'url': 'https://checkout.stripe.com/c/pay/cs_nested',
          },
        }),
        'https://checkout.stripe.com/c/pay/cs_nested',
      );
    });

    test('refuse une réponse sans URL', () {
      expect(
        () => policy.extractCheckoutUrl(const <String, dynamic>{}),
        throwsA(isA<SubscriptionCheckoutException>()),
      );
    });
  });

  group('parseTrustedStripeUri', () {
    test('accepte Stripe et ses sous-domaines en HTTPS', () {
      for (final value in <String>[
        'https://checkout.stripe.com/c/pay/cs_test',
        'https://billing.stripe.com/p/session/test',
        'https://stripe.com/',
        'https://custom.checkout.stripe.com/path',
      ]) {
        expect(policy.parseTrustedStripeUri(value).scheme, 'https');
      }
    });

    test('refuse HTTP, hôtes lookalike et userinfo trompeur', () {
      for (final value in <String>[
        'http://checkout.stripe.com/c/pay/test',
        'https://stripe.com.evil.example/pay',
        'https://evilstripe.com/pay',
        'https://stripe.com@evil.example/pay',
        'javascript:alert(1)',
        'not-a-url',
      ]) {
        expect(
          () => policy.parseTrustedStripeUri(value),
          throwsA(isA<SubscriptionCheckoutException>()),
          reason: value,
        );
      }
    });
  });

  group('expiration', () {
    test('convertit les secondes Unix en millisecondes', () {
      expect(
        policy.parseExpiresAtMs(
          const <String, dynamic>{'expires_at': 1_900_000_000},
          nowMs: nowMs,
        ),
        1_900_000_000_000,
      );
    });

    test('conserve les millisecondes Unix', () {
      expect(
        policy.parseExpiresAtMs(
          const <String, dynamic>{'expiresAtMs': 1_900_000_000_000},
          nowMs: nowMs,
        ),
        1_900_000_000_000,
      );
    });

    test('utilise le TTL par défaut si la réponse est invalide', () {
      expect(
        policy.parseExpiresAtMs(
          const <String, dynamic>{'expiresAt': 'invalide'},
          nowMs: nowMs,
        ),
        nowMs + const Duration(minutes: 20).inMilliseconds,
      );
    });

    test('invalide le cache dans la marge de sécurité', () {
      final almostExpired = StripeCheckoutDestination(
        url: 'https://checkout.stripe.com/c/pay/test',
        expiresAtMs: nowMs + const Duration(seconds: 20).inMilliseconds,
      );
      final fresh = StripeCheckoutDestination(
        url: 'https://checkout.stripe.com/c/pay/test',
        expiresAtMs: nowMs + const Duration(minutes: 5).inMilliseconds,
      );

      expect(policy.isDestinationFresh(almostExpired, nowMs: nowMs), isFalse);
      expect(policy.isDestinationFresh(fresh, nowMs: nowMs), isTrue);
    });
  });

  test('destinationFromResponse valide URL et expiration ensemble', () {
    final destination = policy.destinationFromResponse(
      const <String, dynamic>{
        'checkout_url': 'https://checkout.stripe.com/c/pay/cs_test',
        'expires_at': 1_900_000_000,
      },
      nowMs: nowMs,
    );

    expect(destination.url, 'https://checkout.stripe.com/c/pay/cs_test');
    expect(destination.expiresAtMs, 1_900_000_000_000);
  });

  group('messages Firebase', () {
    test('normalise les erreurs connues', () {
      expect(
        policy.messageForFirebaseFailure(
          code: 'unauthenticated',
          fallback: 'fallback',
        ),
        contains('Reconnectez-vous'),
      );
      expect(
        policy.messageForFirebaseFailure(
          code: 'unavailable',
          fallback: 'fallback',
        ),
        contains('trop de temps'),
      );
      expect(
        policy.messageForFirebaseFailure(
          code: 'resource-exhausted',
          fallback: 'fallback',
        ),
        contains('Trop de tentatives'),
      );
    });

    test('préserve un message backend utile ou utilise le fallback', () {
      expect(
        policy.messageForFirebaseFailure(
          code: 'failed-precondition',
          message: 'Plan indisponible dans ce territoire.',
          fallback: 'fallback',
        ),
        'Plan indisponible dans ce territoire.',
      );
      expect(
        policy.messageForFirebaseFailure(
          code: '  INVALID-ARGUMENT  ',
          message: 'Période annuelle inconnue.',
          fallback: 'fallback',
        ),
        'Période annuelle inconnue.',
      );
      expect(
        policy.messageForFirebaseFailure(
          code: 'internal',
          fallback: 'fallback',
        ),
        'fallback',
      );
    });

    test('utilise les messages par défaut quand le backend est vide', () {
      expect(
        policy.messageForFirebaseFailure(
          code: 'failed-precondition',
          message: '   ',
          fallback: 'fallback',
        ),
        'Ce plan n’est pas disponible pour le moment.',
      );
      expect(
        policy.messageForFirebaseFailure(
          code: 'invalid-argument',
          message: '',
          fallback: 'fallback',
        ),
        'Le plan ou la période de facturation est invalide.',
      );
    });
  });
}
