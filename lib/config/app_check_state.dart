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

/// Type de provider reCAPTCHA web a utiliser pour App Check.
///
/// Le préfixe `6L...` est identique pour une clé reCAPTCHA v3 *classique* et
/// une clé reCAPTCHA *Enterprise*. Si le provider du code ne correspond pas au
/// type réel de la clé, le jeton App Check est rejeté côté backend et **toutes**
/// les lectures Firestore renvoient `permission-denied`.
///
/// Valeurs acceptées (insensibles à la casse) :
/// - `enterprise` (défaut) → [ReCaptchaEnterpriseProvider]
/// - `v3` / `classic` / `recaptchav3` → [ReCaptchaV3Provider]
const String kAppCheckWebRecaptchaProvider = String.fromEnvironment(
  'APPCHECK_RECAPTCHA_PROVIDER',
  defaultValue: 'enterprise',
);

/// `true` lorsque la configuration demande explicitement une clé reCAPTCHA v3
/// classique plutôt qu'une clé Enterprise.
bool get kAppCheckWebUsesRecaptchaV3 {
  final normalized = kAppCheckWebRecaptchaProvider.trim().toLowerCase();
  return normalized == 'v3' ||
      normalized == 'classic' ||
      normalized == 'recaptchav3' ||
      normalized == 'recaptcha_v3' ||
      normalized == 'recaptcha-v3';
}

/// Active App Check pour le web en alignant le provider reCAPTCHA sur le type
/// de clé configuré (Enterprise par défaut, ou v3 classique).
///
/// Centralise le choix Enterprise vs v3 pour éviter toute divergence entre les
/// différents points d'activation (`bootstrapAppCheck`, retry du bootstrap
/// profil, publication d'annonce, lecture des offres publiques). Un provider
/// qui ne correspond pas au type réel de la clé fait rejeter le jeton côté
/// backend et renvoie `permission-denied` sur toutes les lectures Firestore.
Future<void> activateAppCheckWeb(String siteKey) {
  return FirebaseAppCheck.instance.activate(
    webProvider: kAppCheckWebUsesRecaptchaV3
        ? ReCaptchaV3Provider(siteKey)
        : ReCaptchaEnterpriseProvider(siteKey),
  );
}
