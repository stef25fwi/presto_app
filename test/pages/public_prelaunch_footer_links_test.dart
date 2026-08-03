import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/public_prelaunch_page.dart';
import 'package:presto_app/services/public_landing_config_service.dart';

class _NoopRemoteConfigAdapter implements PublicLandingRemoteConfigAdapter {
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
  testWidgets('affiche les six liens publics et légaux demandés',
      (tester) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: PublicPrelaunchPage(
          config: PublicLandingConfigService(
            adapter: _NoopRemoteConfigAdapter(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('public-prelaunch-footer-links')),
      findsOneWidget,
    );

    for (final label in <String>[
      'À propos',
      'Guide d’utilisation',
      'Mentions légales',
      'Confidentialité',
      'CGU',
      'Suppression du compte',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    expect(find.text('Guadeloupe'), findsNothing);
    expect(find.text('Martinique'), findsNothing);
    expect(find.text('Guyane'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
