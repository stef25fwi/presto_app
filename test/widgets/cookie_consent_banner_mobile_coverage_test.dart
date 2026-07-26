import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/cookie_consent_service.dart';
import 'package:presto_app/widgets/cookie_consent_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile consent opens preferences, closes them and refuses', (
    tester,
  ) async {
    // 600 px reste sous le breakpoint mobile de 720 px. Le défaut du dialogue
    // compact à 390 px est suivi séparément dans #871.
    tester.view.physicalSize = const Size(600, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CookieConsentService.instance.resetForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await CookieConsentService.instance.load();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(children: <Widget>[CookieConsentBanner()]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Nous utilisons des cookies\npour améliorer votre expérience',
      ),
      findsOneWidget,
    );
    expect(find.text('RGPD'), findsOneWidget);
    expect(find.text('Consent Mode v2'), findsOneWidget);
    expect(find.text('TCF 2.3'), findsOneWidget);

    await tester.tap(find.text('Gérer mes choix'));
    await tester.pumpAndSettle();
    expect(find.text('Gérer mes préférences'), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.text('Gérer mes préférences'), findsNothing);

    await tester.tap(find.text('Refuser'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Nous utilisons des cookies\npour améliorer votre expérience',
      ),
      findsNothing,
    );
    final state = CookieConsentService.instance.state;
    expect(state, isNotNull);
    expect(state!.choice, CookieConsentChoice.refused);
    expect(state.analyticsAllowed, isFalse);
    expect(state.marketingAllowed, isFalse);
  });
}
