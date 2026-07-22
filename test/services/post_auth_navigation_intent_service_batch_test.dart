import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/post_auth_navigation_intent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('ignore les écritures hors Web et les routes vides', () async {
    final prefs = await SharedPreferences.getInstance();

    await PostAuthNavigationIntentService.rememberRoute(
      '/account',
      webOverride: false,
      preferences: prefs,
    );
    await PostAuthNavigationIntentService.rememberRoute(
      '   ',
      webOverride: true,
      preferences: prefs,
    );

    expect(prefs.getKeys(), isEmpty);
    expect(
      await PostAuthNavigationIntentService.takePendingRoute(
        webOverride: false,
        preferences: prefs,
      ),
      isNull,
    );
  });

  test('mémorise une route normalisée puis la consomme une seule fois', () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 7, 22, 8);

    await PostAuthNavigationIntentService.rememberRoute(
      '  /account  ',
      webOverride: true,
      preferences: prefs,
      now: () => now,
    );

    expect(
      await PostAuthNavigationIntentService.takePendingRoute(
        webOverride: true,
        preferences: prefs,
        now: () => now.add(const Duration(minutes: 2)),
      ),
      PostAuthNavigationIntentService.accountRoute,
    );
    expect(
      await PostAuthNavigationIntentService.takePendingRoute(
        webOverride: true,
        preferences: prefs,
        now: () => now,
      ),
      isNull,
    );
  });

  test('accepte une route sans horodatage et nettoie les clés', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'post_auth_navigation_route': ' /offers ',
    });
    final prefs = await SharedPreferences.getInstance();

    expect(
      await PostAuthNavigationIntentService.takePendingRoute(
        webOverride: true,
        preferences: prefs,
      ),
      '/offers',
    );
    expect(prefs.getKeys(), isEmpty);
  });

  test('rejette les intentions futures ou expirées', () async {
    final now = DateTime(2026, 7, 22, 8);

    for (final timestamp in <DateTime>[
      now.add(const Duration(seconds: 1)),
      now.subtract(const Duration(minutes: 11)),
    ]) {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'post_auth_navigation_route': '/account',
        'post_auth_navigation_timestamp': timestamp.millisecondsSinceEpoch,
      });
      final prefs = await SharedPreferences.getInstance();

      expect(
        await PostAuthNavigationIntentService.takePendingRoute(
          webOverride: true,
          preferences: prefs,
          now: () => now,
        ),
        isNull,
      );
      expect(prefs.getKeys(), isEmpty);
    }
  });
}
