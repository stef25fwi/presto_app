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
  PublicLandingConfigService createConfig() {
    return PublicLandingConfigService(
      adapter: _NoopRemoteConfigAdapter(),
    );
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: PublicPrelaunchPage(
          config: createConfig(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('affiche le contenu principal sur mobile sans débordement',
      (tester) async {
    await pumpPage(tester, size: const Size(320, 640));

    expect(find.text('iliprestō'), findsOneWidget);
    expect(
      find.byKey(const Key('public-prelaunch-title')),
      findsOneWidget,
    );
    expect(
      find.text(PublicLandingConfigService.defaultDescription),
      findsOneWidget,
    );
    expect(find.text('0 % de commission'), findsOneWidget);
    expect(find.textContaining('Accès test'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reste centrée et lisible sur grand écran', (tester) async {
    await pumpPage(tester, size: const Size(1440, 900));

    expect(find.byType(PublicPrelaunchPage), findsOneWidget);
    expect(find.text(PublicLandingConfigService.defaultBadge), findsOneWidget);
    expect(
      find.text(PublicLandingConfigService.defaultLaunchMessage),
      findsOneWidget,
    );
    expect(find.textContaining('Accès test'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('des appuis répétés ne déverrouillent jamais la préouverture',
      (tester) async {
    await pumpPage(tester, size: const Size(390, 844));

    final status = find.byKey(PublicPrelaunchPage.statusKey);
    for (var index = 0; index < 16; index += 1) {
      await tester.ensureVisible(status);
      await tester.tap(status);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 9));

    expect(find.byType(PublicPrelaunchPage), findsOneWidget);
    expect(find.text('Mentions légales'), findsOneWidget);
    expect(find.text('CGU'), findsOneWidget);
    expect(find.textContaining('Accès test'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
