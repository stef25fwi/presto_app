import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

class ProductAnalyticsService {
  ProductAnalyticsService({
    FirebaseAnalytics? analytics,
    FirebasePerformance? performance,
  })  : _analytics = analytics ?? FirebaseAnalytics.instance,
        _performance = performance ?? FirebasePerformance.instance;

  final FirebaseAnalytics _analytics;
  final FirebasePerformance _performance;

  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) async {
    final sanitized = <String, Object>{};
    for (final entry in parameters.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String || value is num || value is bool) {
        sanitized[entry.key] = value;
      } else {
        sanitized[entry.key] = value.toString();
      }
    }
    try {
      await _analytics.logEvent(
        name: name,
        parameters: sanitized,
      );
    } catch (error) {
      debugPrint('[Analytics] logEvent failed for $name: $error');
    }
  }

  Future<T> trace<T>(String traceName, Future<T> Function() action) async {
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
