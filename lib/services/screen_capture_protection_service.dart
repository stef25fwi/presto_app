import 'dart:io';

import 'package:flutter/services.dart';

/// Empêche les captures d'écran et l'enregistrement d'écran pendant qu'une
/// page sensible ("Mon parcours personnalisé") est affichée, via
/// `FLAG_SECURE` côté Android.
///
/// iOS ne propose pas d'API publique équivalente pour bloquer réellement
/// une capture d'écran : l'appel est silencieusement ignoré sur cette
/// plateforme.
class ScreenCaptureProtection {
  ScreenCaptureProtection._();

  static const MethodChannel _channel = MethodChannel(
    'fr.ilipresto.app/screen_capture_protection',
  );

  static Future<void> enable() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('enable');
    } catch (_) {
      // Best-effort : ne doit jamais empêcher l'affichage de la page.
    }
  }

  static Future<void> disable() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('disable');
    } catch (_) {
      // Best-effort.
    }
  }
}
