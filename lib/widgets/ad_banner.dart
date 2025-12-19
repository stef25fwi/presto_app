import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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

  const AdBanner({super.key, this.margin, this.enabled = true});

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
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }

    final margin = widget.margin ?? const EdgeInsets.symmetric(vertical: 12, horizontal: 4);

    if (kIsWeb) {
      // Web: placeholder pour AdSense (intégré côté HTML/hosting)
      return Container(
        margin: margin,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          border: Border.all(color: const Color(0xFFDCDCDC), width: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        height: 90,
        child: const Text(
          'Publicité – Google Ads',
          style: TextStyle(
            fontSize: 11,
            color: Colors.black38,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (!_isLoaded || _bannerAd == null) {
      return SizedBox(
        height: 50,
        child: Container(color: Colors.transparent),
      );
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
