import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/core/localization/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveDeviceLocale (sans préférence enregistrée)', () {
    test('reprend la locale de l\'appareil si elle est supportée', () {
      final controller = LocaleController.instance;
      expect(
        controller.resolveDeviceLocale(const Locale('en')),
        const Locale('en'),
      );
    });

    test('retombe sur le français si l\'appareil est dans une langue non supportée', () {
      final controller = LocaleController.instance;
      expect(
        controller.resolveDeviceLocale(const Locale('de')),
        const Locale('fr'),
      );
    });

    test('retombe sur le français si aucune locale d\'appareil n\'est fournie', () {
      final controller = LocaleController.instance;
      expect(controller.resolveDeviceLocale(null), const Locale('fr'));
    });
  });

  group('cycle de vie complet du contrôleur (singleton, état séquentiel)', () {
    test(
      'initialize charge la préférence persistée, setLocale la met à jour, '
      'useSystemLocale la retire',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'preferred_language': 'es',
        });
        final controller = LocaleController.instance;

        await controller.initialize();
        expect(controller.locale, const Locale('es'));
        expect(controller.followsSystem, isFalse);
        expect(
          controller.resolveDeviceLocale(const Locale('en')),
          const Locale('es'),
          reason: 'une préférence explicite prime sur la locale de l\'appareil',
        );

        await controller.setLocale(const Locale('fr'));
        expect(controller.locale, const Locale('fr'));
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('preferred_language'), 'fr');

        await controller.useSystemLocale();
        expect(controller.locale, isNull);
        expect(controller.followsSystem, isTrue);
        expect(prefs.getString('preferred_language'), isNull);
      },
    );

    test('setLocale rejette une locale non supportée', () async {
      final controller = LocaleController.instance;
      expect(
        () => controller.setLocale(const Locale('de')),
        throwsArgumentError,
      );
    });
  });
}
