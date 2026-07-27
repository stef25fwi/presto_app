import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/marketplace_remote_config_service.dart';

class _FakeRemoteConfigAdapter implements MarketplaceRemoteConfigAdapter {
  Map<String, dynamic>? defaults;
  RemoteConfigSettings? settings;
  var fetched = false;
  final ints = <String, int>{};
  final bools = <String, bool>{};

  @override
  Future<bool> fetchAndActivate() async {
    fetched = true;
    return true;
  }

  @override
  bool getBool(String key) => bools[key] ?? false;

  @override
  int getInt(String key) => ints[key] ?? 0;

  @override
  Future<void> setConfigSettings(RemoteConfigSettings value) async {
    settings = value;
  }

  @override
  Future<void> setDefaults(Map<String, dynamic> value) async {
    defaults = Map<String, dynamic>.from(value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initialise les valeurs par défaut et les réglages de récupération',
      () async {
    final adapter = _FakeRemoteConfigAdapter()
      ..ints['marketplace_listing_max_photos'] = 7
      ..ints['marketplace_report_threshold_hint'] = 4
      ..bools['marketplace_enable_auto_approve_copy'] = false;
    final service = MarketplaceRemoteConfigService(adapter: adapter);

    await service.initialize();

    expect(adapter.defaults, <String, dynamic>{
      'marketplace_listing_max_photos': 10,
      'marketplace_report_threshold_hint': 3,
      'marketplace_enable_auto_approve_copy': true,
    });
    expect(adapter.settings?.fetchTimeout, const Duration(seconds: 15));
    expect(
      adapter.settings?.minimumFetchInterval,
      const Duration(hours: 1),
    );
    expect(adapter.fetched, isTrue);
    expect(service.listingMaxPhotos, 7);
    expect(service.reportThresholdHint, 4);
    expect(service.enableAutoApproveCopy, isFalse);
  });

  test('utilise les fallbacks locaux sans Firebase initialisé', () async {
    final service = MarketplaceRemoteConfigService();

    await service.initialize();

    expect(service.listingMaxPhotos, 10);
    expect(service.reportThresholdHint, 3);
    expect(service.enableAutoApproveCopy, isTrue);
  });
}
