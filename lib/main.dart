// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_element_parameter

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app/theme.dart';
import 'app_core.dart';
import 'constants.dart';
import 'firebase_options.dart';
import 'dev/seed_offers.dart';
import 'features/ai_draft/ai_draft_service.dart';
import 'features/micro_ia/micro_ia_service.dart';
import 'features/micro_ia/web_audio_recorder.dart';
import 'profile_page.dart';
import 'pages/admin_space_page.dart';
import 'pages/legal_info_page.dart';
import 'pages/offers/offer_details_page.dart';
import 'pages/messages/conversations_list_page.dart';
import 'pages/pro_profile_page.dart';
import 'pages/toolbox_hub_page.dart';
import 'services/city_search.dart';
import 'services/account_social_auth_actions.dart';
import 'services/google_auth_service.dart';
import 'services/email_action_service.dart';
import 'services/notification_service.dart';
import 'services/offer_indexing.dart';
import 'utils/crashlytics_context.dart';
import 'utils/friendly_snackbar.dart';
import 'utils/recording_path_web.dart'
    if (dart.library.io) 'utils/recording_path_io.dart';
import 'widgets/ad_banner.dart';
import 'widgets/account_admin_analytics_panel.dart';
import 'widgets/account_admin_micro_ia_panel.dart';
import 'widgets/account_build_version_panel.dart';
import 'widgets/account_profile_sections.dart';
import 'widgets/entrepreneur_toolbox_slide.dart';
import 'widgets/home_bottom_nav_item.dart';
import 'widgets/presto_info_icon_animated.dart';
import 'widgets/premium_ai_button.dart';
import 'widgets/phone_input_field.dart';
import 'widgets/photo_selector_tile.dart';

class PrestoRemoteConfig {
  static String audioPipeline = 'HYBRID';

  static Future<void> init() async {}
}

const kPrestoOrange = Color(0xFFFF6600);
const kPrestoBlue = Color(0xFF1A73E8);

Filter _publicOffersFilter() {
  return Filter.or(
    Filter('visibility.isPublic', isEqualTo: true),
    Filter('status', isEqualTo: 'active'),
  );
}

bool _isPublishedOfferData(Map<String, dynamic> data) {
  final isPublished = data['isPublished'];
  if (isPublished is bool && isPublished) return true;

  final status = (data['status'] ?? '').toString().trim().toLowerCase();
  if (status == 'published' || status == 'active') return true;

  final visibility = data['visibility'];
  if (visibility is Map) {
    final isPublic = visibility['isPublic'];
    if (isPublic is bool && isPublic) return true;
  }

  final isActive = data['isActive'];
  if (isActive is bool && isActive) return true;
  return false;
}

class _HomeCategoryShortcut {
  final IconData icon;
  final String label;
  final String targetCategory;

  const _HomeCategoryShortcut({
    required this.icon,
    required this.label,
    required this.targetCategory,
  });
}

const String kAppBuildSha =
    String.fromEnvironment('APP_BUILD_SHA', defaultValue: 'local');
const String kAppBuildBranch =
    String.fromEnvironment('APP_BUILD_BRANCH', defaultValue: '');
const String kAppBuildTimeUtc =
    String.fromEnvironment('APP_BUILD_TIME', defaultValue: '');
const String kAppBuildTag =
    String.fromEnvironment('APP_BUILD_TAG', defaultValue: '');

class PrestoMonitoring extends ChangeNotifier {
  static final PrestoMonitoring I = PrestoMonitoring._();

  PrestoMonitoring._();

  bool enabled = true;
  bool verboseLogs = false;
  bool monitorOffersStream = true;
  bool monitorOffersFetchOnce = true;
  bool monitorMessagesFetchOnce = true;
  bool monitorFunctionsCalls = true;
  bool monitorOtherStreams = true;

  DateTime sessionStart = DateTime.now();

  int offersQueryBuildCount = 0;
  int offersSnapshotsCount = 0;
  int offersFetchOnceCount = 0;
  int messagesFetchOnceCount = 0;
  int functionsCallsCount = 0;
  int errorsCount = 0;

  int otherStreamsEvents = 0;
  final Map<String, int> otherStreamEventCounts = <String, int>{};
  final Map<String, int> otherStreamLastDocs = <String, int>{};
  String? lastOtherStreamKey;
  int lastOtherStreamDocs = 0;

  int lastOffersSnapshotDocs = 0;
  int lastOffersFetchDocs = 0;
  int lastMessagesFetchDocs = 0;
  int lastOffersFetchMs = 0;
  int lastMessagesFetchMs = 0;
  int lastFunctionsCallMs = 0;
  String? lastOffersQuerySignature;
  String? lastError;

  String get sessionDurationLabel {
    final d = DateTime.now().difference(sessionStart);
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  void _maybeLog(String msg) {
    if (!verboseLogs || !kDebugMode) return;
    debugPrint('[MONITOR] $msg');
  }

  void setEnabled(bool v) {
    enabled = v;
    notifyListeners();
  }

  void setVerbose(bool v) {
    verboseLogs = v;
    notifyListeners();
  }

  void setMonitorOffersStream(bool v) {
    monitorOffersStream = v;
    notifyListeners();
  }

  void setMonitorOffersFetchOnce(bool v) {
    monitorOffersFetchOnce = v;
    notifyListeners();
  }

  void setMonitorMessagesFetchOnce(bool v) {
    monitorMessagesFetchOnce = v;
    notifyListeners();
  }

  void setMonitorFunctionsCalls(bool v) {
    monitorFunctionsCalls = v;
    notifyListeners();
  }

  void setMonitorOtherStreams(bool v) {
    monitorOtherStreams = v;
    notifyListeners();
  }

  void reset() {
    sessionStart = DateTime.now();
    offersQueryBuildCount = 0;
    offersSnapshotsCount = 0;
    offersFetchOnceCount = 0;
    messagesFetchOnceCount = 0;
    functionsCallsCount = 0;
    errorsCount = 0;
    lastOffersSnapshotDocs = 0;
    lastOffersFetchDocs = 0;
    lastMessagesFetchDocs = 0;
    lastOffersFetchMs = 0;
    lastMessagesFetchMs = 0;
    lastFunctionsCallMs = 0;
    lastOffersQuerySignature = null;
    lastError = null;
    otherStreamsEvents = 0;
    otherStreamEventCounts.clear();
    otherStreamLastDocs.clear();
    lastOtherStreamKey = null;
    lastOtherStreamDocs = 0;
    notifyListeners();
  }

  void trackError(String scope, Object e) {
    if (!enabled) return;
    errorsCount++;
    lastError = '$scope: ${e.toString()}';
    _maybeLog('ERROR $lastError');
    notifyListeners();
  }

  void trackOffersQueryBuild({String? signature}) {
    if (!enabled || !monitorOffersStream) return;
    offersQueryBuildCount++;
    if (signature != null && signature.trim().isNotEmpty) {
      lastOffersQuerySignature = signature;
    }
    _maybeLog('offers.query.build count=$offersQueryBuildCount');
    notifyListeners();
  }

  void trackOffersSnapshot(int docsCount) {
    if (!enabled || !monitorOffersStream) return;
    offersSnapshotsCount++;
    lastOffersSnapshotDocs = docsCount;
    _maybeLog('offers.snapshot docs=$docsCount count=$offersSnapshotsCount');
    notifyListeners();
  }

  void trackOffersFetchOnce({required int ms, required int docsCount}) {
    if (!enabled || !monitorOffersFetchOnce) return;
    offersFetchOnceCount++;
    lastOffersFetchMs = ms;
    lastOffersFetchDocs = docsCount;
    _maybeLog('offers.fetchOnce ms=$ms docs=$docsCount');
    notifyListeners();
  }

  void trackMessagesFetchOnce({required int ms, required int docsCount}) {
    if (!enabled || !monitorMessagesFetchOnce) return;
    messagesFetchOnceCount++;
    lastMessagesFetchMs = ms;
    lastMessagesFetchDocs = docsCount;
    _maybeLog('messages.fetchOnce ms=$ms docs=$docsCount');
    notifyListeners();
  }

  void trackFunctionsCall({required String name, required int ms}) {
    if (!enabled || !monitorFunctionsCalls) return;
    functionsCallsCount++;
    lastFunctionsCallMs = ms;
    _maybeLog('functions.call name=$name ms=$ms');
    notifyListeners();
  }

  void trackOtherStream({required String key, required int docsCount}) {
    if (!enabled || !monitorOtherStreams) return;
    otherStreamsEvents++;
    otherStreamEventCounts[key] = (otherStreamEventCounts[key] ?? 0) + 1;
    otherStreamLastDocs[key] = docsCount;
    lastOtherStreamKey = key;
    lastOtherStreamDocs = docsCount;
    _maybeLog('stream.other key=$key docs=$docsCount');
    notifyListeners();
  }
}

SystemUiOverlayStyle prestoOverlayStyleFor(Color backgroundColor) {
  final estimated = ThemeData.estimateBrightnessForColor(backgroundColor);
  final isDarkBackground = estimated == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: backgroundColor,
    statusBarIconBrightness:
        isDarkBackground ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDarkBackground ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: backgroundColor,
    systemNavigationBarDividerColor: backgroundColor,
    systemNavigationBarIconBrightness:
        isDarkBackground ? Brightness.light : Brightness.dark,
  );
}

const Map<String, String> kCityPostalMap = {
  'Baie-Mahault': '97122',
  'Les Abymes': '97139',
  'Pointe-à-Pitre': '97110',
  'Le Gosier': '97190',
  'Sainte-Anne': '97180',
  'Saint-François': '97118',
  'Petit-Bourg': '97170',
  'Lamentin': '97129',
  'Capesterre-Belle-Eau': '97130',
  'Basse-Terre': '97100',
  'Goyave': '97128',
  'Morne-à-l\'Eau': '97111',
  'Sainte-Rose': '97115',
  'Le Moule': '97160',
  'Saint-Claude': '97120',
  'Bouillante': '97125',
  'Deshaies': '97126',
  'Trois-Rivières': '97114',
  'Vieux-Habitants': '97119',
  'Vieux-Fort': '97141',
  'Anse-Bertrand': '97121',
  'Port-Louis': '97117',
  'Petit-Canal': '97131',
  'La Désirade': '97127',
  'Terre-de-Bas': '97136',
  'Terre-de-Haut': '97137',
  'Marie-Galante': '97140',
  'Fort-de-France': '97200',
  'Le Lamentin': '97232',
  'Schoelcher': '97233',
  'Le Robert': '97231',
  'Le François': '97240',
  'Le Marin': '97290',
  'Les Trois-Îlets': '97229',
  'Sainte-Luce': '97228',
  'Sainte-Anne (MQ)': '97227',
  'La Trinité': '97220',
  'Le Lorrain': '97214',
  'Le Carbet': '97221',
  'Le Diamant': '97223',
  'Saint-Esprit': '97270',
};

String? inferRegionFromPostalCode(String cp) {
  cp = cp.trim();
  if (cp.length < 2) return null;

  if (cp.length >= 3) {
    final dromPrefix = cp.substring(0, 3);
    switch (dromPrefix) {
      case '971':
        return 'Guadeloupe';
      case '972':
        return 'Martinique';
      case '973':
        return 'Guyane';
      case '974':
        return 'La Réunion';
      case '976':
        return 'Mayotte';
    }
  }

  if (cp.startsWith('20')) {
    return 'Corse';
  }

  final two = int.tryParse(cp.substring(0, 2));
  if (two == null) return null;

  if (<int>{1, 3, 7, 15, 26, 38, 42, 43, 63, 69, 73, 74}.contains(two)) {
    return 'Auvergne-Rhône-Alpes';
  }

  if (<int>{21, 25, 39, 58, 70, 71, 89, 90}.contains(two)) {
    return 'Bourgogne-Franche-Comté';
  }

  // Bretagne
  if (<int>{22, 29, 35, 56}.contains(two)) {
    return 'Bretagne';
  }

  // Centre-Val de Loire
  if (<int>{18, 28, 36, 37, 41, 45}.contains(two)) {
    return 'Centre-Val de Loire';
  }

  // Grand Est
  if (<int>{8, 10, 51, 52, 54, 55, 57, 67, 68, 88}.contains(two)) {
    return 'Grand Est';
  }

  // Hauts-de-France
  if (<int>{2, 59, 60, 62, 80}.contains(two)) {
    return 'Hauts-de-France';
  }

  // Île-de-France
  if (<int>{75, 77, 78, 91, 92, 93, 94, 95}.contains(two)) {
    return 'Île-de-France';
  }

  // Normandie
  if (<int>{14, 27, 50, 61, 76}.contains(two)) {
    return 'Normandie';
  }

  // Nouvelle-Aquitaine
  if (<int>{16, 17, 19, 23, 24, 33, 40, 47, 64, 79, 86, 87}.contains(two)) {
    return 'Nouvelle-Aquitaine';
  }

  // Occitanie
  if (<int>{9, 11, 12, 30, 31, 32, 34, 46, 48, 65, 66, 81, 82}.contains(two)) {
    return 'Occitanie';
  }

  // Pays de la Loire
  if (<int>{44, 49, 53, 72, 85}.contains(two)) {
    return 'Pays de la Loire';
  }

  // Provence-Alpes-Côte d'Azur
  if (<int>{4, 5, 6, 13, 83, 84}.contains(two)) {
    return 'Provence-Alpes-Côte d\'Azur';
  }

  // Si on n'a rien trouvé, on ne force pas
  return null;
}

/// ============= WIDGETS HELPER POUR OfferDetailPage =============

String _offerDetailsPublishedLabel(dynamic raw) {
  if (raw is Timestamp) {
    final publishedAt = raw.toDate();
    final diff = DateTime.now().difference(publishedAt);

    if (diff.inMinutes < 1) return 'Publiee a l\'instant';
    if (diff.inHours < 1) return 'Publiee il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Publiee il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Publiee il y a ${diff.inDays} j';
  }

  return 'Publication recente';
}

Offer _buildOfferDetailsOffer({
  required String offerId,
  required Map<String, dynamic> data,
}) {
  final title = (data['title'] ?? '').toString().trim();
  final location = ((data['location'] ?? data['city']) ?? '').toString().trim();
  final postalCode =
      ((data['postalCode'] ?? data['cp']) ?? '').toString().trim();
  final category = (data['category'] ?? '').toString().trim();
  final description = (data['description'] ?? '').toString().trim();
  final isUrgent = (data['urgent'] as bool?) ?? false;
  final budget = data['budget'];
  final price = budget is num ? budget.toDouble() : 0.0;
  final imageUrls = (data['imageUrls'] as List<dynamic>? ?? const [])
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList();
  final advertiserName =
      ((data['userName'] ?? data['pseudo']) ?? '').toString().trim();
  final serviceArea =
      (data['serviceArea'] ?? (location.isEmpty ? 'Zone locale' : location))
          .toString();
  final missionDelay =
      ((data['missionDelay'] ?? data['averageDelay']) ?? 'Délai non précisé')
          .toString();

  return Offer(
    id: offerId,
    title: title.isEmpty ? 'Annonce' : title,
    price: price,
    category: category.isEmpty ? 'Categorie non precisee' : category,
    city: location.isEmpty ? 'Lieu non precise' : location,
    postalCode: postalCode,
    isUrgent: isUrgent,
    publishedAtLabel: _offerDetailsPublishedLabel(data['createdAt']),
    availability:
        (data['availability'] ?? 'Disponibilite a confirmer').toString(),
    shortDescription: description.isEmpty
        ? 'Consultez le detail de cette annonce et contactez l\'annonceur.'
        : description,
    description: description,
    phone: (data['phone'] ?? '').toString(),
    imageUrls: imageUrls,
    statusBadges: <String>[
      'Disponible',
      if ((data['urgent'] as bool?) ?? false) 'Urgent',
      if ((data['verified'] as bool?) ?? false) 'Verifie',
      'Nouveau',
    ],
    practicalInfo: PracticalInfo(
      category: category.isEmpty ? 'Service' : category,
      serviceArea: serviceArea,
      canTravel: (data['canTravel'] as bool?) ?? true,
      schedule: (data['schedule'] ?? 'Horaires a convenir').toString(),
      missionDelay: missionDelay,
      averageDelay: missionDelay,
      paymentMethod:
          (data['paymentMethod'] ?? 'Paiement a convenir').toString(),
      serviceType: (data['serviceType'] ?? 'Prestation ponctuelle').toString(),
    ),
    advertiser: Advertiser(
      id: (data['userId'] ?? data['uid'] ?? '').toString(),
      name: advertiserName.isEmpty ? 'Annonceur Presto' : advertiserName,
      verified: (data['verified'] as bool?) ?? false,
      rating:
          (data['rating'] is num) ? (data['rating'] as num).toDouble() : 4.7,
      offersCount: (data['offersCount'] is num)
          ? (data['offersCount'] as num).toInt()
          : 1,
      reviewsCount: (data['reviewsCount'] is num)
          ? (data['reviewsCount'] as num).toInt()
          : (data['reviewCount'] is num)
              ? (data['reviewCount'] as num).toInt()
              : (data['ratingCount'] is num)
                  ? (data['ratingCount'] as num).toInt()
                  : 0,
      seniorityLabel: (data['seniorityLabel'] ?? 'Membre Presto').toString(),
      city: location.isEmpty ? 'Ville non precisee' : location,
      bio: (data['bio'] ?? '').toString(),
      avatarUrl: (data['avatarUrl'] ?? '').toString(),
      isOnline: ((data['status'] ?? '').toString().toLowerCase() == 'online'),
      lastSeenLabel: 'Activite recente',
    ),
    actionType: ((data['actionType'] ?? '') == 'booking')
        ? OfferActionType.booking
        : OfferActionType.contact,
    similarOffers: const [],
  );
}

/// ✅ Pastille affichant le pipeline audio actif (Remote Config)
class AudioPipelineBadge extends StatelessWidget {
  const AudioPipelineBadge({super.key});

  Color _colorFor(String v) {
    switch (v.toUpperCase()) {
      case 'STREAM':
        return Colors.green;
      case 'HYBRID':
        return Colors.blue;
      case 'CHUNK':
        return Colors.orange;
      case 'DISABLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = PrestoRemoteConfig.audioPipeline;
    final c = _colorFor(v);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.graphic_eq, size: 16, color: c),
          const SizedBox(width: 6),
          Text(
            v.isEmpty ? 'UNKNOWN' : v,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Petit état de session (user connecté ou non)
class SessionState {
  static String? userId;
}

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 📋 Diagnostics
    debugPrint('=== Firebase Initialization ===');
    debugPrint('✓ Firebase initialized');
    debugPrint('✓ Auth instance: ${FirebaseAuth.instance.runtimeType}');
    debugPrint(
        '✓ Firestore instance: ${FirebaseFirestore.instance.runtimeType}');
    if (kIsWeb) {
      debugPrint('✓ Platform: Web');
      debugPrint('  - Google Sign-In: Popup + Redirect fallback');
    } else {
      debugPrint(
          '✓ Platform: ${defaultTargetPlatform.toString().split('.').last}');
    }
    debugPrint('');

    // ✅ Activer la persistance Firestore (cache + offline)
    if (!kIsWeb) {
      try {
        await FirebaseFirestore.instance.enableNetwork();
        debugPrint('✓ Firestore persistence: Enabled');
      } catch (e) {
        debugPrint('⚠️ Firestore persistence error: $e');
      }
    } else {
      // Web: persistance auto si IndexedDB disponible
      debugPrint('✓ Firestore Web: Persistence (IndexedDB if available)');
    }

    // ✅ Initialiser le service Firebase centralisé avec optimisations
    // await FirebaseService.instance.initialize();

    // ✅ Remote Config: charger le pipeline audio
    await PrestoRemoteConfig.init();
    debugPrint('[RC] audio_pipeline=${PrestoRemoteConfig.audioPipeline}');

    // 🔒 App Check
    // - Debug: provider debug (ajouter le debug token dans Firebase Console → App Check)
    // - Release: Play Integrity (Android) + App Attest (iOS)
    // - Web: reCAPTCHA v3 si une siteKey est fournie.
    //   Exemple:
    //   `flutter run -d chrome --dart-define=APPCHECK_RECAPTCHA_SITE_KEY=xxxxx`
    // Clé site reCAPTCHA v3 (override possible via --dart-define=APPCHECK_RECAPTCHA_SITE_KEY)
    const webRecaptchaSiteKey = String.fromEnvironment(
      'APPCHECK_RECAPTCHA_SITE_KEY',
      defaultValue: '6LehQ0IsAAAAAIVtHXyi-obNQFOZEnBKXAW_P2de',
    );
    try {
      if (kIsWeb) {
        debugPrint(
            '[APPCHECK] siteKey=${webRecaptchaSiteKey.substring(0, 10)}...');
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider(webRecaptchaSiteKey),
        );
        debugPrint('[AppCheck] Web activated (reCAPTCHA v3)');
      } else {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider:
              kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
        );
      }
    } catch (e) {
      debugPrint('[AppCheck] activation failed: $e');
    }

    // 🔒 Auth minimale requise pour les Cloud Functions (même en anonyme)
    // Supprimé : on n'impose plus de connexion automatique au démarrage
    // L'auth anonyme sera gérée au besoin par chaque page qui en a besoin
    try {
      final auth = FirebaseAuth.instance;
      // Ne force plus signInAnonymously() au démarrage
      if (auth.currentUser != null) {
        debugPrint('[Auth] User already signed in: ${auth.currentUser!.uid}');
        SessionState.userId = auth.currentUser!.uid;
      } else {
        debugPrint('[Auth] No user signed in at startup (OK)');
        SessionState.userId = null;
      }

      // ✅ Synchroniser SessionState.userId automatiquement avec les changements d'auth
      /*
      FirebaseService.instance.authStateChanges.listen((User? user) {
        SessionState.userId = user?.uid;
        debugPrint('[Auth] State changed: ${user?.uid ?? "null"}');
      });
      */
    } catch (e) {
      debugPrint('[Auth] check failed: $e');
    }

    // Configuration globale : barre système bleue Prestō sur toute l'app.
    // (Le SplashScreen surcharge en orange.)
    SystemChrome.setSystemUIOverlayStyle(prestoOverlayStyleFor(kPrestoBlue));

    // Crashlytics n'est pas supporté sur le web
    if (!kIsWeb) {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    await CitySearch.instance.ensureLoaded();

    // Initialisation des notifications push (mobile uniquement)
    if (!kIsWeb) {
      try {
        await NotificationService().initialize();
      } catch (e) {
        debugPrint('[Notifications] init error: $e');
      }
    }

    runApp(const PrestoApp());
  }, (error, stack) {
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

class PrestoApp extends StatelessWidget {
  const PrestoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iliprestō',
      debugShowCheckedModeBanner: false,
      routes: {
        '/publish': (_) => const PublishOfferPage(),
        '/messages': (_) => const MessagesPage(),
        '/account': (_) => const AccountPage(),
        /*
        '/auth': (context) => PrestoPremiumAuthPage(
              onGoogle: () async {
                final auth = FirebaseAuth.instance;
                final provider = GoogleAuthProvider()
                  ..setCustomParameters({'prompt': 'select_account'});
                provider.addScope('email');
                provider.addScope('profile');

                if (kIsWeb) {
                  try {
                    await auth.signInWithPopup(provider);
                  } catch (_) {
                    await auth.signInWithRedirect(provider);
                  }
                } else {
                  await auth.signInWithProvider(provider);
                }
              },
              onApple: () async {
                if (kIsWeb ||
                    !(defaultTargetPlatform == TargetPlatform.iOS ||
                        defaultTargetPlatform == TargetPlatform.macOS)) {
                  throw Exception('Connexion Apple disponible sur iOS/macOS.');
                }
                final appleCredential =
                    await SignInWithApple.getAppleIDCredential(
                  scopes: [
                    AppleIDAuthorizationScopes.email,
                    AppleIDAuthorizationScopes.fullName,
                  ],
                );
                if (appleCredential.identityToken == null) {
                  throw Exception('Identité Apple non reçue');
                }
                final oauthCredential = OAuthProvider('apple.com').credential(
                  idToken: appleCredential.identityToken,
                  accessToken: appleCredential.authorizationCode,
                );
                await FirebaseAuth.instance
                    .signInWithCredential(oauthCredential);
              },
              onEmailLogin: (email, password) async {
                await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: email,
                  password: password,
                );
              },
              onResetPassword: (email) async {
                await EmailActionService.requestPasswordResetEmail(email);
              },
              onGoToSignup: () {
                _showSignupDialog(context);
              },
              onDiscoverPro: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prochainement disponible')),
                );
              },
            ),
        */
        AppRoutes.toolboxHub: (_) => const ToolboxHubPage(),
        AppRoutes.toolboxCurrent: (_) => const CurrentToolboxPage(),
        AppRoutes.entrepreneurCalculator: (_) =>
            const EntrepreneurCalculatorPage(),
      },
      theme: buildPrestoTheme(),
      home: const SplashScreen(),
    );
  }
}

/// Dialogue de création de compte (inscription)
void _showSignupDialog(BuildContext context) {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(
        'Créer un compte',
        style: kPrestoSectionTitleStyle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'votre@email.com',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                hintText: 'Min. 6 caractères',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmer le mot de passe',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () async {
            final email = emailCtrl.text.trim();
            final pass = passCtrl.text;
            final confirmPass = confirmPassCtrl.text;

            if (email.isEmpty || !email.contains('@')) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email invalide')),
              );
              return;
            }

            if (pass.length < 6) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Mot de passe trop court (min. 6)')),
              );
              return;
            }

            if (pass != confirmPass) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Les mots de passe ne correspondent pas')),
              );
              return;
            }

            try {
              final credential =
                  await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: email,
                password: pass,
              );
              if (credential.user != null) {
                await EmailActionService.requestEmailVerificationEmail();
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Compte créé. Vérifiez votre e-mail. ✅')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e')),
                );
              }
            }
          },
          child: const Text('Créer le compte'),
        ),
      ],
    ),
  );
}

