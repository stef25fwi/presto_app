import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/public_prelaunch_page.dart';
import 'package:presto_app/services/public_landing_config_service.dart';

class _NoopPublicLandingAdapter implements PublicLandingRemoteConfigAdapter {
  @override
  Future<bool> fetchAndActivate() async => false;

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
  final config = PublicLandingConfigService(
    adapter: _NoopPublicLandingAdapter(),
  );

  Future<void> pumpPrelaunch(
    WidgetTester tester, {
    required double width,
    required double textScale,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          );
        },
        home: PublicPrelaunchPage(config: config),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in <double>[
    320,
    360,
    390,
    430,
    600,
    768,
    1024,
    1280,
    1440,
  ]) {
    testWidgets('pré-lancement sans overflow à ${width.toInt()} px', (
      tester,
    ) async {
      await pumpPrelaunch(tester, width: width, textScale: 1);

      expect(find.byType(PublicPrelaunchPage), findsOneWidget);
      expect(find.text(PublicLandingConfigService.defaultBadge), findsOneWidget);
      expect(tester.takeException(), isNull);

      final trigger = tester.getSize(
        find.byKey(PublicPrelaunchPage.accessTriggerKey),
      );
      expect(trigger.width, greaterThanOrEqualTo(48));
      expect(trigger.height, greaterThanOrEqualTo(48));
    });
  }

  for (final width in <double>[320, 390, 600, 1024, 1440]) {
    testWidgets(
      'pré-lancement accepte un texte à 200 % à ${width.toInt()} px',
      (tester) async {
        await pumpPrelaunch(tester, width: width, textScale: 2);

        final context = tester.element(find.byType(PublicPrelaunchPage));
        expect(MediaQuery.textScalerOf(context).scale(10), 20);
        expect(find.byType(PublicPrelaunchPage), findsOneWidget);
        expect(
          find.text(PublicLandingConfigService.defaultLaunchMessage),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('le logo expose un en-tête sémantique iliprestō', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    addTearDown(semanticsHandle.dispose);

    await pumpPrelaunch(tester, width: 390, textScale: 1);

    final semantics = tester.getSemantics(find.bySemanticsLabel('iliprestō'));
    expect(semantics.hasFlag(SemanticsFlag.isHeader), isTrue);
  });
}
