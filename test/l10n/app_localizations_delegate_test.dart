import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/l10n/app_localizations.dart';
import 'package:presto_app/l10n/app_localizations_en.dart';
import 'package:presto_app/l10n/app_localizations_es.dart';
import 'package:presto_app/l10n/app_localizations_fr.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('déclare les trois langues et les delegates Flutter attendus', () {
    expect(
      AppLocalizations.supportedLocales,
      const <Locale>[Locale('fr'), Locale('en'), Locale('es')],
    );
    expect(AppLocalizations.localizationsDelegates, hasLength(4));
    expect(AppLocalizations.localizationsDelegates.first,
        same(AppLocalizations.delegate));
  });

  test('résout chaque implémentation de langue', () {
    expect(lookupAppLocalizations(const Locale('fr')),
        isA<AppLocalizationsFr>());
    expect(lookupAppLocalizations(const Locale('en')),
        isA<AppLocalizationsEn>());
    expect(lookupAppLocalizations(const Locale('es')),
        isA<AppLocalizationsEs>());
  });

  test('le delegate charge les langues supportées sans rechargement', () async {
    for (final locale in AppLocalizations.supportedLocales) {
      expect(AppLocalizations.delegate.isSupported(locale), isTrue);
      final localizations = await AppLocalizations.delegate.load(locale);
      expect(localizations.localeName, locale.languageCode);
    }

    expect(
      AppLocalizations.delegate.isSupported(const Locale('de')),
      isFalse,
    );
    expect(
      AppLocalizations.delegate.shouldReload(AppLocalizations.delegate),
      isFalse,
    );
  });

  test('une langue inconnue produit une erreur explicite', () {
    expect(
      () => lookupAppLocalizations(const Locale('de')),
      throwsA(
        isA<FlutterError>().having(
          (error) => error.message,
          'message',
          contains('unsupported locale'),
        ),
      ),
    );
  });

  testWidgets('of récupère la localisation depuis le BuildContext',
      (tester) async {
    late AppLocalizations resolved;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            resolved = AppLocalizations.of(context);
            return Text(resolved.commonSave);
          },
        ),
      ),
    );

    expect(resolved, isA<AppLocalizationsEs>());
    expect(find.text('Guardar'), findsOneWidget);
  });
}
