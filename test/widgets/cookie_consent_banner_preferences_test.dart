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

    expect(find.text('Personnaliser les traceurs'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Marketing / publicité'), findsOneWidget);

    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(2));
    expect(tester.widget<Switch>(switches.at(0)).value, isFalse);
    expect(tester.widget<Switch>(switches.at(1)).value, isFalse);

    await tester.tap(switches.at(0));
    await tester.pump();
    await tester.tap(switches.at(1));
    await tester.pump();

    expect(tester.widget<Switch>(switches.at(0)).value, isTrue);
    expect(tester.widget<Switch>(switches.at(1)).value, isTrue);

    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Personnaliser les traceurs'), findsNothing);
    expect(find.text('Cookies et traceurs'), findsNothing);
    final state = CookieConsentService.instance.state;
    expect(state, isNotNull);
    expect(state!.choice, CookieConsentChoice.customized);
    expect(state.analyticsAllowed, isTrue);
    expect(state.marketingAllowed, isTrue);
  });
}
