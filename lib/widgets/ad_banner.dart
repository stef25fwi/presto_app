import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, kReleaseMode, debugPrint, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:presto_app/widgets/ad_config.dart';
import 'package:presto_app/widgets/managed_ad_placeholder_ticker.dart';

import '../services/ads_consent_service.dart';
import '../services/cookie_consent_service.dart';

typedef AdPlaceholderBuilder = Widget Function({
  required String fallbackFolderPrefix,
  required BorderRadius borderRadius,
  required Duration interval,
  required int antiRepeatWindow,
  required bool enabled,
});

class AdBanner extends StatefulWidget {
  const AdBanner({
    super.key,
    this.margin,
    this.enabled = true,
    this.placeholderHeight,
    this.placeholderFolderPrefix,
    this.flat = false,
    this.animatePlaceholder = true,
    this.placeholderBuilder,
  });

  final EdgeInsetsGeometry? margin;
  final bool enabled;
  final double? placeholderHeight;
  final String? placeholderFolderPrefix;
  final bool flat;
  final bool animatePlaceholder;
  final AdPlaceholderBuilder? placeholderBuilder;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isLoading = false;

  String get _adUnitId {
    if (kIsWeb) return AdConfig.unsupportedAdUnitId;
    return AdConfig.bannerIdFor(
      defaultTargetPlatform,
      releaseMode: kReleaseMode,
    );
  }

  @override
  void initState() {
    super.initState();
    if (!widget.enabled || kIsWeb) return;
    CookieConsentService.instance.addListener(_onConsentChanged);
    _maybeLoad();
  }

  void _onConsentChanged() {
    if (!mounted) return;
    if (CookieConsentService.instance.canUseMarketing) {
      _maybeLoad();
      return;
    }
    _disposeAd();
  }

  void _disposeAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;
    _isLoading = false;
    if (mounted) setState(() {});
  }

  Future<void> _maybeLoad() async {
    if (!widget.enabled || kIsWeb) return;
    if (!CookieConsentService.instance.canUseMarketing) return;
    if (_isLoaded || _isLoading) return;

    _isLoading = true;
    try {
      final canRequestAds =
          await AdsConsentService.instance.initializeForAds();
      if (!canRequestAds) {
        if (kDebugMode) {
          debugPrint('[AdMob] ad request blocked by UMP consent state');
        }
        return;
      }
      if (!mounted || !CookieConsentService.instance.canUseMarketing) return;
      await _load();
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _load() async {
    final id = _adUnitId;
    if (id == AdConfig.unsupportedAdUnitId) return;

    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: id,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted || !CookieConsentService.instance.canUseMarketing) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          if (kDebugMode) {
            debugPrint('[AdMob] load failed: ${error.message}');
          }
          ad.dispose();
        },
        onAdOpened: (_) {
          if (kDebugMode) debugPrint('[AdMob] ad opened');
        },
        onAdClosed: (ad) => ad.dispose(),
      ),
    );

    try {
      await ad.load();
    } catch (error) {
      if (kDebugMode) debugPrint('[AdMob] load exception: $error');
      ad.dispose();
    }
  }

  @override
  void dispose() {
    CookieConsentService.instance.removeListener(_onConsentChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  Widget _buildTicker({
    required String folder,
    required BorderRadius radius,
    required int antiRepeatWindow,
  }) {
    final builder = widget.placeholderBuilder;
    if (builder != null) {
      return builder(
        fallbackFolderPrefix: folder,
        borderRadius: radius,
        interval: const Duration(seconds: 4),
        antiRepeatWindow: antiRepeatWindow,
        enabled: widget.animatePlaceholder,
      );
    }
    return ManagedAdPlaceholderTicker(
      fallbackFolderPrefix: folder,
      borderRadius: radius,
      interval: const Duration(seconds: 4),
      antiRepeatWindow: antiRepeatWindow,
      enabled: widget.animatePlaceholder,
    );
  }

  Widget _placeholderBanner(EdgeInsetsGeometry margin) {
    final folder = widget.placeholderFolderPrefix ?? 'assets/carousel_home/';
    if (widget.flat) {
      return Container(
        margin: margin,
        width: double.infinity,
        child: _buildTicker(
          folder: folder,
          radius: BorderRadius.circular(18),
          antiRepeatWindow: 0,
        ),
      );
    }
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 0.75),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _buildTicker(
        folder: folder,
        radius: BorderRadius.circular(6),
        antiRepeatWindow: 3,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final margin =
        widget.margin ?? const EdgeInsets.symmetric(vertical: 8, horizontal: 4);
    if (!widget.enabled || kIsWeb || !_isLoaded || _bannerAd == null) {
      return _placeholderBanner(margin);
    }
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 0.5),
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
