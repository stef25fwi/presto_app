import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/app_route_parser.dart';

void main() {
  group('App route parser secondary coverage', () {
    test('parse l alias chat avec identifiant et brouillon décodés', () {
      final target = parseAppDeepLink(
        '/chat/conv%20legacy?draft=Bonjour%20depuis%20le%20chat',
      );

      expect(target, isNotNull);
      expect(target!.routeName, AppDeepLinkTarget.messagesRouteName);
      expect(target.conversationId, 'conv legacy');
      expect(target.initialDraftText, 'Bonjour depuis le chat');
      expect(target.preferMarketplace, isFalse);
    });

    test('parse le détail d une offre legacy', () {
      final target = parseAppDeepLink('/offers/offer%20legacy');

      expect(target, isNotNull);
      expect(target!.routeName, '/offers');
      expect(target.offerId, 'offer legacy');
      expect(target.preferMarketplace, isFalse);
    });

    test('parse les deux variantes de profil', () {
      final profile = parseAppDeepLink('/profile/user%201');
      final profil = parseAppDeepLink('/profil/user%202');

      expect(profile, isNotNull);
      expect(profile!.routeName, '/profile');
      expect(profile.userId, 'user 1');
      expect(profile.preferMarketplace, isFalse);

      expect(profil, isNotNull);
      expect(profil!.routeName, '/profile');
      expect(profil.userId, 'user 2');
      expect(profil.preferMarketplace, isFalse);
    });

    test('les constructeurs secondaires conservent leur contrat', () {
      const profile = AppDeepLinkTarget.profile('user-direct');
      const offer = AppDeepLinkTarget.offerDetail('offer-direct');
      const thread = AppDeepLinkTarget.messageThreadV2(
        'conversation-direct',
        initialDraftText: 'Brouillon direct',
      );

      expect(profile.routeName, '/profile');
      expect(profile.userId, 'user-direct');
      expect(offer.routeName, '/offers');
      expect(offer.offerId, 'offer-direct');
      expect(thread.routeName, AppDeepLinkTarget.messagesV2RouteName);
      expect(thread.conversationId, 'conversation-direct');
      expect(thread.initialDraftText, 'Brouillon direct');
    });
  });
}
