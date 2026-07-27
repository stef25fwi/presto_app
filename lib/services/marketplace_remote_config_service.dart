import 'package:firebase_remote_config/firebase_remote_config.dart';

abstract class MarketplaceRemoteConfigAdapter {
  Future<void> setDefaults(Map<String, dynamic> defaults);

  Future<void> setConfigSettings(RemoteConfigSettings settings);

  Future<bool> fetchAndActivate();

  int getInt(String key);

  bool getBool(String key);
}

class FirebaseMarketplaceRemoteConfigAdapter
    implements MarketplaceRemoteConfigAdapter {
  const FirebaseMarketplaceRemoteConfigAdapter(this.remoteConfig);

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
  int getInt(String key) => remoteConfig.getInt(key);

  @override
  bool getBool(String key) => remoteConfig.getBool(key);
}

class MarketplaceRemoteConfigService {
  MarketplaceRemoteConfigService({
    FirebaseRemoteConfig? remoteConfig,
    MarketplaceRemoteConfigAdapter? adapter,
  }) : _adapter = adapter ?? _tryCreateAdapter(remoteConfig);

  static const int _defaultListingMaxPhotos = 10;
  static const int _defaultReportThresholdHint = 3;
  static const bool _defaultEnableAutoApproveCopy = true;

  final MarketplaceRemoteConfigAdapter? _adapter;

  static MarketplaceRemoteConfigAdapter? _tryCreateAdapter(
    FirebaseRemoteConfig? remoteConfig,
  ) {
    try {
      return FirebaseMarketplaceRemoteConfigAdapter(
        remoteConfig ?? FirebaseRemoteConfig.instance,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> initialize() async {
    final adapter = _adapter;
    if (adapter == null) return;

    await adapter.setDefaults(<String, dynamic>{
      'marketplace_listing_max_photos': _defaultListingMaxPhotos,
      'marketplace_report_threshold_hint': _defaultReportThresholdHint,
      'marketplace_enable_auto_approve_copy': _defaultEnableAutoApproveCopy,
    });
    await adapter.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 15),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    await adapter.fetchAndActivate();
  }

  int get listingMaxPhotos =>
      _adapter?.getInt('marketplace_listing_max_photos') ??
      _defaultListingMaxPhotos;

  int get reportThresholdHint =>
      _adapter?.getInt('marketplace_report_threshold_hint') ??
      _defaultReportThresholdHint;

  bool get enableAutoApproveCopy =>
      _adapter?.getBool('marketplace_enable_auto_approve_copy') ??
      _defaultEnableAutoApproveCopy;
}
