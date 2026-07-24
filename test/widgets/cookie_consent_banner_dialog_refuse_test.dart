import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/cookie_consent_service.dart';
import 'package:presto_app/widgets/cookie_consent_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('le dialogue peut être annulé puis tout refuser', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
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

    await tester.tap(find.text('Gérer mes choix'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();

    expect(
      find.text('Nous utilisons des cookies pour améliorer votre expérience'),
      findsOneWidget,
    );
    expect(CookieConsentService.instance.state, isNull);

    await tester.tap(find.text('Gérer mes choix'));
    await tester.pumpAndSettle();
    final refuseAllButton = find.widgetWithText(OutlinedButton, 'Tout refuser');
    await tester.ensureVisible(refuseAllButton);
    await tester.tap(refuseAllButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Nous utilisons des cookies pour améliorer votre expérience'),
      findsNothing,
    );
    final state = CookieConsentService.instance.state;
    expect(state, isNotNull);
    expect(state!.choice, CookieConsentChoice.refused);
    expect(state.analyticsAllowed, isFalse);
    expect(state.marketingAllowed, isFalse);
  });
}
