import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/app_route_parser.dart';

void main() {
  group('parseAppDeepLink', () {
    test('parse la liste des messages', () {
      final target = parseAppDeepLink('/messages');

      expect(target, isNotNull);
      expect(target!.routeName, '/messages');
      expect(target.conversationId, isNull);
    });

    test('parse la liste des messages 2', () {
      final target = parseAppDeepLink('/messages-2');

      expect(target, isNotNull);
      expect(target!.routeName, '/messages-2');
      expect(target.conversationId, isNull);
    });

    test('parse un thread de conversation en path', () {
      final target = parseAppDeepLink('/messages/conv_123');

      expect(target, isNotNull);
      expect(target!.routeName, '/messages');
      expect(target.conversationId, 'conv_123');
    });

    test('parse un thread de conversation en hash route', () {
      final target = parseAppDeepLink('#/messages/conv_hash');

      expect(target, isNotNull);
      expect(target!.routeName, '/messages');
      expect(target.conversationId, 'conv_hash');
    });

    test('parse un thread messages 2 en hash route', () {
      final target = parseAppDeepLink('#/messages-2/conv_hash_v2');

      expect(target, isNotNull);
      expect(target!.routeName, '/messages-2');
      expect(target.conversationId, 'conv_hash_v2');
    });

    test('parse un thread de conversation avec brouillon initial', () {
      final target = parseAppDeepLink(
        '/messages/conv_456?draft=Bonjour%20vendeur',
      );

      expect(target, isNotNull);
      expect(target!.routeName, '/messages');
      expect(target.conversationId, 'conv_456');
      expect(target.initialDraftText, 'Bonjour vendeur');
    });

    test('parse un thread de conversation messages 2 avec brouillon initial',
        () {
      final target = parseAppDeepLink(
        '/messages-2/conv_789?draft=Bonjour%20vendeur',
      );

      expect(target, isNotNull);
      expect(target!.routeName, '/messages-2');
      expect(target.conversationId, 'conv_789');
      expect(target.initialDraftText, 'Bonjour vendeur');
    });

    test('parse une annonce marketplace', () {
      final target = parseAppDeepLink('/listings/listing_123');

      expect(target, isNotNull);
      expect(target!.routeName, '/listings');
      expect(target.offerId, 'listing_123');
      expect(target.preferMarketplace, isTrue);
    });

    test('parse un App Link /app avec UTM', () {
      final target = parseAppDeepLink(
        'https://ilipresto.fr/app/listings/listing_utm'
        '?utm_source=newsletter&utm_medium=email&utm_campaign=launch',
      );

      expect(target, isNotNull);
      expect(target!.routeName, '/listings');
      expect(target.offerId, 'listing_utm');
      expect(target.preferMarketplace, isTrue);
    });

    test('parse un Universal Link vers une offre', () {
      final target = parseAppDeepLink(
        'https://ilipresto.fr/app/offers/offer_web'
        '?utm_source=instagram&utm_medium=social&utm_campaign=offre',
      );

      expect(target, isNotNull);
      expect(target!.routeName, '/offers');
      expect(target.offerId, 'offer_web');
    });

    test('parse le schéma applicatif vers un profil', () {
      final target = parseAppDeepLink(
        'ilipresto://profile/user_1'
        '?utm_source=push&utm_medium=notification&utm_campaign=profil',
      );

      expect(target, isNotNull);
      expect(target!.routeName, '/profile');
      expect(target.userId, 'user_1');
    });
  });

  group('buildMessagesRoute', () {
    test('construit la route simple messages', () {
      expect(buildMessagesRoute(), '/messages');
    });

    test('construit la route thread avec draft encode', () {
      expect(
        buildMessagesRoute(
          conversationId: 'conv_123',
          initialDraftText: 'Bonjour vendeur',
        ),
        '/messages/conv_123?draft=Bonjour+vendeur',
      );
    });

    test('construit la route simple messages 2', () {
      expect(buildMessagesV2Route(), '/messages-2');
    });

    test('construit la route thread messages 2 avec draft encode', () {
      expect(
        buildMessagesV2Route(
          conversationId: 'conv_123',
          initialDraftText: 'Bonjour vendeur',
        ),
        '/messages-2/conv_123?draft=Bonjour+vendeur',
      );
    });
  });
}
