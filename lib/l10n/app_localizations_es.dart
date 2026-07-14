// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'iliprestō';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonBack => 'Volver';

  @override
  String get commonLoading => 'Cargando…';

  @override
  String get languageTitle => 'Idioma de la aplicación';

  @override
  String get languageSystem => 'Automático — idioma del dispositivo';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageChanged => 'El idioma de la aplicación se ha actualizado.';

  @override
  String get errorGeneric => 'Se produjo un error. Inténtalo de nuevo.';

  @override
  String get errorNetworkUnavailable =>
      'Conexión no disponible. Comprueba tu acceso a Internet.';

  @override
  String get errorUserNotFound => 'Usuario no encontrado.';

  @override
  String get errorPaymentFailed =>
      'El pago ha fallado. No se confirmó ningún cargo.';

  @override
  String offerResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anuncios',
      one: '1 anuncio',
      zero: 'Ningún anuncio',
    );
    return '$_temp0';
  }

  @override
  String notificationNewMessage(String senderName) {
    return 'Nuevo mensaje de $senderName';
  }
}
