import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/cookie_consent_service.dart';
import 'package:presto_app/widgets/cookie_consent_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('le dialogue peut être annulé puis tout refuser', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(children: <Widget>[CookieConsentBanner()]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Personnaliser'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Annuler'));
    await tester.pumpAndSettle();

    expect(find.text('Cookies et traceurs'), findsOneWidget);
    expect(CookieConsentService.instance.state, isNull);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Personnaliser'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Tout refuser'));
    await tester.pumpAndSettle();

    expect(find.text('Cookies et traceurs'), findsNothing);
    final state = CookieConsentService.instance.state;
    expect(state, isNotNull);
    expect(state!.choice, CookieConsentChoice.refused);
    expect(state.analyticsAllowed, isFalse);
    expect(state.marketingAllowed, isFalse);
  });
}
