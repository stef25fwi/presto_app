// Shared App Check activation state used by both main.dart bootstrap
// and PublishOfferPage (and any flow needing to gate on App Check).

bool appCheckActivationAttempted = false;
bool appCheckActivationSucceeded = false;
Object? appCheckActivationError;
StackTrace? appCheckActivationStackTrace;

const String kAppCheckWebRecaptchaSiteKey = String.fromEnvironment(
  'APPCHECK_RECAPTCHA_SITE_KEY',
  defaultValue: '6LcrwLUsAAAAAAqJ0undV5NcndC-jLP2qxaNWnR_',
);
