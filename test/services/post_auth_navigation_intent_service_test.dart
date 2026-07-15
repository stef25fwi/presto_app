import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/post_auth_navigation_intent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const routeKey = 'post_auth_navigation_route';
  const timestampKey = 'post_auth_navigation_timestamp';
  final now = DateTime(2026, 7, 15, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('ignore les écritures hors web et les routes vides', () async {
    await PostAuthNavigationIntentService.rememberRoute(
      '/account',
      webOverride: false,
      now: () => now,
    );
    await PostAuthNavigationIntentService.rememberRoute(
      '   ',
      webOverride: true,
      now: () => now,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(routeKey), isNull);
    expect(prefs.getInt(timestampKey), isNull);
  });

  test('mémorise une route normalisée puis la consomme une seule fois', () async {
    await PostAuthNavigationIntentService.rememberRoute(
      '  /account  ',
      webOverride: true,
      now: () => now,
    );

    final first = await PostAuthNavigationIntentService.takePendingRoute(
      webOverride: true,
      now: () => now.add(const Duration(minutes: 3)),
    );
    final second = await PostAuthNavigationIntentService.takePendingRoute(
      webOverride: true,
      now: () => now.add(const Duration(minutes: 3)),
    );

    expect(first, '/account');
    expect(second, isNull);
  });

  test('retourne une route legacy sans horodatage et nettoie les clés', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      routeKey: ' /publish ',
    });
    final prefs = await SharedPreferences.getInstance();

    final route = await PostAuthNavigationIntentService.takePendingRoute(
      webOverride: true,
      preferences: prefs,
      now: () => now,
    );

    expect(route, '/publish');
    expect(prefs.containsKey(routeKey), isFalse);
    expect(prefs.containsKey(timestampKey), isFalse);
  });

  test('rejette les intentions expirées ou datées dans le futur', () async {
    Future<String?> takeWithTimestamp(int timestamp) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        routeKey: '/account',
        timestampKey: timestamp,
      });
      return PostAuthNavigationIntentService.takePendingRoute(
        webOverride: true,
        now: () => now,
      );
    }

    final expired = await takeWithTimestamp(
      now.subtract(const Duration(minutes: 11)).millisecondsSinceEpoch,
    );
    final future = await takeWithTimestamp(
      now.add(const Duration(seconds: 1)).millisecondsSinceEpoch,
    );

    expect(expired, isNull);
    expect(future, isNull);
  });

  test('hors web aucune intention n est consommée', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      routeKey: '/account',
      timestampKey: now.millisecondsSinceEpoch,
    });

    final route = await PostAuthNavigationIntentService.takePendingRoute(
      webOverride: false,
      now: () => now,
    );
    final prefs = await SharedPreferences.getInstance();

    expect(route, isNull);
    expect(prefs.getString(routeKey), '/account');
  });
}
