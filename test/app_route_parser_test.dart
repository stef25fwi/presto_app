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

    test('parse une annonce marketplace', () {
      final target = parseAppDeepLink('/listings/listing_123');

      expect(target, isNotNull);
      expect(target!.routeName, '/listings');
      expect(target.offerId, 'listing_123');
      expect(target.preferMarketplace, isTrue);
    });
  });
}