import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

import 'campaign_attribution_service.dart';
import 'cookie_consent_service.dart';
import 'product_analytics_events.dart';

class ProductAnalyticsService {
  ProductAnalyticsService({
    FirebaseAnalytics? analytics,
    FirebasePerformance? performance,
  })  : _analyticsOverride = analytics,
        _performance = performance ?? FirebasePerformance.instance;

  final FirebaseAnalytics? _analyticsOverride;
  final FirebasePerformance _performance;

  FirebaseAnalytics? _analytics;

  FirebaseAnalytics? get _analyticsInstance {
    if (!CookieConsentService.instance.canUseAnalytics) return null;
    return _analytics ??= _analyticsOverride ?? FirebaseAnalytics.instance;
  }

  Future<void> logProductEvent(ProductAnalyticsEvent event) {
    return logEvent(event.name, parameters: event.parameters);
  }

  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) async {
    if (_analyticsInstance == null) {
      debugPrint('[Analytics] skipped by consent for $name');
      return;
    }

    final attribution = CampaignAttributionService.instance;
    if (attribution.hasObservedAttribution) {
      await attribution.ensureReady();
    }

    final enriched = <String, Object?>{
      ...attribution.parametersForProductEvent(),
      ...parameters,
    };
    final sanitized = <String, Object>{};
    for (final entry in enriched.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String || value is num || value is bool) {
        sanitized[entry.key] = value;
      } else {
        sanitized[entry.key] = value.toString();
      }
    }
    try {
      await _analyticsInstance!.logEvent(
        name: name,
        parameters: sanitized,
      );
    } catch (error) {
      debugPrint('[Analytics] logEvent failed for $name: $error');
    }
  }

  Future<T> trace<T>(String traceName, Future<T> Function() action) async {
    if (!CookieConsentService.instance.canUseAnalytics) {
      return action();
    }

    Trace? trace;
    try {
      trace = _performance.newTrace(traceName);
      await trace.start();
    } catch (error) {
      debugPrint('[Performance] trace start failed for $traceName: $error');
      trace = null;
    }

    try {
      return await action();
    } finally {
      if (trace != null) {
        try {
          await trace.stop();
        } catch (error) {
          debugPrint('[Performance] trace stop failed for $traceName: $error');
        }
      }
    }
  }
}
