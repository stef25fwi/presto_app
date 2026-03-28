import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';

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

    await _analytics.logEvent(
      name: name,
      parameters: sanitized,
    );
  }

  Future<T> trace<T>(String traceName, Future<T> Function() action) async {
    final trace = _performance.newTrace(traceName);
    await trace.start();
    try {
      return await action();
    } finally {
      await trace.stop();
    }
  }
}