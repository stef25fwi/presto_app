import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/cookie_consent_service.dart';
import 'package:presto_app/widgets/cookie_consent_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('refuser masque la bannière et bloque les traceurs optionnels', (
    tester,
  ) async {
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

    expect(find.text('Refuser'), findsOneWidget);

    final refuseButton = find.widgetWithText(OutlinedButton, 'Refuser');
    await tester.ensureVisible(refuseButton);
    await tester.tap(refuseButton);
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
