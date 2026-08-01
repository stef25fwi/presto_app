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
  Future<void> pumpPage(
    WidgetTester tester, {
    required Size size,
    VoidCallback? onDeveloperAccessGranted,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    final config = PublicLandingConfigService(
      adapter: _NoopRemoteConfigAdapter(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PublicPrelaunchPage(
          config: config,
          onDeveloperAccessGranted: onDeveloperAccessGranted,
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
      find.text(PublicLandingConfigService.defaultTitle),
      findsOneWidget,
    );
    expect(
      find.text(PublicLandingConfigService.defaultDescription),
      findsOneWidget,
    );
    expect(find.text('0 % de commission'), findsOneWidget);
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('accorde l’accès développeur après exactement huit appuis',
      (tester) async {
    var accessGrantCount = 0;
    await pumpPage(
      tester,
      size: const Size(390, 844),
      onDeveloperAccessGranted: () => accessGrantCount += 1,
    );

    final trigger = find.byKey(PublicPrelaunchPage.accessTriggerKey);
    expect(trigger, findsOneWidget);

    for (var index = 0;
        index < PublicPrelaunchPage.developerAccessTapCount - 1;
        index += 1) {
      await tester.tap(trigger);
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(accessGrantCount, 0);

    await tester.tap(trigger);
    await tester.pump();

    expect(accessGrantCount, 1);
  });
}
