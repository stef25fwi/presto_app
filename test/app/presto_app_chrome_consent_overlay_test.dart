import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/app/presto_app_chrome.dart';
import 'package:presto_app/services/cookie_consent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'affiche la feuille de consentement sans erreur ParentData ni voile seul',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      CookieConsentService.instance.resetForTesting();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await CookieConsentService.instance.load();

      await tester.pumpWidget(
        const MaterialApp(
          home: PrestoAppChrome(
            child: Scaffold(
              body: Center(child: Text('Accueil iliprestō')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Accueil iliprestō'), findsOneWidget);
      expect(
        find.text(
          'Nous utilisons des cookies\npour améliorer votre expérience',
        ),
        findsOneWidget,
      );
      expect(find.text('Accepter'), findsOneWidget);
      expect(find.text('Refuser'), findsOneWidget);
    },
  );
}
