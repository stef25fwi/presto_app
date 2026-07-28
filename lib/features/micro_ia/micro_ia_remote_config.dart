import 'package:firebase_remote_config/firebase_remote_config.dart';

abstract class MicroIaRemoteConfigAdapter {
  Future<void> setDefaults(Map<String, dynamic> defaults);
  Future<void> setConfigSettings(RemoteConfigSettings settings);
  Future<bool> fetchAndActivate();
  bool getBool(String key);
  int getInt(String key);
}

class FirebaseMicroIaRemoteConfigAdapter
    implements MicroIaRemoteConfigAdapter {
  const FirebaseMicroIaRemoteConfigAdapter(this.remoteConfig);

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
  int getInt(String key) => remoteConfig.getInt(key);
}

class MicroIaRemoteConfig {
  MicroIaRemoteConfig({
    FirebaseRemoteConfig? remoteConfig,
    MicroIaRemoteConfigAdapter? adapter,
  }) : _adapter = adapter ?? _tryCreateAdapter(remoteConfig);

  static const String enabledKey = 'micro_ia_v2_enabled';
  static const String rolloutPercentKey = 'micro_ia_v2_rollout_percent';
  static const String fallbackEnabledKey = 'micro_ia_v1_fallback_enabled';

  static const bool _defaultEnabled = false;
  static const int _defaultRolloutPercent = 0;
  static const bool _defaultFallbackEnabled = true;

  final MicroIaRemoteConfigAdapter? _adapter;
  bool _initialized = false;

  static MicroIaRemoteConfigAdapter? _tryCreateAdapter(
    FirebaseRemoteConfig? remoteConfig,
  ) {
    try {
      return FirebaseMicroIaRemoteConfigAdapter(
        remoteConfig ?? FirebaseRemoteConfig.instance,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final adapter = _adapter;
    if (adapter == null) return;
    try {
      await adapter.setDefaults(<String, dynamic>{
        enabledKey: _defaultEnabled,
        rolloutPercentKey: _defaultRolloutPercent,
        fallbackEnabledKey: _defaultFallbackEnabled,
      });
      await adapter.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 8),
          minimumFetchInterval: const Duration(minutes: 15),
        ),
      );
      await adapter.fetchAndActivate();
    } catch (_) {
      // Les valeurs par défaut gardent le pipeline historique actif.
    }
  }

  bool shouldUseV2(String uid) {
    final adapter = _adapter;
    if (adapter == null || !adapter.getBool(enabledKey)) return false;
    final rollout = adapter.getInt(rolloutPercentKey).clamp(0, 100);
    if (rollout <= 0) return false;
    if (rollout >= 100) return true;
    return stableBucket(uid) < rollout;
  }

  bool get fallbackToV1Enabled =>
      _adapter?.getBool(fallbackEnabledKey) ?? _defaultFallbackEnabled;

  static int stableBucket(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash % 100;
  }
}
