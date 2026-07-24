import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/cookie_consent_service.dart';
import 'package:presto_app/widgets/cookie_consent_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('personnaliser enregistre séparément analytics et marketing', (
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

    await tester.tap(find.text('Gérer mes choix'));
    await tester.pumpAndSettle();

    expect(find.text('Gérer mes préférences'), findsOneWidget);
    expect(find.text('Performance'), findsOneWidget);
    expect(find.text('Marketing'), findsOneWidget);

    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(4));
    expect(tester.widget<Switch>(switches.at(1)).value, isFalse);
    expect(tester.widget<Switch>(switches.at(3)).value, isFalse);

    await tester.tap(switches.at(1));
    await tester.pump();
    await tester.tap(switches.at(3));
    await tester.pump();

    expect(tester.widget<Switch>(switches.at(1)).value, isTrue);
    expect(tester.widget<Switch>(switches.at(3)).value, isTrue);

    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Gérer mes préférences'), findsNothing);
    expect(
      find.text('Nous utilisons des cookies pour améliorer votre expérience'),
      findsNothing,
    );
    final state = CookieConsentService.instance.state;
    expect(state, isNotNull);
    expect(state!.choice, CookieConsentChoice.customized);
    expect(state.analyticsAllowed, isTrue);
    expect(state.marketingAllowed, isTrue);
  });
}
