import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  testWidgets('les appuis de préouverture ne changent pas la route active',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final config = PublicLandingConfigService(
      adapter: _NoopRemoteConfigAdapter(),
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: PublicPrelaunchPage(config: config),
        routes: <String, WidgetBuilder>{
          '/application': (_) => const Scaffold(
                body: Center(child: Text('APP_HOME_COMPLETE')),
              ),
        },
      ),
    );
    await tester.pumpAndSettle();

    final status = find.byKey(PublicPrelaunchPage.statusKey);
    for (var index = 0; index < 16; index += 1) {
      await tester.tap(status);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(find.byType(PublicPrelaunchPage), findsOneWidget);
    expect(find.text('APP_HOME_COMPLETE'), findsNothing);
    expect(navigatorKey.currentState?.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });
}
