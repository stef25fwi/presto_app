import 'dart:io';

import 'package:flutter/services.dart';

typedef ScreenCapturePlatformCheck = bool Function();
typedef ScreenCaptureMethodInvoker = Future<Object?> Function(String method);

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

  static ScreenCapturePlatformCheck? _isAndroidOverride;
  static ScreenCaptureMethodInvoker? _methodInvokerOverride;

  static bool get _isAndroid => _isAndroidOverride?.call() ?? Platform.isAndroid;

  static Future<Object?> _invoke(String method) {
    final invoker = _methodInvokerOverride;
    if (invoker != null) return invoker(method);
    return _channel.invokeMethod(method);
  }

  static void configureForTest({
    ScreenCapturePlatformCheck? isAndroid,
    ScreenCaptureMethodInvoker? methodInvoker,
  }) {
    _isAndroidOverride = isAndroid;
    _methodInvokerOverride = methodInvoker;
  }

  static void resetForTest() {
    _isAndroidOverride = null;
    _methodInvokerOverride = null;
  }

  static Future<void> enable() async {
    if (!_isAndroid) return;
    try {
      await _invoke('enable');
    } catch (_) {
      // Best-effort : ne doit jamais empêcher l'affichage de la page.
    }
  }

  static Future<void> disable() async {
    if (!_isAndroid) return;
    try {
      await _invoke('disable');
    } catch (_) {
      // Best-effort.
    }
  }
}
