import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/campaign_attribution_service.dart';

void main() {
  group('parseCampaignAttribution', () {
    test('parse une campagne complète sur un App Link marketplace', () {
      final attribution = parseCampaignAttribution(
        'https://ilipresto.fr/app/listings/listing_42'
        '?utm_source=newsletter&utm_medium=email&utm_campaign=launch'
        '&utm_id=c-17&utm_term=plomberie&utm_content=cta&gclid=secret',
        capturedAt: DateTime.utc(2026, 8, 6),
      );

      expect(attribution, isNotNull);
      expect(attribution!.source, 'newsletter');
      expect(attribution.medium, 'email');
      expect(attribution.campaign, 'launch');
      expect(attribution.campaignId, 'c-17');
      expect(attribution.term, 'plomberie');
      expect(attribution.content, 'cta');
      expect(attribution.clickIdType, 'gclid');
      expect(attribution.landingRoute, '/listings/:id');
      expect(attribution.destination, 'listing');
      expect(attribution.analyticsParameters(), isNot(contains('gclid')));
      expect(attribution.analyticsParameters()['click_id_type'], 'gclid');
    });

    test('infère les sources et médias depuis chaque click id supporté', () {
      const cases = <String, (String, String)> {
        'gclid': ('google', 'cpc'),
        'gbraid': ('google', 'cpc'),
        'wbraid': ('google', 'cpc'),
        'dclid': ('google', 'display'),
        'fbclid': ('facebook', 'paid_social'),
        'ttclid': ('tiktok', 'paid_social'),
        'msclkid': ('bing', 'cpc'),
      };

      for (final entry in cases.entries) {
        final attribution = parseCampaignAttribution(
          'https://ilipresto.fr/app/offers/offer_1?${entry.key}=opaque',
          capturedAt: DateTime.utc(2026, 8, 6),
        );
        expect(attribution, isNotNull, reason: entry.key);
        expect(attribution!.source, entry.value.$1, reason: entry.key);
        expect(attribution.medium, entry.value.$2, reason: entry.key);
        expect(attribution.clickIdType, entry.key, reason: entry.key);
      }
    });

    test('parse le schéma applicatif', () {
      final attribution = parseCampaignAttribution(
        'ilipresto://offers/offer_1'
        '?utm_source=push&utm_medium=notification&utm_campaign=reactivation',
      );

      expect(attribution, isNotNull);
      expect(attribution!.landingRoute, '/offers/:id');
      expect(attribution.destination, 'offer');
      expect(attribution.source, 'push');
    });

    test('parse une route portée par le fragment hash', () {
      final attribution = parseCampaignAttribution(
        'https://ilipresto.fr/#/messages/thread-42'
        '?utm_source=push&utm_medium=notification&utm_campaign=reply',
        capturedAt: DateTime.utc(2026, 8, 6),
      );

      expect(attribution, isNotNull);
      expect(attribution!.landingRoute, '/messages/:id');
      expect(attribution.destination, 'messages');
    });

    test('ignore une URL vide, invalide ou sans paramètre de campagne', () {
      expect(parseCampaignAttribution(null), isNull);
      expect(parseCampaignAttribution('   '), isNull);
      expect(
        parseCampaignAttribution('https://ilipresto.fr/app/offers/offer_1'),
        isNull,
      );
    });

    test('nettoie et borne les valeurs de campagne', () {
      final longSource = '${'x' * 120}\n source';
      final attribution = parseCampaignAttribution(
        'https://ilipresto.fr/app/publish'
        '?utm_source=${Uri.encodeQueryComponent(longSource)}'
        '&utm_medium=%20social%20%20paid%20'
        '&utm_campaign=%00launch',
        capturedAt: DateTime.utc(2026, 8, 6),
      );

      expect(attribution, isNotNull);
      expect(attribution!.source.length, 100);
      expect(attribution.medium, 'social paid');
      expect(attribution.campaign, 'launch');
      expect(attribution.destination, 'publish');
    });
  });

  group('CampaignAttribution', () {
    test('sérialise, restaure et préfixe les paramètres analytics', () {
      final original = parseCampaignAttribution(
        'https://ilipresto.fr/app/profile/user_1'
        '?utm_source=instagram&utm_medium=social&utm_campaign=profil'
        '&utm_id=id-1&utm_term=service&utm_content=hero&fbclid=opaque',
        capturedAt: DateTime.utc(2026, 8, 6, 10),
      )!;

      final restored = CampaignAttribution.fromJson(original.toJson());
      expect(restored, isNotNull);
      expect(restored!.fingerprint, original.fingerprint);
      expect(restored.destination, 'profile');
      expect(
        restored.analyticsParameters(prefix: 'first'),
        containsPair('first_source', 'instagram'),
      );
      expect(
        restored.analyticsParameters(prefix: 'first'),
        containsPair('first_click_id_type', 'fbclid'),
      );
    });

    test('fromJson refuse les structures invalides ou incomplètes', () {
      expect(CampaignAttribution.fromJson(null), isNull);
      expect(CampaignAttribution.fromJson(<String, Object>{}), isNull);
      expect(
        CampaignAttribution.fromJson(<String, Object>{
          'source': 'newsletter',
          'medium': 'email',
          'campaign': 'launch',
          'landingRoute': '/',
          'destination': 'home',
          'capturedAt': 'not-a-date',
        }),
        isNull,
      );
    });

    test('isExpired applique la rétention de 90 jours', () {
      final fresh = CampaignAttribution(
        source: 'test',
        medium: 'test',
        campaign: 'fresh',
        landingRoute: '/',
        destination: 'home',
        capturedAt: DateTime.now().toUtc().subtract(const Duration(days: 89)),
      );
      final expired = CampaignAttribution(
        source: 'test',
        medium: 'test',
        campaign: 'expired',
        landingRoute: '/',
        destination: 'home',
        capturedAt: DateTime.now().toUtc().subtract(const Duration(days: 91)),
      );

      expect(fresh.isExpired, isFalse);
      expect(expired.isExpired, isTrue);
    });
  });

  group('campaign routing helpers', () {
    test('effectiveCampaignUri normalise app links, schéma et fragments', () {
      expect(
        effectiveCampaignUri('https://ilipresto.fr/app/offers/abc?utm_source=x')!
            .path,
        '/offers/abc',
      );
      expect(
        effectiveCampaignUri('ilipresto://profile/user-7?utm_source=x')!.path,
        '/profile/user-7',
      );
      expect(
        effectiveCampaignUri('https://ilipresto.fr/#/account?utm_source=x')!
            .path,
        '/account',
      );
      expect(effectiveCampaignUri(''), isNull);
    });

    test('normalizedCampaignRoute remplace les ids connus', () {
      expect(normalizedCampaignRoute(Uri(path: '/')), '/');
      expect(normalizedCampaignRoute(Uri(path: '/offers/42')), '/offers/:id');
      expect(
        normalizedCampaignRoute(Uri(path: '/listings/42')),
        '/listings/:id',
      );
      expect(normalizedCampaignRoute(Uri(path: '/profil/42')), '/profil/:id');
      expect(normalizedCampaignRoute(Uri(path: '/chat/42')), '/chat/:id');
      expect(normalizedCampaignRoute(Uri(path: '/publish')), '/publish');
    });

    test('campaignDestinationForRoute classe toutes les destinations', () {
      expect(campaignDestinationForRoute('/'), 'home');
      expect(campaignDestinationForRoute('/offers/:id'), 'offer');
      expect(campaignDestinationForRoute('/listings/:id'), 'listing');
      expect(campaignDestinationForRoute('/profile/:id'), 'profile');
      expect(campaignDestinationForRoute('/profil/:id'), 'profile');
      expect(campaignDestinationForRoute('/messages/:id'), 'messages');
      expect(campaignDestinationForRoute('/chat/:id'), 'messages');
      expect(campaignDestinationForRoute('/publish'), 'publish');
      expect(campaignDestinationForRoute('/account'), 'account');
      expect(campaignDestinationForRoute('/unknown'), 'other');
    });
  });

  group('buildCampaignDeepLink', () {
    test('produit le format canonique /app avec les champs optionnels', () {
      final link = buildCampaignDeepLink(
        path: '/offers/abc',
        source: 'newsletter',
        medium: 'email',
        campaign: 'lancement',
        campaignId: 'lot17',
        term: 'plomberie',
        content: 'cta',
      );

      expect(link.scheme, 'https');
      expect(link.host, 'ilipresto.fr');
      expect(link.path, '/app/offers/abc');
      expect(link.queryParameters['utm_source'], 'newsletter');
      expect(link.queryParameters['utm_id'], 'lot17');
      expect(link.queryParameters['utm_term'], 'plomberie');
      expect(link.queryParameters['utm_content'], 'cta');
    });

    test('normalise les chemins sans slash, racine et déjà /app', () {
      expect(
        buildCampaignDeepLink(
          path: 'account',
          source: 'x',
          medium: 'y',
          campaign: 'z',
        ).path,
        '/app/account',
      );
      expect(
        buildCampaignDeepLink(
          path: '/',
          source: 'x',
          medium: 'y',
          campaign: 'z',
        ).path,
        '/app',
      );
      expect(
        buildCampaignDeepLink(
          path: '/app/publish',
          source: 'x',
          medium: 'y',
          campaign: 'z',
        ).path,
        '/app/publish',
      );
    });
  });
}