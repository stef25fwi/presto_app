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

    test('infère Facebook paid social depuis fbclid', () {
      final attribution = parseCampaignAttribution(
        'https://ilipresto.fr/app/offers/offer_1?fbclid=opaque',
      );

      expect(attribution, isNotNull);
      expect(attribution!.source, 'facebook');
      expect(attribution.medium, 'paid_social');
      expect(attribution.campaign, '(not set)');
      expect(attribution.destination, 'offer');
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

    test('ignore une URL sans paramètre de campagne', () {
      expect(
        parseCampaignAttribution('https://ilipresto.fr/app/offers/offer_1'),
        isNull,
      );
    });

    test('sérialise et restaure une attribution', () {
      final original = parseCampaignAttribution(
        'https://ilipresto.fr/app/profile/user_1'
        '?utm_source=instagram&utm_medium=social&utm_campaign=profil',
        capturedAt: DateTime.utc(2026, 8, 6, 10),
      )!;

      final restored = CampaignAttribution.fromJson(original.toJson());
      expect(restored, isNotNull);
      expect(restored!.fingerprint, original.fingerprint);
      expect(restored.destination, 'profile');
    });
  });

  test('buildCampaignDeepLink produit le format canonique /app', () {
    final link = buildCampaignDeepLink(
      path: '/offers/abc',
      source: 'newsletter',
      medium: 'email',
      campaign: 'lancement',
      campaignId: 'lot17',
    );

    expect(link.scheme, 'https');
    expect(link.host, 'ilipresto.fr');
    expect(link.path, '/app/offers/abc');
    expect(link.queryParameters['utm_source'], 'newsletter');
    expect(link.queryParameters['utm_id'], 'lot17');
  });
}
