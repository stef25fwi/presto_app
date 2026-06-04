// Shared App Check activation state used by both main.dart bootstrap
// and PublishOfferPage (and any flow needing to gate on App Check).

import 'package:firebase_app_check/firebase_app_check.dart';

bool appCheckActivationAttempted = false;
bool appCheckActivationSucceeded = false;
Object? appCheckActivationError;
StackTrace? appCheckActivationStackTrace;
DateTime? appCheckLastTokenRefreshAt;
Object? appCheckLastTokenRefreshError;

const String kAppCheckWebRecaptchaSiteKey = String.fromEnvironment(
  'APPCHECK_RECAPTCHA_SITE_KEY',
  defaultValue: '',
);

const String kAppCheckWebRecaptchaProviderLabel = 'enterprise';

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
