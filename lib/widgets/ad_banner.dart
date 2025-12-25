import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:presto_app/widgets/random_asset_ticker.dart';

/// Config pour les IDs pub (remplacer par vos vrais IDs AdMob/AdSense)
class AdConfig {
  // ====== ANDROID ======
  static const String androidBannerId = 'ca-app-pub-3940256099942544/6300978111'; // TEST
  static const String androidNativeId = 'ca-app-pub-3940256099942544/2247696110'; // TEST
  static const String androidInterstitialId = 'ca-app-pub-3940256099942544/1033173712'; // TEST

  // ====== iOS ======
  static const String iosBannerId = 'ca-app-pub-3940256099942544/2934735716'; // TEST
  static const String iosNativeId = 'ca-app-pub-3940256099942544/3986624511'; // TEST
  static const String iosInterstitialId = 'ca-app-pub-3940256099942544/5135589807'; // TEST

  // ====== WEB / AdSense ======
  static const String webAdSlotId = 'ca-app-pub-3940256099942544'; // TEST (remplacer avec votre slot)
}

class AdBanner extends StatefulWidget {
  final EdgeInsetsGeometry? margin;
  final bool enabled;
  final double? placeholderHeight; // hauteur placeholder (mobile/web)
  final String? placeholderFolderPrefix; // dossier images placeholder
  final bool flat; // placeholder sans rebords

  const AdBanner({
    super.key,
    this.margin,
    this.enabled = true,
    this.placeholderHeight,
    this.placeholderFolderPrefix,
    this.flat = false,
  });

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  static bool _initialized = false;
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (e) {
      if (kDebugMode) print('AdMob init error: $e');
    }
  }

  String get _adUnitId {
    if (Platform.isAndroid) {
      return AdConfig.androidBannerId;
    } else if (Platform.isIOS) {
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
    final margin = widget.margin ?? const EdgeInsets.symmetric(vertical: 8, horizontal: 4);

    // Fonction helper: placeholder image (ticker) tant que pub non active
    Widget placeholderBanner() {
      final ph = widget.placeholderHeight ?? (kIsWeb ? 90.0 : 60.0);
      final folder = widget.placeholderFolderPrefix ?? 'assets/carousel_home/';

      if (widget.flat) {
        // Mode sans rebords: aucune décoration ni padding, l'image remplit 100% de l'espace
        return Container(
          margin: margin,
          child: SizedBox(
            height: ph,
            width: double.infinity,
            child: ClipRect(
              child: RandomAssetTicker(
                folderPrefix: folder,
                fit: BoxFit.cover,
                interval: const Duration(seconds: 4),
                antiRepeatWindow: 3,
              ),
            ),
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
        child: SizedBox(
          height: ph,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: RandomAssetTicker(
              folderPrefix: folder,
              fit: BoxFit.cover,
              interval: const Duration(seconds: 4),
              antiRepeatWindow: 3,
            ),
          ),
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
