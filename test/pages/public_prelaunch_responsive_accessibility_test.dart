import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/public_prelaunch_page.dart';
import 'package:presto_app/services/public_landing_config_service.dart';

class _FakePublicLandingConfigAdapter
    implements PublicLandingRemoteConfigAdapter {
  @override
  bool getBool(String key) => false;

  @override
  String getString(String key) => '';
}

void main() {
  final config = PublicLandingConfigService(
    adapter: _FakePublicLandingConfigAdapter(),
  );

  Future<void> pumpPrelaunch(
    WidgetTester tester, {
    required double width,
    required double textScale,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 1000));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 1000),
            textScaler: TextScaler.linear(textScale),
          ),
          child: PublicPrelaunchPage(config: config),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byType(PublicPrelaunchPage)),
      ).scale(16),
      closeTo(16 * textScale, 0.001),
    );
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
