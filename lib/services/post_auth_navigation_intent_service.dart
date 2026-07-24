import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class PostAuthNavigationIntentService {
  static const String accountRoute = '/account';

  static const String _routeKey = 'post_auth_navigation_route';
  static const String _timestampKey = 'post_auth_navigation_timestamp';
  static const Duration _maxAge = Duration(minutes: 10);

  static Future<void> rememberAccountRoute() async {
    await rememberRoute(accountRoute);
  }

  static Future<void> rememberRoute(
    String route, {
    bool? webOverride,
    SharedPreferences? preferences,
    DateTime Function()? now,
  }) async {
    if (!(webOverride ?? kIsWeb)) return;
    final normalizedRoute = route.trim();
    if (normalizedRoute.isEmpty) return;

    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.setString(_routeKey, normalizedRoute);
    await prefs.setInt(
      _timestampKey,
      (now?.call() ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  static Future<String?> takePendingRoute({
    bool? webOverride,
    SharedPreferences? preferences,
    DateTime Function()? now,
  }) async {
    if (!(webOverride ?? kIsWeb)) return null;

    final prefs = preferences ?? await SharedPreferences.getInstance();
    final route = prefs.getString(_routeKey)?.trim();
    final timestamp = prefs.getInt(_timestampKey);

    await prefs.remove(_routeKey);
    await prefs.remove(_timestampKey);

    if (route == null || route.isEmpty) {
      return null;
    }

    if (timestamp == null) {
      return route;
    }

    final ageMs = (now?.call() ?? DateTime.now()).millisecondsSinceEpoch -
        timestamp;
    if (ageMs < 0 || ageMs > _maxAge.inMilliseconds) {
      return null;
    }

    return route;
  }
}
