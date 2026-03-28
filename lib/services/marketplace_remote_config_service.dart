import 'package:firebase_remote_config/firebase_remote_config.dart';

class MarketplaceRemoteConfigService {
  MarketplaceRemoteConfigService({FirebaseRemoteConfig? remoteConfig})
      : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _remoteConfig;

  Future<void> initialize() async {
    await _remoteConfig.setDefaults(<String, dynamic>{
      'marketplace_listing_max_photos': 10,
      'marketplace_report_threshold_hint': 3,
      'marketplace_enable_auto_approve_copy': true,
    });
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 15),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    await _remoteConfig.fetchAndActivate();
  }

  int get listingMaxPhotos => _remoteConfig.getInt('marketplace_listing_max_photos');

  int get reportThresholdHint => _remoteConfig.getInt('marketplace_report_threshold_hint');

  bool get enableAutoApproveCopy =>
      _remoteConfig.getBool('marketplace_enable_auto_approve_copy');
}