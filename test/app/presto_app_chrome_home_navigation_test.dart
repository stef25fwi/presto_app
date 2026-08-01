import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/app/presto_app_chrome.dart';
import 'package:presto_app/pages/public_prelaunch_page.dart';
import 'package:presto_app/services/public_landing_config_service.dart';

class _NoopRemoteConfigAdapter
    implements PublicLandingRemoteConfigAdapter {
  @override
  Future<bool> fetchAndActivate() async => true;

  @override
  bool getBool(String key) => PublicLandingConfigService.defaultEnabled;

  @override
  String getString(String key) => '';

  @override
  Future<void> setConfigSettings(RemoteConfigSettings settings) async {}

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) async {}
}

void main() {
  testWidgets(
    'le huitième appui vide la pile et ouvre une seule page Home',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final config = PublicLandingConfigService(
        adapter: _NoopRemoteConfigAdapter(),
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          initialRoute: '/prelaunch',
          routes: <String, WidgetBuilder>{
            '/': (_) => const Scaffold(
                  body: Center(child: Text('APP_HOME_COMPLETE')),
                ),
            '/prelaunch': (_) => PublicPrelaunchPage(
                  config: config,
                  onDeveloperAccessGranted: () {
                    resetNavigatorToHomeAfterPublicLandingAccess(navigatorKey);
                  },
                ),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PublicPrelaunchPage), findsOneWidget);
      expect(find.text('APP_HOME_COMPLETE'), findsNothing);

      final trigger = find.byKey(PublicPrelaunchPage.accessTriggerKey);
      for (var index = 0;
          index < PublicPrelaunchPage.developerAccessTapCount;
          index += 1) {
        await tester.tap(trigger);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      expect(find.byType(PublicPrelaunchPage), findsNothing);
      expect(find.text('APP_HOME_COMPLETE'), findsOneWidget);
      expect(navigatorKey.currentState?.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('le retour Home échoue proprement sans Navigator actif',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    expect(
      resetNavigatorToHomeAfterPublicLandingAccess(navigatorKey),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
