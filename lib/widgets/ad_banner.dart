import 'dart:async' as async;

import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, kReleaseMode, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:presto_app/widgets/managed_ad_placeholder_ticker.dart';

import '../services/cookie_consent_service.dart';

/// Blocs publicitaires AdMob.
///
/// Les blocs réels ne doivent servir **qu'en release**. Charger une publicité
/// depuis un build de développement génère du trafic invalide sur le compte
/// AdMob : c'est un motif de suspension, et cela fausse les statistiques de
/// diffusion. Les blocs de démonstration Google existent exactement pour ça et
/// sont donc utilisés partout ailleurs.
class AdConfig {
  /// Bloc bannière réel — compte `ca-app-pub-1792076968124623`, celui déclaré
  /// dans `AndroidManifest.xml` et `Info.plist`.
  static const String androidBannerId =
      'ca-app-pub-1792076968124623/1951540793';
  static const String iosBannerId =
      'ca-app-pub-1792076968124623/4960847514';

  /// Blocs de démonstration publiés par Google : ils renvoient toujours une
  /// publicité de test et ne créditent aucun revenu.
  static const String androidTestBannerId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String iosTestBannerId =
      'ca-app-pub-3940256099942544/2934735716';

  /// Bloc bannière à utiliser pour une plateforme donnée.
  ///
  /// `releaseMode` est un paramètre plutôt qu'une lecture directe de
  /// `kReleaseMode` pour que les deux branches soient vérifiables en test —
  /// la suite de tests s'exécute toujours en mode debug.
  static String bannerIdFor(
    TargetPlatform platform, {
    required bool releaseMode,
  }) {
    switch (platform) {
      case TargetPlatform.android:
        return releaseMode ? androidBannerId : androidTestBannerId;
      case TargetPlatform.iOS:
        return releaseMode ? iosBannerId : iosTestBannerId;
      default:
        return unsupportedAdUnitId;
    }
  }

  static const String unsupportedAdUnitId = 'unsupported';
}

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
  static bool _initialized = false;
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isLoading = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      final consentCompleter = async.Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            ConsentForm.loadAndShowConsentFormIfRequired((formError) {
              if (kDebugMode && formError != null) {
                debugPrint('[AdMob] UMP form error: ${formError.message}');
              }
              consentCompleter.complete();
            });
          } else {
            consentCompleter.complete();
          }
        },
        (requestError) {
          if (kDebugMode) {
            debugPrint('[AdMob] UMP request error: ${requestError.message}');
          }
          consentCompleter.complete();
        },
      );
      await consentCompleter.future;
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (error) {
      if (kDebugMode) debugPrint('[AdMob] init error: $error');
    }
  }

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
    if (_bannerAd == null) return;
    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;
    _isLoading = false;
    setState(() {});
  }

  Future<void> _maybeLoad() async {
    if (!widget.enabled || kIsWeb) return;
    if (!CookieConsentService.instance.canUseMarketing) return;
    if (_isLoaded || _isLoading) return;
    _isLoading = true;
    try {
      await _load();
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _load() async {
    await _ensureInitialized();
    final id = _adUnitId;
    if (id == AdConfig.unsupportedAdUnitId) return;
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: id,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
        onAdOpened: (_) {
          if (kDebugMode) print('Ad opened');
        },
        onAdClosed: (ad) => ad.dispose(),
      ),
    );
    try {
      await ad.load();
    } catch (error) {
      if (kDebugMode) print('Ad load error: $error');
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
