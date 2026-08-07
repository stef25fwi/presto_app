/// Runtime/build constants kept outside `main.dart` so the application entrypoint
/// only coordinates startup and composition.
class PrestoRemoteConfig {
  static String audioPipeline = 'HYBRID';

  static Future<void> init() async {}
}

const String kOfferDeleteReasonFoundProvider =
    'J ai deja trouve un prestataire';
const String kOfferDeleteReasonFoundOnIliPresto =
    'J’ai trouvé quelqu’un sur iliprestō';
const Duration kOfferJobDoneOverlayDuration = Duration(hours: 10);
const double kMarketplaceOutlineWidth = 1.2;

const String kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'dev',
);
const String kAppBuildNumber = String.fromEnvironment(
  'APP_BUILD_NUMBER',
  defaultValue: '0',
);
const String kAppBuildSha = String.fromEnvironment(
  'APP_BUILD_SHA',
  defaultValue: 'local',
);
const String kAppBuildBranch = String.fromEnvironment(
  'APP_BUILD_BRANCH',
  defaultValue: '',
);
const String kAppBuildTag = String.fromEnvironment(
  'APP_BUILD_TAG',
  defaultValue: '',
);
const String kAppBuildTimeUtc = String.fromEnvironment(
  'APP_BUILD_TIME_UTC',
  defaultValue: '',
);
const String kDebugStartPage = String.fromEnvironment(
  'PRESTO_DEBUG_START_PAGE',
  defaultValue: '',
);
