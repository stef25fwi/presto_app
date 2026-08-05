import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/l10n/app_localizations_es.dart';

void main() {
  group('AppLocalizationsEs', () {
    test('exposes every Spanish label', () {
      final l10n = AppLocalizationsEs();

      expect(l10n.localeName, 'es');
      expect(
        <String>[
          l10n.appName,
          l10n.commonSave,
          l10n.commonCancel,
          l10n.commonDelete,
          l10n.commonRetry,
          l10n.commonClose,
          l10n.commonContinue,
          l10n.commonBack,
          l10n.commonLoading,
          l10n.languageTitle,
          l10n.languageSystem,
          l10n.languageFrench,
          l10n.languageEnglish,
          l10n.languageSpanish,
          l10n.languageChanged,
          l10n.errorGeneric,
          l10n.errorNetworkUnavailable,
          l10n.errorUserNotFound,
          l10n.errorPaymentFailed,
        ],
        <String>[
          'iliprestō',
          'Guardar',
          'Cancelar',
          'Eliminar',
          'Reintentar',
          'Cerrar',
          'Continuar',
          'Volver',
          'Cargando…',
          'Idioma de la aplicación',
          'Automático — idioma del dispositivo',
          'Français',
          'English',
          'Español',
          'El idioma de la aplicación se ha actualizado.',
          'Se produjo un error. Inténtalo de nuevo.',
          'Conexión no disponible. Comprueba tu acceso a Internet.',
          'Usuario no encontrado.',
          'El pago ha fallado. No se confirmó ningún cargo.',
        ],
      );
    });

    test('formats result counts and message notifications', () {
      final l10n = AppLocalizationsEs('es_ES');

      expect(l10n.localeName, 'es_ES');
      expect(l10n.offerResultsCount(0), 'Ningún anuncio');
      expect(l10n.offerResultsCount(1), '1 anuncio');
      expect(l10n.offerResultsCount(7), '7 anuncios');
      expect(l10n.notificationNewMessage('Sofía'), 'Nuevo mensaje de Sofía');
    });
  });
}
