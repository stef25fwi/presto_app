import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/micro_ia/micro_ia_remote_config.dart';

class _FakeAdapter implements MicroIaRemoteConfigAdapter {
  final Map<String, dynamic> values = <String, dynamic>{};

  @override
  Future<bool> fetchAndActivate() async => true;

  @override
  bool getBool(String key) => values[key] as bool? ?? false;

  @override
  int getInt(String key) => values[key] as int? ?? 0;

  @override
  Future<void> setConfigSettings(RemoteConfigSettings settings) async {}

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) async {
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

  test('100 percent rollout selects V2 for every user', () async {
    final adapter = _FakeAdapter();
    adapter.values[MicroIaRemoteConfig.enabledKey] = true;
    adapter.values[MicroIaRemoteConfig.rolloutPercentKey] = 100;
    final config = MicroIaRemoteConfig(adapter: adapter);
    await config.initialize();

    expect(config.shouldUseV2('user-1'), isTrue);
    expect(config.shouldUseV2('user-2'), isTrue);
  });

  test('stable bucket is deterministic and remains inside 0..99', () {
    final first = MicroIaRemoteConfig.stableBucket('same-user');
    final second = MicroIaRemoteConfig.stableBucket('same-user');

    expect(first, second);
    expect(first, inInclusiveRange(0, 99));
  });
}
