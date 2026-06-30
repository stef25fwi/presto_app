import 'dart:async' as async;
import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:presto_app/widgets/managed_ad_placeholder_ticker.dart';

/// Config pour les IDs pub AdMob production
class AdConfig {
  // ====== ANDROID (fr.ilipresto.app) ======
  static const String androidBannerId =
      'ca-app-pub-1792076968124623/1951540793'; // PROD
  static const String androidNativeId =
      'ca-app-pub-3940256099942544/2247696110'; // non utilisé — remplacer si activé
  static const String androidInterstitialId =
      'ca-app-pub-3940256099942544/1033173712'; // non utilisé — remplacer si activé

  // ====== iOS (fr.ilipresto.app) ======
  static const String iosBannerId =
      'ca-app-pub-1792076968124623/4960847514'; // PROD
  static const String iosNativeId =
      'ca-app-pub-3940256099942544/3986624511'; // non utilisé — remplacer si activé
  static const String iosInterstitialId =
      'ca-app-pub-3940256099942544/5135589807'; // non utilisé — remplacer si activé

  // ====== WEB / AdSense ======
  static const String webAdSlotId =
      'ca-app-pub-1792076968124623'; // Publisher ID production
}

class AdBanner extends StatefulWidget {
  final EdgeInsetsGeometry? margin;
  final bool enabled;
  final double? placeholderHeight; // hauteur placeholder (mobile/web)
  final String? placeholderFolderPrefix; // dossier images placeholder
  final bool flat; // placeholder sans rebords
  final bool animatePlaceholder; // anime le placeholder (ticker)

  const AdBanner({
    super.key,
    this.margin,
    this.enabled = true,
    this.placeholderHeight,
    this.placeholderFolderPrefix,
    this.flat = false,
    this.animatePlaceholder = true,
  });

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  static bool _initialized = false;
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  // Demande le consentement UMP (Google User Messaging Platform) puis
  // initialise MobileAds. Obligatoire pour les utilisateurs EEA (RGPD).
  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      final params = ConsentRequestParameters();
      final consentCompleter = async.Completer<void>();

      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          // Afficher le formulaire de consentement si disponible et requis.
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            ConsentForm.loadAndShowConsentFormIfRequired(
              (formError) {
                // Erreur formulaire : on initialise quand même pour les
                // utilisateurs hors EEA ou si le consentement n'est pas requis.
                if (kDebugMode && formError != null) {
                  debugPrint('[AdMob] UMP form error: ${formError.message}');
                }
                consentCompleter.complete();
              },
            );
          } else {
            consentCompleter.complete();
          }
        },
        (requestError) {
          // Erreur réseau UMP : initialiser ads sans consentement (hors EEA).
          if (kDebugMode) {
            debugPrint('[AdMob] UMP request error: ${requestError.message}');
          }
          consentCompleter.complete();
        },
      );

      await consentCompleter.future;
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[AdMob] init error: $e');
    }
  }

  String get _adUnitId {
    if (kIsWeb) return 'unsupported';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AdConfig.androidBannerId;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AdConfig.iosBannerId;
    }
    return 'unsupported';
  }

  @override
  void initState() {
    super.initState();
    if (!widget.enabled || kIsWeb) return;
    _load();
  }

  Future<void> _load() async {
    await _ensureInitialized();

    final id = _adUnitId;
    if (id == 'unsupported') return;

    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: id,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (mounted) {
            setState(() {
              _bannerAd = ad as BannerAd;
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
        },
        onAdOpened: (Ad ad) {
          if (kDebugMode) print('Ad opened');
        },
        onAdClosed: (Ad ad) {
          ad.dispose();
        },
      ),
    );

    try {
      await ad.load();
    } catch (e) {
      if (kDebugMode) print('Ad load error: $e');
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Placeholder margin commun
    final margin =
        widget.margin ?? const EdgeInsets.symmetric(vertical: 8, horizontal: 4);

    // Fonction helper: placeholder image (ticker) tant que pub non active
    Widget placeholderBanner() {
      // ignore: unused_local_variable
      final ph = widget.placeholderHeight ?? (kIsWeb ? 90.0 : 60.0);
      final folder = widget.placeholderFolderPrefix ?? 'assets/carousel_home/';

      if (widget.flat) {
        // Placeholder plein format pour la page Je consulte :
        // largeur pleine + hauteur automatique selon le ratio réel de l’image.
        return Container(
          margin: margin,
          width: double.infinity,
          child: ManagedAdPlaceholderTicker(
            fallbackFolderPrefix: folder,
            borderRadius: BorderRadius.circular(18),
            interval: const Duration(seconds: 4),
            enabled: widget.animatePlaceholder,
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
        child: ManagedAdPlaceholderTicker(
          fallbackFolderPrefix: folder,
          borderRadius: BorderRadius.circular(6),
          interval: const Duration(seconds: 4),
          antiRepeatWindow: 3,
          enabled: widget.animatePlaceholder,
        ),
      );
    }

    // Si explicitement désactivé: affichage placeholder images
    if (!widget.enabled) {
      return placeholderBanner();
    }

    if (kIsWeb) {
      // Web: afficher aussi placeholder images tant qu'AdSense n'est pas branché
      return placeholderBanner();
    }

    if (!_isLoaded || _bannerAd == null) {
      // Mobile: pub non chargée => afficher placeholder images
      return placeholderBanner();
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
