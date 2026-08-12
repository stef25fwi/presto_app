import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/cookie_consent_service.dart';
import 'package:presto_app/widgets/ad_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    CookieConsentService.instance.resetForTesting();
  });

  tearDown(() {
    CookieConsentService.instance.resetForTesting();
  });

  testWidgets(
    'enabled sans consentement marketing reste en placeholder et se désabonne au dispose',
    (tester) async {
      var placeholderBuilds = 0;

      Widget placeholderBuilder({
        required String fallbackFolderPrefix,
        required BorderRadius borderRadius,
        required Duration interval,
        required int antiRepeatWindow,
        required bool enabled,
      }) {
        placeholderBuilds += 1;
        return const SizedBox(
          key: ValueKey<String>('consent-placeholder'),
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdBanner(
              enabled: true,
              animatePlaceholder: false,
              placeholderBuilder: placeholderBuilder,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(CookieConsentService.instance.canUseMarketing, isFalse);
      expect(
        find.byKey(const ValueKey<String>('consent-placeholder')),
        findsOneWidget,
      );
      expect(placeholderBuilds, greaterThanOrEqualTo(1));
      expect(tester.takeException(), isNull);

      // Notifie réellement AdBanner via ChangeNotifier. Comme le marketing
      // reste refusé, _onConsentChanged s'arrête avant tout chargement AdMob.
      await CookieConsentService.instance.refuseAll();
      await tester.pump();

      expect(CookieConsentService.instance.canUseMarketing, isFalse);
      expect(
        find.byKey(const ValueKey<String>('consent-placeholder')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // Le dispose doit retirer le listener : une nouvelle notification ne
      // doit provoquer aucun setState sur un State démonté.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
      await CookieConsentService.instance.refuseAll();
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('enabled utilise les valeurs placeholder par défaut', (
    tester,
  ) async {
    String? capturedFolder;
    BorderRadius? capturedRadius;
    Duration? capturedInterval;
    int? capturedAntiRepeatWindow;
    bool? capturedEnabled;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdBanner(
            enabled: true,
            placeholderBuilder: ({
              required String fallbackFolderPrefix,
              required BorderRadius borderRadius,
              required Duration interval,
              required int antiRepeatWindow,
              required bool enabled,
            }) {
              capturedFolder = fallbackFolderPrefix;
              capturedRadius = borderRadius;
              capturedInterval = interval;
              capturedAntiRepeatWindow = antiRepeatWindow;
              capturedEnabled = enabled;
              return const SizedBox(
                key: ValueKey<String>('default-placeholder'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('default-placeholder')),
      findsOneWidget,
    );
    expect(capturedFolder, 'assets/carousel_home/');
    expect(capturedRadius, BorderRadius.circular(6));
    expect(capturedInterval, const Duration(seconds: 4));
    expect(capturedAntiRepeatWindow, 3);
    expect(capturedEnabled, isTrue);
    expect(tester.takeException(), isNull);
  });
}
