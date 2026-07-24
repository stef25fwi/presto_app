import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/cookie_consent_service.dart';
import 'package:presto_app/widgets/cookie_consent_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('accepter masque la bannière et autorise tous les traceurs', (
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

    expect(find.text('Cookies et traceurs'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Accepter'));
    await tester.pumpAndSettle();

    expect(find.text('Cookies et traceurs'), findsNothing);
    final state = CookieConsentService.instance.state;
    expect(state, isNotNull);
    expect(state!.choice, CookieConsentChoice.accepted);
    expect(state.analyticsAllowed, isTrue);
    expect(state.marketingAllowed, isTrue);
  });
}
