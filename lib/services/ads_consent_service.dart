import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Centralise Google UMP + Mobile Ads so ads are never requested before the
/// UMP consent state says that requests are allowed.
///
/// `requestConsentInfoUpdate` must run before `canRequestAds()`. The service
/// also exposes the publisher-rendered privacy-options entry point required by
/// some UMP message configurations.
class AdsConsentService extends ChangeNotifier {
  AdsConsentService._();

  static final AdsConsentService instance = AdsConsentService._();

  Future<bool>? _initialization;
  bool _mobileAdsInitialized = false;
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;

  bool get canRequestAds => _canRequestAds;
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  @visibleForTesting
  void resetForTesting() {
    _initialization = null;
    _mobileAdsInitialized = false;
    _canRequestAds = false;
    _privacyOptionsRequired = false;
  }

  /// Refreshes UMP state, presents any required consent/IDFA message, then
  /// initializes Mobile Ads only when UMP permits ad requests.
  Future<bool> initializeForAds() {
    return _initialization ??= _initializeForAds();
  }

  Future<bool> _initializeForAds() async {
    final consentCompleter = Completer<void>();

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
              if (formError != null && kDebugMode) {
                debugPrint(
                  '[AdsConsent] UMP form error '
                  '${formError.errorCode}: ${formError.message}',
                );
              }
              if (!consentCompleter.isCompleted) {
                consentCompleter.complete();
              }
            });
          } catch (error) {
            if (kDebugMode) {
              debugPrint('[AdsConsent] UMP form exception: $error');
            }
            if (!consentCompleter.isCompleted) {
              consentCompleter.complete();
            }
          }
        },
        (requestError) {
          if (kDebugMode) {
            debugPrint(
              '[AdsConsent] UMP update error '
              '${requestError.errorCode}: ${requestError.message}',
            );
          }
          if (!consentCompleter.isCompleted) {
            consentCompleter.complete();
          }
        },
      );

      await consentCompleter.future;
      await _refreshPrivacyOptionsRequirement();

      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      if (!_canRequestAds) {
        notifyListeners();
        return false;
      }

      if (!_mobileAdsInitialized) {
        await MobileAds.instance.initialize();
        _mobileAdsInitialized = true;
      }

      notifyListeners();
      return true;
    } catch (error) {
      _canRequestAds = false;
      if (kDebugMode) {
        debugPrint('[AdsConsent] initialization failed: $error');
      }
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshConsent() async {
    _initialization = null;
    await initializeForAds();
  }

  Future<void> _refreshPrivacyOptionsRequirement() async {
    try {
      _privacyOptionsRequired =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
              PrivacyOptionsRequirementStatus.required;
    } catch (error) {
      _privacyOptionsRequired = false;
      if (kDebugMode) {
        debugPrint('[AdsConsent] privacy options status failed: $error');
      }
    }
  }

  /// Displays Google's UMP privacy-options form when the active message
  /// configuration requires a publisher-rendered entry point.
  Future<void> showPrivacyOptions() async {
    await _refreshPrivacyOptionsRequirement();
    if (!_privacyOptionsRequired) return;

    final completer = Completer<void>();
    try {
      await ConsentForm.showPrivacyOptionsForm((formError) {
        if (formError != null && kDebugMode) {
          debugPrint(
            '[AdsConsent] privacy options error '
            '${formError.errorCode}: ${formError.message}',
          );
        }
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future;
      _initialization = null;
      await initializeForAds();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[AdsConsent] privacy options exception: $error');
      }
    }
  }
}
