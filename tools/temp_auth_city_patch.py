from pathlib import Path

source_path = Path('lib/services/account_social_auth_actions.dart')
source = source_path.read_text()

class_marker = 'class AccountSocialAuthActions {\n'
insertion = '''class AccountSocialAuthActions {
  static bool? _debugIsWebOverride;
  static String? _debugBaseHostOverride;
  static Future<void> Function()? _debugRememberAccountRouteOverride;

  static bool get _isWeb => _debugIsWebOverride ?? kIsWeb;
  static String get _baseHost => _debugBaseHostOverride ?? Uri.base.host;

  @visibleForTesting
  static void configureWebEnvironmentForTesting({
    required bool isWeb,
    required String baseHost,
    Future<void> Function()? rememberAccountRoute,
  }) {
    _debugIsWebOverride = isWeb;
    _debugBaseHostOverride = baseHost;
    _debugRememberAccountRouteOverride = rememberAccountRoute;
  }

  @visibleForTesting
  static void resetTestingOverrides() {
    _debugIsWebOverride = null;
    _debugBaseHostOverride = null;
    _debugRememberAccountRouteOverride = null;
  }

  @visibleForTesting
  static bool shouldFallbackToRedirectForTesting(Object error) =>
      _shouldFallbackToRedirect(error);

  @visibleForTesting
  static String facebookErrorMessageForTesting(Object error) =>
      _facebookErrorMessage(error);

  @visibleForTesting
  static String generateNonceForTesting([int length = 32]) =>
      _generateNonce(length);

  @visibleForTesting
  static String sha256OfStringForTesting(String input) =>
      _sha256OfString(input);

  @visibleForTesting
  static GoogleAuthProvider buildGoogleProviderForTesting() =>
      _buildGoogleProvider();
'''
if class_marker not in source:
    raise SystemExit('AccountSocialAuthActions class marker not found')
source = source.replace(class_marker, insertion, 1)

replacements = [
    (
        "details: kIsWeb ? 'Mode Web' : 'Mode Mobile',",
        "details: _isWeb ? 'Mode Web' : 'Mode Mobile',",
    ),
    (
        "final bool onGitHubPages = Uri.base.host.endsWith('.github.io');",
        "final bool onGitHubPages = _baseHost.endsWith('.github.io');",
    ),
    (
        "if (kIsWeb ||\n        !(defaultTargetPlatform == TargetPlatform.iOS ||",
        "if (_isWeb ||\n        !(defaultTargetPlatform == TargetPlatform.iOS ||",
    ),
]
for old, new in replacements:
    if old not in source:
        raise SystemExit(f'Missing source snippet: {old}')
    source = source.replace(old, new, 1)

web_branch_count = source.count('if (kIsWeb) {')
if web_branch_count != 2:
    raise SystemExit(f'Expected two web branches, found {web_branch_count}')
source = source.replace('if (kIsWeb) {', 'if (_isWeb) {')

old_remember = '''  static Future<void> _rememberAccountRouteForWebRedirect() async {
    if (!kIsWeb) return;
    await PostAuthNavigationIntentService.rememberAccountRoute();
  }
'''
new_remember = '''  static Future<void> _rememberAccountRouteForWebRedirect() async {
    if (!_isWeb) return;
    final override = _debugRememberAccountRouteOverride;
    if (override != null) {
      await override();
      return;
    }
    await PostAuthNavigationIntentService.rememberAccountRoute();
  }
'''
if old_remember not in source:
    raise SystemExit('Remember route helper not found')
source = source.replace(old_remember, new_remember, 1)
source_path.write_text(source)