/// SPLASH /////////////////////////////////////////////////////////////////

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    // Splash : status bar + barre de navigation système en orange.
    SystemChrome.setSystemUIOverlayStyle(prestoOverlayStyleFor(kPrestoOrange));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Sur Web, vérifier d'abord le redirect Google Sign-In
    if (kIsWeb) {
      _checkGoogleRedirectAndNavigate();
    } else {
      _navTimer = Timer(const Duration(milliseconds: 3500), () {
        _navigateTo(const HomePage());
      });
    }
  }

  /// Vérifie si l'utilisateur revient d'un redirect Google Sign-In (Web uniquement)
  Future<void> _checkGoogleRedirectAndNavigate() async {
    debugPrint('🔍 [SPLASH] Checking for Google redirect result...');
    try {
      final result = await FirebaseAuth.instance.getRedirectResult();
      if (result.user != null) {
        debugPrint('✅ [SPLASH] User authenticated via redirect!');
        debugPrint('✅ [SPLASH] Email: ${result.user?.email}');
        debugPrint('✅ [SPLASH] UID: ${result.user?.uid}');
        // Attendre un peu pour montrer le splash, puis naviguer vers HomePage
        _navTimer = Timer(const Duration(milliseconds: 1500), () {
          _navigateTo(const HomePage());
        });
      } else {
        debugPrint('ℹ️ [SPLASH] No redirect result, normal app start');
        // Pas de redirect, navigation normale après splash
        _navTimer = Timer(const Duration(milliseconds: 3500), () {
          _navigateTo(const HomePage());
        });
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [SPLASH] FirebaseAuthException during redirect check');
      debugPrint('❌ [SPLASH] Code: ${e.code}');
      debugPrint('❌ [SPLASH] Message: ${e.message}');
      // Erreur d'auth, mais on continue quand même vers HomePage
      _navTimer = Timer(const Duration(milliseconds: 3500), () {
        _navigateTo(const HomePage());
      });
    } catch (e) {
      debugPrint('❌ [SPLASH] Unexpected error: $e');
      // Erreur inattendue, navigation normale
      _navTimer = Timer(const Duration(milliseconds: 3500), () {
        _navigateTo(const HomePage());
      });
    }
  }

  void _navigateTo(Widget page) {
    if (!mounted) return;
    _navTimer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _navTimer?.cancel();
    // Sécurité: si le widget est détruit autrement, on remet le style global.
    SystemChrome.setSystemUIOverlayStyle(prestoOverlayStyleFor(kPrestoBlue));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: prestoOverlayStyleFor(kPrestoOrange),
      child: Scaffold(
        backgroundColor: kPrestoOrange,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /*
                  GestureDetector(
                    onLongPress: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomePageV2Option2(),
                        ),
                      );
                    },
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: const Text(
                        'iliprestō',
                        style: TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ),
                  ),
                  */
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: const Text(
                      'iliprestō',
                      style: TextStyle(
                        fontSize: 54,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ),
                  // */
                  const SizedBox(height: 28),
                  const Text(
                    'Trouvez un prestataire\nillico presto!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 46),
                  SizedBox(
                    width: 260,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white, width: 2),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () =>
                          _navigateTo(const HomePage(initialIndex: 2)),
                      child: const Text(
                        "J’offre un job",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 260,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 8),
                        backgroundColor: kPrestoBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () =>
                          _navigateTo(const HomePage(initialIndex: 1)),
                      child: const Text(
                        "Je consulte les offres",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// HOME ////////////////////////////////////////////////////////////////////

class HomePage extends StatefulWidget {
  final int initialIndex;
  final String? initialConsultCategoryFilter;
  final String? initialConsultSearchQuery;

  const HomePage({
    super.key,
    this.initialIndex = 0,
    this.initialConsultCategoryFilter,
    this.initialConsultSearchQuery,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const List<_HomeCategoryShortcut> _homeCategoryShortcuts = [
    _HomeCategoryShortcut(
      icon: Icons.restaurant_outlined,
      label: 'Restauration',
      targetCategory: 'Restauration / Extra',
    ),
    _HomeCategoryShortcut(
      icon: Icons.construction_outlined,
      label: 'Bricolage',
      targetCategory: 'Bricolage / Travaux',
    ),
    _HomeCategoryShortcut(
      icon: Icons.home_outlined,
      label: 'Aide domicile',
      targetCategory: 'Aide à domicile',
    ),
    _HomeCategoryShortcut(
      icon: Icons.child_care_outlined,
      label: 'Garde enfants',
      targetCategory: 'Garde d\'enfants',
    ),
    _HomeCategoryShortcut(
      icon: Icons.music_note_outlined,
      label: 'DJ / Sono',
      targetCategory: 'Événementiel / DJ',
    ),
    _HomeCategoryShortcut(
      icon: Icons.school_outlined,
      label: 'Cours',
      targetCategory: 'Cours & soutien',
    ),
    _HomeCategoryShortcut(
      icon: Icons.eco_outlined,
      label: 'Jardinage',
      targetCategory: 'Jardinage',
    ),
    _HomeCategoryShortcut(
      icon: Icons.format_paint_outlined,
      label: 'Peinture',
      targetCategory: 'Peinture',
    ),
    _HomeCategoryShortcut(
      icon: Icons.handyman_outlined,
      label: 'Main-d\'oeuvre',
      targetCategory: 'Main-d\'œuvre',
    ),
    _HomeCategoryShortcut(
      icon: Icons.other_houses_outlined,
      label: 'Autres',
      targetCategory: 'Autre',
    ),
  ];

  late int _selectedIndex;
  String? _consultCategoryFilter;
  String? _consultSearchQuery;
  final PageController _carouselController = PageController();
  final ScrollController _scrollController = ScrollController();
  int _currentSlide = 0;

  Timer? _homeAutoSlideTimer;
  Timer? _presenceTimer;
  DateTime? _lastPresenceUpdate;
  DateTime? _sessionStartTime;
  // Bottom bar désormais fixe (ne se masque plus au scroll/clavier)

  late final AnimationController _categoryController;

  // Taille de police de référence pour les titres des slides (alignée sur le slide 1)
  static const double _homeSlideTitleFontSize = 26;

  bool _isSeeding = false;

  /// Contrôle l'affichage des suggestions de recherche
  bool _showSearchSuggestions = true;

  /// Chargement figé à l'ouverture de la home pour stabiliser la section.
  late final Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _latestOffersFuture;

  /// Slogans animés (fade + slide) pour le 1er slide
  final List<String> _firstSlideSlogans = const [
    "Trouvez immédiatement quelqu’un pour faire le job.",
    "Une personne disponible près de chez vous.",
    "Publiez… ils arrivent aussitôt.",
  ];
  int _sloganIndex = 0;
  Timer? _sloganTimer;

  /// Mots-clés statiques
  final List<String> _baseSearchKeywords = const [
    "jardinage",
    "jardinage aujourd’hui",
    "serveur",
    "serveur ce soir",
    "peinture",
    "débroussaillage",
    "déménagement",
    "aide aux devoirs",
    "nettoyage",
    "ménage",
    "garde d’enfants",
    "DJ",
    "sono",
  ];

  /// Mots-clés dynamiques basés sur les offres Firestore
  List<String> _dynamicKeywords = [];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _dynamicKeywordsSubscription;

  /// Suggestions “smart” par défaut
  final List<String> _trendingSuggestions = const [
    "Jardinage aujourd’hui",
    "Serveur ce soir",
    "Peinture urgent",
    "Jardinage Petit-Bourg demain",
  ];

  /// Slides d’accueil
  final List<_HomeSlide> _slides = const [
    _HomeSlide(
      title: "Trouvez immédiatement quelqu’un pour faire le job.",
      subtitle: "Carte des personnes disponibles en quelques secondes.",
      badge: "Disponible",
      // plus d'image chrono ici
      imageAsset: null,
    ),
    _HomeSlide(
      title: "Boîte à outils de l'entrepreneur",
      subtitle: "Liens utiles CCI, Région, aides et infos clés.",
      badge: "Pro",
      icon: Icons.business_center_outlined,
    ),
    _HomeSlide(
      title: "iliprestō",
      subtitle: "Qui sommes-nous ? Mentions légales, confidentialité, CGU.",
      badge: "Infos",
      icon: Icons.info_outline,
    ),
  ];

  // late final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  void _goToSearch(String query) {
    final q = query.trim();
    if (q.isEmpty) return;

    // ✅ Log la recherche
    _logSearch(q);

    setState(() {
      _consultCategoryFilter = null;
      _consultSearchQuery = q;
      _selectedIndex = 1;
    });
  }

  void _goToCategoryOffers(String category) {
    final normalizedCategory = category.trim();
    if (normalizedCategory.isEmpty) return;

    setState(() {
      _consultCategoryFilter = normalizedCategory;
      _consultSearchQuery = null;
      _selectedIndex = 1;
    });
  }

  /// ✅ Enregistre la recherche effectuée
  Future<void> _logSearch(String searchQuery) async {
    try {
      // await _analytics.logSearch(searchTerm: searchQuery);
    } catch (e) {
      debugPrint('[Analytics] logSearch error: $e');
    }
  }

  void _onBottomTap(int index) {
    if (_selectedIndex == index) return;

    // ✅ Log le changement d'onglet
    /*
    _analytics.logEvent(
      name: 'tab_changed',
      parameters: {
        'previous_tab': _selectedIndex,
        'new_tab': index,
      },
    );
    */

    setState(() => _selectedIndex = index);
  }

  @override
  void initState() {
    super.initState();

    // Assure la barre de statut bleue dès que l'accueil est actif
    SystemChrome.setSystemUIOverlayStyle(prestoOverlayStyleFor(kPrestoBlue));

    _selectedIndex = widget.initialIndex;
    _consultCategoryFilter = widget.initialConsultCategoryFilter;
    _consultSearchQuery = widget.initialConsultSearchQuery;
    _sessionStartTime = DateTime.now();
    WidgetsBinding.instance.addObserver(this);

    // ✅ Présence initiale avec statut "online"
    _touchPresence(status: 'online');
    _presenceTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _touchPresence();
    });

    // À l'arrivée sur l'accueil: on laisse le slide texte visible 4s,
    // puis on passe automatiquement au slide 2.
    if (_selectedIndex == 0) {
      _homeAutoSlideTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        if (!_carouselController.hasClients) return;
        _carouselController.animateToPage(
          1,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
        );
      });
    }

    _categoryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    if (_firstSlideSlogans.length > 1) {
      _sloganTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        setState(() {
          _sloganIndex = (_sloganIndex + 1) % _firstSlideSlogans.length;
        });
      });
    }

    _listenDynamicKeywords();

    _latestOffersFuture = _loadLatestOffers();

    // Listener pour hide/show bottom bar au scroll
    _scrollController.addListener(() {
      _onPageScroll(_scrollController.offset);
    });
  }

  Future<void> _touchPresence({String? status}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ✅ Throttling: ne pas mettre à jour si < 30s depuis dernière update
    final now = DateTime.now();
    if (_lastPresenceUpdate != null &&
        status == null &&
        now.difference(_lastPresenceUpdate!).inSeconds < 30) {
      return;
    }

    _lastPresenceUpdate = now;

    try {
      final data = <String, dynamic>{
        'lastSeenAt': FieldValue.serverTimestamp(),
      };

      // ✅ Ajouter le statut si fourni (online/away/offline)
      if (status != null) {
        data['status'] = status;
      }

      // ✅ Stats de session (temps passé)
      if (_sessionStartTime != null && status == 'offline') {
        final sessionDuration = now.difference(_sessionStartTime!);
        data['lastSessionDuration'] = sessionDuration.inMinutes;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
            data,
            SetOptions(merge: true),
          );
    } catch (_) {
      // best-effort
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // ✅ App reprend → online
        _touchPresence(status: 'online');
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // ✅ App en pause → away
        _touchPresence(status: 'away');
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // ✅ App fermée → offline
        _touchPresence(status: 'offline');
        break;
    }
  }

  void _onPageScroll(double offset) {
    // Intentionnel : bottom bar fixe sur toutes les pages.
  }

  void _listenDynamicKeywords() {
    _dynamicKeywordsSubscription?.cancel();

    // Important perf: ne pas écouter toute la collection `offers`.
    // On se limite aux dernières offres pour alimenter des suggestions utiles,
    // sans déclencher des rebuilds massifs quand la collection grossit.
    _dynamicKeywordsSubscription = FirebaseFirestore.instance
        .collection('offers')
        .where(_publicOffersFilter())
        .where(
          'createdAt',
          isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(0),
        )
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .listen(
      (snapshot) {
        final words = <String>{};
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final title = (data['title'] ?? '').toString().toLowerCase();
          final description =
              (data['description'] ?? '').toString().toLowerCase();
          final combined = '$title $description';
          for (final word in combined.split(RegExp(r'\s+'))) {
            if (word.length > 3 &&
                !RegExp(r'[0-9]').hasMatch(word) &&
                !word.startsWith('0')) {
              words.add(word);
            }
          }
        }

        final next = words.toList()..sort();

        if (!mounted) return;
        if (listEquals(_dynamicKeywords, next)) return;

        setState(() {
          _dynamicKeywords = next;
        });
      },
      onError: (e) {
        debugPrint('Dynamic keywords stream error: $e');
      },
    );
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialConsultCategoryFilter != oldWidget.initialConsultCategoryFilter ||
        widget.initialConsultSearchQuery != oldWidget.initialConsultSearchQuery) {
      _consultCategoryFilter = widget.initialConsultCategoryFilter;
      _consultSearchQuery = widget.initialConsultSearchQuery;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // ✅ Marquer offline avant de quitter
    _touchPresence(status: 'offline');

    _carouselController.dispose();
    _scrollController.dispose();
    _categoryController.dispose();
    _sloganTimer?.cancel();
    _homeAutoSlideTimer?.cancel();
    _presenceTimer?.cancel();
    _dynamicKeywordsSubscription?.cancel();
    super.dispose();
  }

  /// Animation "bump" séquentielle sur les 6 catégories
  double _categoryScaleForIndex(int index, {int count = 10}) {
    final t = _categoryController.value * count;
    final active = t.floor() % count;
    final localT = t - t.floor();
    if (index == active) {
      return 1.0 + 0.25 * (1 - (localT - 0.5) * (localT - 0.5) * 4);
    }
    return 1.0;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _loadLatestOffers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('offers')
        .where(
          'createdAt',
          isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(0),
        )
        .orderBy('createdAt', descending: true)
        .limit(60)
        .get();

    return snapshot.docs
        .where((doc) => _isPublishedOfferData(doc.data()))
        .take(12)
        .toList(growable: false);
  }

  Widget _buildHomeCategoriesSection() {
    const compactTargets = <String>[
      'Jardinage',
      'Peinture',
      'Main-d\'œuvre',
      'Autre',
      'Garde d\'enfants',
      'Événementiel / DJ',
    ];

    final compactCategories = compactTargets
        .map(
          (target) => _homeCategoryShortcuts.firstWhere(
            (item) => item.targetCategory == target,
          ),
        )
        .toList(growable: false);

    return AnimatedBuilder(
      animation: _categoryController,
      builder: (context, child) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < compactCategories.length; index++) ...[
                if (index > 0) const SizedBox(width: 6),
                _CategoryChip(
                  icon: compactCategories[index].icon,
                  label: compactCategories[index].label,
                  iconScale: _categoryScaleForIndex(
                    index,
                    count: compactCategories.length,
                  ),
                  onTap: () => _goToCategoryOffers(
                    compactCategories[index].targetCategory,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLatestOffersSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Dernières offres',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _onBottomTap(1),
                child: const Text(
                  'Voir tout',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kPrestoBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            future: _latestOffersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _friendlyFirestoreErrorMessage(snapshot.error!),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }

              final docs = snapshot.data ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

              if (docs.isNotEmpty) {
                PrestoMonitoring.I.trackOtherStream(
                  key: 'home.latestOffers',
                  docsCount: docs.length,
                );
              }
              if (docs.isEmpty) {
                return const Text(
                  'Aucune offre publiée pour le moment.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }

              return RepaintBoundary(
                child: _AutoScrollingOffersCarousel(
                  offers: docs,
                  onOfferTap: (doc) {
                    final data = doc.data();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OfferDetailsPage(
                          offer: _buildOfferDetailsOffer(
                            offerId: doc.id,
                            data: data,
                          ),
                          currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Iterable<String> _buildSearchSuggestions(TextEditingValue value) {
    final text = value.text.trim().toLowerCase();

    final all = <String>{
      ..._baseSearchKeywords,
      ..._trendingSuggestions,
      ..._dynamicKeywords,
    };

    if (text.isEmpty) {
      return all.take(8);
    }

    return all.where((s) => s.toLowerCase().contains(text)).take(8);
  }

  Future<void> _seedSampleOffers() async {
    if (_isSeeding) return;
    setState(() => _isSeeding = true);

    try {
      if (mounted) {
        showSuccessSnackBar(context, "Reset + seed des offres en cours…");
      }

      await resetAndSeedOffers();

      // Compat legacy : certaines vues utilisent encore `location` / `postalCode`.
      // On les remplit à partir de `city` / `cp` si absents.
      final fs = FirebaseFirestore.instance;
      final col = fs.collection(kOffersCollection);
      final snap = await col.get();

      WriteBatch batch = fs.batch();
      int ops = 0;
      Future<void> commitIfNeeded() async {
        if (ops == 0) return;
        await batch.commit();
        batch = fs.batch();
        ops = 0;
      }

      for (final doc in snap.docs) {
        final data = doc.data();
        final city = (data['city'] ?? '').toString();
        final cp = (data['cp'] ?? '').toString();

        final needsLocation =
            !(data.containsKey('location')) || (data['location'] == null);
        final needsPostalCode =
            !(data.containsKey('postalCode')) || (data['postalCode'] == null);

        if (!needsLocation && !needsPostalCode) continue;
        if (city.isEmpty && cp.isEmpty) continue;

        final patch = <String, dynamic>{};
        if (needsLocation && city.isNotEmpty) patch['location'] = city;
        if (needsPostalCode && cp.isNotEmpty) patch['postalCode'] = cp;

        if (patch.isEmpty) continue;

        batch.set(doc.reference, patch, SetOptions(merge: true));
        ops++;
        if (ops >= 450) {
          await commitIfNeeded();
        }
      }
      await commitIfNeeded();

      if (mounted) {
        showSuccessSnackBar(
            context, "Offres de test réinitialisées et injectées ✅");
      }
    } catch (e) {
      if (mounted) {
        showSuccessSnackBar(context, "Erreur lors du seed des offres : $e");
      }
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  Widget _buildSmartSearchBar() {
    TextEditingController? searchController;
    FocusNode? searchFocusNode;

    void selectSuggestion(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;

      searchController?.text = trimmed;
      searchController?.selection =
          TextSelection.collapsed(offset: trimmed.length);

      setState(() => _showSearchSuggestions = false);
      searchFocusNode?.unfocus();

      _goToSearch(trimmed);
    }

    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue value) {
        // ✅ Ne pas afficher les suggestions quand le clavier est visible (Android fix)
        final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
        if (!_showSearchSuggestions || isKeyboardVisible)
          return const Iterable<String>.empty();
        return _buildSearchSuggestions(value);
      },
      onSelected: selectSuggestion,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        searchController = textEditingController;
        searchFocusNode = focusNode;

        return GestureDetector(
          onTap: () {
            if (focusNode.hasFocus) {
              // Si déjà focusé, basculer l'affichage des suggestions
              setState(() {
                _showSearchSuggestions = !_showSearchSuggestions;
              });
            } else {
              // Sinon, montrer les suggestions
              setState(() {
                _showSearchSuggestions = true;
              });
            }
          },
          child: TextField(
            controller: textEditingController,
            focusNode: focusNode,
            onSubmitted: selectSuggestion,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: "Que cherchez-vous ? (ex: jardinage aujourd’hui)",
              hintStyle: const TextStyle(
                fontSize: 14,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: const Icon(
                Icons.search,
                color: kPrestoBlue,
                size: 22,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: kPrestoBlue, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: kPrestoBlue, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: kPrestoBlue, width: 2),
              ),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final surface = Theme.of(context).colorScheme.surface;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: surface,
            elevation: 4,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  final highlightedIndex =
                      AutocompleteHighlightedOption.of(context);
                  final isHighlighted = index == highlightedIndex;
                  return ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Text(
                      option,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    tileColor:
                        isHighlighted ? kPrestoBlue.withOpacity(0.08) : null,
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Cloche : pastille = nombre de messages non lus + notifications d'offres
  Widget _buildNotificationBell() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        // Non connecté → cloche simple
        if (user == null) {
          return _TapScale(
            onTap: () {
              showSuccessSnackBar(
                context,
                "Connecte-toi à ton compte pour recevoir les notifications de nouveaux messages et annonces.",
              );
            },
            child: const _NotificationBellBase(badgeCount: 0),
          );
        }

        return _UnreadInboxBell(
          userId: user.uid,
          monitoringKeyPrefix: 'home.bell',
          builder: (context, badgeCount) => _TapScale(
            onTap: () {
              _showNotificationsDialog(context, user.uid);
            },
            child: _NotificationBellBase(badgeCount: badgeCount),
          ),
        );
      },
    );
  }

  /// Affiche un dialogue avec les notifications récentes
  void _showNotificationsDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Notifications',
          textAlign: TextAlign.center,
          style: kPrestoSectionTitleStyle,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: userId)
                .orderBy('createdAt', descending: true)
                .limit(20)
                .snapshots()
                .map((snap) {
              PrestoMonitoring.I.trackOtherStream(
                key: 'home.dialog.notifications',
                docsCount: snap.docs.length,
              );
              return snap;
            }),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final notifications = snapshot.data!.docs;

              if (notifications.isEmpty) {
                return const Text(
                  'Aucune notification pour le moment.',
                  style: kPrestoBodyTextStyle,
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  final data = notif.data();
                  final title = data['title'] as String? ?? '';
                  final message = data['message'] as String? ?? '';
                  final isRead = data['read'] as bool? ?? false;
                  final offerId = data['offerId'] as String?;

                  return ListTile(
                    leading: Icon(
                      Icons.announcement,
                      color: isRead ? Colors.grey : Colors.green,
                    ),
                    title: Text(
                      title,
                      style: kPrestoBodyTextStyle.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isRead ? Colors.grey.shade700 : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      message,
                      style: kPrestoMetaTextStyle.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isRead
                            ? Colors.grey.shade600
                            : Colors.grey.shade800,
                      ),
                    ),
                    onTap: () async {
                      // Marquer comme lue
                      if (!isRead) {
                        await FirebaseFirestore.instance
                            .collection('notifications')
                            .doc(notif.id)
                            .update({'read': true});
                      }

                      // Naviguer vers l'offre si disponible
                      if (offerId != null && context.mounted) {
                        Navigator.of(context).pop();
                        // Ouvrir la page ConsultOffersPage avec un filtre sur cette offre
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HomePage(initialIndex: 1),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Marquer toutes comme lues (Firestore batch limité à 500)
              final notifs = await FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: userId)
                  .where('read', isEqualTo: false)
                  .limit(500)
                  .get();

              if (notifs.docs.isNotEmpty) {
                final batch = FirebaseFirestore.instance.batch();
                for (final doc in notifs.docs) {
                  batch.update(doc.reference, {'read': true});
                }
                await batch.commit();
              }

              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Tout marquer comme lu'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  /// Icône d'information pour accéder aux pages légales
  Widget _buildInfoIcon() {
    // Icône supprimée sur la page d'accueil (on garde juste l'espace pour l'alignement).
    return const SizedBox(width: 40, height: 40);
  }

  /// Illustration à droite du slide (plus de chrono image)
  Widget _buildSlideIllustration(
    _HomeSlide slide,
    int index, {
    VoidCallback? onTap,
  }) {
    // Le slide 3 (infos) reprend le style d'icône bleue animée de la boîte à outils.
    if (index == _slides.length - 1) {
      return PrestoInfoIconAnimated(
        size: 72,
        showBadge: false,
        onTap: onTap ?? () {},
      );
    }

    // On ignore complètement slide.imageAsset, on affiche juste une icône
    final child = Container(
      width: 70,
      height: 70,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(
        slide.icon ?? Icons.flash_on,
        color: kPrestoBlue,
        size: 32,
      ),
    );

    if (onTap == null) return child;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: prestoOverlayStyleFor(kPrestoBlue),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          extendBody:
              true, // Permettre au contenu de s'étendre sous la bottom bar
          backgroundColor:
              Colors.white, // Fond blanc pour éviter le bandeau beige
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      IndexedStack(
                        index: _selectedIndex,
                        children: [
                          _buildHomeContent(),
                          ConsultOffersPage(
                            key: ValueKey<String>(
                              'consult:${_consultCategoryFilter ?? ''}|${_consultSearchQuery ?? ''}',
                            ),
                            onScroll: _onPageScroll,
                            categoryFilter: _consultCategoryFilter,
                            searchQuery: _consultSearchQuery,
                          ),
                          PublishOfferPage(onScroll: _onPageScroll),
                          const MessagesPage(),
                          const AccountPage(),
                        ],
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: MediaQuery.removeViewInsets(
                          removeBottom: true,
                          context: context,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF1A73E8),
                                  Color(0xFF0D47A1),
                                ],
                              ),
                              borderRadius:
                                  BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                            padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                            child: SafeArea(
                              top: false,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: HomeBottomNavItem(
                                      icon: Icons.home,
                                      label: "Accueil",
                                      selected: _selectedIndex == 0,
                                      onTap: () => _onBottomTap(0),
                                    ),
                                  ),
                                  Expanded(
                                    child: HomeBottomNavItem(
                                      icon: Icons.search,
                                      label: "Je consulte\nles offres",
                                      selected: _selectedIndex == 1,
                                      onTap: () => _onBottomTap(1),
                                    ),
                                  ),
                                  Expanded(
                                    child: HomeBottomNavItem(
                                      icon: Icons.add_circle_outline,
                                      label: "Publier\nune offre",
                                      isBig: true,
                                      selected: _selectedIndex == 2,
                                      onTap: () => _onBottomTap(2),
                                    ),
                                  ),
                                  Expanded(
                                    child: HomeBottomNavItem(
                                      icon: Icons.chat_bubble_outline,
                                      label: "Messages",
                                      selected: _selectedIndex == 3,
                                      onTap: () => _onBottomTap(3),
                                    ),
                                  ),
                                  Expanded(
                                    child: HomeBottomNavItem(
                                      icon: Icons.person_outline,
                                      label: "Compte",
                                      selected: _selectedIndex == 4,
                                      onTap: () => _onBottomTap(4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    const double bottomPadding = 150;

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(0, 8, 0, bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ligne du haut : info + logo
                Row(
                  children: [
                    _buildInfoIcon(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onLongPress: _seedSampleOffers,
                        child: const Center(
                          child: Text(
                            "iliprestō",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: kPrestoOrange,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 36),
                  ],
                ),

                const SizedBox(height: 8),

                _buildSmartSearchBar(),

                const SizedBox(height: 14),

                // SLIDER
                SizedBox(
                  height: 220,
                  child: OverflowBox(
                    alignment: Alignment.center,
                    minWidth: MediaQuery.of(context).size.width,
                    maxWidth: MediaQuery.of(context).size.width,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: _carouselController,
                            itemCount: _slides.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentSlide = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              final slideIndex = index;
                              final slide = _slides[slideIndex];

                              // 🔥 SLIDE 1 : plein texte, sans image, phrase géante sur toute la largeur
                              if (slideIndex == 0) {
                                const String bigText =
                                    "Trouvez immédiatement quelqu'un pour faire le job !";

                                return Container(
                                  height: double.infinity,
                                  decoration: const BoxDecoration(
                                    color: kPrestoOrange,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 18,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          "DISPONIBLE",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        SizedBox(height: 10),
                                        // ✅ Phrase principale en très gros sur toute la largeur
                                        Text(
                                          bigText,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize:
                                                _homeSlideTitleFontSize, // taille bien grosse
                                            fontWeight: FontWeight.w900,
                                            height: 1.25,
                                          ),
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          "Une personne disponible près de chez vous, en quelques minutes.",
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              // ✅ SLIDE 2 : Boîte à outils de l'entrepreneur (icône bleue animée + badge)
                              if (slideIndex == 1) {
                                return const EntrepreneurToolboxSlide();
                              }

                              // 🔁 Slides texte restants : layout texte + icône / image
                              final VoidCallback? onSlideTap = slideIndex ==
                                      (_slides.length - 1)
                                  ? () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const LegalInfoPage(),
                                        ),
                                      );
                                    }
                                  : null;

                              final slideBody = Container(
                                height: double.infinity,
                                decoration: const BoxDecoration(
                                  color: kPrestoOrange,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      // Texte
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              slide.badge.toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              slide.title,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize:
                                                    _homeSlideTitleFontSize,
                                                fontWeight: FontWeight.w900,
                                                height: 1.25,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              slide.subtitle,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // 👉 Illustration (icône) sur les slides texte
                                      if (slideIndex != 0) ...[
                                        const SizedBox(width: 8),
                                        _buildSlideIllustration(
                                          slide,
                                          index,
                                          onTap: onSlideTap,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );

                              if (onSlideTap == null) return slideBody;
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onSlideTap,
                                child: slideBody,
                              );
                            },
                          ),
                          // Indicateurs
                          Positioned(
                            bottom: 8,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                _slides.length,
                                (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  width: _currentSlide == index ? 16 : 8,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: _currentSlide == index
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _buildHomeCategoriesSection(),

                const SizedBox(height: 18),

                _buildLatestOffersSection(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// SLIDE MODEL
class _HomeSlide {
  final String title;
  final String subtitle;
  final String badge;
  final IconData? icon;
  final String? imageAsset;

  const _HomeSlide({
    required this.title,
    required this.subtitle,
    required this.badge,
    this.icon,
    this.imageAsset,
  });
}

/// EFFET SCALE SUR TAP
class _TapScale extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _TapScale({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: AnimatedScale(
        scale: 1.0,
        duration: const Duration(milliseconds: 120),
        child: child,
      ),
    );
  }
}

/// CHIPS / CARDS ///////////////////////////////////////////////////////////

class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double iconScale;

  const _CategoryChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.iconScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return _TapScale(
      onTap: onTap ??
          () {
            showSuccessSnackBar(
              context,
              'Catégorie "$label" : bientôt disponible',
            );
          },
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: kPrestoOrange,
              shape: BoxShape.circle,
              border: Border.all(
                color: kPrestoBlue,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Transform.scale(
                scale: iconScale,
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 90,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget pour l'animation de point pulsant pendant l'enregistrement
class _PulsingDot extends StatefulWidget {
  final int delay;

  const _PulsingDot({required this.delay});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isBig;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.isBig = false,
  });

  @override
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_BottomNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Jouer l'animation quand sélectionné
    if (widget.selected && !oldWidget.selected) {
      _controller.forward().then((_) {
        if (mounted) {
          _controller.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Colors.white;
    final fontWeight = widget.selected ? FontWeight.w700 : FontWeight.w500;

    return _TapScale(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: EdgeInsets.all(widget.isBig ? 6 : 4),
                decoration: BoxDecoration(
                  color: widget.isBig
                      ? Colors.white
                      : widget.selected
                          ? Colors.white.withOpacity(0.35)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: widget.isBig
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : widget.selected
                          ? [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.5),
                                blurRadius: 12,
                                spreadRadius: 3,
                              ),
                            ]
                          : null,
                ),
                child: Icon(
                  widget.icon,
                  size: widget.isBig ? 28 : 24,
                  color: widget.isBig ? kPrestoOrange : color,
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: 70,
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: fontWeight,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cloche de notifications avec badge dynamique /////////////////////////////

class _NotificationBellBase extends StatelessWidget {
  final int badgeCount;
  final bool showBackground;
  final Color iconColor;

  const _NotificationBellBase({
    required this.badgeCount,
    this.showBackground = true,
    this.iconColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    final String? label;
    if (badgeCount <= 0) {
      label = null;
    } else if (badgeCount > 9) {
      label = "9+";
    } else {
      label = badgeCount.toString();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: showBackground
              ? BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                )
              : null,
          child: Icon(
            Icons.notifications_none_outlined,
            size: 22,
            color: iconColor,
          ),
        ),
        if (label != null)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

int _countUnreadMessages(
  QuerySnapshot<Map<String, dynamic>>? snapshot,
  String userId,
) {
  if (snapshot == null) return 0;

  var unreadMessagesCount = 0;
  for (final doc in snapshot.docs) {
    final data = doc.data();
    final unreadMap = (data['unreadCount'] as Map<String, dynamic>?) ?? {};
    final value = unreadMap[userId];
    if (value is int) unreadMessagesCount += value;
  }

  return unreadMessagesCount;
}

class _UnreadInboxBell extends StatelessWidget {
  final String userId;
  final String? monitoringKeyPrefix;
  final Widget Function(BuildContext context, int badgeCount) builder;

  const _UnreadInboxBell({
    required this.userId,
    required this.builder,
    this.monitoringKeyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snap) {
      if (monitoringKeyPrefix != null) {
        PrestoMonitoring.I.trackOtherStream(
          key: monitoringKeyPrefix!,
          docsCount: snap.docs.length,
        );
      }
      return snap;
    });

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          if (error != null) {
            PrestoMonitoring.I.trackError(
              '${monitoringKeyPrefix ?? 'messages'}.stream',
              error,
            );
          }
          return builder(context, 0);
        }

        final badgeCount = _countUnreadMessages(snapshot.data, userId);
        return builder(context, badgeCount);
      },
    );
  }
}

/// BLOC COMMENT ÇA MARCHE /////////////////////////////////////////////////
class _HowItWorksStepWithProgress extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String description;
  final bool showLine;

  const _HowItWorksStepWithProgress({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.showLine,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: kPrestoOrange,
                child: Text(
                  stepNumber.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              if (showLine)
                Expanded(
                  child: Container(
                    width: 3,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          kPrestoOrange,
                          kPrestoOrange.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 1, bottom: showLine ? 10 : 0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: kPrestoBlue.withOpacity(0.12),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kPrestoBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// PAGE "JE CONSULTE LES OFFRES" ///////////////////////////////////////////

class ConsultOffersPage extends StatefulWidget {
  final String? categoryFilter;
  final String? searchQuery;
  final Function(double)? onScroll;

  const ConsultOffersPage({
    super.key,
    this.categoryFilter,
    this.searchQuery,
    this.onScroll,
  });

  @override
  State<ConsultOffersPage> createState() => _ConsultOffersPageState();
}

class _Debouncer {
  _Debouncer({this.delay = const Duration(milliseconds: 300)});
  final Duration delay;
  Timer? _t;

  void run(void Function() action) {
    _t?.cancel();
    _t = Timer(delay, action);
  }

  void dispose() => _t?.cancel();
}

/// ✅ Conversion d'erreur Firestore en message amical
String _friendlyFirestoreErrorMessage(Object error) {
  final msg = error.toString().toLowerCase();

  // ✅ failed-precondition : index manquant
  if (msg.contains('failed-precondition') || msg.contains('index')) {
    debugPrint('[Error] Firestore index missing: $error');
    return "Mise à jour en cours, réessaie dans 1 minute";
  }

  // ✅ permission-denied : accès refusé
  if (msg.contains('permission-denied') || msg.contains('permission')) {
    debugPrint('[Error] Permission denied: $error');
    return "Tu n'as pas accès à ces offres";
  }

  // ✅ unavailable : problème réseau
  if (msg.contains('unavailable') ||
      msg.contains('deadline-exceeded') ||
      msg.contains('network')) {
    debugPrint('[Error] Network issue: $error');
    return "Problème réseau, réessaie";
  }

  // ✅ not-found
  if (msg.contains('not-found') || msg.contains('not found')) {
    debugPrint('[Error] Not found: $error');
    return "Ressource introuvable";
  }

  // ✅ invalid-argument
  if (msg.contains('invalid-argument') || msg.contains('invalid')) {
    debugPrint('[Error] Invalid argument: $error');
    return "Requête invalide, vérifie les filtres";
  }

  // Fallback : log technique complet en console
  debugPrint('[Error] Unknown Firestore error: $error');
  return "Une erreur s'est produite, réessaie";
}

class _ConsultOffersPageState extends State<ConsultOffersPage> {
  static const Color _offersBg = Color(0xFFF6F1F1);
  static const Color _offersNavy = Color(0xFF1E2554);
  static const Color _offersOrange = Color(0xFFFF7A00);
  static const Color _offersSoftText = Color(0xFF626584);
  static const Color _offersCardBorder = Color(0xFFF0E8E8);

  // --- Normalisation (réduction index) ---
  String _slugId(String input) {
    final s = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll('œ', 'oe')
        .replaceAll(RegExp(r"[/\-'’']"), ' ')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(' ', '-');
    return s;
  }

  // ✅ Logs analytics
  // late final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// ✅ Enregistre la recherche effectuée
  Future<void> _logSearch(String searchQuery) async {
    try {
      // await _analytics.logSearch(searchTerm: searchQuery);
    } catch (e) {
      debugPrint('[Analytics] logSearch error: $e');
    }
  }

  /// ✅ Enregistre l'utilisation des filtres
  Future<void> _logFilterUsage(String filterType, String filterValue) async {
    try {
      /*
      await _analytics.logEvent(
        name: 'filter_applied',
        parameters: {
          'filter_type': filterType,
          'filter_value': filterValue,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      */
    } catch (e) {
      debugPrint('[Analytics] logFilterUsage error: $e');
    }
  }

  /// ✅ Enregistre la visite de la page ConsultOffers
  Future<void> _logPageView() async {
    try {
      /*
      await _analytics.logScreenView(
        screenName: 'ConsultOffers',
        screenClass: 'ConsultOffersPage',
      );
      */
    } catch (e) {
      debugPrint('[Analytics] logPageView error: $e');
    }
  }

  /// ✅ Enregistre les filtres appliqués
  Future<void> _logFiltersApplied({
    required String? category,
    required String? region,
    required String? department,
    required String? city,
    required String? searchQuery,
    required int resultCount,
  }) async {
    try {
      /*
      await _analytics.logEvent(
        name: 'filters_applied',
        parameters: {
          'category': category ?? 'none',
          'region': region ?? 'none',
          'department': department ?? 'none',
          'city': city ?? 'none',
          'search_query': searchQuery ?? 'none',
          'result_count': resultCount,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      */
    } catch (e) {
      debugPrint('[Analytics] logFiltersApplied error: $e');
    }
  }

  /// ✅ Enregistre quand l'utilisateur clique sur une offre
  Future<void> _logOfferClicked(String offerId, String title) async {
    try {
      /*
      await _analytics.logEvent(
        name: 'select_item',
        parameters: {
          'item_id': offerId,
          'item_name': title,
          'item_category': _filterCategory ?? 'unknown',
        },
      );
      */
    } catch (e) {
      debugPrint('[Analytics] logOfferClicked error: $e');
    }
  }

  // ✅ Suivi du statut réseau
  final bool _isOnline = true;
  // late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  String? _makeCategoryId(String? categoryLabel) {
    final s = (categoryLabel ?? '').trim();
    if (s.isEmpty || s == 'Toutes catégories') return null;
    return _slugId(s);
  }

  String? _makeCityId({
    required String cityName,
    required String postalCode,
  }) {
    final city = cityName.trim();
    final cp = postalCode.trim();
    if (city.isEmpty || cp.length < 3) return null; // CP requis pour stabilité
    return '${cp}_${_slugId(city)}';
  }

  String? _makeCityCategoryKey(
      {required String? cityId, required String? categoryId}) {
    if (cityId == null || categoryId == null) return null;
    return '${cityId}_$categoryId';
  }

  // ✅ Range budget (AVANCÉ) — évite requêtes “impossibles” + explosion d’index
  final bool _advancedFilters = false;
  final TextEditingController _budgetMinCtrl = TextEditingController();
  final TextEditingController _budgetMaxCtrl = TextEditingController();
  String? _budgetRangeWarning; // affiché dans l’UI si range désactivé

  double? _parseBudgetBound(String raw) {
    final s = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Copié")),
    );
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await canLaunchUrl(uri);
    if (!ok) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  final TextEditingController _keywordCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();

  int _filterPanelKey = 0;
  int _lastSnapshotRawCount = 0;
  DateTime? _lastPaginationRequestAt;

  String? _selectedCategory;
  String? _selectedRegionCode;
  String? _selectedSubCategory;

  String? _lastOffersQuerySignature;

  String _buildOffersQuerySignature({
    required bool hasCategory,
    required bool hasDept,
    required bool hasLocation,
    required bool hasPostalCode,
    required bool hasSubcategory,
    required bool hasBudgetRange,
  }) {
    final parts = <String>[
      'offers',
      if (hasCategory) 'where(category==)',
      if (hasDept) 'where(dept==)',
      if (hasLocation) 'where(location==)',
      if (hasPostalCode) 'where(postalCode==)',
      if (hasSubcategory) 'where(subcategory==)',
      if (hasBudgetRange) 'where(budgetValue>=/<=)',
      if (hasBudgetRange)
        'orderBy(budgetValue asc) + orderBy(createdAt desc)'
      else
        'orderBy(createdAt desc)',
      'limit($_pageLimit)',
    ];
    return parts.join(' + ');
  }

  final _Debouncer _filterDebounce =
      _Debouncer(delay: const Duration(milliseconds: 300));

  String? _filterCategory;
  String? _filterRegionCode;
  String? _filterDepartmentCode;
  String? _filterCityName;

  // Pagination / loading state
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _isLoading = false;

  // + Pagination progressive (moins brutale: 10 par page au lieu de 20)
  static const int _initialLimit = 10;
  static const int _pageSize = 10;
  static const int _maxLimit = 100;
  int _pageLimit = _initialLimit;

  /// Mot-clé actif appliqué aux résultats (initialisé depuis searchQuery, réinitialisable)
  String? _activeSearchQuery;

  // Variables pour l'autocomplétion de ville dans les filtres
  final TextEditingController _filterCityController = TextEditingController();
  final TextEditingController _filterPostalCodeController =
      TextEditingController();
  final FocusNode _regionFocus = FocusNode();
  final FocusNode _deptFocus = FocusNode();
  final FocusNode _filterCityFocusNode = FocusNode();
  List<CityRecord> _filterCitySuggestions = [];
  int _filterCityHighlightedIndex = -1;
  Timer? _filterCityDebounce;

  final ScrollController _scrollController = ScrollController();

  bool _showFilters = false; // Panneau de filtres rétracté au départ
  int _lastResultCount = 0;
  String _headerTitle = 'Je consulte les offres';

  late final Map<String, String> _deptToRegion = _buildDeptToRegion();

  // ✅ Cache de normalisation pour améliorer la performance de recherche
  final Map<String, String> _normalizedTextCache = {};

  // ✅ Cache des résultats Firestore pour éviter les re-queries
  Map<String, List<DocumentSnapshot<Map<String, dynamic>>>>? _queryResultsCache;
  String? _lastCachedQuerySignature;
  Timer? _cacheInvalidationTimer;

  /// Normalise un texte pour la recherche (diacritiques, casse, séparateurs)
  String _normalizeText(String input) {
    // Cache hit: retourner directement
    if (_normalizedTextCache.containsKey(input)) {
      return _normalizedTextCache[input]!;
    }

    final normalized = input
        .trim()
        .toLowerCase()
        // Diacritiques courants FR
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll('œ', 'oe')
        // Séparateurs usuels
        .replaceAll(RegExp(r"[/\-'’']"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    // Limiter la taille du cache à 200 entrées
    if (_normalizedTextCache.length > 200) {
      _normalizedTextCache.clear();
    }

    _normalizedTextCache[input] = normalized;
    return normalized;
  }

  String _normalizeForCategoryMatch(String input) {
    return _normalizeText(input);
  }

  String? _matchKnownCategory(String input) {
    return canonicalizeOfferCategory(input);
  }

  Map<String, String> _buildDeptToRegion() {
    final out = <String, String>{};
    for (final entry in kRegionDepartments.entries) {
      for (final deptCode in entry.value) {
        out[deptCode] = entry.key;
      }
    }
    return out;
  }

  // ✅ Départements affichés selon région sélectionnée
  List<String> get _filteredDepartmentCodes {
    if (_filterRegionCode == null) {
      return kDepartments.keys.toList();
    }
    final depts = kRegionDepartments[_filterRegionCode!];
    return depts?.toList() ?? [];
  }

  // ✅ Les départements autorisés pour filtrer les villes
  List<String>? get _allowedDeptCodesForCity {
    if (_filterDepartmentCode != null) return [_filterDepartmentCode!];
    if (_filterRegionCode == null) return null; // null = pas de limite
    return _filteredDepartmentCodes;
  }

  /// Badge = messages non lus + notifications d'annonces (dont favoris)
  Widget _buildConsultNotificationBell() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        if (user == null) {
          return IconButton(
            onPressed: () {
              showSuccessSnackBar(
                context,
                'Connecte-toi pour recevoir les notifications.',
              );
            },
            icon: const _NotificationBellBase(
              badgeCount: 0,
              showBackground: false,
              iconColor: Colors.white,
            ),
            splashRadius: 20,
            padding: EdgeInsets.zero,
          );
        }

        return _UnreadInboxBell(
          userId: user.uid,
          builder: (context, badgeCount) => IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MessagesPage()),
              );
            },
            icon: _NotificationBellBase(
              badgeCount: badgeCount,
              showBackground: false,
              iconColor: Colors.white,
            ),
            splashRadius: 20,
            padding: EdgeInsets.zero,
          ),
        );
      },
    );
  }

  bool get _hasActiveClientFilters {
    final selectedCategory =
        (_filterCategory != null && _filterCategory!.isNotEmpty)
            ? _filterCategory
            : ((_selectedCategory != null &&
                    _selectedCategory != 'Toutes catégories')
                ? _selectedCategory
                : null);
    final hasCity = _filterCityName?.trim().isNotEmpty ?? false;
    final hasSearch = _activeSearchQuery?.trim().isNotEmpty ?? false;
    final hasSubcategory =
        _selectedSubCategory != null && _selectedSubCategory!.isNotEmpty;
    final hasDept =
        (_filterDepartmentCode != null && _filterDepartmentCode!.isNotEmpty) ||
            (_filterRegionCode != null && _filterRegionCode!.isNotEmpty) ||
            (_selectedRegionCode != null && _selectedRegionCode!.isNotEmpty);
    final min = _parseBudgetBound(_budgetMinCtrl.text);
    final max = _parseBudgetBound(_budgetMaxCtrl.text);
    final hasBudgetRange = _advancedFilters &&
        (min != null || max != null) &&
        _budgetRangeWarning == null;

    return (selectedCategory != null && selectedCategory.isNotEmpty) ||
        hasCity ||
        hasSearch ||
        hasSubcategory ||
        hasDept ||
        hasBudgetRange;
  }

  @override
  void initState() {
    super.initState();

    // ✅ Analytics: page view
    _logPageView();

    _scrollController.addListener(() {
      widget.onScroll?.call(_scrollController.offset);
      _maybeLoadMore();
    });

    final initialCategoryFilter = widget.categoryFilter?.trim();
    if (initialCategoryFilter != null && initialCategoryFilter.isNotEmpty) {
      _selectedCategory = initialCategoryFilter;
      final matched = _matchKnownCategory(initialCategoryFilter);
      if (matched != null) {
        _filterCategory = matched;
        _selectedCategory = matched;
      }
    } else {
      _selectedCategory = 'Toutes catégories';
    }

    _selectedRegionCode = null; // Pas de région sélectionnée par défaut

    // ✅ Si un searchQuery est fourni (barre de recherche Accueil),
    // on essaie d'abord de le refléter dans le filtre Catégorie.
    // Si aucune catégorie ne correspond, on garde le comportement "mot-clé".
    final initialQuery = widget.searchQuery?.trim();
    if (initialQuery != null && initialQuery.isNotEmpty) {
      final matchedCategory = _matchKnownCategory(initialQuery);
      if (matchedCategory != null) {
        _filterCategory = matchedCategory;
        _selectedCategory = matchedCategory;
        _activeSearchQuery = null;
        _keywordCtrl.clear();
      } else {
        _activeSearchQuery = initialQuery;
        _keywordCtrl.text = initialQuery;
      }

      // ✅ Analytics: recherche (même si ça match une catégorie)
      _logSearch(initialQuery);
    }

    _headerTitle = _resolveConsultOffersTitle();

    // Quand le code postal change, on essaie de déduire la région
    _postalCodeController.addListener(_syncRegionWithPostalCode);

    // ✅ Précharger les données région/département
    _preloadRegionDeptData();

    // Synchroniser la ville sélectionnée (si déjà connue) dans le champ visible
    _filterCityController.addListener(_syncLocationFieldFromFilter);
    _syncLocationFieldFromFilter();

    // ✅ Écouter les changements de connectivité
    _monitorConnectivity();
  }

  void _monitorConnectivity() {
    // Utiliser la librairie `connectivity_plus` pour détecter le réseau
    // (à ajouter dans pubspec.yaml si absent)
    /*
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final isNowOnline = results.any((r) => r != ConnectivityResult.none);
      if (isNowOnline != _isOnline && mounted) {
        setState(() {
          _isOnline = isNowOnline;
        });
        if (isNowOnline) {
          // Resync des données quand on retrouve du réseau
          setState(() {});
        }
      }
    });
    */
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    if (_hasActiveClientFilters) return;
    if (_pageLimit >= _maxLimit) return;
    if (_lastSnapshotRawCount < _pageLimit) return;

    final position = _scrollController.position;
    // Seuil : quand on approche du bas (500px), on augmente la limite progressivement
    const thresholdPx = 500.0;
    if (position.maxScrollExtent - position.pixels > thresholdPx) return;

    final now = DateTime.now();
    final canRequest = _lastPaginationRequestAt == null ||
        now.difference(_lastPaginationRequestAt!) >
            const Duration(milliseconds: 450);
    if (!canRequest) return;

    _lastPaginationRequestAt = now;

    setState(() {
      _pageLimit = math.min(_pageLimit + _pageSize, _maxLimit);
    });
  }

  /// ✅ Précharge les données région/département au démarrage
  Future<void> _preloadRegionDeptData() async {
    try {
      // Simplement accéder à la map pour la forcer en mémoire
      debugPrint(
          '[ConsultOffers] Préchargement région/département (${_deptToRegion.length} entrées)');
    } catch (e) {
      debugPrint('[ConsultOffers] Erreur préchargement: $e');
    }
  }

  /// ✅ Cache les résultats Firestore pour éviter les re-queries inutiles (template pour utilisation future)
  List<DocumentSnapshot<Map<String, dynamic>>> _getCachedOrFreshResults(
    String querySignature,
    List<DocumentSnapshot<Map<String, dynamic>>> freshResults,
  ) {
    // Si la signature a changé, invalider le cache
    if (_lastCachedQuerySignature != querySignature) {
      _queryResultsCache = null;
      _lastCachedQuerySignature = querySignature;
      _cacheInvalidationTimer?.cancel();

      // Cache expire après 5 minutes
      _cacheInvalidationTimer = Timer(const Duration(minutes: 5), () {
        _queryResultsCache = null;
        _lastCachedQuerySignature = null;
      });
    }

    // Mettre en cache les résultats
    _queryResultsCache = {'results': freshResults};
    return freshResults;
  }

  @override
  void dispose() {
    // _connectivitySubscription.cancel();
    _filterDebounce.dispose();
    _cacheInvalidationTimer?.cancel(); // ✅ Nettoyer le timer de cache
    _locationController.dispose();
    _postalCodeController.dispose();
    _scrollController.dispose();
    _filterCityController.dispose();
    _filterPostalCodeController.dispose();
    _filterCityFocusNode.dispose();
    _filterCityDebounce?.cancel();
    _keywordCtrl.dispose();
    _cityCtrl.dispose();
    _budgetMinCtrl.dispose();
    _budgetMaxCtrl.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _buildOffersQuery() {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('offers').where(
              _publicOffersFilter(),
            );

    final loc = _locationController.text.trim();
    final cp = _postalCodeController.text.trim();
    final cat = _selectedCategory;
    final regionCode = _selectedRegionCode;
    final subcat = _selectedSubCategory;

    final filterCat = _filterCategory;
    final filterRegCode = _filterRegionCode;
    final filterDeptCode = _filterDepartmentCode;
    final filterCity = _filterCityName?.trim();

    final String? categoryLabel =
        (filterCat != null && filterCat.isNotEmpty) ? filterCat : cat;
    final String? categoryId = _makeCategoryId(categoryLabel);

    final String cityName =
        (filterCity != null && filterCity.isNotEmpty) ? filterCity : loc;

    final String cpForCity = (filterCity != null &&
            filterCity.isNotEmpty &&
            _filterPostalCodeController.text.trim().isNotEmpty)
        ? _filterPostalCodeController.text.trim()
        : cp;

    final String? cityId =
        _makeCityId(cityName: cityName, postalCode: cpForCity);

    final String? cityCategoryKey =
        _makeCityCategoryKey(cityId: cityId, categoryId: categoryId);

    final bool hasSubcategory = (subcat != null && subcat.isNotEmpty);
    final bool hasDept =
        (filterDeptCode != null && filterDeptCode.isNotEmpty) ||
            (filterRegCode != null && filterRegCode.isNotEmpty) ||
            (regionCode != null && regionCode.isNotEmpty);

    final min = _parseBudgetBound(_budgetMinCtrl.text);
    final max = _parseBudgetBound(_budgetMaxCtrl.text);
    final bool wantsBudgetRange = _advancedFilters &&
        (min != null || max != null) &&
        _budgetRangeWarning == null;

    // NOTE:
    // Ne pas trier côté Firestore ici: la combinaison OR (public/legacy active)
    // + orderBy(createdAt) peut déclencher des erreurs d'index selon l'état du
    // projet. On trie côté client après filtrage pour garder une UX stable.

    final hasClientFilters = categoryId != null ||
        cityId != null ||
        cityCategoryKey != null ||
        hasSubcategory ||
        hasDept ||
        wantsBudgetRange ||
        (_activeSearchQuery?.trim().isNotEmpty ?? false);

    query = query.limit(hasClientFilters ? _maxLimit : _pageLimit);

    // Signature (audit index) — minimaliste
    _lastOffersQuerySignature = _buildOffersQuerySignature(
      hasCategory: categoryId != null,
      hasDept: hasDept,
      hasLocation: cityId != null || cityCategoryKey != null,
      hasPostalCode: cpForCity.trim().isNotEmpty,
      hasSubcategory: hasSubcategory,
      hasBudgetRange: wantsBudgetRange,
    );

    // ✅ Log la signature de la query (debug only)
    if (kDebugMode) {
      debugPrint('[OFFERS][QUERY] $_lastOffersQuerySignature');
    }

    // ✅ Log en Crashlytics en prod (non-fatal)
    if (!kDebugMode && _lastOffersQuerySignature != null) {
      try {
        FirebaseCrashlytics.instance.log(
          'Offers Query: $_lastOffersQuerySignature',
        );
      } catch (e) {
        debugPrint('[Crashlytics] log error: $e');
      }
    }

    // ✅ Monitoring local (dashboard admin)
    PrestoMonitoring.I
        .trackOffersQueryBuild(signature: _lastOffersQuerySignature);

    return query;
  }

  bool _offerIsActive(Map<String, dynamic> data) {
    final dynamic isActive = data['isActive'];
    if (isActive is bool) return isActive;

    final status = (data['status'] ?? '').toString().trim().toLowerCase();
    if (status.isNotEmpty) return status == 'active';

    return true;
  }

  String _offerCategoryLabel(Map<String, dynamic> data) {
    final raw = (data['category'] ?? '').toString().trim();
    return _matchKnownCategory(raw) ?? raw;
  }

  String _offerCityLabel(Map<String, dynamic> data) {
    return ((data['city'] ?? data['location']) ?? '').toString().trim();
  }

  String _offerPostalCode(Map<String, dynamic> data) {
    return ((data['postalCode'] ?? data['cp']) ?? '').toString().trim();
  }

  String? _offerDepartmentCode(Map<String, dynamic> data) {
    final rawDept = (data['dept'] ?? '').toString().trim();
    if (rawDept.isNotEmpty) return rawDept;
    return departmentFromPostalCode(_offerPostalCode(data));
  }

  String? _offerRegionCode(Map<String, dynamic> data) {
    final dept = _offerDepartmentCode(data);
    if (dept == null || dept.isEmpty) return null;
    return _deptToRegion[dept];
  }

  double? _offerBudgetValue(Map<String, dynamic> data) {
    return budgetValueFromDynamic(
      data['budgetValue'] ?? data['budget'] ?? data['price'],
    );
  }

  bool _matchesOfferFilters(Map<String, dynamic> data) {
    if (!_offerIsActive(data)) return false;

    final selectedCategory =
        (_filterCategory != null && _filterCategory!.isNotEmpty)
            ? _filterCategory
            : ((_selectedCategory != null &&
                    _selectedCategory != 'Toutes catégories')
                ? _selectedCategory
                : null);
    if (selectedCategory != null && selectedCategory.isNotEmpty) {
      final offerCategory = _offerCategoryLabel(data);
      if (_normalizeForCategoryMatch(offerCategory) !=
          _normalizeForCategoryMatch(selectedCategory)) {
        return false;
      }
    }

    if (_selectedSubCategory != null && _selectedSubCategory!.isNotEmpty) {
      final offerSubCategory =
          ((data['subCategory'] ?? data['subcategory']) ?? '')
              .toString()
              .trim();
      if (offerSubCategory != _selectedSubCategory) {
        return false;
      }
    }

    if (_filterDepartmentCode != null && _filterDepartmentCode!.isNotEmpty) {
      if (_offerDepartmentCode(data) != _filterDepartmentCode) {
        return false;
      }
    }

    final regionFilter =
        (_filterRegionCode != null && _filterRegionCode!.isNotEmpty)
            ? _filterRegionCode
            : _selectedRegionCode;
    if (regionFilter != null && regionFilter.isNotEmpty) {
      if (_offerRegionCode(data) != regionFilter) {
        return false;
      }
    }

    final cityFilter = _filterCityName?.trim();
    if (cityFilter != null && cityFilter.isNotEmpty) {
      if (_normalizeText(_offerCityLabel(data)) != _normalizeText(cityFilter)) {
        return false;
      }
      final filterPostalCode = _filterPostalCodeController.text.trim();
      if (filterPostalCode.isNotEmpty &&
          _offerPostalCode(data) != filterPostalCode) {
        return false;
      }
    }

    final min = _parseBudgetBound(_budgetMinCtrl.text);
    final max = _parseBudgetBound(_budgetMaxCtrl.text);
    if (_advancedFilters &&
        (min != null || max != null) &&
        _budgetRangeWarning == null) {
      final offerBudget = _offerBudgetValue(data);
      if (offerBudget == null) return false;
      if (min != null && offerBudget < min) return false;
      if (max != null && offerBudget > max) return false;
    }

    if (_activeSearchQuery != null && _activeSearchQuery!.trim().isNotEmpty) {
      final q = _normalizeText(_activeSearchQuery!);
      final queryTokens = q.split(' ').where((t) => t.isNotEmpty).toList();
      final title = _normalizeText((data['title'] ?? '').toString());
      final desc = _normalizeText((data['description'] ?? '').toString());
      final combined = '$title $desc';
      if (!queryTokens.every((token) => combined.contains(token))) {
        return false;
      }
    }

    return true;
  }

  Future<void> _fetchOffers({bool resetPaging = false}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final sw = Stopwatch()..start();

    if (resetPaging) {
      _lastDoc = null;
      // Si tu stockes une liste d'offres en mémoire : offers.clear();
    }

    try {
      var query = _buildOffersQuery();

      // Exemple de pagination si besoin
      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      // Charge une première page (adapter la limite si besoin)
      final snap = await query.limit(20).get();

      sw.stop();
      PrestoMonitoring.I.trackOffersFetchOnce(
          ms: sw.elapsedMilliseconds, docsCount: snap.docs.length);

      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
      }

      // Si tu conserves les résultats : setState(() => offers = ...);
    } catch (e) {
      PrestoMonitoring.I.trackError('offers.fetchOnce', e);
      if (kDebugMode) {
        debugPrint('Erreur lors du chargement des offres: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFiltersOrSearch() {
    // Annule le debounce en cours pour éviter les conflits
    _filterDebounce._t?.cancel();

    final min = _parseBudgetBound(_budgetMinCtrl.text);
    final max = _parseBudgetBound(_budgetMaxCtrl.text);

    // ✅ Log l'utilisation des filtres
    if (_filterCategory != null && _filterCategory!.isNotEmpty) {
      _logFilterUsage('category', _filterCategory!);
    }
    if (_filterRegionCode != null && _filterRegionCode!.isNotEmpty) {
      _logFilterUsage('region', _filterRegionCode!);
    }
    if (_filterDepartmentCode != null && _filterDepartmentCode!.isNotEmpty) {
      _logFilterUsage('department', _filterDepartmentCode!);
    }
    if (_filterCityName != null && _filterCityName!.isNotEmpty) {
      _logFilterUsage('city', _filterCityName!);
    }

    // Compter les filtres égalité actifs (pour éviter explosion d’index si range)
    final bool eqCat =
        (_filterCategory != null && _filterCategory!.isNotEmpty) ||
            ((_selectedCategory ?? '').isNotEmpty &&
                _selectedCategory != 'Toutes catégories');
    final bool eqDept =
        (_filterDepartmentCode != null && _filterDepartmentCode!.isNotEmpty) ||
            ((_filterRegionCode ?? '').isNotEmpty) ||
            ((_selectedRegionCode ?? '').isNotEmpty);
    final bool eqLoc =
        (_filterCityName != null && _filterCityName!.trim().isNotEmpty) ||
            _locationController.text.trim().isNotEmpty;
    final bool eqCp = _postalCodeController.text.trim().isNotEmpty;
    final bool eqSub =
        (_selectedSubCategory != null && _selectedSubCategory!.isNotEmpty);

    final int eqCount =
        <bool>[eqCat, eqDept, eqLoc, eqCp, eqSub].where((b) => b).length;

    // ✅ Règle: range budget uniquement en “avancé” + idéalement peu de filtres == (sinon index explosion)
    String? budgetWarning;
    if (_advancedFilters && (min != null || max != null) && eqCount > 1) {
      budgetWarning = "Budget (avancé) désactivé : trop de filtres combinés. "
          "Garde 0–1 filtre (ex: seulement Ville OU seulement Catégorie) pour éviter l’explosion d’index.";
    }

    // ✅ Log les filtres appliqués
    _logFiltersApplied(
      category: _filterCategory,
      region: _filterRegionCode,
      department: _filterDepartmentCode,
      city: _filterCityName,
      searchQuery: _activeSearchQuery,
      resultCount: 0, // sera mis à jour après le StreamBuilder
    );

    setState(() {
      _budgetRangeWarning = budgetWarning;
      _activeSearchQuery =
          _keywordCtrl.text.trim().isEmpty ? null : _keywordCtrl.text.trim();
      _lastDoc = null; // Reset pagination
      _pageLimit = _initialLimit;
      _lastPaginationRequestAt = null;
      _showFilters = false;
      _headerTitle = _resolveConsultOffersTitle();
    });
  }

  void _onAnyFilterChanged() {
    // ✅ Auto-apply avec debounce
    _filterDebounce.run(() {
      _applyFiltersOrSearch();
    });
  }

  String _deptFromPostal(String cp) {
    final s = cp.trim();
    if (s.length < 2) return s;
    // DOM: 971/972/973/974/976 (postal commence par 97x) + 98x
    if (s.startsWith('97') || s.startsWith('98')) {
      return s.length >= 3 ? s.substring(0, 3) : s;
    }
    // Métropole
    return s.substring(0, 2);
  }

  void _resetFilters() {
    // 1) reset valeurs filtres
    setState(() {
      _selectedCategory = 'Toutes catégories';
      _selectedRegionCode = null;
      _selectedSubCategory = null;
      _filterCategory = null;
      _filterRegionCode = null;
      _filterDepartmentCode = null;
      _filterCityName = null;
      _filterCitySuggestions = [];
      _filterCityHighlightedIndex = -1;
      _activeSearchQuery = null;
      _budgetRangeWarning = null;
      _filterPanelKey++; // Force la reconstruction du panneau
      _pageLimit = _initialLimit;
      _lastPaginationRequestAt = null;
      _showFilters = false;
      _headerTitle = _resolveConsultOffersTitle();
    });

    // 2) reset champs texte
    _keywordCtrl.clear();
    _cityCtrl.clear();
    _locationController.clear();
    _postalCodeController.clear();
    _filterCityController.clear();
    _filterPostalCodeController.clear();

    // Assurer que le champ visible est remis à vide
    _syncLocationFieldFromFilter();

    // 3) ferme le clavier si besoin
    FocusScope.of(context).unfocus();

    // 4) ✅ Pas de scroll forcé: on conserve la position courante
  }

  String _resolveConsultOffersTitle() {
    final activeCategory = (_filterCategory?.trim().isNotEmpty ?? false)
        ? _filterCategory!.trim()
        : (((_selectedCategory?.trim().isNotEmpty ?? false) &&
                _selectedCategory != 'Toutes catégories')
            ? _selectedCategory!.trim()
            : null);

    if (activeCategory == null) {
      return 'Je consulte les offres';
    }

    return 'Offres : $activeCategory';
  }

  // Met à jour le champ "Ville" visible avec la valeur des filtres si présente
  void _syncLocationFieldFromFilter() {
    final val = _filterCityController.text.trim();
    if (val.isNotEmpty && _locationController.text != val) {
      _locationController.text = val;
    }
  }

  void _syncRegionWithPostalCode() {
    final cp = _postalCodeController.text.trim();
    if (cp.length < 3) return;

    final regionName = inferRegionFromPostalCode(cp);
    if (regionName != null) {
      // Chercher le code région correspondant
      String? regionCode;
      for (final entry in kRegions.entries) {
        if (entry.value == regionName) {
          regionCode = entry.key;
          break;
        }
      }
      if (regionCode != null && regionCode != _selectedRegionCode) {
        setState(() {
          _selectedRegionCode = regionCode;
        });
      }
    }
  }

  /// ✅ Tuile unique cliquable pour afficher/masquer les filtres
  Widget _buildActiveFilterChips() {
    // Compter les filtres actifs
    int activeFiltersCount = 0;
    if (_filterCategory != null && _filterCategory!.isNotEmpty)
      activeFiltersCount++;
    if (_filterRegionCode != null && _filterRegionCode!.isNotEmpty)
      activeFiltersCount++;
    if (_filterDepartmentCode != null && _filterDepartmentCode!.isNotEmpty)
      activeFiltersCount++;
    if (_filterCityName != null && _filterCityName!.isNotEmpty)
      activeFiltersCount++;
    if (_activeSearchQuery != null && _activeSearchQuery!.isNotEmpty)
      activeFiltersCount++;

    final offersLabel =
        '$_lastResultCount annonce${_lastResultCount > 1 ? 's' : ''}';

    return Container(
      color: const Color(0xFFF6F0F2),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 360;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => setState(() => _showFilters = !_showFilters),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isNarrow ? 10 : 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFE4D8DA),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showFilters ? Icons.tune : Icons.tune_rounded,
                          size: 18,
                          color: const Color(0xFF585D7C),
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          'Filtres',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF474D70),
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _showFilters
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: const Color(0xFF777B97),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: isNarrow ? 10 : 14),
              Expanded(
                child: Text(
                  offersLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isNarrow ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    color: _offersNavy,
                    letterSpacing: -0.15,
                  ),
                ),
              ),
              if (activeFiltersCount > 0)
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _offersOrange,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$activeFiltersCount',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (activeFiltersCount > 0) const SizedBox(width: 8),
              if (activeFiltersCount > 0)
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: _resetFilters,
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.close_rounded,
                      size: 19,
                      color: _offersOrange,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTitle = _headerTitle;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: _offersBg,
        body: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: kToolbarHeight,
                  color: kPrestoOrange,
                  padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          baseTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: kPrestoAppBarTitleStyle.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ✅ Tuiles cliquables pour filtres actifs
                _buildActiveFilterChips(),
                _buildFilterPanel(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _buildOffersQuery().snapshots().map((snap) {
                      PrestoMonitoring.I.trackOffersSnapshot(snap.docs.length);
                      return snap;
                    }),
                    builder: (context, snapshot) {
                      // ✅ Ne plus afficher le loader si on a déjà des données
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(kPrestoOrange),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        debugPrint('❌ [OFFERS] Error: ${snapshot.error}');
                        debugPrint('❌ [OFFERS] Stack: ${snapshot.stackTrace}');

                        final err = snapshot.error;
                        if (err != null) {
                          PrestoMonitoring.I
                              .trackError('offers.snapshots', err);
                        }

                        final friendly = err == null
                            ? "Une erreur s'est produite, réessaie"
                            : _friendlyFirestoreErrorMessage(err);

                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Erreur lors du chargement des offres",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  friendly,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Réessayer'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrestoOrange,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final rawDocs = snapshot.data?.docs ?? const [];
                      _lastSnapshotRawCount = rawDocs.length;

                      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                          rawDocs
                              .where((d) => _matchesOfferFilters(d.data()))
                              .toList();

                        docs.sort((a, b) {
                        final aTs = a.data()['createdAt'];
                        final bTs = b.data()['createdAt'];
                        final aMs = aTs is Timestamp
                          ? aTs.millisecondsSinceEpoch
                          : 0;
                        final bMs = bTs is Timestamp
                          ? bTs.millisecondsSinceEpoch
                          : 0;
                        return bMs.compareTo(aMs);
                        });

                      // Nombre après filtrage
                      final int resultCount = docs.length;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _lastResultCount != resultCount) {
                          setState(() => _lastResultCount = resultCount);
                        }
                      });

                      if (docs.isEmpty) {
                        return Column(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 18, 24, 12),
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.grid_view_rounded,
                                    size: 20,
                                    color: _offersOrange,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    '0 annonce',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: _offersNavy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Expanded(child: _EmptyOffers()),
                          ],
                        );
                      }

                      const int _adsEvery =
                          8; // Bandeau pub après chaque 8 annonces
                      final int _adSlots = docs.length ~/ _adsEvery;
                      final int _totalItems = docs.length + _adSlots;

                      return Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              key: const PageStorageKey<String>(
                                'consult-offers-list',
                              ),
                              controller: _scrollController,
                              physics: const ClampingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(6, 0, 6, 132),
                              addAutomaticKeepAlives: true,
                              addRepaintBoundaries: true,
                              itemCount: _totalItems,
                              itemBuilder: (context, index) {
                                final bool isAd =
                                    (index + 1) % (_adsEvery + 1) == 0;
                                if (isAd) {
                                  return AdBanner(
                                    margin: EdgeInsets.zero,
                                    placeholderHeight: kIsWeb ? 180.0 : 100.0,
                                    placeholderFolderPrefix:
                                        'assets/carousel_home/',
                                    flat: true,
                                    animatePlaceholder: false,
                                  );
                                }

                                final int docIndex =
                                    index - (index ~/ (_adsEvery + 1));
                                final doc = docs[docIndex];
                                final offerId = doc.id;
                                final data = doc.data();

                                final title =
                                    (data['title'] ?? 'Sans titre') as String;

                                final city =
                                    ((data['city'] ?? data['location']) ??
                                            'Lieu non précisé')
                                        .toString();
                                final postalCode =
                                    ((data['postalCode'] ?? data['cp']) ?? '')
                                        .toString()
                                        .trim();
                                final category = (data['category'] ??
                                        'Catégorie non précisée')
                                    .toString();
                                final budgetRaw =
                                    data['budget'] ?? data['price'];
                                final int budget = budgetRaw is num
                                    ? budgetRaw.round()
                                    : int.tryParse(
                                            budgetRaw?.toString() ?? '') ??
                                        0;
                                final publishedAge =
                                    _ageLabelFromCreatedAt(data['createdAt']);
                                final publishedText = publishedAge.isEmpty
                                    ? 'Publication récente'
                                    : 'Publié il y a $publishedAge';
                                final isUrgent = data['urgent'] == true;
                                final missionDelayLabel =
                                    _extractMissionDelayLabel(data);
                                final cleanTitle = _sanitizeOfferTitle(
                                  rawTitle: title,
                                  city: city,
                                  postalCode: postalCode,
                                );

                                return RepaintBoundary(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: _OfferBrowseTile(
                                      onTap: () {
                                        _logOfferClicked(offerId, title);
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => OfferDetailsPage(
                                              offer: _buildOfferDetailsOffer(
                                                offerId: offerId,
                                                data: data,
                                              ),
                                              currentUserId: FirebaseAuth
                                                      .instance
                                                      .currentUser
                                                      ?.uid ??
                                                  '',
                                            ),
                                          ),
                                        );
                                      },
                                      data: _OfferBrowseTileData(
                                        title: cleanTitle,
                                        subtitle: [
                                          city,
                                          if (postalCode.isNotEmpty) postalCode,
                                          category,
                                        ].join(' / '),
                                        publishedText: publishedText,
                                        price: budget,
                                        missionDelayLabel: missionDelayLabel,
                                        isUrgent: isUrgent,
                                        icon: _categoryIcon(category),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 220),
      crossFadeState:
          _showFilters ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: Form(
        key: ValueKey(_filterPanelKey),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCategoryDropdown(),
              const SizedBox(height: 12),
              _buildRegionDropdown(),
              const SizedBox(height: 12),
              _buildDepartmentDropdown(),
              const SizedBox(height: 12),
              _buildFilterCityField(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetFilters,
                      child: const Text('Réinitialiser'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _applyFiltersOrSearch,
                      icon: const Icon(Icons.search),
                      label: const Text('Rechercher'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrestoBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      secondChild: const SizedBox.shrink(),
    );
  }

  Widget _buildRegionDropdown() {
    return Focus(
      focusNode: _regionFocus,
      child: DropdownButtonFormField<String?>(
        value: _filterRegionCode,
        isDense: true,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(14),
        decoration: const InputDecoration(
          labelText: "Région",
          isDense: true,
        ),
        items: <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(
            value: null,
            child: Text("Toutes régions"),
          ),
          ...kRegionsOrdered.map((r) => DropdownMenuItem<String?>(
                value: r.code,
                child: Text(r.name),
              )),
        ],
        onChanged: (code) {
          setState(() {
            _filterRegionCode = code;

            // ✅ Région change => on reset le dept + ville + CP
            _filterDepartmentCode = null;
            _filterCityController.clear();
            _filterPostalCodeController.clear();
            _filterCityName = null;
            _filterCitySuggestions = [];
            _filterCityHighlightedIndex = -1;
          });

          _onAnyFilterChanged(); // ✅ auto-apply

          // Passe au champ département
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FocusScope.of(context).requestFocus(_deptFocus);
          });
        },
      ),
    );
  }

  Widget _buildDepartmentDropdown() {
    // ✅ Utilise le getter pour obtenir les départements filtrés
    final deptCodes = [..._filteredDepartmentCodes]..sort();

    final allowedCodes = deptCodes.toSet();
    final safeValue = (_filterDepartmentCode != null &&
            allowedCodes.contains(_filterDepartmentCode))
        ? _filterDepartmentCode
        : null; // ✅ si la valeur n’existe pas, on repasse à "Tous"

    // ✅ Si le filtre courant pointe vers un département non disponible,
    // on remet aussi l'état interne à null (sinon on a un "ghost value").
    if (_filterDepartmentCode != null && safeValue == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_filterDepartmentCode == null) return;

        final stillInvalid = !allowedCodes.contains(_filterDepartmentCode);
        if (!stillInvalid) return;

        setState(() {
          _filterDepartmentCode = null;

          _filterCityController.clear();
          _filterPostalCodeController.clear();
          _filterCityName = null;
          _filterCitySuggestions = [];
          _filterCityHighlightedIndex = -1;
        });

        _onAnyFilterChanged();
      });
    }

    return Focus(
      focusNode: _deptFocus,
      child: DropdownButtonFormField<String?>(
        value: safeValue,
        isDense: true,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(14),
        decoration: InputDecoration(
          labelText: 'Département',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Tous départements'),
          ),
          ...deptCodes.map(
            (code) => DropdownMenuItem<String?>(
              value: code,
              child: Text(kDepartments[code] ?? code),
            ),
          ),
        ],
        onChanged: (code) {
          setState(() {
            _filterDepartmentCode = code;

            // ✅ Si on choisit un dept, on synchronise la région automatiquement
            if (code != null) {
              final regionCode = _deptToRegion[code];
              if (regionCode != null) _filterRegionCode = regionCode;

              // ✅ Dept change => reset ville + CP (évite incohérences)
              _filterCityController.clear();
              _filterPostalCodeController.clear();
              _filterCityName = null;
              _filterCitySuggestions = [];
              _filterCityHighlightedIndex = -1;
            } else {
              // ✅ Tous départements => reset ville + CP
              _filterCityController.clear();
              _filterPostalCodeController.clear();
              _filterCityName = null;
              _filterCitySuggestions = [];
              _filterCityHighlightedIndex = -1;
            }
          });

          _onAnyFilterChanged(); // ✅ auto-apply

          // Passe au champ ville
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FocusScope.of(context).requestFocus(_filterCityFocusNode);
          });
        },
      ),
    );
  }

  // Méthodes pour la gestion de l'autocomplétion de ville dans les filtres
  List<CityRecord> _searchCities(String q) {
    final allowed = _allowedDeptCodesForCity;
    return CitySearch.instance.search(
      q,
      limit: 20,
      allowedDeptCodes: allowed,
    );
  }

  Widget _buildFilterCityField() {
    return Autocomplete<CityRecord>(
      displayStringForOption: (c) => '${c.name} (${c.cp})',
      optionsBuilder: (TextEditingValue v) {
        final q = v.text.trim();
        if (q.length < 2) return const Iterable<CityRecord>.empty();
        return _searchCities(q);
      },
      optionsViewBuilder: (context, onSelected, options) {
        final surface = Theme.of(context).colorScheme.surface;

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: surface,
            elevation: 4,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  final highlightedIndex =
                      AutocompleteHighlightedOption.of(context);
                  final isHighlighted = index == highlightedIndex;

                  return ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Text(
                      '${option.name} (${option.cp})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    tileColor:
                        isHighlighted ? kPrestoBlue.withOpacity(0.08) : null,
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (CityRecord c) {
        final dept = (c.departmentCode.trim().isNotEmpty)
            ? c.departmentCode.trim()
            : _deptFromPostal(c.postalCode);

        setState(() {
          // ✅ Ville
          _filterCityController.text = c.name;
          _filterCityName = c.name;

          // ✅ CP
          _filterPostalCodeController.text = c.postalCode;

          // ✅ Dept (ex: 971 au lieu de 97)
          _filterDepartmentCode = dept;

          // ✅ Région: prendre celle du record si dispo, sinon fallback via dept
          final regionFromRecord = c.regionCode.trim();
          if (regionFromRecord.isNotEmpty) {
            _filterRegionCode = regionFromRecord;
          } else {
            for (final entry in kRegionDepartments.entries) {
              if (entry.value.contains(dept)) {
                _filterRegionCode = entry.key;
                break;
              }
            }
          }

          _filterCitySuggestions = [];
          _filterCityHighlightedIndex = -1;
        });

        _onAnyFilterChanged();
      },
      fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
        // Synchroniser avec notre controller
        if (_filterCityController.text != textCtrl.text) {
          textCtrl.text = _filterCityController.text;
        }

        return TextField(
          controller: textCtrl,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Ville',
            hintText: 'Ex: Paris, Les Abymes...',
            isDense: true,
            suffixIcon: textCtrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _filterCityController.clear();
                        _filterPostalCodeController.clear();
                        _filterCityName = null;
                        _filterCitySuggestions = [];
                        _filterCityHighlightedIndex = -1;
                      });
                      textCtrl.clear();
                      _onAnyFilterChanged();
                    },
                  ),
          ),
          onChanged: (value) {
            _filterCityController.text = value;
          },
        );
      },
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _filterCategory,
      isDense: true,
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(14),
      decoration: const InputDecoration(
        labelText: 'Catégorie',
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text('Toutes les catégories'),
        ),
        ...kCategories.map(
          (c) => DropdownMenuItem(
            value: c,
            child: Text(c),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _filterCategory = value;
          _headerTitle = _resolveConsultOffersTitle();
        });
        _onAnyFilterChanged();
      },
    );
  }

  String _ageLabelFromCreatedAt(dynamic createdAt) {
    if (createdAt == null) return '';

    DateTime dt;
    try {
      // Firestore Timestamp
      if (createdAt is Timestamp) {
        dt = createdAt.toDate();
      }
      // Milliseconds since epoch
      else if (createdAt is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(createdAt);
      }
      // ISO string
      else if (createdAt is String) {
        dt = DateTime.tryParse(createdAt) ?? DateTime.now();
      } else {
        return '';
      }
    } catch (_) {
      return '';
    }

    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} j';
  }

  String _sanitizeOfferTitle({
    required String rawTitle,
    required String city,
    required String postalCode,
  }) {
    var title = rawTitle.trim();
    if (title.isEmpty) return 'Sans titre';

    final safeCity = city.trim();
    final safePostalCode = postalCode.trim();

    if (safeCity.isNotEmpty && safeCity != 'Lieu non précisé') {
      final cityRegex = RegExp(
        _escapeRegex(safeCity),
        caseSensitive: false,
      );
      title = title.replaceAll(cityRegex, ' ');
    }

    if (safePostalCode.isNotEmpty) {
      final postalRegex = RegExp(
        '\\b${_escapeRegex(safePostalCode)}\\b',
        caseSensitive: false,
      );
      title = title.replaceAll(postalRegex, ' ');
    }

    title = title
        .replaceAll(RegExp(r'\s*[-–/|]\s*'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return title.isEmpty ? rawTitle.trim() : title;
  }

  String _escapeRegex(String input) {
    return input.replaceAllMapped(
      RegExp(r'[\\^\$.|?*+(){}\[\]]'),
      (m) => '\\${m[0]}',
    );
  }

  String _extractMissionDelayLabel(Map<String, dynamic> data) {
    final candidates = [
      data['missionDelay'],
      data['averageDelay'],
      data['dateLabel'],
      data['deadlineLabel'],
      data['executionDelay'],
      data['responseDelay'],
    ];

    for (final candidate in candidates) {
      final value = (candidate ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }

    return 'Délai non précisé';
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'plomberie':
        return Icons.plumbing_outlined;
      case 'bricolage':
        return Icons.handyman_outlined;
      case 'jardinage':
        return Icons.yard_outlined;
      case 'menage':
      case 'ménage':
        return Icons.cleaning_services_outlined;
      case 'demenagement':
      case 'déménagement':
        return Icons.local_shipping_outlined;
      default:
        return Icons.work_outline_rounded;
    }
  }

  bool _isQuickResponse(Map<String, dynamic> data) {
    final dynamic direct = data['quickResponse'] ?? data['isQuickResponse'];
    if (direct is bool) return direct;

    final statusBadges = (data['statusBadges'] as List<dynamic>? ?? const [])
        .map((e) => e.toString().toLowerCase())
        .toList();
    if (statusBadges.any((b) => b.contains('rapide'))) {
      return true;
    }

    final availability = (data['availability'] ?? '').toString().toLowerCase();
    if (availability.contains('rapide')) {
      return true;
    }

    final averageDelay = (data['averageDelay'] ?? '').toString().toLowerCase();
    if (averageDelay.contains('min')) {
      return true;
    }

    return false;
  }

  Future<void> _showEditOfferDialog(
    BuildContext context,
    String offerId,
    Map<String, dynamic> data,
  ) async {
    final titleCtrl =
        TextEditingController(text: (data['title'] ?? '').toString());
    final cityCtrl =
        TextEditingController(text: (data['city'] ?? '').toString());
    final descCtrl =
        TextEditingController(text: (data['description'] ?? '').toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Modifier l\'annonce',
          style: kPrestoSectionTitleStyle,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Titre')),
              const SizedBox(height: 8),
              TextField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(labelText: 'Ville')),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 3,
                maxLines: 6,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enregistrer')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await FirebaseFirestore.instance.collection('offers').doc(offerId).update({
        'title': titleCtrl.text.trim(),
        'city': cityCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de modifier l\'annonce : $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteOffer(
    BuildContext context,
    String offerId,
    String title,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Supprimer l\'annonce ?',
          style: kPrestoSectionTitleStyle,
        ),
        content: Text(
          'Supprimer : "$title" ?',
          style: kPrestoBodyTextStyle,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer')),
        ],
      ),
    );

    if (yes != true) return;

    try {
      await FirebaseFirestore.instance.collection('offers').doc(offerId).delete();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de supprimer l\'annonce : $e')),
        );
      }
    }
  }
}

class _OfferBrowseTileData {
  final String title;
  final String subtitle;
  final String publishedText;
  final int price;
  final String missionDelayLabel;
  final bool isUrgent;
  final IconData icon;

  const _OfferBrowseTileData({
    required this.title,
    required this.subtitle,
    required this.publishedText,
    required this.price,
    required this.missionDelayLabel,
    required this.isUrgent,
    required this.icon,
  });
}

class _OfferBrowseTile extends StatefulWidget {
  final _OfferBrowseTileData data;
  final VoidCallback? onTap;

  const _OfferBrowseTile({
    required this.data,
    this.onTap,
  });

  @override
  State<_OfferBrowseTile> createState() => _OfferBrowseTileState();
}

class _OfferBrowseTileState extends State<_OfferBrowseTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const outerRadius = 24.0;
    const innerRadius = 22.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final showUrgentContour = widget.data.isUrgent;
        final pulse = _pulse.value;

        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(outerRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(outerRadius),
            onTap: widget.onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(outerRadius),
                gradient: showUrgentContour
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF9CDEFF).withValues(
                            alpha: 0.56 + (0.14 * pulse),
                          ),
                          const Color(0xFF1A73E8).withValues(
                            alpha: 0.84 + (0.10 * pulse),
                          ),
                          const Color(0xFF5FB4FF).withValues(
                            alpha: 0.60 + (0.14 * pulse),
                          ),
                        ],
                      )
                    : null,
                color: showUrgentContour
                    ? null
                    : Colors.white.withValues(alpha: 0.96),
                border: showUrgentContour
                    ? null
                    : Border.all(
                        color: _ConsultOffersPageState._offersCardBorder,
                        width: 1,
                      ),
                boxShadow: [
                  const BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                  if (showUrgentContour)
                    BoxShadow(
                      color: const Color(0xFF1A73E8).withValues(
                        alpha: 0.10 + (0.12 * pulse),
                      ),
                      blurRadius: 14 + (8 * pulse),
                      spreadRadius: 0.5 + (0.7 * pulse),
                      offset: const Offset(0, 0),
                    ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(showUrgentContour ? 1.5 : 0),
                child: Ink(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(innerRadius),
                    border: Border.all(
                      color: showUrgentContour
                          ? Colors.white.withValues(alpha: 0.78)
                          : _ConsultOffersPageState._offersCardBorder,
                      width: showUrgentContour ? 0.8 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.data.title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: _ConsultOffersPageState._offersNavy,
                            letterSpacing: 0.15,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.data.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.0,
                            fontWeight: FontWeight.w500,
                            color: _ConsultOffersPageState._offersNavy
                                .withValues(alpha: 0.82),
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                widget.data.publishedText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.0,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      _ConsultOffersPageState._offersSoftText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 148),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${widget.data.price} €',
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      height: 1.0,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          _ConsultOffersPageState._offersOrange,
                                      letterSpacing: -0.9,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _OfferMissionDelayChip(
                                    label: widget.data.missionDelayLabel,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OfferMissionDelayChip extends StatelessWidget {
  final String label;

  const _OfferMissionDelayChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final maxWidth = (MediaQuery.sizeOf(context).width * 0.34).clamp(
      112.0,
      148.0,
    );

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFFFFC04A),
            Color(0xFFFF7A00),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color:
                _ConsultOffersPageState._offersOrange.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _StandardResponseBadge extends StatelessWidget {
  const _StandardResponseBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEF4),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: const Text(
        'Standard',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF666C87),
        ),
      ),
    );
  }
}

class _EmptyOffers extends StatelessWidget {
  const _EmptyOffers();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              "Les annonces peuvent arriver à tout moment.",
              style: TextStyle(
                fontSize: 17,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              "Ajoutez cette catégorie en favori pour être alerté dès qu'une annonce est publiée.",
              style: TextStyle(
                fontSize: 17,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              "Créez un compte pour enregistrer vos favoris et activer les notifications.",
              style: TextStyle(
                fontSize: 17,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ DEPRECATED: OfferDetailPage supprimee
// Utilisez OfferDetailsPage (pages/offers/offer_details_page.dart) a la place

class UserPublicProfilePage extends StatefulWidget {
  final String userId;
  final String? initialPseudo;

  const UserPublicProfilePage({
    super.key,
    required this.userId,
    this.initialPseudo,
  });

  @override
  State<UserPublicProfilePage> createState() => _UserPublicProfilePageState();
}

class _UserPublicProfilePageState extends State<UserPublicProfilePage> {
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadActiveOffers() async {
    final col = FirebaseFirestore.instance.collection('offers');

    final resUid = await col
        .where('uid', isEqualTo: widget.userId)
        .where(_publicOffersFilter())
        .get();
    final resUserId = await col
        .where('userId', isEqualTo: widget.userId)
        .where(_publicOffersFilter())
        .get();

    final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final d in resUid.docs) {
      byId[d.id] = d;
    }
    for (final d in resUserId.docs) {
      byId[d.id] = d;
    }

    final docs = byId.values.toList(growable: false);

    // Filtrer “en cours”: public (nouveau modèle) ou status=active (legacy)
    final filtered = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in docs) {
      final data = doc.data();
      final visibility = (data['visibility'] is Map)
          ? (data['visibility'] as Map)
          : const <String, dynamic>{};
      final isPublic =
          visibility['isPublic'] == true || data['status'] == 'active';
      if (!isPublic) continue;
      filtered.add(doc);
    }
    return filtered;
  }

  String _extractUserPseudo(Map<String, dynamic>? data) {
    final candidates = <String?>[
      data?['pseudo']?.toString(),
      data?['username']?.toString(),
      data?['displayName']?.toString(),
      data?['name']?.toString(),
      widget.initialPseudo,
    ];
    for (final v in candidates) {
      final s = (v ?? '').trim();
      if (s.isNotEmpty) return s;
    }
    return 'Profil';
  }

  Future<void> _contactUser(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final bool isLoggedIn = user != null;

    if (!isLoggedIn) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AccountPage(),
        ),
      );
      return;
    }

    if (!context.mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        systemOverlayStyle: prestoOverlayStyleFor(kPrestoBlue),
        leading: const BackButton(),
        title: const Text(
          'Profil',
          style: kPrestoAppBarTitleStyle,
        ),
        centerTitle: true,
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .snapshots()
                  .map((snap) {
                PrestoMonitoring.I.trackOtherStream(
                  key: 'userProfile.userDoc',
                  docsCount: snap.exists ? 1 : 0,
                );
                return snap;
              }),
              builder: (context, snap) {
                final pseudo = _extractUserPseudo(snap.data?.data());
                return _CardShell(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFFFF3E8),
                            child: Icon(
                              Icons.person_outline,
                              size: 20,
                              color: Colors.orange.shade800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              pseudo,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Contacter ce membre pour échanger sur ses annonces.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrestoBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onPressed: () => _contactUser(context),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Contacter par message'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            _CardShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Annonces publiées en cours',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<
                      List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                    future: _loadActiveOffers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(kPrestoOrange),
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Text(
                          "Erreur de chargement des annonces.",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }

                      final docs = snapshot.data ?? const [];
                      if (docs.isEmpty) {
                        return Text(
                          "Aucune annonce en cours.",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }

                      return Column(
                        children: [
                          for (final doc in docs) ...[
                            _UserOfferMiniCard(
                              offerId: doc.id,
                              data: doc.data(),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserOfferMiniCard extends StatelessWidget {
  final String offerId;
  final Map<String, dynamic> data;
  const _UserOfferMiniCard({required this.offerId, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = (data['title'] ?? '').toString().trim();
    final location = (data['location'] ?? data['city'] ?? '').toString().trim();
    final category = (data['category'] ?? '').toString().trim();
    final budget = data['budget'];
    final priceText = (budget is num) ? "${budget.toStringAsFixed(0)} €" : '';

    final annonceurId = (data['userId'] ?? data['uid'] ?? '').toString().trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) {
                final description = (data['description'] ?? '').toString();
                final phone = data['phone']?.toString();

                final List<String> imageUrls =
                    (data['imageUrls'] as List<dynamic>? ?? [])
                        .map((e) => e.toString())
                        .toList();

                return OfferDetailsPage(
                  offer: _buildOfferDetailsOffer(
                    offerId: offerId,
                    data: data,
                  ),
                  currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
                );
              },
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.isEmpty ? 'Annonce' : title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              if (location.isNotEmpty)
                Text(
                  location,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (category.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    category,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (priceText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    priceText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: kPrestoOrange,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
// (supprimé) `_OfferMetaRow` était non référencé et générait un avertissement.

/// Utilitaire : format d'heure pour la liste de conversations
String formatTimeLabel(Timestamp? ts) {
  if (ts == null) return '';
  final dt = ts.toDate();
  final now = DateTime.now();

  final sameDay =
      dt.year == now.year && dt.month == now.month && dt.day == now.day;

  if (sameDay) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
}

/// Utilitaire : format "il y a X h/j" depuis un Timestamp
String formatAgeSince(Timestamp? ts) {
  if (ts == null) {
    return ""; // quand createdAt pas encore rempli (serverTimestamp)
  }
  final dt = ts.toDate();
  final now = DateTime.now();

  final diff = now.difference(dt);
  if (diff.isNegative) return ""; // sécurité si horloge bizarre

  if (diff.inHours < 24) {
    final h = diff.inHours;
    // si < 1h, on affiche en minutes (optionnel)
    if (h <= 0) {
      final m = diff.inMinutes.clamp(0, 59);
      return "il y a $m min";
    }
    return "il y a $h h";
  }

  final d = diff.inDays;
  return "il y a $d j";
}

/// PAGE MESSAGES (LISTE DE CONVERSATIONS) //////////////////////////////////

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ConversationsListPage();
  }
}

/// PAGE PUBLIER UNE OFFRE //////////////////////////////////////////////////

class PublishOfferPage extends StatefulWidget {
  final Function(double)? onScroll;

  const PublishOfferPage({
    super.key,
    this.onScroll,
  });

  @override
  State<PublishOfferPage> createState() => _PublishOfferPageState();
}

class _PublishOfferPageState extends State<PublishOfferPage> {
  // ✅ NOUVEAU: Variables pour le streaming
  final StreamController<String> _transcriptionStream =
      StreamController<String>.broadcast();
  String _partialTranscript = '';
  Timer? _streamingTimer;
  bool _isStreaming = false;

  // ✅ AJOUT: Subscription pour le stream audio
  StreamSubscription<Uint8List>? _streamMicSub;

  /// ✅ STREAMING RÉEL: Mobile avec startStream() + PCM16
  Future<void> _startStreamingMic() async {
    if (_isListening || _isStreaming) return;

    if (kIsWeb) {
      // ✅ WEB: Chunking mode (chunks toutes les 2 secondes)
      // Note: Web enregistre des chunks et les envoie progressivement
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          showSuccessSnackBar(context, 'Connecte-toi pour utiliser la dictée');
          return;
        }

        await _webRec.start();

        setState(() {
          _isListening = true;
          _isStreaming = true; // Web: mode chunking (quasi temps-réel)
          _partialTranscript = '';
        });

        debugPrint('[Streaming Web] Web recording started (chunked mode)');

        // ✅ Chunking timer: toutes les 2 secondes
        _streamingTimer?.cancel();
        _streamingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
          if (!_isListening || !mounted) return;

          try {
            // ✅ Arrêter temporairement et récupérer le blob du chunk
            final blob = await _webRec.stopToBlob();

            debugPrint('[Streaming Web] Chunk blob acquired');

            // ✅ Redémarrer pour le prochain chunk
            await _webRec.start();

            // ✅ Convertir blob en bytes et uploader
            final chunkBytes = await webBlobToBytes(blob);
            if (chunkBytes.isEmpty) {
              debugPrint('[Streaming Web] Empty chunk bytes');
              return;
            }

            final ts = DateTime.now().millisecondsSinceEpoch;
            final chunkPath = 'stt_streaming/$uid/${ts}_chunk.webm';

            final ref = FirebaseStorage.instance.ref(chunkPath);
            await ref.putData(
              chunkBytes,
              SettableMetadata(contentType: 'audio/webm'),
            );

            debugPrint(
                '[Streaming Web] Chunk uploaded: $chunkPath (${chunkBytes.length} bytes)');

            // ✅ Transcription du chunk (async, non-bloquant)
            MicroIaService.processAudio(
              storagePath: chunkPath,
              languageCode: 'fr-FR',
              // streamingMode: true,
            ).then((result) {
              if (!mounted) return;

              final text = (result['text'] ?? '').toString().trim();
              if (text.isNotEmpty) {
                final newTranscript = _partialTranscript.isEmpty
                    ? text
                    : '$_partialTranscript $text';

                // ✅ Envoyer au stream pour update UI
                _transcriptionStream.add(newTranscript);
                debugPrint('[Streaming Web] Chunk transcribed: "$text"');
              }
            }).catchError((e) {
              debugPrint('[Streaming Web] Transcription error: $e');
            });
          } catch (e) {
            debugPrint('[Streaming Web] Chunk processing error: $e');
          }
        });
      } catch (e, st) {
        await CrashlyticsContext.recordError(
          e is Exception ? e : Exception(e.toString()),
          st,
          reason: 'Web streaming mic failed',
          fatal: false,
        );
        if (!mounted) return;
        showSuccessSnackBar(context, 'Erreur streaming micro: $e');
      }
      return;
    }

    // ✅ MOBILE: Streaming RÉEL avec startStream() + PCM16
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!mounted) return;

      if (!hasPermission) {
        if (!mounted) return;
        showSuccessSnackBar(context, 'Permission micro requise');
        return;
      }

      // ✅ CHANGEMENT 1: startStream() retourne un Stream<Uint8List>
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits, // ✅ PCM16 (requis pour Google STT)
          sampleRate: 16000, // ✅ 16kHz
          numChannels: 1,
        ),
      );

      if (!mounted) return;

      setState(() {
        _isListening = true;
        _isStreaming = true; // Mode streaming réel
        _partialTranscript = '';
      });

      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      int chunkBytes = 0;
      final int chunkThreshold = 16000 * 2; // ~2 secondes à 16kHz

      debugPrint('[Streaming Mobile] Stream started with PCM16');

      // ✅ CHANGEMENT 2: Écouter le stream audio
      _streamMicSub?.cancel();
      _streamMicSub = stream.listen(
        (Uint8List chunk) async {
          if (!_isListening || !mounted) return;

          try {
            chunkBytes += chunk.length;

            // Envoyer quand le seuil est atteint
            if (chunkBytes >= chunkThreshold) {
              final ts = DateTime.now().millisecondsSinceEpoch;
              final chunkPath = 'stt_streaming/$uid/${ts}_chunk.pcm';

              // ✅ CHANGEMENT 3: Upload du chunk PCM
              final ref = FirebaseStorage.instance.ref(chunkPath);
              await ref.putData(
                chunk,
                SettableMetadata(contentType: 'audio/pcm'),
              );

              debugPrint(
                  '[Streaming Mobile] Chunk uploaded: ${chunk.length} bytes at $chunkPath');

              // ✅ Transcription du chunk (async, non-bloquant)
              MicroIaService.processAudio(
                storagePath: chunkPath,
                languageCode: 'fr-FR',
                // streamingMode: true,
              ).then((result) {
                if (!mounted) return;

                final text = (result['text'] ?? '').toString().trim();
                if (text.isNotEmpty) {
                  final newTranscript = _partialTranscript.isEmpty
                      ? text
                      : '$_partialTranscript $text';

                  // ✅ Envoyer au stream pour update UI
                  _transcriptionStream.add(newTranscript);
                  debugPrint('[Streaming Mobile] Chunk transcribed: "$text"');
                }
              }).catchError((e) {
                debugPrint('[Streaming Mobile] Transcription error: $e');
              });

              chunkBytes = 0; // Reset
            }
          } catch (e) {
            debugPrint('[Streaming Mobile] Chunk error: $e');
          }
        },
        onError: (error) {
          debugPrint('[Streaming Mobile] Stream error: $error');
          if (mounted) {
            setState(() {
              _isListening = false;
              _isStreaming = false;
            });
          }
        },
        onDone: () {
          debugPrint('[Streaming Mobile] Stream done');
          if (mounted) {
            setState(() {
              _isListening = false;
              _isStreaming = false;
            });
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[Streaming Mobile] Start error: $e');
      if (mounted) {
        showSuccessSnackBar(context, 'Erreur streaming: $e');
      }

      // ✅ Fallback: enregistrement classique si streaming non supporté
      await _startMic();
    }
  }

  Future<void> _stopStreamingMic() async {
    if (!_isListening) return;

    _streamingTimer?.cancel();
    _streamingTimer = null;

    // Stop Web chunking
    if (kIsWeb) {
      try {
        // Stopper l'enregistreur (on ignore le blob final)
        await _webRec.stopToBlob();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _isListening = false;
        _isStreaming = false;
      });
      return;
    }

    // Stop Mobile streaming
    try {
      await _streamMicSub?.cancel();
      _streamMicSub = null;
    } catch (_) {}

    try {
      await _recorder.stop();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isListening = false;
      _isStreaming = false;
    });
  }

  /// ✅ MODIFIÉ: Utiliser _startStreamingMic() au lieu de _startMic()
  /// ✅ MODIFIÉ: Bouton micro avec feedback streaming amélioré

  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  bool _isUrgent = false;

  // ✅ Analytics
  // late final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// ✅ Enregistre la publication d'une offre
  Future<void> _logOfferPublished({
    required String offerId,
    required String title,
    required String category,
    required String? budget,
    required String budgetType,
  }) async {
    try {
      /*
      await _analytics.logEvent(
        name: 'ecommerce_purchase',
        parameters: {
          'value': (budget != null && budget.isNotEmpty)
              ? double.tryParse(budget) ?? 0.0
              : 0.0,
          'currency': 'EUR',
          'transaction_id': offerId,
          'items': [
            {
              'item_id': offerId,
              'item_name': title,
              'item_category': category,
            },
          ],
        },
      );

      // ✅ Event personnalisé supplémentaire
      await _analytics.logEvent(
        name: 'offer_published',
        parameters: {
          'offer_id': offerId,
          'title': title,
          'category': category,
          'budget_type': budgetType,
          'has_photos': _selectedPhotos.isNotEmpty,
          'photo_count': _selectedPhotos.length,
          'is_urgent': _isUrgent,
        },
      );
      */
    } catch (e) {
      debugPrint('[Analytics] logOfferPublished error: $e');
    }
  }

  // Champs texte
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  // Indicatif téléphonique sélectionné
  String _selectedPhoneCountryCode = '+33';

  // Catégories / sous-catégories
  String? _category;
  String? _selectedSubCategory;

  List<String> get _categories =>
      kCategorySubcategories.keys.toList(); // Map<String, List<String>>

  // Budget: type (fixe / à négocier)
  final List<String> _budgetTypes = const ['Fixe', 'À négocier'];
  String _budgetType = 'Fixe';

  // Délai pour effectuer la mission
  final List<String> _missionDelayOptions = const [
    'Immédiat',
    'Dans la journée',
    'Sous 24h',
    'Sous 48h',
    'Cette semaine',
    'À convenir',
  ];
  String? _missionDelay;

  // Photos (max 2)
  final List<XFile> _selectedPhotos = [];
  final List<Uint8List?> _selectedPhotoBytes = [];
  final List<String> _uploadedPhotoUrls = [];

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  // Autocomplétion villes
  List<CityRecord> _citySuggestions = [];
  int _highlightedIndex = -1;

  // Région / département (optionnel à exploiter dans le futur)
  String? _selectedRegionCode;
  String? _selectedDeptCode;

  bool _isSubmitting = false;
  bool _isAnalyzing = false;
  bool _isListening = false;

  bool _attemptedSubmit = false; // affiche erreurs après tentative
  bool _publishLocked = false; // lock après tentative invalide
  bool _canPublish = false;

  // Service IA pour analyser la description
  final AiDraftService _aiService = AiDraftService();
  final AudioRecorder _recorder = AudioRecorder();
  final WebAudioRecorder _webRec = WebAudioRecorder();
  String? _recordingPath;
  // Toujours actif (améliore la qualité via Google STT côté serveur)
  final bool _useCloudStt = true;

  // ✅ Extraction rapide CP (FR + DROM) depuis la transcription
  String? _extractPostalCodeFromTranscript(String transcript) {
    final t = transcript;
    // 5 chiffres métropole + 97x/98x (DROM/COM) acceptés aussi (souvent 5 chiffres au final)
    final m = RegExp(r'\b(97[0-9]{3}|98[0-9]{3}|[0-9]{5})\b').firstMatch(t);
    return m?.group(1);
  }

  // ✅ Extraction ville: soit via CP (fiable), soit via motif "à <ville>"
  CityRecord? _extractCityRecordFromTranscript(String transcript,
      {String? cp}) {
    if (cp != null && cp.trim().isNotEmpty) {
      return CitySearch.instance.pickBestForPostalCode(cp.trim());
    }

    // ✅ FIX: raw string + apostrophes => utiliser guillemets doubles
    final m = RegExp(
      r"\b(?:a|à|sur|vers|près de|proche de)\s+([A-Za-zÀ-ÖØ-öø-ÿ'’\-\s]{2,40})\b",
      caseSensitive: false,
    ).firstMatch(transcript);

    final rawCity = m?.group(1)?.trim();
    if (rawCity == null || rawCity.isEmpty) return null;

    final candidates = CitySearch.instance.search(rawCity, limit: 1);
    return candidates.isNotEmpty ? candidates.first : null;
  }

  /// Remplissage immédiat (latence perçue ↓) dès que la transcription est prête.
  /// L'IA pourra ensuite affiner et remplacer.
  void _applyFastDraftFromTranscript(String transcript) {
    final t = transcript.trim();
    if (t.isEmpty) return;

    // Description: si vide, on met la transcription brute immédiatement.
    if (_descriptionController.text.trim().isEmpty) {
      _descriptionController.text = t;
    }

    // Titre: si vide, on extrait une 1ère ligne/sentence courte.
    if (_titleController.text.trim().isEmpty) {
      final firstLine = t.split('\n').first.trim();
      final firstSentence = firstLine.split(RegExp(r'[.!?]')).first.trim();
      final candidate = (firstSentence.isNotEmpty ? firstSentence : firstLine);

      final title = candidate.length > 72
          ? '${candidate.substring(0, 72).trim()}…'
          : candidate;
      if (title.isNotEmpty) _titleController.text = title;
    }

    // ✅ CP + ville (sans inventer): uniquement si on détecte un CP ou une ville matchable
    if (_postalCodeController.text.trim().isEmpty) {
      final cp = _extractPostalCodeFromTranscript(t);
      if (cp != null && cp.isNotEmpty) _postalCodeController.text = cp;
    }

    final effectiveCp = _postalCodeController.text.trim().isEmpty
        ? null
        : _postalCodeController.text.trim();

    if (_locationController.text.trim().isEmpty) {
      final cityRec = _extractCityRecordFromTranscript(t, cp: effectiveCp);
      if (cityRec != null) {
        _locationController.text = cityRec.name;

        // si CP vide mais la ville en a un, on complète
        if (_postalCodeController.text.trim().isEmpty &&
            cityRec.cp.isNotEmpty) {
          _postalCodeController.text = cityRec.cp;
        }

        // bonus cohérence UI: indicatif selon dept (déjà présent dans le code)
        if (!mounted) return;
        setState(() {
          _selectedDeptCode = cityRec.dept;
          _selectedRegionCode = cityRec.region;
          _selectedPhoneCountryCode = _countryCodeForDept(cityRec.dept);
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      widget.onScroll?.call(_scrollController.offset);
    });

    _titleController.addListener(_recompute);
    _descriptionController.addListener(_recompute);
    _locationController.addListener(_recompute);
    _phoneController.addListener(_recompute);
    _budgetController.addListener(_recompute);

    WidgetsBinding.instance.addPostFrameCallback((_) => _recompute());

    // ✅ Écouter le stream de transcription
    _transcriptionStream.stream.listen((text) {
      if (!mounted) return;
      setState(() {
        _partialTranscript = text;
        // Remplir les champs au fur et à mesure
        _applyFastDraftFromTranscript(text);
      });
    });
  }

  bool _isValidPhoneFR(String raw) {
    final s = raw.replaceAll(RegExp(r'\s+'), '');
    if (s.isEmpty) return false;

    // Accepte : 612345678, 06XXXXXXXX, 07XXXXXXXX, +336XXXXXXXX, +337XXXXXXXX
    final fr9 = RegExp(r'^[67]\d{8}$');
    final fr10 = RegExp(r'^0[67]\d{8}$');
    final intl = RegExp(r'^\+33[67]\d{8}$');
    return fr9.hasMatch(s) || fr10.hasMatch(s) || intl.hasMatch(s);
  }

  double? _parseBudget(String raw) {
    final cleaned = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  Widget _requiredLabel(String text) {
    final theme = Theme.of(context);
    final base = theme.inputDecorationTheme.labelStyle ??
        theme.textTheme.bodyLarge ??
        const TextStyle(fontSize: 16, color: Colors.black87);
    final baseColor = base.color ?? Colors.black87;

    return RichText(
      text: TextSpan(
        style: base.copyWith(color: baseColor),
        children: [
          TextSpan(text: text),
          const TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  bool _requiredOk() {
    final titleOk = _titleController.text.trim().isNotEmpty;
    final descOk = _descriptionController.text.trim().isNotEmpty;
    final cityOk = _locationController.text.trim().isNotEmpty;
    final catOk = (_category ?? '').trim().isNotEmpty;
    final subOk = (_selectedSubCategory ?? '').trim().isNotEmpty;
    final delayOk = (_missionDelay ?? '').trim().isNotEmpty;
    final phoneOk = _isValidPhoneFR(_phoneController.text);

    final budgetOk = _budgetType == 'À négocier'
        ? true
        : () {
            final b = _parseBudget(_budgetController.text);
            return b != null && b > 0;
          }();

    return titleOk &&
        descOk &&
        cityOk &&
        catOk &&
        subOk &&
        delayOk &&
        phoneOk &&
        budgetOk;
  }

  void _recompute() {
    final ok = _requiredOk();
    if (!mounted) return;
    if (_canPublish == ok && !(_publishLocked && ok)) return;
    setState(() {
      _canPublish = ok;
      if (_publishLocked && ok) _publishLocked = false; // délock auto
    });
  }

  Future<bool> _ensureLoggedInForPublish() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) return true;

    final startInSignup = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Text(
                'Connecte-toi pour publier',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ton formulaire reste rempli. Connecte-toi ou crée ton compte pour finaliser la publication.',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrestoOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Je me connecte'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text("Je crée mon compte"),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Plus tard'),
              ),
            ],
          ),
        );
      },
    );

    if (startInSignup == null) return false;

    if (!mounted) return false;

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AccountPage(startInSignup: startInSignup),
      ),
    );

    return FirebaseAuth.instance.currentUser != null;
  }

  Future<void> _onPublishPressed() async {
    final loggedIn = await _ensureLoggedInForPublish();
    if (!loggedIn) return;

    setState(() {
      _attemptedSubmit = true;
      _publishLocked = false;
    });

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || !_requiredOk()) {
      // Les champs invalides (ou manquants) seront affichés en rouge via la validation.
      return;
    }

    await _submitForm();
  }

  Future<void> _startMic() async {
    if (_isListening) return;

    // ✅ Micro global: on ne fait PLUS speech_to_text (trop variable)
    // On enregistre uniquement en WAV 16k mono, puis _stopMic() déclenchera _uploadAndTranscribe() (MicroIA).
    if (kIsWeb) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          if (!mounted) return;
          showSuccessSnackBar(context, 'Connecte-toi pour utiliser la dictée');
          return;
        }

        await CrashlyticsContext.setUserId(uid);
        await CrashlyticsContext.setKey('flow', 'webMic');

        await _webRec.start();
        if (!mounted) return;
        setState(() => _isListening = true);
      } catch (e, st) {
        await CrashlyticsContext.recordError(
          e is Exception ? e : Exception(e.toString()),
          st,
          reason: 'Web mic start failed',
          fatal: false,
          keys: {
            'component': 'Main',
            'flow': 'webMic',
            'step': 'start',
          },
        );
        if (!mounted) return;
        showSuccessSnackBar(context, 'Micro web indisponible: $e');
      }
      return;
    }

    // Préparer l'enregistreur haute qualité (WAV)
    try {
      if (await _recorder.hasPermission()) {
        final filePath =
            await createTempAudioPath(prefix: 'presto', extension: 'm4a');
        await _recorder.start(
          RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 44100,
            numChannels: 1,
          ),
          path: filePath,
        );
        _recordingPath = filePath;
      } else {
        if (!mounted) return;
        showSuccessSnackBar(context, 'Permission micro requise');
        return;
      }
    } catch (e) {
      debugPrint('Recorder start error: $e');
    }

    setState(() {
      _isListening = true;
    });
  }

  Future<void> _stopMic() async {
    if (!_isListening) return;
    if (_isAnalyzing) return;

    // ✅ Arrêter le timer de chunking web (streaming mode)
    _streamingTimer?.cancel();
    _streamingTimer = null;

    if (kIsWeb) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _isAnalyzing = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        final uid = user?.uid;
        if (uid == null) throw Exception('Not authenticated');

        final blob = await _webRec.stopToBlob();
        final webmBytes = await webBlobToBytes(blob);
        if (webmBytes.length < 30000) {
          throw Exception(
              'Audio invalide (blob trop petit: ${webmBytes.length} bytes).');
        }

        final ts = DateTime.now().millisecondsSinceEpoch;
        final destPath = 'stt/${uid}_$ts.webm';
        final ref = FirebaseStorage.instance.ref(destPath);
        await ref.putData(
            webmBytes, SettableMetadata(contentType: 'audio/webm'));

        final out = await MicroIaService.processAudio(
          storagePath: destPath,
          languageCode: 'fr-FR',
        );

        final transcript = (out['text'] ?? '').toString().trim();
        if (transcript.isEmpty) throw Exception('Aucun texte reconnu');

        // Remplissage immédiat (titre/desc/ville/cp) avant l'IA.
        _applyFastDraftFromTranscript(transcript);

        final draft = await _aiService.generateOfferDraft(text: transcript);
        if (!mounted) return;

        if (draft['success'] == true) {
          setState(() {
            final title = (draft['title'] as String? ?? '').trim();
            final category = (draft['category'] as String? ?? '').trim();
            final description = (draft['description'] as String? ?? '').trim();
            final location = (draft['location'] as String? ?? '').trim();
            final postalCode = (draft['postalCode'] as String? ?? '').trim();

            if (title.isNotEmpty) _titleController.text = title;
            if (description.isNotEmpty)
              _descriptionController.text = description;
            if (category.isNotEmpty) {
              _category = category;
              _selectedSubCategory = null;
            }
            if (location.isNotEmpty) _locationController.text = location;
            if (postalCode.isNotEmpty) _postalCodeController.text = postalCode;
          });

          showSuccessSnackBar(
              context, 'Transcription réussie et champs remplis');
        } else {
          final code = (draft['code'] ?? '').toString();
          showSuccessSnackBar(
            context,
            code == 'deadline-exceeded'
                ? 'Connexion lente, réessaie.'
                : 'Erreur IA: ${draft['error'] ?? 'inconnue'}',
          );
        }
      } catch (e, st) {
        await CrashlyticsContext.recordError(
          e is Exception ? e : Exception(e.toString()),
          st,
          reason: 'Web mic stop/process failed',
          fatal: false,
          keys: {
            'component': 'Main',
            'flow': 'webMic',
            'step': 'stop',
          },
        );
        if (!mounted) return;
        if (isTimeoutError(e)) {
          showTimeoutSnackBar(context);
        } else {
          showSuccessSnackBar(context, 'Erreur transcription (web): $e');
        }
      } finally {
        if (mounted) setState(() => _isAnalyzing = false);
      }
      return;
    }

    String? recordedPath;
    try {
      recordedPath = await _recorder.stop();
      if (recordedPath == null) {
        recordedPath = _recordingPath;
      }
    } catch (e) {
      debugPrint('Recorder stop error: $e');
    }
    setState(() {
      _isListening = false;
    });
    // Si l'audio est disponible et cloud STT activé, on passe par la fonction distante
    if (_useCloudStt && recordedPath != null) {
      setState(() => _isAnalyzing = true);
      try {
        await _uploadAndTranscribe(recordedPath);
      } catch (e) {
        if (!mounted) return;
        if (isTimeoutError(e)) {
          showTimeoutSnackBar(context);
        } else {
          showSuccessSnackBar(context, 'Erreur transcription: $e');
        }
      } finally {
        if (mounted) setState(() => _isAnalyzing = false);
      }
      return;
    }

    if (!mounted) return;
    showSuccessSnackBar(context, 'Aucun audio disponible');
  }

  /// Construire le bouton d'enregistrement au micro avec indicateur visuel
  Widget _buildMicRecordingButton() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.92,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE53935), // Rouge plus clair en haut
            Color(0xFFC62828), // Rouge plus profond en bas
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC62828).withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isStreaming ? _stopStreamingMic : _stopMic,
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stop_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                'Appuyer pour arrêter',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      letterSpacing: 0.3,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadAndTranscribe(String localPath) async {
    // Upload vers Firebase Storage puis appel de la Cloud Function.
    // ✅ Forcer le pipeline MicroIA (WAV 16k mono) + génération de draft.
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'anonymous';
    final xfile = XFile(localPath);
    final audioBytes = await xfile.readAsBytes();
    if (audioBytes.isEmpty) {
      throw 'Fichier audio introuvable';
    }
    final lower = localPath.toLowerCase();
    final isM4a = lower.endsWith('.m4a');
    final isMp4 = lower.endsWith('.mp4');
    final ext = isM4a ? 'm4a' : (isMp4 ? 'mp4' : 'wav');
    final contentType = (isM4a || isMp4) ? 'audio/mp4' : 'audio/wav';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final storage = FirebaseStorage.instance;
    final destPath = 'stt/${uid}_$ts.$ext';
    final ref = storage.ref(destPath);
    await ref.putData(audioBytes, SettableMetadata(contentType: contentType));

    final out = await MicroIaService.processAudio(
      storagePath: destPath,
      languageCode: 'fr-FR',
    );

    final transcript = (out['text'] ?? '').toString().trim();
    if (transcript.isEmpty) {
      throw Exception('Aucun texte reconnu');
    }

    // Remplissage immédiat (titre/desc/ville/cp) avant l'IA.
    _applyFastDraftFromTranscript(transcript);

    final draft = await _aiService.generateOfferDraft(text: transcript);
    if (!mounted) return;

    if (draft['success'] == true) {
      setState(() {
        final title = (draft['title'] as String? ?? '').trim();
        final category = (draft['category'] as String? ?? '').trim();
        final description = (draft['description'] as String? ?? '').trim();
        final location = (draft['location'] as String? ?? '').trim();
        final postalCode = (draft['postalCode'] as String? ?? '').trim();

        if (title.isNotEmpty) _titleController.text = title;
        if (description.isNotEmpty) _descriptionController.text = description;
        if (category.isNotEmpty) {
          _category = category;
          _selectedSubCategory = null;
        }
        if (location.isNotEmpty) _locationController.text = location;
        if (postalCode.isNotEmpty) _postalCodeController.text = postalCode;
      });

      showSuccessSnackBar(context, 'Transcription réussie et champs remplis');
    } else {
      final code = (draft['code'] ?? '').toString();
      showSuccessSnackBar(
        context,
        code == 'deadline-exceeded'
            ? 'Connexion lente, réessaie.'
            : 'Erreur IA: ${draft['error'] ?? 'inconnue'}',
      );
    }
  }

  /// Appelle la Cloud Function pour analyser la description avec OpenAI
  Future<void> _onTapAiAnalyze() async {
    final input = _descriptionController.text.trim();
    if (input.isEmpty) {
      showSuccessSnackBar(context, "Veuillez d'abord saisir une description");
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final draft = await _aiService.generateOfferDraft(text: input);

      if (!mounted) return;

      if (draft['success'] == true) {
        setState(() {
          if ((draft['title'] as String).isNotEmpty) {
            _titleController.text = draft['title'] as String;
          }
          if ((draft['category'] as String).isNotEmpty) {
            _category = draft['category'] as String;
            _selectedSubCategory = null;
          }
          if ((draft['description'] as String).isNotEmpty) {
            _descriptionController.text = draft['description'] as String;
          }
          // Remplir la ville si disponible
          final location = (draft['location'] as String? ?? '').trim();
          if (location.isNotEmpty) {
            _locationController.text = location;
          }
          // Remplir le code postal si disponible
          final postalCode = (draft['postalCode'] as String? ?? '').trim();
          if (postalCode.isNotEmpty) {
            _postalCodeController.text = postalCode;
          }
        });

        showSuccessSnackBar(
          context,
          '✨ Analyse IA complétée\nChamps remplis automatiquement',
        );
      } else {
        showSuccessSnackBar(
          context,
          "Erreur IA : ${draft['error'] ?? 'Erreur inconnue'}",
        );
      }
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, "Erreur lors de l'analyse : $e");
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  void dispose() {
    _transcriptionStream.close();
    _streamingTimer?.cancel();
    _streamMicSub?.cancel(); // ✅ AJOUT: Cleanup du stream
    _streamMicSub = null;
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _postalCodeController.dispose();
    _phoneController.dispose();
    _budgetController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _resetAllFields() {
    setState(() {
      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();
      _postalCodeController.clear();
      _phoneController.clear();
      _budgetController.clear();
      _category = null;
      _selectedSubCategory = null;
      _missionDelay = null;
      _budgetType = 'Fixe';
      _selectedPhotos.clear();
      _selectedPhotoBytes.clear();
      _uploadedPhotoUrls.clear();
      _citySuggestions.clear();
      _highlightedIndex = -1;
      _selectedRegionCode = null;
      _selectedDeptCode = null;
      _selectedPhoneCountryCode = '+33';

      _isUrgent = false;

      _attemptedSubmit = false;
      _publishLocked = false;
      _canPublish = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _recompute());
    showSuccessSnackBar(context, 'Tous les champs ont été réinitialisés');
  }

  // --- LOGIQUE AUTOCOMPLÉTION VILLE ---

  void _onCityChanged(String value) {
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _citySuggestions = [];
        _highlightedIndex = -1;
      });
      return;
    }

    final results = CitySearch.instance.search(query, limit: 10);
    setState(() {
      _citySuggestions = results;
      _highlightedIndex = results.isNotEmpty ? 0 : -1;
    });
  }

  void _onPostalCodeChanged(String value) {
    final cp = value.trim();
    if (cp.length < 2) {
      // On ne spam pas si l'utilisateur tape juste "7"
      return;
    }

    final results = CitySearch.instance.searchByPostalCode(cp, limit: 10);

    if (!mounted) return;

    if (results.isEmpty) {
      setState(() {
        _citySuggestions = [];
        _highlightedIndex = -1;
      });
      return;
    }

    final best = CitySearch.instance.pickBestForPostalCode(cp);

    setState(() {
      _citySuggestions = results;
      _highlightedIndex = 0;
    });

    if (best != null) {
      _applyCity(best);
    }
  }

  void _applyCity(CityRecord city) {
    setState(() {
      _locationController.text = city.name;
      _postalCodeController.text = city.cp;

      _selectedDeptCode = city.dept;
      _selectedRegionCode = city.region;
      _selectedPhoneCountryCode = _countryCodeForDept(city.dept);

      _citySuggestions = [];
      _highlightedIndex = -1;
    });
  }

  String _countryCodeForDept(String dept) {
    if (dept.startsWith('971')) return '+590'; // Guadeloupe
    if (dept.startsWith('972')) return '+596'; // Martinique
    if (dept.startsWith('973')) return '+594'; // Guyane
    if (dept.startsWith('974')) return '+262'; // La Réunion
    if (dept.startsWith('976')) return '+262'; // Mayotte
    if (dept.startsWith('987')) return '+689'; // Polynésie
    return '+33'; // Métropole par défaut
  }

  Widget _buildCitySuggestionsOverlay() {
    if (_citySuggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            spreadRadius: 1,
            color: Colors.black12,
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _citySuggestions.length,
        itemBuilder: (context, index) {
          final city = _citySuggestions[index];
          final selected = index == _highlightedIndex;

          return InkWell(
            onTap: () => _applyCity(city),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: selected ? kPrestoBlue.withOpacity(0.08) : null,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${city.name} (${city.cp})',
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Dept ${city.dept}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- GESTION DES PHOTOS ---

  Future<void> _showPhotoPopup(
      {required XFile file, required String label}) async {
    final bytes = await file.readAsBytes();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.white,
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text(
                          'Image indisponible',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Fermer',
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.black87),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onPhotoTileTap(int photoIndex) async {
    if (photoIndex < _selectedPhotos.length) {
      final file = _selectedPhotos[photoIndex];
      final label = 'Photo ${photoIndex + 1}';
      await _showPhotoPopup(file: file, label: label);
      return;
    }
    await _pickImage(photoIndex);
  }

  Future<ImageSource?> _selectPhotoSource() async {
    if (!mounted) return null;

    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Galerie'),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
                ),
                ListTile(
                  enabled: !kIsWeb,
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Appareil photo'),
                  subtitle: kIsWeb ? const Text('Indisponible sur Web') : null,
                  onTap: kIsWeb
                      ? null
                      : () => Navigator.of(ctx).pop(ImageSource.camera),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(int photoIndex) async {
    if (_selectedPhotos.length >= 2 && photoIndex >= _selectedPhotos.length) {
      showSuccessSnackBar(context, 'Maximum 2 photos autorisées');
      return;
    }

    try {
      final source = await _selectPhotoSource();
      if (source == null) return;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      setState(() {
        if (photoIndex < _selectedPhotos.length) {
          _selectedPhotos[photoIndex] = image;
          if (photoIndex < _selectedPhotoBytes.length) {
            _selectedPhotoBytes[photoIndex] = bytes;
          } else {
            while (_selectedPhotoBytes.length < photoIndex) {
              _selectedPhotoBytes.add(null);
            }
            _selectedPhotoBytes.add(bytes);
          }
        } else {
          _selectedPhotos.add(image);
          while (_selectedPhotoBytes.length < _selectedPhotos.length - 1) {
            _selectedPhotoBytes.add(null);
          }
          _selectedPhotoBytes.add(bytes);
        }
      });
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, 'Erreur lors de la sélection : $e');
    }
  }

  Future<void> _uploadPhotos({required String uid}) async {
    if (_selectedPhotos.isEmpty) {
      _uploadedPhotoUrls.clear();
      return;
    }

    try {
      _uploadedPhotoUrls.clear();

      final callable = _functions.httpsCallable(
        'processOfferPhoto',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );

      for (int i = 0; i < _selectedPhotos.length; i++) {
        final photo = _selectedPhotos[i];
        final ts = DateTime.now().millisecondsSinceEpoch;
        final rawPath = 'offers_raw/$uid/${ts}_$i.jpg';

        final ref = FirebaseStorage.instance.ref().child(rawPath);
        final bytes = await photo.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

        final res = await callable.call<dynamic>({
          'storagePath': rawPath,
        });
        final data = (res.data is Map)
            ? Map<String, dynamic>.from(res.data as Map)
            : <String, dynamic>{};
        final url = (data['downloadUrl'] ?? '').toString().trim();
        if (url.isEmpty) {
          throw Exception('URL de photo manquante');
        }
        _uploadedPhotoUrls.add(url);
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, "Erreur lors de l'upload : $e");
      debugPrint('[Upload] Erreur: $e');
    }
  }

  /// Crée des notifications pour les utilisateurs ayant cette catégorie en favori
  Future<void> _createNotificationsForFavorites(
    String offerId,
    String category,
    String? subCategory,
    String offerTitle,
    String publisherUserId,
  ) async {
    // 🔒 Sécurité: la création de notifications se fait côté serveur (Cloud Functions)
    // afin d'éviter qu'un client puisse créer des notifications pour d'autres utilisateurs.
    return;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Récupérer l'utilisateur actuel
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Uploader les photos (optionnel) -> traitement serveur (resize + filigrane UID)
      await _uploadPhotos(uid: user.uid);

      // Sauvegarder l'offre dans Firestore
      final city = _locationController.text.trim();
      final postalCode = _postalCodeController.text.trim();
      final budgetRaw = _budgetController.text.trim();
      final normalizedOffer = buildOfferIndexFields(
        category: _category,
        city: city,
        postalCode: postalCode,
        budget: budgetRaw,
        isActive: true,
        status: 'active',
      );

      final docRef = await FirebaseFirestore.instance.collection('offers').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'subCategory': _selectedSubCategory,
        'missionDelay': _missionDelay,
        'averageDelay': _missionDelay,
        'urgent': _isUrgent,
        'phone': _phoneController.text.trim(),
        'budget': budgetRaw,
        'budgetType': _budgetType,
        'imageUrls': _uploadedPhotoUrls.isEmpty ? null : _uploadedPhotoUrls,
        'userId': user.uid,
        'ownerId': user.uid,
        'createdAt': Timestamp.now(),
        ...normalizedOffer,
      });

      // ✅ Analytics: publication
      await _logOfferPublished(
        offerId: docRef.id,
        title: _titleController.text.trim(),
        category: (_category ?? '').toString().trim(),
        budget: _budgetController.text.trim(),
        budgetType: _budgetType,
      );

      // Créer des notifications pour les utilisateurs ayant cette catégorie en favori
      await _createNotificationsForFavorites(
        docRef.id,
        _category ?? '',
        _selectedSubCategory,
        _titleController.text.trim(),
        user.uid,
      );

      if (!mounted) return;

      final offerId = docRef.id;
      final title = _titleController.text.trim();
      final location = _locationController.text.trim();
      final category = (_category ?? '').toString().trim();
      final subcategory = _selectedSubCategory;
      final missionDelay = _missionDelay;
      final budgetNum = _budgetType == 'À négocier'
          ? null
          : _parseBudget(_budgetController.text);
      final description = _descriptionController.text.trim();
      final phone = _phoneController.text.trim();
      final imageUrls = _uploadedPhotoUrls.isEmpty
          ? null
          : List<String>.from(_uploadedPhotoUrls);

      // ✅ Checkmark bleu au milieu de l'écran.
      showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.10),
        builder: (_) => const Center(
          child: Icon(
            Icons.check_circle,
            color: kPrestoBlue,
            size: 96,
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      // Fermer le checkmark puis aller au détail.
      Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OfferDetailsPage(
            offer: _buildOfferDetailsOffer(
              offerId: offerId,
              data: {
                'title': title,
                'location': location,
                'category': category,
                'subcategory': subcategory,
                'missionDelay': missionDelay,
                'averageDelay': missionDelay,
                'budget': budgetNum,
                'description': description,
                'phone': phone,
                'imageUrls': imageUrls,
                'userId': user.uid,
              },
            ),
            currentUserId: user.uid,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, 'Erreur lors de la publication : $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final publishVisuallyDisabled = !_canPublish || _isSubmitting;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          systemOverlayStyle: prestoOverlayStyleFor(kPrestoBlue),
          backgroundColor: kPrestoOrange,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          title: const Text(
            'Je publie une offre',
            style: kPrestoAppBarTitleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_outlined),
              tooltip: 'Réinitialiser tous les champs',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: Colors.white,
                    title: const Text(
                      'Réinitialiser ?',
                      style: kPrestoSectionTitleStyle,
                    ),
                    content: const Text(
                      'Voulez-vous effacer tous les champs et recommencer ?',
                      style: kPrestoBodyTextStyle,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: kPrestoBlue,
                        ),
                        child: const Text('Annuler'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _resetAllFields();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: kPrestoOrange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Réinitialiser'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Form(
              key: _formKey,
              autovalidateMode: _attemptedSubmit
                  ? AutovalidateMode.always
                  : AutovalidateMode.disabled,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
                children: [
                  // Bouton Premium AI avec enregistrement audio
                  Center(
                    child: _isListening
                        ? _buildMicRecordingButton()
                        : PremiumAiButton(
                            onPressed: _isAnalyzing ? null : _startStreamingMic,
                            label: 'Décrire mon besoin (IA)',
                            isLoading: _isAnalyzing,
                          ),
                  ),
                  if (_isListening) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PulsingDot(delay: 0),
                        const SizedBox(width: 8),
                        _PulsingDot(delay: 200),
                        const SizedBox(width: 8),
                        _PulsingDot(delay: 400),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enregistrement en cours...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_useCloudStt && !kIsWeb)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: kPrestoBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: kPrestoBlue.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.cloud_done,
                                  size: 16, color: kPrestoBlue),
                              SizedBox(width: 6),
                              Text(
                                'Qualité audio améliorée (Cloud)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kPrestoBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  if (_isAnalyzing) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: kPrestoBlue.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(999),
                          border:
                              Border.all(color: kPrestoBlue.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _useCloudStt && !kIsWeb
                                ? const Icon(Icons.cloud_sync,
                                    size: 16, color: kPrestoBlue)
                                : SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          kPrestoBlue),
                                    ),
                                  ),
                            const SizedBox(width: 8),
                            Text(
                              _useCloudStt && !kIsWeb
                                  ? 'Transcription et analyse (Cloud)…'
                                  : 'Analyse en cours…',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: kPrestoBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // TITRE
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      label: _requiredLabel('Titre de l’offre'),
                      border: const OutlineInputBorder(),
                      hintText: 'Ex : Monter un meuble IKEA',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Merci de saisir un titre';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // CATÉGORIE
                  DropdownButtonFormField<String>(
                    value: _category,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    decoration: InputDecoration(
                      label: _requiredLabel('Catégorie'),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    items: _categories
                        .map(
                          (cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _category = value;
                        _selectedSubCategory = null;
                      });
                      _recompute();
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Merci de choisir une catégorie';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // SOUS-CATÉGORIE (dropdown dynamique)
                  if (_category != null)
                    DropdownButtonFormField<String>(
                      value: _selectedSubCategory,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      decoration: InputDecoration(
                        label: _requiredLabel('Sous-catégorie'),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      items: (kCategorySubcategories[_category] ?? [])
                          .map(
                            (sub) => DropdownMenuItem(
                              value: sub,
                              child: Text(sub),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSubCategory = value;
                        });
                        _recompute();
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Merci de choisir une sous-catégorie';
                        }
                        return null;
                      },
                    ),
                  if (_category != null) const SizedBox(height: 16),

                  // DESCRIPTION
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      label: _requiredLabel('Description détaillée'),
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    minLines: 4,
                    maxLines: 8,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Merci de décrire votre besoin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // PHOTOS (max 2)
                  Row(
                    children: const [
                      Text(
                        'Photos de l\'offre',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '(optionnel)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: PhotoSelectorTile(
                          label: 'Photo 1',
                          file: _selectedPhotos.isNotEmpty
                              ? _selectedPhotos[0]
                              : null,
                          bytes: _selectedPhotoBytes.isNotEmpty
                              ? _selectedPhotoBytes[0]
                              : null,
                          onTap: () => _onPhotoTileTap(0),
                          onLongPress: () => _pickImage(0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PhotoSelectorTile(
                          label: 'Photo 2',
                          file: _selectedPhotos.length > 1
                              ? _selectedPhotos[1]
                              : null,
                          bytes: _selectedPhotoBytes.length > 1
                              ? _selectedPhotoBytes[1]
                              : null,
                          onTap: () => _onPhotoTileTap(1),
                          onLongPress: () => _pickImage(1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // VILLE + CP + AUTOCOMPLÉTION
                  const Text(
                    'Localisation',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      label: _requiredLabel('Ville'),
                      hintText: 'Ex : Les Abymes, Baie-Mahault, Paris...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    onChanged: _onCityChanged,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Merci de saisir une ville';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _postalCodeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Code postal',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    onChanged: _onPostalCodeChanged,
                  ),
                  _buildCitySuggestionsOverlay(),
                  const SizedBox(height: 16),

                  // TÉLÉPHONE avec sélection indicatif
                  PhoneInputFieldCompact(
                    controller: _phoneController,
                    label: _requiredLabel('Téléphone (pour être rappelé)'),
                    hintText: '612345678',
                    initialCountryCode: _selectedPhoneCountryCode,
                    onCountryCodeChanged: (code) {
                      setState(() {
                        _selectedPhoneCountryCode = code;
                      });
                    },
                    onPhoneChanged: (_) => _recompute(),
                    validator: (value) {
                      return _isValidPhoneFR(value ?? '')
                          ? null
                          : 'Téléphone invalide';
                    },
                  ),
                  const SizedBox(height: 16),

                  // DÉLAI POUR EFFECTUER LA MISSION
                  DropdownButtonFormField<String>(
                    value: _missionDelay,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    decoration: InputDecoration(
                      label: _requiredLabel('Délai pour effectuer la mission'),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    items: _missionDelayOptions
                        .map(
                          (delay) => DropdownMenuItem(
                            value: delay,
                            child: Text(delay),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _missionDelay = value);
                      _recompute();
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Merci de choisir un délai';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // URGENT
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: SwitchListTile.adaptive(
                      value: _isUrgent,
                      onChanged: (v) {
                        setState(() => _isUrgent = v);
                      },
                      title: const Text(
                        'Urgent',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      activeColor: kPrestoOrange,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // BUDGET
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _budgetType,
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          items: _budgetTypes
                              .map((t) =>
                                  DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _budgetType = v;
                              if (_budgetType == 'À négocier') {
                                _budgetController.clear();
                              }
                            });
                            _recompute();
                          },
                          decoration: InputDecoration(
                            labelText: 'Budget',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _budgetController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9., ]'))
                          ],
                          decoration: InputDecoration(
                            label: _budgetType == 'Fixe'
                                ? _requiredLabel('Montant (€)')
                                : null,
                            labelText:
                                _budgetType == 'Fixe' ? null : 'Montant (€)',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                          enabled: _budgetType == 'Fixe',
                          validator: (value) {
                            if (_budgetType == 'À négocier') return null;
                            final b = _parseBudget(value ?? '');
                            if (b == null) return 'Montant invalide';
                            if (b <= 0) return 'Le montant doit être > 0';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    '* Champs obligatoires',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),

                  // BOUTON PUBLIER
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _onPublishPressed,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(
                        _isSubmitting
                            ? 'Publication en cours...'
                            : 'Publier mon offre',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: publishVisuallyDisabled
                            ? Colors.grey.shade400
                            : kPrestoOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// PAGE COMPTE (Firebase Auth : email / Google / Apple) ////////////////////

class AccountPage extends StatefulWidget {
  final Function(double)? onScroll;
  final bool startInSignup;

  const AccountPage({super.key, this.onScroll, this.startInSignup = false});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  final GoogleAuthService _googleAuthService = GoogleAuthService();

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<void> _trackLogin({
    String? authMethod,
    bool isNewUser = false,
  }) async {
    final sw = Stopwatch()..start();
    try {
      // ✅ Métriques enrichies
      final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
      final deviceType = _getDeviceType();

      final callable = _functions.httpsCallable(
        'trackUserLogin',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
      );

      await callable.call<dynamic>({
        'authMethod': authMethod,
        'platform': platform,
        'deviceType': deviceType,
        'isNewUser': isNewUser,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      sw.stop();
      PrestoMonitoring.I.trackFunctionsCall(
          name: 'trackUserLogin', ms: sw.elapsedMilliseconds);
    } catch (e) {
      PrestoMonitoring.I.trackError('trackUserLogin', e);
      debugPrint('[Tracking] Error: $e');
    }
  }

  String _getDeviceType() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }

  final TextEditingController _adminMicroIaLanguageController =
      TextEditingController();

  // final _formKey = GlobalKey<FormState>(); // Plus utilisé avec PrestoPremiumAuthPage

  // Email / mot de passe - Maintenant gérés par PrestoPremiumAuthPage
  // final _emailController = TextEditingController();
  // final _passwordController = TextEditingController();
  // final _passwordConfirmController = TextEditingController();

  // Profil utilisateur
  final TextEditingController _profilePseudoController =
      TextEditingController();
  final TextEditingController _profileCityController = TextEditingController();
  final TextEditingController _profilePhoneController = TextEditingController();

  Set<String> _favoriteCategories = <String>{};
  Set<String> _selectedFavoriteCategories = <String>{};
  Set<String> _selectedFavoriteSubcategories = <String>{};
  Set<String> _draftFavoriteSelections = <String>{};
  bool _profileLoaded = false;
  bool _profileLoadRequested = false;
  bool _isSavingProfile = false;
  bool _isEditingProfile = false; // ✅ Mode édition du profil
  bool _profileLoadError = false;
  int _profileLoadRetries = 0;
  static const int _maxProfileLoadRetries = 3;

  // Admin: paramètres Micro-IA (Remote Config)
  bool _adminConfigLoaded = false;
  bool _adminSaving = false;
  bool _adminMicroIaEditing = false;
  String _adminMicroIaMode = 'HYBRID';
  bool _adminMicroIaFallbackEnabled = true;
  double _adminMicroIaQualityThreshold = 0.62;
  String _adminMicroIaLanguageCode = 'fr-FR';

  Future<Map<String, dynamic>>? _adminCfgFuture;

  Future<Map<String, dynamic>> _adminGetMicroIaConfig() async {
    final sw = Stopwatch()..start();
    final callable = _functions.httpsCallable(
      'adminGetMicroIaConfig',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    try {
      final res = await callable.call<dynamic>({});
      sw.stop();
      PrestoMonitoring.I.trackFunctionsCall(
          name: 'adminGetMicroIaConfig', ms: sw.elapsedMilliseconds);
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      PrestoMonitoring.I.trackError('adminGetMicroIaConfig', e);
      rethrow;
    }
  }

  Future<void> _adminSetMicroIaConfig() async {
    if (_adminSaving) return;
    setState(() => _adminSaving = true);
    final sw = Stopwatch()..start();
    try {
      final callable = _functions.httpsCallable(
        'adminSetMicroIaConfig',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final res = await callable.call<dynamic>({
        'mode': _adminMicroIaMode,
        'fallbackEnabled': _adminMicroIaFallbackEnabled,
        'qualityThreshold': _adminMicroIaQualityThreshold,
        'languageCode': _adminMicroIaLanguageCode,
      });

      sw.stop();
      PrestoMonitoring.I.trackFunctionsCall(
          name: 'adminSetMicroIaConfig', ms: sw.elapsedMilliseconds);

      // ✅ Re-synchronise l'UI avec la config effectivement publiée.
      final data = (res.data is Map)
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      final mode = (data['mode'] ?? _adminMicroIaMode).toString();
      final fallback = data['fallbackEnabled'] == true;
      final threshold = (data['qualityThreshold'] as num?)?.toDouble() ??
          _adminMicroIaQualityThreshold;
      final lang =
          (data['languageCode'] ?? _adminMicroIaLanguageCode).toString();

      if (!mounted) return;

      setState(() {
        _adminMicroIaMode = mode;
        _adminMicroIaFallbackEnabled = fallback;
        _adminMicroIaQualityThreshold = threshold;
        _adminMicroIaLanguageCode = lang;
        _adminMicroIaLanguageController.text = lang;
        _adminMicroIaEditing = false; // ✅ re-griser les champs
      });
      showSuccessSnackBar(context, 'Paramètres Micro-IA mis à jour');
    } on FirebaseFunctionsException catch (e) {
      PrestoMonitoring.I.trackError('adminSetMicroIaConfig', e);
      if (!mounted) return;
      showSuccessSnackBar(context, e.message ?? 'Erreur admin');
    } catch (e) {
      PrestoMonitoring.I.trackError('adminSetMicroIaConfig', e);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Erreur admin: $e');
    } finally {
      if (mounted) setState(() => _adminSaving = false);
    }
  }

  Widget _buildAdminAnalyticsPanel() {
    return AnimatedBuilder(
      animation: PrestoMonitoring.I,
      builder: (context, _) {
        final m = PrestoMonitoring.I;

        return AccountAdminAnalyticsPanel(
          enabled: m.enabled,
          verboseLogs: m.verboseLogs,
          sessionLabel: m.sessionDurationLabel,
          errorsCount: m.errorsCount,
          onEnabledChanged: m.setEnabled,
          onVerboseChanged: m.setVerbose,
          onReset: m.reset,
          metrics: [
            AccountAnalyticsMetricItem(
              icon: '🧾',
              label: 'Offres — Stream Firestore',
              subtitle: 'snapshots() sur la query (temps réel)',
              enabled: m.monitorOffersStream,
              onToggle: m.setMonitorOffersStream,
              value:
                  '${m.offersSnapshotsCount} snap • ${m.lastOffersSnapshotDocs} docs',
              hint: m.lastOffersQuerySignature,
              color: kPrestoBlue,
            ),
            AccountAnalyticsMetricItem(
              icon: '📥',
              label: 'Offres — Fetch once',
              subtitle: 'get() ponctuel (debug/pagination)',
              enabled: m.monitorOffersFetchOnce,
              onToggle: m.setMonitorOffersFetchOnce,
              value:
                  '${m.offersFetchOnceCount} • ${m.lastOffersFetchMs}ms • ${m.lastOffersFetchDocs} docs',
              color: kPrestoOrange,
            ),
            AccountAnalyticsMetricItem(
              icon: '💬',
              label: 'Messages — Fetch once',
              subtitle: 'get() messages d’une conversation',
              enabled: m.monitorMessagesFetchOnce,
              onToggle: m.setMonitorMessagesFetchOnce,
              value:
                  '${m.messagesFetchOnceCount} • ${m.lastMessagesFetchMs}ms • ${m.lastMessagesFetchDocs} docs',
              color: Colors.purple,
            ),
            AccountAnalyticsMetricItem(
              icon: '⚡',
              label: 'Cloud Functions',
              subtitle: 'callable (admin/login/...)',
              enabled: m.monitorFunctionsCalls,
              onToggle: m.setMonitorFunctionsCalls,
              value: '${m.functionsCallsCount} • ${m.lastFunctionsCallMs}ms',
              hint: m.lastError,
              color: Colors.teal,
            ),
            AccountAnalyticsMetricItem(
              icon: '🛰️',
              label: 'Autres streams Firestore',
              subtitle: 'notifications / conversations / profils / home',
              enabled: m.monitorOtherStreams,
              onToggle: m.setMonitorOtherStreams,
              value: '${m.otherStreamsEvents} • ${m.lastOtherStreamDocs} docs',
              hint: m.lastOtherStreamKey,
              color: Colors.indigo,
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdminMicroIaPanel(User user) {
    _adminCfgFuture ??= _adminGetMicroIaConfig();

    return FutureBuilder<Map<String, dynamic>>(
      future: _adminCfgFuture,
      builder: (context, cfgSnap) {
        if (cfgSnap.connectionState == ConnectionState.waiting &&
            !_adminConfigLoaded) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
              ),
            ),
          );
        }

        if (cfgSnap.hasError && !_adminConfigLoaded) {
          final err = cfgSnap.error;
          if (err is FirebaseFunctionsException) {
            if (err.code == 'permission-denied' ||
                err.code == 'unauthenticated') {
              return const SizedBox.shrink();
            }
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "Erreur chargement Admin.\n$err",
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        if (cfgSnap.hasData && !_adminConfigLoaded) {
          final cfg = cfgSnap.data!;
          final mode = (cfg['mode'] ?? 'HYBRID').toString();
          final fallback = cfg['fallbackEnabled'] == true;
          final threshold =
              (cfg['qualityThreshold'] as num?)?.toDouble() ?? 0.62;
          final lang = (cfg['languageCode'] ?? 'fr-FR').toString();

          _adminMicroIaMode = mode;
          _adminMicroIaFallbackEnabled = fallback;
          _adminMicroIaQualityThreshold = threshold;
          _adminMicroIaLanguageCode = lang;
          _adminMicroIaLanguageController.text = lang;
          _adminConfigLoaded = true;
        }

        final techLines = <String>[
          'uid: ${user.uid}',
          'email: ${user.email ?? "(null)"}',
          'providers: ${user.providerData.map((p) => p.providerId).join(', ')}',
          'createdAt: ${user.metadata.creationTime?.toIso8601String() ?? "(null)"}',
          'lastSignIn: ${user.metadata.lastSignInTime?.toIso8601String() ?? "(null)"}',
        ];

        return AccountAdminMicroIaPanel(
          techLines: techLines,
          buildVersionPanel: AccountBuildVersionPanel(
            platformLabel: kIsWeb ? 'web' : defaultTargetPlatform.name,
            modeLabel:
                kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug'),
            sha: kAppBuildSha,
            tag: kAppBuildTag,
            branch: kAppBuildBranch,
            buildTimeUtc: kAppBuildTimeUtc,
            onCopySha: () async {
              await Clipboard.setData(
                const ClipboardData(text: kAppBuildSha),
              );
              if (!context.mounted) return;
              showSuccessSnackBar(context, 'SHA copié');
            },
          ),
          analyticsPanel: _buildAdminAnalyticsPanel(),
          mode: _adminMicroIaMode,
          fallbackEnabled: _adminMicroIaFallbackEnabled,
          qualityThreshold: _adminMicroIaQualityThreshold,
          languageController: _adminMicroIaLanguageController,
          canEdit: _adminMicroIaEditing && !_adminSaving,
          isSaving: _adminSaving,
          onModeChanged: (v) {
            if (v == null) return;
            setState(() => _adminMicroIaMode = v);
          },
          onFallbackChanged: (v) =>
              setState(() => _adminMicroIaFallbackEnabled = v),
          onThresholdChanged: (v) =>
              setState(() => _adminMicroIaQualityThreshold = v),
          onLanguageChanged: (v) {
            _adminMicroIaLanguageCode = v.trim();
          },
          onApplyPressed: _adminSetMicroIaConfig,
          onEditPressed: () {
            setState(() => _adminMicroIaEditing = true);
          },
        );
      },
    );
  }

  static const List<String> _allFavoriteCategories = [
    'Restauration / Extra',
    'Bricolage / Travaux',
    'Aide à domicile',
    'Garde d’enfants',
    'Événementiel / DJ',
    'Cours & soutien',
    'Jardinage',
    'Peinture',
    'Main-d’œuvre',
    'Autre',
  ];

  static const Map<String, List<String>> _subCategoriesByCategory = {
    'Restauration / Extra': ['Service', 'Plonge', 'Cuisine', 'Bar'],
    'Bricolage / Travaux': [
      'Montage meuble',
      'Électricité',
      'Plomberie',
      'Peinture'
    ],
    'Aide à domicile': ['Ménage', 'Repassage', 'Courses'],
    'Garde d’enfants': ['Sortie d’école', 'Soirée', 'Mercredi'],
    'Événementiel / DJ': ['DJ', 'Sono', 'Lumières'],
    'Cours & soutien': ['Maths', 'Langues', 'Musique'],
    'Jardinage': ['Tonte', 'Taille', 'Désherbage'],
    'Peinture': ['Intérieur', 'Extérieur'],
    'Main-d’œuvre': ['Manutention', 'Aide chantier'],
    'Autre': ['Général'],
  };

  @override
  void initState() {
    super.initState();
    // _isLoginMode = !widget.startInSignup; // Plus utilisé avec PrestoPremiumAuthPage
    _scrollController.addListener(() {
      widget.onScroll?.call(_scrollController.offset);
    });

    // Sur Web, vérifie si l'utilisateur revient d'un redirect Google Sign-In
    if (kIsWeb) {
      _checkGoogleRedirectResult();
    }
  }

  Future<void> _checkGoogleRedirectResult() async {
    try {
      final result = await _auth.getRedirectResult();
      if (result.user != null) {
        final isNew = result.additionalUserInfo?.isNewUser ?? false;
        await _trackLogin(authMethod: 'google', isNewUser: isNew);
        if (!mounted) return;
        showSuccessSnackBar(context, "Connecté avec Google");
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg = "Erreur Google";
      if (e.code == 'unauthorized-domain') {
        msg =
            "Domaine non autorisé. Ajoute ce domaine dans Firebase Console → Authentication → Authorized domains.";
      } else if (e.code == 'operation-not-allowed') {
        msg =
            "Google Sign-In non activé. Active-le dans Firebase Console → Authentication → Sign-in method.";
      } else if (e.code != 'invalid-credential' && e.code != 'no-auth-event') {
        msg = "Erreur Google : ${e.message ?? e.code}";
        showErrorSnackBar(context, msg);
      }
    } catch (e) {
      debugPrint('[Google Redirect] Error checking result: $e');
    }
  }

  @override
  void dispose() {
    // _emailController.dispose(); // Maintenant géré par PrestoPremiumAuthPage
    // _passwordController.dispose();
    // _passwordConfirmController.dispose();
    _profilePseudoController.dispose();
    _profileCityController.dispose();
    _profilePhoneController.dispose();
    _adminMicroIaLanguageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Ancienne méthode - maintenant gérée par PrestoPremiumAuthPage

  Future<void> _loadUserProfile(User user, {bool isRetry = false}) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 8));

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _profilePseudoController.text = (data['pseudo'] ?? '').toString();
        _profileCityController.text = (data['city'] ?? '').toString();
        _profilePhoneController.text = (data['phone'] ?? '').toString();
        final favs = (data['favoriteCategories'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();
        _favoriteCategories = favs.toSet();
        _draftFavoriteSelections = _favoriteCategories.toSet();
        final selectedCats =
            (data['selectedFavoriteCategories'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();
        _selectedFavoriteCategories = selectedCats.toSet();
        final selectedSubcats =
            (data['selectedFavoriteSubcategories'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();
        _selectedFavoriteSubcategories = selectedSubcats.toSet();

        // ✅ Si les champs sont remplis, ne pas être en mode édition par défaut
        final hasProfile = _profilePseudoController.text.isNotEmpty ||
            _profileCityController.text.isNotEmpty ||
            _profilePhoneController.text.isNotEmpty;
        _isEditingProfile = !hasProfile;
        _profileLoadError = false;
        _profileLoadRetries = 0;
      } else {
        // Profil vide : créer un document par défaut
        _favoriteCategories = <String>{};
        _selectedFavoriteCategories = <String>{};
        _selectedFavoriteSubcategories = <String>{};
        _draftFavoriteSelections = <String>{};
        _isEditingProfile = true;
        _profileLoadError = false;
      }
    } catch (e) {
      debugPrint('[Profile] Erreur chargement profil: $e');

      // Retry automatique jusqu'à 3 fois
      if (!isRetry && _profileLoadRetries < _maxProfileLoadRetries) {
        _profileLoadRetries++;
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          await _loadUserProfile(user, isRetry: true);
          return;
        }
      }

      _favoriteCategories = <String>{};
      _selectedFavoriteCategories = <String>{};
      _selectedFavoriteSubcategories = <String>{};
      _draftFavoriteSelections = <String>{};
      _profileLoadError = true;
      _isEditingProfile = true;
    }

    if (mounted) {
      setState(() {
        _profileLoaded = true;
        _profileLoadRequested = true;
      });
    }
  }

  bool _validateProfile() {
    final pseudo = _profilePseudoController.text.trim();
    final phone = _profilePhoneController.text.trim();

    // Validation pseudo
    if (pseudo.isEmpty) {
      showErrorSnackBar(context, "Le pseudo est obligatoire");
      return false;
    }
    if (pseudo.length < 2) {
      showErrorSnackBar(
          context, "Le pseudo doit contenir au moins 2 caractères");
      return false;
    }
    if (pseudo.length > 50) {
      showErrorSnackBar(
          context, "Le pseudo ne doit pas dépasser 50 caractères");
      return false;
    }
    if (!RegExp(r'^[a-zA-Z0-9àâäæéèêëïîôùûüœçÀÂÄÆÉÈÊËÏÎÔÙÛÜŒÇ\s\-_\.]+$')
        .hasMatch(pseudo)) {
      showErrorSnackBar(context,
          "Le pseudo ne peut contenir que des lettres, chiffres et caractères spéciaux (-, _, .)");
      return false;
    }

    // Validation phone (optionnel mais si rempli)
    if (phone.isNotEmpty) {
      if (!RegExp(r'^[+]?[0-9]{10,15}$').hasMatch(phone.replaceAll(' ', ''))) {
        showErrorSnackBar(
            context, "Le numéro de téléphone doit contenir 10-15 chiffres");
        return false;
      }
    }

    return true;
  }

  double _calculateProfileCompleteness() {
    int filled = 0;
    int total = 4;

    if (_profilePseudoController.text.trim().isNotEmpty) filled++;
    if (_profileCityController.text.trim().isNotEmpty) filled++;
    if (_profilePhoneController.text.trim().isNotEmpty) filled++;
    if (_favoriteCategories.isNotEmpty) filled++;

    return filled / total;
  }

  Future<bool> _saveProfile(
    User user, {
    bool showSuccess = true,
  }) async {
    if (!mounted) return false;

    // Validation du profil
    if (!_validateProfile()) {
      return false;
    }

    setState(() => _isSavingProfile = true);
    try {
      final pseudo = _profilePseudoController.text.trim();
      final city = _profileCityController.text.trim();
      final phone = _profilePhoneController.text.trim();

      final profileData = {
        'pseudo': pseudo,
        'city': city,
        'phone': phone,
        'favoriteCategories': _favoriteCategories.toList(),
        'selectedFavoriteCategories': _selectedFavoriteCategories.toList(),
        'selectedFavoriteSubcategories':
            _selectedFavoriteSubcategories.toList(),
        'profileUpdatedAt': FieldValue.serverTimestamp(),
        'profileCompleteness': _calculateProfileCompleteness(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(profileData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      // Mise à jour du displayName Firebase Auth
      if (pseudo.isNotEmpty) {
        try {
          await user.updateDisplayName(pseudo).timeout(
                const Duration(seconds: 5),
              );
        } catch (e) {
          debugPrint('[Profile] Erreur mise à jour displayName: $e');
          // Continue même si échoue
        }
      }

      // ✅ Vérifier l'email si pas encore vérifié
      if (!user.emailVerified && user.email != null) {
        try {
          await EmailActionService.requestEmailVerificationEmail();
        } catch (_) {
          // Silencieux
        }
      }

      if (mounted) {
        setState(() => _isEditingProfile = false);
        if (showSuccess) {
          showSuccessSnackBar(context, "Profil mis à jour avec succès");
        }
      }
      return true;
    } catch (e) {
      if (mounted) {
        String errorMsg = "Erreur lors de la sauvegarde du profil";
        if (e.toString().contains('TimeoutException')) {
          errorMsg = "Délai d'attente dépassé. Vérifiez votre connexion";
        } else if (e.toString().contains('PermissionDenied')) {
          errorMsg = "Vous n'êtes pas autorisé à modifier ce profil";
        }
        showErrorSnackBar(context, errorMsg);
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  void _mutateDraftCategory(String category) {
    if (_draftFavoriteSelections.contains(category)) {
      _draftFavoriteSelections.remove(category);
      _draftFavoriteSelections.removeWhere((e) => e.startsWith('$category — '));
    } else {
      _draftFavoriteSelections.add(category);
    }
  }

  void _mutateDraftSubcategory({
    required String category,
    required String subcategory,
  }) {
    final label = '$category — $subcategory';
    if (_draftFavoriteSelections.contains(label)) {
      _draftFavoriteSelections.remove(label);
    } else {
      _draftFavoriteSelections.add(category);
      _draftFavoriteSelections.add(label);
    }
  }

  Future<void> _applyDraftFavorites(User user) async {
    final draft = _draftFavoriteSelections.toSet();

    final selectedCats = draft.where((e) => !e.contains('—')).toSet();
    final selectedSubcats = draft.where((e) => e.contains('—')).toSet();

    setState(() {
      _favoriteCategories = draft;
      _selectedFavoriteCategories = selectedCats;
      _selectedFavoriteSubcategories = selectedSubcats;
    });

    final ok = await _saveProfile(user, showSuccess: false);
    if (!mounted) return;
    if (ok) {
      showSuccessSnackBar(context, 'Alertes enregistrées');
    }
  }

  Future<void> _openCategoryPickerSheet() async {
    var changed = false;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.65,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: _allFavoriteCategories.length + 1,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, index) {
                    if (index == 0) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Choisir des catégories',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    }

                    final cat = _allFavoriteCategories[index - 1];
                    final selected = _draftFavoriteSelections.contains(cat);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(
                        cat,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(Icons.check, color: kPrestoBlue)
                          : null,
                      onTap: () {
                        sheetSetState(() {
                          _mutateDraftCategory(cat);
                          changed = true;
                        });
                      },
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );

    if (changed && mounted) setState(() {});
  }

  Future<void> _openSubcategoryPickerSheet() async {
    final selectedCategories =
        _draftFavoriteSelections.where((e) => !e.contains('—')).toList();

    var changed = false;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        if (selectedCategories.isEmpty) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.35,
              child: const Center(
                child: Text(
                  'Choisis d’abord une catégorie',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }

        final items =
            <({String category, String? subcategory, bool isHeader})>[];
        for (final category in selectedCategories) {
          items.add((category: category, subcategory: null, isHeader: true));
          final subs = _subCategoriesByCategory[category] ?? const <String>[];
          for (final sub in subs) {
            items.add((category: category, subcategory: sub, isHeader: false));
          }
        }

        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.65,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, index) {
                    if (index == 0) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Choisir des sous-catégories',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    }

                    final item = items[index - 1];
                    if (item.isHeader) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 6),
                        child: Text(
                          item.category,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: kPrestoBlue,
                          ),
                        ),
                      );
                    }

                    final sub = item.subcategory!;
                    final label = '${item.category} — $sub';
                    final selected = _draftFavoriteSelections.contains(label);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(
                        sub,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(Icons.check, color: kPrestoBlue)
                          : null,
                      onTap: () {
                        sheetSetState(() {
                          _mutateDraftSubcategory(
                            category: item.category,
                            subcategory: sub,
                          );
                          changed = true;
                        });
                      },
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );

    if (changed && mounted) setState(() {});
  }

  Future<void> _toggleFavoriteSubcategory(User user, String subcategory) async {
    setState(() {
      if (_selectedFavoriteSubcategories.contains(subcategory)) {
        _selectedFavoriteSubcategories.remove(subcategory);
      } else {
        _selectedFavoriteSubcategories.add(subcategory);
      }
    });
    await _saveProfile(user, showSuccess: false);
  }

  Future<void> _signInWithGoogle() async {
    await AccountSocialAuthActions.signInWithGoogle(
      context: context,
      auth: _auth,
      googleAuthService: _googleAuthService,
      trackLogin: _trackLogin,
    );
  }

  Future<void> _signInWithApple() async {
    await AccountSocialAuthActions.signInWithApple(
      context: context,
      auth: _auth,
      trackLogin: _trackLogin,
    );
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      // ✅ SessionState.userId sera automatiquement mis à null via authStateChanges()
      await CrashlyticsContext.setUserId(null);
    } catch (_) {}
  }

  // Ancienne méthode _buildProfile supprimée - remplacée par PrestoPremiumAuthPage pour l'auth

  Widget _buildProfile(User user) {
    // ✅ SessionState.userId est maintenant synchronisé automatiquement via authStateChanges()
    // Lier les crash reports à l'utilisateur connecté
    CrashlyticsContext.setUserId(user.uid);

    if (!_profileLoaded && !_profileLoadRequested) {
      _profileLoadRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadUserProfile(user);
      });
    }

    final pseudo = _profilePseudoController.text.trim();
    final displayName = pseudo.isNotEmpty
        ? pseudo
        : (user.displayName ?? "Utilisateur iliprestō");

    final profileViewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final profileBottomInset =
        profileViewInsetsBottom > 10 ? profileViewInsetsBottom : 0.0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          systemOverlayStyle: prestoOverlayStyleFor(kPrestoBlue),
          title: const Text(
            "Mon compte iliprestō",
            style: kPrestoAppBarTitleStyle,
          ),
          backgroundColor: kPrestoOrange,
          foregroundColor: Colors.white,
        ),
        backgroundColor: Colors.white,
        body: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: profileBottomInset,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 150),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: kPrestoOrange.withOpacity(0.1),
                              backgroundImage: user.photoURL != null
                                  ? NetworkImage(user.photoURL!)
                                  : null,
                              child: user.photoURL == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 42,
                                      color: kPrestoOrange,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email ?? "",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // ✅ Indicateur de complétude du profil
                            if (_profileLoaded)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Complétude du profil",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: _calculateProfileCompleteness(),
                                        minHeight: 6,
                                        backgroundColor: Colors.grey.shade300,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          _calculateProfileCompleteness() >= 1.0
                                              ? Colors.green
                                              : _calculateProfileCompleteness() >=
                                                      0.75
                                                  ? Colors.orange
                                                  : Colors.red,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(_calculateProfileCompleteness() * 100).toStringAsFixed(0)}% complet',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_profileLoadError)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber,
                                        size: 14, color: Colors.red.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Erreur chargement profil',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            const Text(
                              "Tu restes connecté automatiquement.\nTu ne seras déconnecté que si tu appuies sur « Se déconnecter ».",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      AccountProfileFormSection(
                        pseudoController: _profilePseudoController,
                        cityController: _profileCityController,
                        phoneController: _profilePhoneController,
                        isEditing: _isEditingProfile,
                        isSaving: _isSavingProfile,
                        onStartEditing: () {
                          setState(() => _isEditingProfile = true);
                        },
                        onSave: () {
                          _saveProfile(user);
                        },
                      ),
                      const SizedBox(height: 24),
                      AccountMessagesSection(
                        onOpenMessages: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MessagesPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Mes annonces publiées",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RepaintBoundary(
                        child: UserOffersSection(userId: user.uid),
                      ),
                      const SizedBox(height: 24),
                      RepaintBoundary(
                        child: FavoriteOffersSection(userId: user.uid),
                      ),
                      const SizedBox(height: 24),
                      RepaintBoundary(
                        child: AccountFavoriteCategoriesSection(
                          categoriesCount: _draftFavoriteSelections
                              .where((e) => !e.contains('—'))
                              .length,
                          subcategoriesCount: _draftFavoriteSelections
                              .where((e) => e.contains('—'))
                              .length,
                          isSaving: _isSavingProfile,
                          onOpenCategoryPicker: _openCategoryPickerSheet,
                          onOpenSubcategoryPicker: _openSubcategoryPickerSheet,
                          onApply: () => _applyDraftFavorites(user),
                        ),
                      ),
                      const SizedBox(height: 20),
                      AccountProUpgradeSection(
                        onOpenProProfile: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProProfilePage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      _buildAdminSpaceEntry(user),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout),
                          label: const Text(
                            "Se déconnecter",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminSpaceEntry(User user) {
    _adminCfgFuture ??= _adminGetMicroIaConfig();

    return FutureBuilder<Map<String, dynamic>>(
      future: _adminCfgFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          // Non-admin => on masque.
          final errStr = snapshot.error.toString();
          if (errStr.contains('permission-denied') ||
              errStr.contains('unauthenticated')) {
            return const SizedBox.shrink();
          }
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kPrestoBlue.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.admin_panel_settings,
                      color: kPrestoBlue.withOpacity(0.95)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Espace admin',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "Outils d’administration et réglages Micro-IA.",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminSpacePage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text("Ouvrir l'espace admin"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrestoOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<String> _getSubcategoriesForCategory(String category) {
    final subcats = kCategorySubcategories[category] ?? [];
    return ['', ...subcats];
  }

  List<String> _getAvailableSubcategories() {
    final allSubcats = <String>{};
    for (final cat in _selectedFavoriteCategories) {
      final subcats = kCategorySubcategories[cat] ?? [];
      allSubcats.addAll(subcats);
    }
    return allSubcats.toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          SessionState.userId = null;
          CrashlyticsContext.setUserId(null);
          return const ProfilePage();
          /*
          return PrestoPremiumAuthPage(
            onGoogle: () async => await _signInWithGoogle(),
            onApple: () async => await _signInWithApple(),
            onEmailLogin: (email, password) async {
              await _auth.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
            },
            onResetPassword: (email) async {
              await _auth.sendPasswordResetEmail(email: email);
            },
          );
          */
        } else {
          return _buildProfile(user);
        }
      },
    );
  }
}

// 🔥 SECTION "Mes annonces publiées" dans Mon compte
class UserOffersSection extends StatefulWidget {
  final String userId;

  const UserOffersSection({
    super.key,
    required this.userId,
  });

  @override
  State<UserOffersSection> createState() => _UserOffersSectionState();
}

class FavoriteOffersSection extends StatefulWidget {
  final String userId;

  const FavoriteOffersSection({
    super.key,
    required this.userId,
  });

  @override
  State<FavoriteOffersSection> createState() => _FavoriteOffersSectionState();
}

class _FavoriteOffersSectionState extends State<FavoriteOffersSection> {
  List<_FavoriteOfferItem> _offers = const [];
  bool _isLoading = true;
  String? _error;
  String? _selectedOfferId;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    if (widget.userId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _offers = const [];
        _isLoading = false;
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      final favoriteMetaSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('favoriteOffers')
          .orderBy('addedAt', descending: true)
          .get();

      if (favoriteMetaSnap.docs.isNotEmpty) {
        final items = favoriteMetaSnap.docs.map((doc) {
          final data = doc.data();
          return _FavoriteOfferItem(
            offerId: doc.id,
            title: (data['title'] ?? 'Sans titre').toString().trim(),
            city: (data['city'] ?? 'Lieu non précisé').toString().trim(),
            category: (data['category'] ?? 'Catégorie non précisée')
                .toString()
                .trim(),
            price: (data['price'] as num?)?.toDouble(),
            imageUrl: (data['imageUrl'] ?? '').toString().trim(),
            addedAt: data['addedAt'] is Timestamp
                ? data['addedAt'] as Timestamp
                : null,
            rawData: data,
          );
        }).toList();

        if (!mounted) return;
        setState(() {
          _offers = items;
          _isLoading = false;

          final ids = items.map((item) => item.offerId).toSet();
          if (_selectedOfferId == null || !ids.contains(_selectedOfferId)) {
            _selectedOfferId = items.isNotEmpty ? items.first.offerId : null;
          }
        });
        return;
      }

      final favoriteIds =
          (userDoc.data()?['favoriteOfferIds'] as List<dynamic>? ?? const [])
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
              .reversed
              .toList();

      if (favoriteIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _offers = const [];
          _isLoading = false;
          _selectedOfferId = null;
        });
        return;
      }

      final docs = await Future.wait(
        favoriteIds.map(
          (offerId) => FirebaseFirestore.instance
              .collection('offers')
              .doc(offerId)
              .get(),
        ),
      );

      final existingDocs = docs.where((doc) => doc.exists).toList();

      existingDocs.sort((a, b) {
        final ta = a.data()?['createdAt'];
        final tb = b.data()?['createdAt'];
        final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
        final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
        return mb.compareTo(ma);
      });

      final items = existingDocs.map((doc) {
        final data = doc.data() ?? const <String, dynamic>{};
        final imageUrls = (data['imageUrls'] as List<dynamic>? ?? const [])
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
        return _FavoriteOfferItem(
          offerId: doc.id,
          title: (data['title'] ?? 'Sans titre').toString().trim(),
          city: (data['location'] ?? data['city'] ?? 'Lieu non précisé')
              .toString()
              .trim(),
          category:
              (data['category'] ?? 'Catégorie non précisée').toString().trim(),
          price: (data['budget'] as num?)?.toDouble(),
          imageUrl: imageUrls.isNotEmpty ? imageUrls.first : '',
          addedAt: null,
          rawData: data,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _offers = items;
        _isLoading = false;

        final ids = items.map((item) => item.offerId).toSet();
        if (_selectedOfferId == null || !ids.contains(_selectedOfferId)) {
          _selectedOfferId = items.isNotEmpty ? items.first.offerId : null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFavorite(String offerId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({
        'favoriteOfferIds': FieldValue.arrayRemove([offerId]),
        'favoriteOffersUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('favoriteOffers')
          .doc(offerId)
          .delete();

      if (!mounted) return;
      showSuccessSnackBar(context, 'Annonce retirée des favoris');
      await _loadFavorites();
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, 'Erreur lors du retrait du favori : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          "Erreur lors du chargement de vos favoris.\n$_error",
          style: const TextStyle(
            color: Colors.red,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final docs = _offers;

    if (docs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          "Tu n’as encore aucune annonce favorite.",
          style: TextStyle(
            fontSize: 13,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final selectedId = _selectedOfferId;
    final selectedDoc = (selectedId == null)
        ? docs.first
        : (docs.where((doc) => doc.offerId == selectedId).isNotEmpty
            ? docs.firstWhere((doc) => doc.offerId == selectedId)
            : docs.first);

    final selectedData = selectedDoc.rawData;
    final selectedTitle = selectedDoc.title;
    final selectedLocation = selectedDoc.city;
    final selectedCategory = selectedDoc.category;
    final selectedBudget = selectedDoc.price;

    String subtitle = "$selectedLocation · $selectedCategory";
    if (selectedBudget != null) {
      subtitle += " · ${selectedBudget.toStringAsFixed(0)} €";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                "Mes annonces favorites",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kPrestoOrange.withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${docs.length}',
                style: const TextStyle(
                  color: kPrestoOrange,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: InputDecoration(
            labelText: 'Mes favoris',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedDoc.offerId,
              items: docs.map((doc) {
                return DropdownMenuItem<String>(
                  value: doc.offerId,
                  child: Text(
                    doc.title.isEmpty ? 'Sans titre' : doc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedOfferId = value);
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: selectedDoc.imageUrl.isNotEmpty
                      ? Image.network(
                          selectedDoc.imageUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildFavoritePlaceholder(),
                        )
                      : _buildFavoritePlaceholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedTitle.isEmpty ? 'Sans titre' : selectedTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _favoriteAddedLabel(selectedDoc.addedAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OfferDetailsPage(
                        offer: _buildOfferDetailsOffer(
                          offerId: selectedDoc.offerId,
                          data: selectedData,
                        ),
                        currentUserId:
                            FirebaseAuth.instance.currentUser?.uid ?? '',
                      ),
                    ),
                  );
                },
                child: const Text('Voir détail'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onPressed: () => _removeFavorite(selectedDoc.offerId),
                child: const Text('Retirer'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFavoritePlaceholder() {
    return Container(
      width: 72,
      height: 72,
      color: const Color(0xFFFFEDF1),
      alignment: Alignment.center,
      child: const Icon(
        Icons.favorite,
        color: Colors.redAccent,
      ),
    );
  }

  String _favoriteAddedLabel(Timestamp? addedAt) {
    if (addedAt == null) return 'Favori enregistré';

    final diff = DateTime.now().difference(addedAt.toDate());
    if (diff.inMinutes < 1) return 'Ajouté à l’instant';
    if (diff.inMinutes < 60) return 'Ajouté il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Ajouté il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Ajouté il y a ${diff.inDays} j';

    final date = addedAt.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return 'Ajouté le $day/$month/${date.year}';
  }
}

class _FavoriteOfferItem {
  final String offerId;
  final String title;
  final String city;
  final String category;
  final double? price;
  final String imageUrl;
  final Timestamp? addedAt;
  final Map<String, dynamic> rawData;

  const _FavoriteOfferItem({
    required this.offerId,
    required this.title,
    required this.city,
    required this.category,
    required this.price,
    required this.imageUrl,
    required this.addedAt,
    required this.rawData,
  });
}

class _UserOffersSectionState extends State<UserOffersSection> {
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _offers;
  bool _isLoading = true;
  String? _error;
  String? _selectedOfferId;

  bool _isPermissionDeniedError(Object error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied';
    }

    final text = error.toString().toLowerCase();
    return text.contains('permission-denied') || text.contains('permission denied');
  }

  bool _isOfferPublished(Map<String, dynamic> data) {
    final isPublished = data['isPublished'];
    if (isPublished is bool && isPublished) return true;

    final status = (data['status'] ?? '').toString().trim().toLowerCase();
    if (status == 'published' || status == 'active') return true;

    final visibility = data['visibility'];
    if (visibility is Map) {
      final isPublic = visibility['isPublic'];
      if (isPublic is bool && isPublic) return true;
    }

    final isActive = data['isActive'];
    if (isActive is bool && isActive) return true;

    return false;
  }

  String _offerLocation(Map<String, dynamic> data) {
    final v = (data['location'] ?? data['city'] ?? data['serviceArea'] ?? '')
        .toString()
        .trim();
    return v.isEmpty ? 'Lieu non précisé' : v;
  }

  String _offerCategory(Map<String, dynamic> data) {
    final v = (data['category'] ?? data['subcategory'] ?? '').toString().trim();
    return v.isEmpty ? 'Catégorie non précisée' : v;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _loadOffersByOwnerField(
    String field,
  ) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('offers')
          .where(field, isEqualTo: widget.userId)
          .limit(120)
          .get();
      return snapshot.docs;
    } on FirebaseException catch (e) {
      if (_isPermissionDeniedError(e)) {
        return const [];
      }
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    if (widget.userId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _offers = [];
        });
      }
      return;
    }

    try {
      final snapshots = await Future.wait([
        _loadOffersByOwnerField('userId'),
        _loadOffersByOwnerField('uid'),
        _loadOffersByOwnerField('ownerId'),
      ]);

      final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final docs in snapshots) {
        for (final doc in docs) {
          byId[doc.id] = doc;
        }
      }

      final docs = byId.values
          .where((d) => _isOfferPublished(d.data()))
          .toList(growable: false);

      docs.sort((a, b) {
        final ta = a.data()['createdAt'];
        final tb = b.data()['createdAt'];
        final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
        final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
        return mb.compareTo(ma);
      });

      if (!mounted) return;

      setState(() {
        _offers = docs;
        _isLoading = false;

        final ids = docs.map((d) => d.id).toSet();
        if (_selectedOfferId == null || !ids.contains(_selectedOfferId)) {
          _selectedOfferId = docs.isNotEmpty ? docs.first.id : null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _isPermissionDeniedError(e)
            ? 'Vos annonces publiées sont momentanément indisponibles.'
            : 'Impossible de charger vos annonces pour le moment.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mes annonces publiées',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadOffers();
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    final docs = _offers ?? [];

    if (docs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: const Text(
          "Tu n’as pas encore publié d’annonce.",
          style: TextStyle(
            fontSize: 13,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final selectedId = _selectedOfferId;
    final selectedDoc = (selectedId == null)
        ? docs.first
        : (docs.where((d) => d.id == selectedId).isNotEmpty
            ? docs.firstWhere((d) => d.id == selectedId)
            : docs.first);

    final selectedData = selectedDoc.data();
    final selectedTitle =
        (selectedData['title'] ?? 'Sans titre').toString().trim();
    final selectedLocation = _offerLocation(selectedData);
    final selectedCategory = _offerCategory(selectedData);
    final selectedBudget = selectedData['budget'];

    String subtitle = "$selectedLocation · $selectedCategory";
    if (selectedBudget != null && selectedBudget.toString().trim().isNotEmpty) {
      subtitle += " · ${selectedBudget.toString()} €";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: 'Mes annonces',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedDoc.id,
              items: docs.map((doc) {
                final data = doc.data();
                final title = (data['title'] ?? 'Sans titre').toString().trim();
                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(
                    title.isEmpty ? 'Sans titre' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selectedOfferId = v);
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFFF3E0),
              child: Icon(
                Icons.work_outline,
                color: kPrestoOrange,
              ),
            ),
            title: Text(
              selectedTitle.isEmpty ? 'Sans titre' : selectedTitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OfferDetailsPage(
                        offer: _buildOfferDetailsOffer(
                          offerId: selectedDoc.id,
                          data: selectedData,
                        ),
                        currentUserId:
                            FirebaseAuth.instance.currentUser?.uid ?? '',
                      ),
                    ),
                  );
                },
                child: const Text('Voir détail'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onPressed: () async {
                  final deleted = await _confirmDeleteOffer(
                    context,
                    selectedDoc.id,
                    selectedTitle.isEmpty ? 'Sans titre' : selectedTitle,
                  );
                  if (deleted) {
                    await _loadOffers();
                  }
                },
                child: const Text('Supprimer'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showEditOfferDialog(
    BuildContext context,
    String offerId,
    Map<String, dynamic> data,
  ) async {
    final titleController =
        TextEditingController(text: (data['title'] ?? '') as String);
    final descController =
        TextEditingController(text: (data['description'] ?? '') as String);
    final budgetController = TextEditingController(
      text: data['budget']?.toString() ?? '',
    );

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Modifier l’annonce"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: "Titre",
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: "Description",
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: budgetController,
                  decoration: const InputDecoration(
                    labelText: "Budget (€)",
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () async {
                final newTitle = titleController.text.trim();
                final newDesc = descController.text.trim();
                final budgetText = budgetController.text.trim();

                num? newBudget;
                if (budgetText.isNotEmpty) {
                  newBudget = num.tryParse(budgetText.replaceAll(',', '.'));
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('offers')
                      .doc(offerId)
                      .update({
                    'title': newTitle.isEmpty ? data['title'] : newTitle,
                    'description':
                        newDesc.isEmpty ? data['description'] : newDesc,
                    'budget': newBudget ?? data['budget'],
                  });

                  if (!mounted || !context.mounted) return;
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                  showSuccessSnackBar(context, "Annonce mise à jour ✅");
                } catch (e) {
                  if (!mounted || !context.mounted) return;
                  showErrorSnackBar(context, "Erreur lors de la mise à jour");
                }
              },
              child: const Text("Enregistrer"),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmDeleteOffer(
    BuildContext context,
    String offerId,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Supprimer l’annonce"),
          content: Text(
            'Voulez-vous vraiment supprimer :\n"$title" ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text("Supprimer"),
            ),
          ],
        );
      },
    );

    if (!context.mounted) return false;

    if (confirmed == true) {
      try {
        // 1️⃣ Récupérer les URLs des images avant suppression
        final doc = await FirebaseFirestore.instance
            .collection('offers')
            .doc(offerId)
            .get();

        final imageUrls = (doc.data()?['imageUrls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        // 2️⃣ Supprimer les images de Storage
        if (imageUrls.isNotEmpty) {
          debugPrint(
              '🗑️ [DELETE] Suppression de ${imageUrls.length} images...');
          for (final url in imageUrls) {
            try {
              final ref = FirebaseStorage.instance.refFromURL(url);
              await ref.delete();
              debugPrint('✅ [DELETE] Image supprimée: $url');
            } catch (e) {
              debugPrint('⚠️ [DELETE] Erreur suppression image: $e');
              // Continue même si une image échoue
            }
          }
        }

        // 3️⃣ Supprimer le document Firestore
        await FirebaseFirestore.instance
            .collection('offers')
            .doc(offerId)
            .delete();

        if (!context.mounted) return false;

        showSuccessSnackBar(context, "Annonce supprimée ✅");
        return true;
      } catch (e) {
        debugPrint('❌ [DELETE] Erreur: $e');
        if (!context.mounted) return false;

        showErrorSnackBar(context, "Erreur lors de la suppression");
        return false;
      }
    }

    return false;
  }
}

// ============================================================================
// CARROUSEL AUTO-DÉFILANT POUR LES DERNIÈRES OFFRES (ligne unique)
// ============================================================================
class _AutoScrollingOffersCarousel extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> offers;
  final void Function(QueryDocumentSnapshot<Map<String, dynamic>>)? onOfferTap;

  const _AutoScrollingOffersCarousel({
    required this.offers,
    this.onOfferTap,
  });

  @override
  State<_AutoScrollingOffersCarousel> createState() =>
      _AutoScrollingOffersCarouselState();
}

class _AutoScrollingOffersCarouselState
    extends State<_AutoScrollingOffersCarousel>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _scrollTicker;
  bool _isHovered = false;
  Duration _lastElapsed = Duration.zero;
  static const double _pixelsPerSecond = 44.0;

  @override
  void initState() {
    super.initState();
    _scrollTicker = AnimationController.unbounded(vsync: this)
      ..addListener(_onTick)
      ..repeat(min: 0, max: 1, period: const Duration(seconds: 1));
  }

  @override
  void didUpdateWidget(covariant _AutoScrollingOffersCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offers.length != widget.offers.length) {
      _lastElapsed = Duration.zero;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  @override
  void dispose() {
    _scrollTicker
      ..removeListener(_onTick)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTick() {
    if (_isHovered || !_scrollController.hasClients) return;

    final elapsed = _scrollTicker.lastElapsedDuration;
    if (elapsed == null) return;

    final dtMs = (elapsed - _lastElapsed).inMilliseconds;
    _lastElapsed = elapsed;
    if (dtMs <= 0) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final loopPoint = maxScroll / 2;
    if (loopPoint <= 0) return;

    final delta = _pixelsPerSecond * (dtMs / 1000.0);
    var next = _scrollController.offset + delta;
    if (next >= loopPoint) {
      next -= loopPoint;
    }

    _scrollController.jumpTo(next);
  }

  String _labelWhenFromTitle(String title) {
    final lower = title.toLowerCase();
    if (lower.contains("aujourd'hui")) return "Aujourd'hui";
    if (lower.contains('demain')) return 'Demain';
    return 'Bientôt';
  }

  String _escapeRegex(String value) {
    return value.replaceAllMapped(
      RegExp(r'[\\^$.|?*+()\[\]{}]'),
      (match) => '\\${match.group(0)}',
    );
  }

  String _displayOfferTitle(String title, String location) {
    final trimmedTitle = title.trim();
    final trimmedLocation = location.trim();
    if (trimmedTitle.isEmpty || trimmedLocation.isEmpty) return trimmedTitle;

    final escapedLocation = _escapeRegex(trimmedLocation);
    final patterns = <RegExp>[
      RegExp(r'\s*[-–—|:]\s*' + escapedLocation + r'$', caseSensitive: false),
      RegExp(r'\s*\(' + escapedLocation + r'\)$', caseSensitive: false),
      RegExp(r'\s*,\s*' + escapedLocation + r'$', caseSensitive: false),
    ];

    var cleanedTitle = trimmedTitle;
    for (final pattern in patterns) {
      cleanedTitle = cleanedTitle.replaceFirst(pattern, '').trim();
    }

    return cleanedTitle.isEmpty ? trimmedTitle : cleanedTitle;
  }

  Widget _buildOfferCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final title = (data['title'] ?? 'Sans titre') as String;
    final location = (data['location'] ?? 'Lieu non précisé') as String;
    final displayTitle = _displayOfferTitle(title, location);
    final whenLabel = _labelWhenFromTitle(title);

    return GestureDetector(
      onTap: () => widget.onOfferTap?.call(doc),
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.flash_on_outlined,
                color: kPrestoOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    "$location — $whenLabel",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final duplicatedOffers = [...widget.offers, ...widget.offers];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: SizedBox(
        height: 60,
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          itemCount: duplicatedOffers.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) => _buildOfferCard(duplicatedOffers[index]),
        ),
      ),
    );
  }
}
