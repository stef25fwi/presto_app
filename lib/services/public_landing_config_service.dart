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

  static PublicLandingConfigService? _instance;

  /// Singleton créé uniquement au premier accès depuis l'application.
  ///
  /// L'initialisation paresseuse évite de toucher Firebase Remote Config lors
  /// du simple import de cette bibliothèque, notamment dans les tests widget
  /// qui injectent leur propre adaptateur avant Firebase.initializeApp().
  static PublicLandingConfigService get instance =>
      _instance ??= PublicLandingConfigService();

  static const String enabledKey = 'public_landing_enabled';
  static const String badgeKey = 'public_landing_badge';
  static const String titleKey = 'public_landing_title';
  static const String descriptionKey = 'public_landing_description';
  static const String launchMessageKey = 'public_landing_launch_message';

  static const bool defaultEnabled = true;
  static const String defaultBadge = 'Bientôt disponible';
  static const String defaultTitle =
      'La solution à tout moment pour tous vos besoins du quotidien';
  static const String defaultDescription =
      'Publiez une annonce assistée par IA à partir d’un texte ou de votre voix '
      'pour vos besoins du quotidien. iliprestō ne prélève aucune commission sur '
      'vos prestations et ne collecte ni ne gère les paiements entre utilisateurs. '
      'Vous échangez et convenez directement des conditions de la mission.';
  static const String defaultLaunchMessage =
      'Site national en cours de déploiement. Première ouverture en Guadeloupe, '
      'Martinique et Guyane.';

  static const Set<String> _legacyDefaultTitles = <String>{
    'La solution instantanée pour trouver un service près de chez vous',
    'Trouvez rapidement un particulier ou un professionnel près de chez vous',
    'Trouvez rapidement un particulier, un indépendant ou un professionnel '
        'près de chez vous',
  };
  static const Set<String> _legacyDefaultDescriptions = <String>{
    'iliprestō est un site de petites annonces de services et micro-services '
        'du quotidien. Publiez votre besoin, indiquez votre prix ou votre budget '
        'et trouvez un particulier, un indépendant ou un professionnel disponible '
        'à l’instant près de chez vous. Les personnes disponibles peuvent vous '
        'contacter immédiatement, avec 0 % de commission.',
    'iliprestō met en relation particuliers, indépendants et professionnels '
        'pour répondre rapidement à vos besoins en services et microservices du '
        'quotidien, avec des annonces assistées par IA et 0 % de commission.',
    'Trouvez rapidement un particulier, un indépendant ou un professionnel '
        'partout en France. Publiez une annonce assistée par IA et échangez '
        'directement, avec 0 % de commission.',
    'Publiez votre besoin en quelques secondes, par texte ou à la voix. '
        'Votre annonce est assistée par IA et vous échangez directement avec '
        'des particuliers, indépendants et professionnels, sans commission.',
  };
  static const Set<String> _legacyDefaultLaunchMessages = <String>{
    'Ouverture prochaine en Guadeloupe, Martinique et Guyane.',
    'Plateforme nationale en cours de déploiement. Première ouverture en '
        'Guadeloupe, Martinique et Guyane.',
  };

  static const Set<String> _publicHosts = <String>{
    'ilipresto.fr',
    'www.ilipresto.fr',
    'ilipresto.web.app',
    'ilipresto.firebaseapp.com',
    'presto-app-74abe.web.app',
    'presto-app-74abe.firebaseapp.com',
  };

  /// Seules les deux pages juridiques explicitement autorisées restent
  /// consultables pendant la préouverture. Toutes les autres routes, y compris
  /// authentification, administration, confidentialité et suppression de compte,
  /// restent couvertes par la page « bientôt disponible ».
  static const Set<String> bypassPaths = <String>{
    '/mentions-legales',
    '/cgu',
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

    // Remote Config peut encore contenir les anciennes valeurs publiées.
    // Cette migration maintient immédiatement le nouveau positionnement SEO
    // sans attendre une modification manuelle de la console Firebase.
    if (_legacyDefaultTitles.contains(_title)) {
      _title = defaultTitle;
    }
    if (_legacyDefaultDescriptions.contains(_description)) {
      _description = defaultDescription;
    }
    if (_legacyDefaultLaunchMessages.contains(_launchMessage)) {
      _launchMessage = defaultLaunchMessage;
    }
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
    for (final allowedPath in bypassPaths) {
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
