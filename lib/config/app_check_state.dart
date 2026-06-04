// Shared App Check activation state used by both main.dart bootstrap
// and PublishOfferPage (and any flow needing to gate on App Check).

import 'package:firebase_app_check/firebase_app_check.dart';

bool appCheckActivationAttempted = false;
bool appCheckActivationSucceeded = false;
Object? appCheckActivationError;
StackTrace? appCheckActivationStackTrace;

const String kAppCheckWebRecaptchaSiteKey = String.fromEnvironment(
  'APPCHECK_RECAPTCHA_SITE_KEY',
  defaultValue: '',
);

const String kAppCheckWebRecaptchaProviderLabel = 'enterprise';

/// Active App Check pour le web avec la clé reCAPTCHA Enterprise configurée
/// dans Firebase Console > App Check > app Web.
///
/// La clé de production confirmée (`presto-web-appcheck-prod`) est une clé
/// reCAPTCHA Enterprise avec `integrationType: SCORE`; Flutter doit donc
/// toujours utiliser [ReCaptchaEnterpriseProvider].
Future<void> activateAppCheckWeb(String siteKey) {
  return FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaEnterpriseProvider(siteKey),
  );
}
