import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/micro_ia/micro_ia_remote_config.dart';

class _FakeAdapter implements MicroIaRemoteConfigAdapter {
  final Map<String, dynamic> values = <String, dynamic>{};
  int defaultsCalls = 0;
  int settingsCalls = 0;
  int fetchCalls = 0;
  RemoteConfigSettings? capturedSettings;
  Object? failure;

  @override
  Future<bool> fetchAndActivate() async {
    fetchCalls++;
    final error = failure;
    if (error != null) throw error;
    return true;
  }

  @override
  bool getBool(String key) => values[key] as bool? ?? false;

  @override
  int getInt(String key) => values[key] as int? ?? 0;

  @override
  Future<void> setConfigSettings(RemoteConfigSettings settings) async {
    settingsCalls++;
    capturedSettings = settings;
  }

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) async {
    defaultsCalls++;
    for (final entry in defaults.entries) {
      values.putIfAbsent(entry.key, () => entry.value);
    }
  }
}

void main() {
  test('V2 stays disabled by default', () async {
    final adapter = _FakeAdapter();
    final config = MicroIaRemoteConfig(adapter: adapter);
    await config.initialize();

    expect(config.shouldUseV2('user-1'), isFalse);
    expect(config.fallbackToV1Enabled, isTrue);
  });

  test('initialize configure les valeurs, délais et ne s exécute qu une fois',
      () async {
    final adapter = _FakeAdapter();
    final config = MicroIaRemoteConfig(adapter: adapter);

    await config.initialize();
    await config.initialize();

    expect(adapter.defaultsCalls, 1);
    expect(adapter.settingsCalls, 1);
    expect(adapter.fetchCalls, 1);
    expect(
      adapter.values,
      containsPair(MicroIaRemoteConfig.enabledKey, false),
    );
    expect(
      adapter.values,
      containsPair(MicroIaRemoteConfig.rolloutPercentKey, 0),
    );
    expect(
      adapter.values,
      containsPair(MicroIaRemoteConfig.fallbackEnabledKey, true),
    );
    expect(adapter.capturedSettings?.fetchTimeout, const Duration(seconds: 8));
    expect(
      adapter.capturedSettings?.minimumFetchInterval,
      const Duration(minutes: 15),
    );
  });

  test('initialize absorbe une erreur de récupération sans nouvelle tentative',
      () async {
    final adapter = _FakeAdapter()..failure = StateError('remote config down');
    final config = MicroIaRemoteConfig(adapter: adapter);

    await config.initialize();
    await config.initialize();

    expect(adapter.defaultsCalls, 1);
    expect(adapter.settingsCalls, 1);
    expect(adapter.fetchCalls, 1);
    expect(config.shouldUseV2('user-1'), isFalse);
    expect(config.fallbackToV1Enabled, isTrue);
  });

  test('100 percent rollout selects V2 for every user', () async {
    final adapter = _FakeAdapter();
    adapter.values[MicroIaRemoteConfig.enabledKey] = true;
    adapter.values[MicroIaRemoteConfig.rolloutPercentKey] = 100;
    final config = MicroIaRemoteConfig(adapter: adapter);
    await config.initialize();

    expect(config.shouldUseV2('user-1'), isTrue);
    expect(config.shouldUseV2('user-2'), isTrue);
  });

  test('rollout est borné et le drapeau enabled reste prioritaire', () async {
    final adapter = _FakeAdapter();
    final config = MicroIaRemoteConfig(adapter: adapter);
    await config.initialize();

    adapter.values[MicroIaRemoteConfig.rolloutPercentKey] = 150;
    expect(config.shouldUseV2('user-1'), isFalse);

    adapter.values[MicroIaRemoteConfig.enabledKey] = true;
    adapter.values[MicroIaRemoteConfig.rolloutPercentKey] = -10;
    expect(config.shouldUseV2('user-1'), isFalse);

    adapter.values[MicroIaRemoteConfig.rolloutPercentKey] = 150;
    expect(config.shouldUseV2('user-1'), isTrue);
  });

  test('rollout partiel utilise le bucket stable de l utilisateur', () async {
    final adapter = _FakeAdapter();
    adapter.values[MicroIaRemoteConfig.enabledKey] = true;
    adapter.values[MicroIaRemoteConfig.rolloutPercentKey] = 50;
    final config = MicroIaRemoteConfig(adapter: adapter);
    await config.initialize();

    final selected = List<String>.generate(500, (index) => 'user-$index')
        .firstWhere((uid) => MicroIaRemoteConfig.stableBucket(uid) < 50);
    final excluded = List<String>.generate(500, (index) => 'other-$index')
        .firstWhere((uid) => MicroIaRemoteConfig.stableBucket(uid) >= 50);

    expect(config.shouldUseV2(selected), isTrue);
    expect(config.shouldUseV2(excluded), isFalse);
  });

  test('fallback V1 reflète la valeur distante explicite', () async {
    final adapter = _FakeAdapter();
    adapter.values[MicroIaRemoteConfig.fallbackEnabledKey] = false;
    final config = MicroIaRemoteConfig(adapter: adapter);
    await config.initialize();

    expect(config.fallbackToV1Enabled, isFalse);
  });

  test('stable bucket is deterministic and remains inside 0..99', () {
    final first = MicroIaRemoteConfig.stableBucket('same-user');
    final second = MicroIaRemoteConfig.stableBucket('same-user');

    expect(first, second);
    expect(first, inInclusiveRange(0, 99));
    expect(MicroIaRemoteConfig.stableBucket(''), inInclusiveRange(0, 99));
  });
}
