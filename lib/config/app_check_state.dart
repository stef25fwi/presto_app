// Shared App Check activation state used by both main.dart bootstrap
// and PublishOfferPage (and any flow needing to gate on App Check).

import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

bool appCheckActivationAttempted = false;
bool appCheckActivationSucceeded = false;
Object? appCheckActivationError;
StackTrace? appCheckActivationStackTrace;
DateTime? appCheckLastTokenRefreshAt;
Object? appCheckLastTokenRefreshError;

const Set<String> kAppCheckKnownProdHosts = <String>{
  'ilipresto.fr',
  'www.ilipresto.fr',
  'ilipresto.web.app',
  'ilipresto.firebaseapp.com',
  'presto-app-74abe.web.app',
  'presto-app-74abe.firebaseapp.com',
};

const String kAppCheckWebRecaptchaSiteKey = String.fromEnvironment(
  'APPCHECK_RECAPTCHA_SITE_KEY',
  defaultValue: '',
);

const String kAppCheckWebRecaptchaProviderLabel = 'enterprise';

String currentAppCheckWebHost() {
  if (!kIsWeb) return '';
  return Uri.base.host.trim().toLowerCase();
}

bool isLocalAppCheckWebHost(String host) {
  return host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';
}

bool isPreviewAppCheckWebHost(String host) {
  return host.endsWith('.app.github.dev') ||
      host.endsWith('.github.dev') ||
      host.contains('preview');
}

String appCheckWebHostClass([String? hostOverride]) {
  final host = (hostOverride ?? currentAppCheckWebHost()).trim().toLowerCase();
  if (host.isEmpty) return 'unknown';
  if (kAppCheckKnownProdHosts.contains(host)) return 'prod';
  if (isLocalAppCheckWebHost(host)) return 'local';
  if (isPreviewAppCheckWebHost(host)) return 'preview';
  return 'custom';
}

String appCheckWebHostHint() {
  if (!kIsWeb) return '';

  final host = currentAppCheckWebHost();
  switch (appCheckWebHostClass(host)) {
    case 'prod':
      return '';
    case 'local':
      return ' Host actuel: $host. Verifie que localhost est autorise dans la cle reCAPTCHA Enterprise et dans Firebase App Check.';
    case 'preview':
      return ' Host actuel: $host. Les URLs Codespaces/preview changent souvent et doivent etre explicitement autorisees, sinon App Check sera rejete.';
    case 'custom':
      return ' Host actuel: $host. Ce domaine n’est pas dans la liste prod attendue; verifie qu’il est autorise dans la cle reCAPTCHA Enterprise et dans Firebase App Check.';
    default:
      return ' Host web inconnu; verifie le domaine courant et la configuration App Check.';
  }
}

/// Active App Check pour le web avec la site key reCAPTCHA Enterprise publique
/// configuree dans Firebase Console > App Check > app Web.
///
/// Ne jamais fournir de secret key ici : toute valeur injectee par
/// `--dart-define` dans Flutter Web est lisible dans le bundle frontend.
///
/// La clé de production confirmée (`presto-web-appcheck-prod`) est une clé
/// reCAPTCHA Enterprise avec `integrationType: SCORE`; Flutter doit donc
/// toujours utiliser [ReCaptchaEnterpriseProvider].
Future<void> activateAppCheckWeb(String siteKey) {
  return FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaEnterpriseProvider(siteKey),
  );
}
