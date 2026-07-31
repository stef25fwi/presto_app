import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

abstract class PublicLandingRemoteConfigAdapter {
  Future<void> setDefaults(Map<String, dynamic> defaults);

  Future<void> setConfigSettings(RemoteConfigSettings settings);

  Future<bool> fetchAndActivate();

  bool getBool(String key);

  String getString(String key);
}

class FirebasePublicLandingRemoteConfigAdapter
    implements PublicLandingRemoteConfigAdapter {
  const FirebasePublicLandingRemoteConfigAdapter(this.remoteConfig);

  final FirebaseRemoteConfig remoteConfig;

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) =>
      remoteConfig.setDefaults(defaults);

  @override
  Future<void> setConfigSettings(RemoteConfigSettings settings) =>
      remoteConfig.setConfigSettings(settings);

  @override
  Future<bool> fetchAndActivate() => remoteConfig.fetchAndActivate();

  @override
  bool getBool(String key) => remoteConfig.getBool(key);

  @override
  String getString(String key) => remoteConfig.getString(key);
}

/// Pilote la page publique de pré-lancement depuis Firebase Remote Config.
///
/// Le mode est activé par défaut afin qu'un déploiement de préparation ne
/// rende pas l'application incomplète visible sur le domaine public. Il peut
/// être désactivé dans Remote Config avec `public_landing_enabled = false`,
/// sans nouveau déploiement Flutter.
class PublicLandingConfigService extends ChangeNotifier {
  PublicLandingConfigService({
    PublicLandingRemoteConfigAdapter? adapter,
  }) : _adapter = adapter ?? _tryCreateAdapter();

  static final PublicLandingConfigService instance =
      PublicLandingConfigService();

  static const String enabledKey = 'public_landing_enabled';
  static const String badgeKey = 'public_landing_badge';
  static const String titleKey = 'public_landing_title';
  static const String descriptionKey = 'public_landing_description';
  static const String launchMessageKey = 'public_landing_launch_message';

  static const bool defaultEnabled = true;
  static const String defaultBadge = 'Bientôt disponible';
  static const String defaultTitle =
      'Trouvez rapidement un particulier ou un professionnel près de chez vous';
  static const String defaultDescription =
      'iliprestō met en relation particuliers, indépendants et professionnels '
      'pour répondre rapidement à vos besoins en services et microservices du '
      'quotidien, avec des annonces assistées par IA et 0 % de commission.';
  static const String defaultLaunchMessage =
      'Ouverture prochaine en Guadeloupe, Martinique et Guyane.';

  static const Set<String> _publicHosts = <String>{
    'ilipresto.fr',
    'www.ilipresto.fr',
    'ilipresto.web.app',
    'ilipresto.firebaseapp.com',
    'presto-app-74abe.web.app',
    'presto-app-74abe.firebaseapp.com',
  };

  static const Set<String> _bypassPaths = <String>{
    '/admin',
    '/auth',
    '/login',
    '/register',
    '/forgot-password',
    '/verify-email',
    '/reset-password-success',
    '/__/auth',
  };

  final PublicLandingRemoteConfigAdapter? _adapter;

  Future<void>? _initialization;
  Future<void>? _refreshInFlight;
  bool _initialized = false;
  bool _enabled = defaultEnabled;
  String _badge = defaultBadge;
  String _title = defaultTitle;
  String _description = defaultDescription;
  String _launchMessage = defaultLaunchMessage;

  bool get initialized => _initialized;
  bool get enabled => _enabled;
  String get badge => _badge;
  String get title => _title;
  String get description => _description;
  String get launchMessage => _launchMessage;

  static PublicLandingRemoteConfigAdapter? _tryCreateAdapter() {
    try {
      return FirebasePublicLandingRemoteConfigAdapter(
        FirebaseRemoteConfig.instance,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    final adapter = _adapter;
    if (adapter == null) {
      _initialized = true;
      notifyListeners();
      return;
    }

    try {
      await adapter.setDefaults(<String, dynamic>{
        enabledKey: defaultEnabled,
        badgeKey: defaultBadge,
        titleKey: defaultTitle,
        descriptionKey: defaultDescription,
        launchMessageKey: defaultLaunchMessage,
      });
      await adapter.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval:
              kDebugMode ? Duration.zero : const Duration(minutes: 5),
        ),
      );
      await _fetchAndApply(adapter);
    } catch (error) {
      _logRemoteConfigError(error);
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await initialize();
    final adapter = _adapter;
    if (adapter == null) return;

    final currentRefresh = _refreshInFlight;
    if (currentRefresh != null) return currentRefresh;

    final refresh = _refresh(adapter);
    _refreshInFlight = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<void> _refresh(PublicLandingRemoteConfigAdapter adapter) async {
    try {
      await _fetchAndApply(adapter);
      notifyListeners();
    } catch (error) {
      _logRemoteConfigError(error);
    }
  }

  Future<void> _fetchAndApply(
    PublicLandingRemoteConfigAdapter adapter,
  ) async {
    await adapter.fetchAndActivate();
    _enabled = adapter.getBool(enabledKey);
    _badge = _valueOrDefault(adapter.getString(badgeKey), defaultBadge);
    _title = _valueOrDefault(adapter.getString(titleKey), defaultTitle);
    _description = _valueOrDefault(
      adapter.getString(descriptionKey),
      defaultDescription,
    );
    _launchMessage = _valueOrDefault(
      adapter.getString(launchMessageKey),
      defaultLaunchMessage,
    );
  }

  void _logRemoteConfigError(Object error) {
    if (kDebugMode) {
      debugPrint('[PublicLanding] Remote Config indisponible: $error');
    }
  }

  bool shouldShowFor(Uri uri, {bool isWeb = kIsWeb}) {
    if (!isWeb || !_enabled) return false;

    final host = uri.host.trim().toLowerCase();
    if (!_publicHosts.contains(host)) return false;

    final path = _effectiveRoutePath(uri);
    if (_isBypassPath(path)) return false;

    return true;
  }

  static String _effectiveRoutePath(Uri uri) {
    final path = _normalizePath(uri.path);
    if (path != '/') return path;

    final rawFragment = uri.fragment.trim();
    if (rawFragment.isEmpty) return path;

    try {
      final fragment = rawFragment.startsWith('/')
          ? rawFragment
          : '/$rawFragment';
      return _normalizePath(Uri.parse(fragment).path);
    } catch (_) {
      return path;
    }
  }

  static String _normalizePath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) return '/';
    final prefixed = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    if (prefixed.length > 1 && prefixed.endsWith('/')) {
      return prefixed.substring(0, prefixed.length - 1);
    }
    return prefixed;
  }

  static bool _isBypassPath(String path) {
    for (final allowedPath in _bypassPaths) {
      if (path == allowedPath || path.startsWith('$allowedPath/')) {
        return true;
      }
    }
    return false;
  }

  static String _valueOrDefault(String value, String fallback) {
    final normalized = value.trim();
    return normalized.isEmpty ? fallback : normalized;
  }
}
