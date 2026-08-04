import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/core/localization/locale_controller.dart';
import 'package:presto_app/l10n/app_localizations.dart';
import 'package:presto_app/widgets/language_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocaleController.instance.useSystemLocale();
  });

  Widget host() {
    return MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showLanguagePickerSheet(context),
              child: const Text('Langue'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Langue'));
    await tester.pumpAndSettle();
  }

  testWidgets('affiche le titre et les quatre choix disponibles',
      (tester) async {
    await openSheet(tester);

    expect(find.text('Langue de l’application'), findsOneWidget);
    expect(find.text('Langue de l’appareil'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Español'), findsOneWidget);
    expect(find.byType(RadioListTile<Locale?>), findsNWidgets(4));
  });

  testWidgets('sélectionne et persiste le français', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();

    expect(LocaleController.instance.locale, const Locale('fr'));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('preferred_language'), 'fr');
    expect(find.text('Langue modifiée'), findsOneWidget);
  });

  testWidgets('sélectionne successivement anglais et espagnol',
      (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(LocaleController.instance.locale, const Locale('en'));

    await tester.tap(find.text('Langue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();

    expect(LocaleController.instance.locale, const Locale('es'));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('preferred_language'), 'es');
  });

  testWidgets('revient au suivi de la langue système', (tester) async {
    await LocaleController.instance.setLocale(const Locale('en'));
    await openSheet(tester);

    await tester.tap(find.text('Langue de l’appareil'));
    await tester.pumpAndSettle();

    expect(LocaleController.instance.locale, isNull);
    expect(LocaleController.instance.followsSystem, isTrue);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('preferred_language'), isFalse);
  });
}
