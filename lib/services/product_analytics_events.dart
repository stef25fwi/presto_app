import 'package:flutter/foundation.dart';

/// Étapes du tunnel commercial iliprestō.
enum ProductFunnelStage {
  acquisition,
  registration,
  activation,
  engagement,
  conversion,
  retention,
  revenue,
}

/// Événement produit typé, conçu pour exclure les données personnelles.
@immutable
class ProductAnalyticsEvent {
  ProductAnalyticsEvent({
    required this.name,
    required this.stage,
    Map<String, Object?> parameters = const <String, Object?>{},
  }) : parameters = Map<String, Object?>.unmodifiable(
          <String, Object?>{
            ..._validateParameters(name, parameters),
            'funnel_stage': stage.name,
          },
        );

  final String name;
  final ProductFunnelStage stage;
  final Map<String, Object?> parameters;

  static final RegExp _validName = RegExp(r'^[a-z][a-z0-9_]{0,39}$');
  static final RegExp _validKey = RegExp(r'^[a-z][a-z0-9_]{0,39}$');
  static const Set<String> _forbiddenKeys = <String>{
    'email',
    'email_address',
    'phone',
    'phone_number',
    'first_name',
    'last_name',
    'full_name',
    'address',
    'postal_address',
    'message',
    'description',
    'free_text',
    'auth_token',
    'access_token',
    'id_token',
    'user_id',
    'uid',
  };

  static Map<String, Object?> _validateParameters(
    String name,
    Map<String, Object?> parameters,
  ) {
    if (!_validName.hasMatch(name)) {
      throw ArgumentError.value(
        name,
        'name',
        'Le nom doit utiliser snake_case et contenir 1 à 40 caractères.',
      );
    }

    final validated = <String, Object?>{};
    for (final entry in parameters.entries) {
      final key = entry.key.trim().toLowerCase();
      if (!_validKey.hasMatch(key)) {
        throw ArgumentError.value(entry.key, 'parameters', 'Clé invalide.');
      }
      if (_forbiddenKeys.contains(key)) {
        throw ArgumentError.value(
          entry.key,
          'parameters',
          'Les données personnelles et secrets sont interdits.',
        );
      }
      final value = entry.value;
      if (value == null || value is String || value is num || value is bool) {
        validated[key] = value;
        continue;
      }
      throw ArgumentError.value(
        value,
        'parameters[$key]',
        'Seuls String, num, bool et null sont autorisés.',
      );
    }
    return validated;
  }

  factory ProductAnalyticsEvent.acquisitionLandingViewed({
    required String source,
    required String territory,
  }) {
    return ProductAnalyticsEvent(
      name: 'acquisition_landing_viewed',
      stage: ProductFunnelStage.acquisition,
      parameters: <String, Object?>{
        'source': source,
        'territory': territory,
      },
    );
  }

  factory ProductAnalyticsEvent.registrationCompleted({
    required String method,
    required String territory,
  }) {
    return ProductAnalyticsEvent(
      name: 'registration_completed',
      stage: ProductFunnelStage.registration,
      parameters: <String, Object?>{
        'method': method,
        'territory': territory,
      },
    );
  }

  factory ProductAnalyticsEvent.activationFirstValue({
    required String valueType,
    required int secondsSinceRegistration,
  }) {
    return ProductAnalyticsEvent(
      name: 'activation_first_value',
      stage: ProductFunnelStage.activation,
      parameters: <String, Object?>{
        'value_type': valueType,
        'seconds_since_registration': secondsSinceRegistration,
      },
    );
  }

  factory ProductAnalyticsEvent.engagementListingContacted({
    required String categoryId,
    required String territory,
    required String channel,
  }) {
    return ProductAnalyticsEvent(
      name: 'engagement_listing_contacted',
      stage: ProductFunnelStage.engagement,
      parameters: <String, Object?>{
        'category_id': categoryId,
        'territory': territory,
        'channel': channel,
      },
    );
  }

  factory ProductAnalyticsEvent.engagementFavoriteChanged({
    required String listingId,
    required bool added,
  }) {
    return ProductAnalyticsEvent(
      name: 'engagement_favorite_changed',
      stage: ProductFunnelStage.engagement,
      parameters: <String, Object?>{
        'listing_id': listingId,
        'added': added,
      },
    );
  }

  factory ProductAnalyticsEvent.conversionPlanSelected({
    required String planId,
    required String billingPeriod,
  }) {
    return ProductAnalyticsEvent(
      name: 'conversion_plan_selected',
      stage: ProductFunnelStage.conversion,
      parameters: <String, Object?>{
        'plan_id': planId,
        'billing_period': billingPeriod,
      },
    );
  }

  factory ProductAnalyticsEvent.conversionCheckoutCompleted({
    required String planId,
    required num amount,
    required String currency,
  }) {
    return ProductAnalyticsEvent(
      name: 'conversion_checkout_completed',
      stage: ProductFunnelStage.conversion,
      parameters: <String, Object?>{
        'plan_id': planId,
        'amount': amount,
        'currency': currency,
      },
    );
  }

  factory ProductAnalyticsEvent.retentionReturned({
    required int daysSinceRegistration,
    required String trigger,
  }) {
    return ProductAnalyticsEvent(
      name: 'retention_returned',
      stage: ProductFunnelStage.retention,
      parameters: <String, Object?>{
        'days_since_registration': daysSinceRegistration,
        'trigger': trigger,
      },
    );
  }

  factory ProductAnalyticsEvent.revenueSubscriptionRenewed({
    required String planId,
    required int renewalNumber,
  }) {
    return ProductAnalyticsEvent(
      name: 'revenue_subscription_renewed',
      stage: ProductFunnelStage.revenue,
      parameters: <String, Object?>{
        'plan_id': planId,
        'renewal_number': renewalNumber,
      },
    );
  }
}
