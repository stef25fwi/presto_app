import 'package:firebase_remote_config/firebase_remote_config.dart';

class MarketplaceRemoteConfigService {
  MarketplaceRemoteConfigService({FirebaseRemoteConfig? remoteConfig})
      : _remoteConfig = remoteConfig ?? _tryGetRemoteConfig();

  static const int _defaultListingMaxPhotos = 10;
  static const int _defaultReportThresholdHint = 3;
  static const bool _defaultEnableAutoApproveCopy = true;

  final FirebaseRemoteConfig? _remoteConfig;

  static FirebaseRemoteConfig? _tryGetRemoteConfig() {
    try {
      return FirebaseRemoteConfig.instance;
    } catch (_) {
      return null;
    }
  }

  Future<void> initialize() async {
    final remoteConfig = _remoteConfig;
    if (remoteConfig == null) {
      return;
    }
    await remoteConfig.setDefaults(<String, dynamic>{
      'marketplace_listing_max_photos': _defaultListingMaxPhotos,
      'marketplace_report_threshold_hint': _defaultReportThresholdHint,
      'marketplace_enable_auto_approve_copy': _defaultEnableAutoApproveCopy,
    });
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 15),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    await remoteConfig.fetchAndActivate();
  }

  int get listingMaxPhotos =>
      _remoteConfig?.getInt('marketplace_listing_max_photos') ??
      _defaultListingMaxPhotos;

  int get reportThresholdHint =>
      _remoteConfig?.getInt('marketplace_report_threshold_hint') ??
      _defaultReportThresholdHint;

  bool get enableAutoApproveCopy =>
      _remoteConfig?.getBool('marketplace_enable_auto_approve_copy') ??
      _defaultEnableAutoApproveCopy;
}
