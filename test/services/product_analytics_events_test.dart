import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/product_analytics_events.dart';

void main() {
  test('construit un événement de conversion sans donnée personnelle', () {
    final event = ProductAnalyticsEvent.conversionCheckoutCompleted(
      planId: 'ilipresto_plus',
      amount: 1.99,
      currency: 'EUR',
    );

    expect(event.name, 'conversion_checkout_completed');
    expect(event.stage, ProductFunnelStage.conversion);
    expect(event.parameters, <String, Object?>{
      'plan_id': 'ilipresto_plus',
      'amount': 1.99,
      'currency': 'EUR',
      'funnel_stage': 'conversion',
    });
  });

  test('refuse les noms hors snake_case ou supérieurs à 40 caractères', () {
    expect(
      () => ProductAnalyticsEvent(
        name: 'Checkout Completed',
        stage: ProductFunnelStage.conversion,
      ),
      throwsArgumentError,
    );
    expect(
      () => ProductAnalyticsEvent(
        name: 'a${List<String>.filled(40, 'b').join()}',
        stage: ProductFunnelStage.engagement,
      ),
      throwsArgumentError,
    );
  });

  test('refuse les clés personnelles ou secrètes', () {
    for (final key in <String>[
      'email',
      'phone_number',
      'full_name',
      'address',
      'message',
      'auth_token',
      'user_id',
    ]) {
      expect(
        () => ProductAnalyticsEvent(
          name: 'engagement_tested',
          stage: ProductFunnelStage.engagement,
          parameters: <String, Object?>{key: 'interdit'},
        ),
        throwsArgumentError,
        reason: key,
      );
    }
  });

  test('refuse les valeurs structurées non supportées par Analytics', () {
    expect(
      () => ProductAnalyticsEvent(
        name: 'engagement_tested',
        stage: ProductFunnelStage.engagement,
        parameters: <String, Object?>{
          'categories': <String>['maison', 'jardin'],
        },
      ),
      throwsArgumentError,
    );
  });

  test('les paramètres sont immuables', () {
    final source = <String, Object?>{'source': 'organic'};
    final event = ProductAnalyticsEvent(
      name: 'acquisition_tested',
      stage: ProductFunnelStage.acquisition,
      parameters: source,
    );
    source['source'] = 'paid';

    expect(event.parameters['source'], 'organic');
    expect(
      () => event.parameters['source'] = 'other',
      throwsUnsupportedError,
    );
  });
}
