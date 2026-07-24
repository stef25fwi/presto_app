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
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    expect(switches, findsNWidgets(3));
    expect(tester.widget<Switch>(switches.at(0)).value, isFalse);
    expect(tester.widget<Switch>(switches.at(2)).value, isFalse);

    await tester.tap(switches.at(0));
    await tester.pump();
    await tester.tap(switches.at(2));
    await tester.pump();

    expect(tester.widget<Switch>(switches.at(0)).value, isTrue);
    expect(tester.widget<Switch>(switches.at(2)).value, isTrue);

    final saveButton = find.widgetWithText(FilledButton, 'Enregistrer');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
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
