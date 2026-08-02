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

    await tester.pumpWidget(
      MaterialApp(
        home: PublicPrelaunchPage(
          config: createConfig(),
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

  testWidgets('toute la carte compte huit appuis sans afficher de compteur',
      (tester) async {
    var accessGrantCount = 0;
    await pumpPage(
      tester,
      size: const Size(390, 844),
      onDeveloperAccessGranted: () => accessGrantCount += 1,
    );

    final launchMessage =
        find.text(PublicLandingConfigService.defaultLaunchMessage);
    expect(launchMessage, findsOneWidget);

    Future<void> tapVisibleLaunchMessage() async {
      await tester.ensureVisible(launchMessage);
      await tester.pumpAndSettle();
      await tester.tap(launchMessage);
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (var index = 0;
        index < PublicPrelaunchPage.developerAccessTapCount - 1;
        index += 1) {
      await tapVisibleLaunchMessage();
      expect(find.textContaining('Accès test'), findsNothing);
    }

    expect(accessGrantCount, 0);

    await tapVisibleLaunchMessage();

    expect(accessGrantCount, 1);
    expect(find.textContaining('Accès test'), findsNothing);
  });

  testWidgets('accorde l’accès une seule fois au huitième appui silencieux',
      (tester) async {
    var accessGrantCount = 0;
    await pumpPage(
      tester,
      size: const Size(390, 844),
      onDeveloperAccessGranted: () => accessGrantCount += 1,
    );

    final trigger = find.text(PublicLandingConfigService.defaultBadge);
    expect(trigger, findsOneWidget);

    for (var index = 0;
        index < PublicPrelaunchPage.developerAccessTapCount - 1;
        index += 1) {
      await tester.tap(trigger);
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(accessGrantCount, 0);
    expect(find.textContaining('Accès test'), findsNothing);

    await tester.tap(trigger);
    await tester.pump();

    expect(accessGrantCount, 1);

    for (var index = 0;
        index < PublicPrelaunchPage.developerAccessTapCount;
        index += 1) {
      await tester.tap(trigger);
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(accessGrantCount, 1);
    expect(find.textContaining('Accès test'), findsNothing);
  });

  testWidgets('réinitialise silencieusement la séquence après huit secondes',
      (tester) async {
    var accessGrantCount = 0;
    await pumpPage(
      tester,
      size: const Size(390, 844),
      onDeveloperAccessGranted: () => accessGrantCount += 1,
    );

    final trigger = find.text(PublicLandingConfigService.defaultBadge);
    await tester.tap(trigger);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Accès test'), findsNothing);

    await tester.pump(const Duration(seconds: 9));

    for (var index = 0;
        index < PublicPrelaunchPage.developerAccessTapCount - 1;
        index += 1) {
      await tester.tap(trigger);
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(accessGrantCount, 0);
    expect(find.textContaining('Accès test'), findsNothing);

    await tester.tap(trigger);
    await tester.pump();

    expect(accessGrantCount, 1);
  });

  testWidgets('remplace la préouverture par une seule page application',
      (tester) async {
    var showPrelaunch = true;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            if (!showPrelaunch) {
              return const Scaffold(
                body: Center(child: Text('APP_HOME_UNIQUE')),
              );
            }

            return PublicPrelaunchPage(
              config: createConfig(),
              onDeveloperAccessGranted: () {
                setState(() => showPrelaunch = false);
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final trigger = find.text(PublicLandingConfigService.defaultBadge);
    for (var index = 0;
        index < PublicPrelaunchPage.developerAccessTapCount;
        index += 1) {
      await tester.tap(trigger);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(find.byType(PublicPrelaunchPage), findsNothing);
    expect(find.text('APP_HOME_UNIQUE'), findsOneWidget);
    expect(find.textContaining('Accès test'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
