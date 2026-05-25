// Shared App Check activation state used by both main.dart bootstrap
// and PublishOfferPage (and any flow needing to gate on App Check).

bool appCheckActivationAttempted = false;
bool appCheckActivationSucceeded = false;
Object? appCheckActivationError;
StackTrace? appCheckActivationStackTrace;

const String _kAppCheckWebRecaptchaSiteKeyPrimary = String.fromEnvironment(
  'APPCHECK_RECAPTCHA_SITE_KEY',
  defaultValue: '',
);
const String kAppCheckWebRecaptchaSiteKey =
    _kAppCheckWebRecaptchaSiteKeyPrimary;

const String kAppCheckWebRecaptchaSiteKeySource =
    _kAppCheckWebRecaptchaSiteKeyPrimary != ''
    ? 'APPCHECK_RECAPTCHA_SITE_KEY'
    : 'missing';
