import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/campaign_attribution_service.dart';
import 'package:presto_app/services/cookie_consent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    CookieConsentService.instance.resetForTesting();
    CampaignAttributionService.instance.resetForTesting();
  });

  test('gère pending, consentement, persistance, doublon, expiration et refus',
      () async {
    final service = CampaignAttributionService.instance;
    final consent = CookieConsentService.instance;
    const firstUrl =
        'https://ilipresto.fr/app/offers/offer-42?utm_source=newsletter'
        '&utm_medium=email&utm_campaign=launch&utm_id=campaign-42';

    service.observeRoute(firstUrl);

    expect(service.hasObservedAttribution, isTrue);
    expect(service.firstTouch, isNull);
    expect(service.lastTouch?.campaign, 'launch');
    expect(service.parametersForProductEvent(), isEmpty);

    await consent.acceptAll();
    await service.ensureReady();
    await pumpEventQueue(times: 5);

    expect(service.firstTouch?.campaign, 'launch');
    expect(service.lastTouch?.campaign, 'launch');
    expect(
      service.parametersForProductEvent(),
      containsPair('first_source', 'newsletter'),
    );
    expect(
      service.parametersForProductEvent(),
      containsPair('last_campaign_id', 'campaign-42'),
    );

    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('campaign_attribution_first_v1'), isNotNull);
    expect(prefs.getString('campaign_attribution_last_v1'), isNotNull);
    final firstFingerprint =
        prefs.getString('campaign_attribution_last_logged_v1');
    expect(firstFingerprint, isNotEmpty);

    service.resetForTesting();
    service.observeRoute(firstUrl);
    await service.ensureReady();
    await pumpEventQueue(times: 5);
    prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('campaign_attribution_last_logged_v1'),
      firstFingerprint,
    );

    final expired = CampaignAttribution(
      source: 'old-source',
      medium: 'email',
      campaign: 'old-campaign',
      landingRoute: '/offers/:id',
      destination: 'offer',
      capturedAt:
          DateTime.now().toUtc().subtract(const Duration(days: 91)),
    );
    await prefs.setString(
      'campaign_attribution_first_v1',
      jsonEncode(expired.toJson()),
    );
    await prefs.setString(
      'campaign_attribution_last_v1',
      jsonEncode(expired.toJson()),
    );
    service.resetForTesting();
    await service.ensureReady();

    expect(service.firstTouch, isNull);
    expect(service.lastTouch, isNull);
    expect(prefs.getString('campaign_attribution_first_v1'), isNull);
    expect(prefs.getString('campaign_attribution_last_v1'), isNull);

    await prefs.setString('campaign_attribution_first_v1', '{invalid-json');
    await prefs.setString('campaign_attribution_last_v1', '{invalid-json');
    service.resetForTesting();
    await service.ensureReady();
    expect(service.firstTouch, isNull);
    expect(service.lastTouch, isNull);

    service.observeRoute(
      'https://ilipresto.fr/app/profile/user-7?utm_source=push'
      '&utm_medium=notification&utm_campaign=reactivation',
    );
    await service.ensureReady();
    await pumpEventQueue(times: 5);
    expect(service.lastTouch?.campaign, 'reactivation');
    expect(service.lastTouch?.destination, 'profile');

    await consent.refuseAll();
    await pumpEventQueue(times: 10);

    prefs = await SharedPreferences.getInstance();
    expect(service.hasObservedAttribution, isFalse);
    expect(service.firstTouch, isNull);
    expect(service.lastTouch, isNull);
    expect(service.parametersForProductEvent(), isEmpty);
    expect(prefs.getString('campaign_attribution_first_v1'), isNull);
    expect(prefs.getString('campaign_attribution_last_v1'), isNull);
    expect(prefs.getString('campaign_attribution_last_logged_v1'), isNull);
  });

  test('parse une campagne minimale avec les valeurs directes par défaut', () {
    final attribution = parseCampaignAttribution(
      'https://ilipresto.fr/app/account?utm_campaign=organic-launch',
      capturedAt: DateTime.utc(2026, 8, 7),
    );

    expect(attribution, isNotNull);
    expect(attribution!.source, 'direct');
    expect(attribution.medium, 'campaign');
    expect(attribution.campaign, 'organic-launch');
    expect(attribution.clickIdType, isNull);
    expect(attribution.destination, 'account');
  });

  test('fromJson normalise les clés non String et les champs optionnels vides',
      () {
    final restored = CampaignAttribution.fromJson(<Object?, Object?>{
      'source': ' newsletter ',
      'medium': ' email ',
      'campaign': ' launch ',
      'campaignId': '   ',
      'term': '',
      'content': null,
      'clickIdType': '',
      'landingRoute': ' / ',
      'destination': ' home ',
      'capturedAt': '2026-08-07T12:00:00Z',
      42: 'ignored',
    });

    expect(restored, isNotNull);
    expect(restored!.source, 'newsletter');
    expect(restored.medium, 'email');
    expect(restored.campaign, 'launch');
    expect(restored.campaignId, isNull);
    expect(restored.term, isNull);
    expect(restored.content, isNull);
    expect(restored.clickIdType, isNull);
    expect(restored.landingRoute, '/');
    expect(restored.destination, 'home');
  });
}
