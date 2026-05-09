// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_element_parameter

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'app/app_globals.dart';
import 'app/presto_overlay_theme.dart';
import 'app/secondary_named_routes.dart';
import 'app/theme.dart';
import 'app_core.dart';
import 'constants.dart';
import 'firebase_init.dart';
import 'dev/page_capture_catalog_page.dart';
import 'debug_auth.dart';
import 'config/app_check_state.dart';
import 'pages/offers/offer_details_page.dart';
import 'pages/messages/messages_page_v2.dart';
import 'pages/home_page.dart';
import 'pages/account_page.dart';
import 'pages/publish_offer_page.dart';
import 'pages/admin_space_page.dart';
import 'pages/consult_offers_page.dart' show UserPublicProfilePage;
import 'services/city_search.dart';
import 'services/email_action_service.dart';
import 'services/app_route_parser.dart';
import 'services/notification_service.dart';
import 'services/admin_audio_runtime_store.dart';
import 'services/post_auth_navigation_intent_service.dart';
import 'services/user_profile_bootstrap_service.dart';

export 'pages/publish_offer_page.dart' show PublishOfferPage;

final AdminAudioRuntimeStore adminAudioRuntimeStore =
    AdminAudioRuntimeStore.instance;

/// Résultat de `FirebaseAuth.getRedirectResult()` capturé une seule fois au
/// démarrage (web). Permet aux pages compte/profil de récupérer le retour
/// d'un sign-in fédéré (Google/Facebook/Apple) sans courir la course
/// contre la consommation interne du SDK Firebase.
UserCredential? pendingRedirectAuthResult;
Object? pendingRedirectAuthError;
String? pendingPostAuthRoute;

class PrestoRemoteConfig {
  static String audioPipeline = 'HYBRID';

  static Future<void> init() async {}
}
const String kOfferDeleteReasonFoundProvider =
    'J ai deja trouve un prestataire';
const String kOfferDeleteReasonFoundOnIliPresto =
    'J’ai trouvé quelqu’un sur iliprestō';
const Duration kOfferJobDoneOverlayDuration = Duration(hours: 10);
const double kMarketplaceOutlineWidth = 1.2;
const String kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'dev',
);
const String kAppBuildNumber = String.fromEnvironment(
  'APP_BUILD_NUMBER',
  defaultValue: '0',
);
const String kAppBuildSha = String.fromEnvironment(
  'APP_BUILD_SHA',
  defaultValue: 'local',
);
const String kAppBuildBranch = String.fromEnvironment(
  'APP_BUILD_BRANCH',
  defaultValue: '',
);
const String kAppBuildTag = String.fromEnvironment(
  'APP_BUILD_TAG',
  defaultValue: '',
);
const String kAppBuildTimeUtc = String.fromEnvironment(
  'APP_BUILD_TIME_UTC',
  defaultValue: '',
);

String _normalizeOfferDeletionReason(String input) {
  return input
      .trim()
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôöō]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool _isOfferJobDoneDeletionReason(String? reason) {
  final normalized = _normalizeOfferDeletionReason(reason ?? '');
  final foundOnIliPresto =
      normalized.contains('trouve quelqu') && normalized.contains('ilipresto');
  final foundProvider =
      normalized.contains('deja trouve') && normalized.contains('prestataire');
  return foundOnIliPresto || foundProvider;
}

DateTime? _offerDateTimeFromDynamic(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value);
  return null;
}

DateTime? _offerJobDoneVisibleUntil(Map<String, dynamic> data) {
  return _offerDateTimeFromDynamic(
    data['jobDoneOverlayVisibleUntil'] ??
        data['removeFromBrowseAt'] ??
        data['pendingScreenRemovalUntil'],
  );
}

class PrestoMonitoring extends ChangeNotifier {
  PrestoMonitoring._();

  static final PrestoMonitoring I = PrestoMonitoring._();

  bool enabled = true;
  bool monitorOffersFetchOnce = true;
  bool monitorMessagesFetchOnce = true;
  bool monitorFunctionsCalls = true;
  bool monitorOtherStreams = true;

  DateTime sessionStart = DateTime.now();

  int offersQueryBuildCount = 0;
  int offersSnapshotsCount = 0;
  int offersFetchOnceCount = 0;
  int lastOffersFetchMs = 0;
  int lastOffersFetchDocs = 0;
  int messagesFetchOnceCount = 0;
  int lastMessagesFetchMs = 0;
  int lastMessagesFetchDocs = 0;
  int functionsCallsCount = 0;
  int lastFunctionsCallMs = 0;
  int otherStreamsEvents = 0;
  final Map<String, int> otherStreamEventCounts = <String, int>{};
  final Map<String, int> otherStreamLastDocs = <String, int>{};
  String lastOtherStreamKey = '';
  int lastOtherStreamDocs = 0;
  String lastErrorKey = '';
  String lastErrorMessage = '';

  void _maybeLog(String message) {
    if (!enabled || !kDebugMode) return;
    debugPrint('[PrestoMonitoring] $message');
  }

  void trackOffersQueryBuild({String? signature}) {
    if (!enabled) return;
    offersQueryBuildCount++;
    _maybeLog('offers.queryBuild signature=${signature ?? '-'}');
    notifyListeners();
  }

  void trackOffersSnapshot(int docsCount) {
    if (!enabled) return;
    offersSnapshotsCount++;
    lastOffersFetchDocs = docsCount;
    _maybeLog('offers.snapshot docs=$docsCount');
    notifyListeners();
  }

  void trackOffersFetchOnce({required int ms, required int docsCount}) {
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

  void trackError(String key, Object error) {
    if (!enabled) return;
    lastErrorKey = key;
    lastErrorMessage = error.toString();
    _maybeLog('error key=$key error=$error');
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

String _extractOfferImageUrl(dynamic entry) {
  if (entry == null) return '';
  if (entry is Map) {
    for (final key in const [
      'downloadUrl',
      'thumbnailUrl',
      'imageUrl',
      'photoUrl',
      'url',
      'secureUrl',
      'src',
      'storagePath',
      'filePath',
      'path',
    ]) {
      final value = (entry[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }
  return entry.toString().trim();
}

List<String> _collectOfferImageUrls({
  dynamic rawImageUrls,
  dynamic rawMedia,
  dynamic rawImageUrl,
  dynamic rawThumbnailUrl,
}) {
  final orderedUrls = <String>[];

  void addUrl(dynamic value) {
    final url = _extractOfferImageUrl(value);
    if (url.isEmpty || orderedUrls.contains(url)) {
      return;
    }
    orderedUrls.add(url);
  }

  if (rawImageUrls is List) {
    for (final entry in rawImageUrls) {
      addUrl(entry);
    }
  }

  if (rawMedia is List) {
    for (final entry in rawMedia) {
      addUrl(entry);
    }
  }

  addUrl(rawImageUrl);
  addUrl(rawThumbnailUrl);

  return orderedUrls;
}

Offer buildOfferDetailsOffer({
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
  final rawMedia = (data['media'] as List<dynamic>? ?? const <dynamic>[])
      .whereType<Map>()
      .map(
        (entry) => Map<String, dynamic>.from(entry.cast<dynamic, dynamic>()),
      )
      .toList(growable: false);
  final thumbnailUrl = (data['thumbnailUrl'] ?? '').toString().trim();
  final imageUrls = _collectOfferImageUrls(
    rawImageUrls: data['imageUrls'],
    rawMedia: rawMedia,
    rawImageUrl: data['imageUrl'],
    rawThumbnailUrl: thumbnailUrl,
  );
  final advertiserName =
      ((data['userName'] ?? data['pseudo']) ?? '').toString().trim();
  final serviceArea =
      (data['serviceArea'] ?? (location.isEmpty ? 'Zone locale' : location))
          .toString();
  final missionDelay =
      ((data['missionDelay'] ?? data['averageDelay']) ?? 'Délai non précisé')
          .toString();
  final createdAt = data['createdAt'];
  final publishedAt = data['publishedAt'];
  final listingStatus = (data['status'] ?? '').toString().trim();
  final moderationStatus = (data['moderationStatus'] ?? '').toString().trim();
  final visibility = (data['visibility'] ?? '').toString().trim();
  final mediaProcessingStatus =
      (data['mediaProcessingStatus'] ?? '').toString().trim();
  final categoryId = (data['categoryId'] ?? '').toString().trim();
  final cityId = (data['cityId'] ?? '').toString().trim();
  final isMarketplaceValue = data['isMarketplace'];
  final isMarketplace = isMarketplaceValue is bool
      ? isMarketplaceValue
      : isMarketplaceValue.toString().trim().toLowerCase() == 'true';

  return Offer(
    id: offerId,
    listingId: offerId,
    title: title.isEmpty ? 'Annonce' : title,
    price: price,
    category: category.isEmpty ? 'Categorie non precisee' : category,
    categoryId: categoryId,
    city: location.isEmpty ? 'Lieu non precise' : location,
    cityId: cityId,
    postalCode: postalCode,
    isUrgent: isUrgent,
    publishedAtLabel: _offerDetailsPublishedLabel(data['createdAt']),
    publishedAt: publishedAt is Timestamp ? publishedAt.toDate() : null,
    createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    availability:
        (data['availability'] ?? 'Disponibilite a confirmer').toString(),
    shortDescription: description.isEmpty
        ? 'Consultez le detail de cette annonce et contactez l\'annonceur.'
        : description,
    description: description,
    phone: (data['phone'] ?? '').toString(),
    imageUrls: imageUrls,
    media: rawMedia,
    thumbnailUrl: thumbnailUrl,
    statusBadges: <String>[
      'Disponible',
      if ((data['urgent'] as bool?) ?? false) 'Urgent',
      if ((data['verified'] as bool?) ?? false) 'Verifie',
      'Nouveau',
    ],
    status: listingStatus,
    moderationStatus: moderationStatus,
    visibility: visibility,
    mediaProcessingStatus: mediaProcessingStatus,
    isMarketplace: isMarketplace,
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
          (data['rating'] is num) ? (data['rating'] as num).toDouble() : null,
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


class CardShell extends StatelessWidget {
  final Widget child;
  const CardShell({Key? key, required this.child}) : super(key: key);

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


Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await ensureFirebaseInitialized(source: 'main');

    // 📋 Diagnostics
    if (kDebugMode) {
      debugPrint('=== Firebase Initialization ===');
      debugPrint('[FirebaseInit] ready platform=${firebaseInitPlatformLabel()}');
      debugPrint('✓ Auth instance: ${FirebaseAuth.instance.runtimeType}');
      debugPrint(
          '✓ Firestore instance: ${FirebaseFirestore.instance.runtimeType}');
      debugPrint('[Firestore] initialization ready');
      if (kIsWeb) {
        debugPrint('✓ Platform: Web');
        debugPrint('  - Google Sign-In: Popup + Redirect fallback');
      } else {
        debugPrint(
            '✓ Platform: ${defaultTargetPlatform.toString().split('.').last}');
      }
      debugPrint('');
    }

    // ✅ Activer la persistance Firestore (cache + offline)
    if (!kIsWeb) {
      try {
        await FirebaseFirestore.instance.enableNetwork();
        if (kDebugMode) debugPrint('✓ Firestore persistence: Enabled');
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Firestore persistence error: $e');
      }
    } else {
      // Web: persistance auto si IndexedDB disponible
      if (kDebugMode) debugPrint('✓ Firestore Web: Persistence (IndexedDB if available)');
    }

    // ✅ Initialiser le service Firebase centralisé avec optimisations
    // await FirebaseService.instance.initialize();

    // ✅ Remote Config: charger le pipeline audio
    await PrestoRemoteConfig.init();
    if (kDebugMode) debugPrint('[RC] audio_pipeline=${PrestoRemoteConfig.audioPipeline}');

    // 🔒 App Check
    // - Debug: provider debug (ajouter le debug token dans Firebase Console → App Check)
    // - Release: Play Integrity (Android) + App Attest (iOS)
    // - Web: reCAPTCHA Enterprise si une siteKey est fournie.
    //   Exemple:
    //   `flutter run -d chrome --dart-define=APPCHECK_RECAPTCHA_SITE_KEY=xxxxx`
    // Clé site reCAPTCHA Enterprise (override possible via --dart-define=APPCHECK_RECAPTCHA_SITE_KEY)
    appCheckActivationAttempted = true;
    appCheckActivationSucceeded = false;
    appCheckActivationError = null;
    appCheckActivationStackTrace = null;
    if (kDebugMode) debugPrint(
        '[AppCheck] initializing platform=${firebaseInitPlatformLabel()}');
    try {
      if (kIsWeb) {
        final siteKey = kAppCheckWebRecaptchaSiteKey.trim();
        if (siteKey.isEmpty) {
          const message =
              '[AppCheck] Web skipped: reCAPTCHA site key absente';
          if (kDebugMode) debugPrint(message);
          try {
            await FirebaseCrashlytics.instance.recordError(
              StateError(message),
              StackTrace.current,
              reason: 'missing_app_check_recaptcha_site_key',
              fatal: false,
            );
          } catch (_) {
            // Crashlytics peut être indisponible très tôt au bootstrap web.
          }
          throw StateError(
            '$message. Ajoute --dart-define=APPCHECK_RECAPTCHA_SITE_KEY=... au build web.',
          );
        } else {
          final preview =
              siteKey.length > 10 ? siteKey.substring(0, 10) : siteKey;
          if (kDebugMode) debugPrint('[APPCHECK] siteKey=$preview...');
          await FirebaseAppCheck.instance.activate(
            webProvider: ReCaptchaEnterpriseProvider(siteKey),
          );
          if (kDebugMode) debugPrint('[AppCheck] Web activated (reCAPTCHA Enterprise)');
        }
      } else {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider: kDebugMode
              ? AppleProvider.debug
              : AppleProvider.appAttest,
        );
      }
      final appCheckToken = await FirebaseAppCheck.instance
          .getToken(true)
          .timeout(const Duration(seconds: 8));
      if ((appCheckToken ?? '').trim().isEmpty) {
        throw StateError('Jeton App Check vide apres activation');
      }
      appCheckActivationSucceeded = true;
      if (kDebugMode) debugPrint('[AppCheck] ready token=ok');
    } catch (e, st) {
      appCheckActivationError = e;
      appCheckActivationStackTrace = st;
      if (kDebugMode) debugPrint('[AppCheck] activation failed: $e');
    }

    // 🔒 Auth minimale requise pour les Cloud Functions (même en anonyme)
    // Supprimé : on n'impose plus de connexion automatique au démarrage
    // L'auth anonyme sera gérée au besoin par chaque page qui en a besoin
    try {
      final auth = FirebaseAuth.instance;
      if (kDebugMode) {
        DebugAuth.installAuthStateLogs();
      }

      if (kIsWeb) {
        // Garantit la persistance LOCAL pour survivre au signInWithRedirect
        // (sinon Safari/Brave retombent en SESSION et perdent l'état au
        // retour OAuth).
        try {
          await auth.setPersistence(Persistence.LOCAL);
        } catch (e) {
          if (kDebugMode) debugPrint('[Auth] setPersistence failed: $e');
        }

        // Capture UNE SEULE FOIS le résultat d'un éventuel
        // signInWithRedirect précédent. Doit être appelé tôt pour ne pas
        // courir la course contre AccountPage qui appelle aussi
        // getRedirectResult dans son initState.
        try {
          pendingRedirectAuthResult = await auth.getRedirectResult();
          if (kDebugMode) {
            debugPrint(
              '[Auth] getRedirectResult: user='
              '${pendingRedirectAuthResult?.user?.uid} '
              'provider=${pendingRedirectAuthResult?.credential?.providerId}',
            );
          }
        } catch (e) {
          pendingRedirectAuthError = e;
          if (kDebugMode) debugPrint('[Auth] getRedirectResult error: $e');
        }

        final shouldRestorePostAuthRoute =
            pendingRedirectAuthResult?.user != null ||
            pendingRedirectAuthError != null;
        if (shouldRestorePostAuthRoute) {
          try {
            pendingPostAuthRoute =
                await PostAuthNavigationIntentService.takePendingRoute();
            if (kDebugMode && pendingPostAuthRoute != null) {
              debugPrint('[Auth] pending post-auth route=$pendingPostAuthRoute');
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[Auth] takePendingRoute failed: $e');
            }
          }
        }
      }

      // Ne force plus signInAnonymously() au démarrage
      if (auth.currentUser != null) {
        if (kDebugMode) debugPrint('[Auth] User already signed in: ${auth.currentUser!.uid}');
        SessionState.userId = auth.currentUser!.uid;
      } else {
        if (kDebugMode) debugPrint('[Auth] No user signed in at startup (OK)');
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
      if (kDebugMode) debugPrint('[Auth] check failed: $e');
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

    // Initialisation des notifications push sur toutes les plateformes.
    // Sur Web, l'enregistrement du token dépend de FCM_WEB_VAPID_KEY.
    try {
      await NotificationService().initialize(
        navigatorKey: appNavigatorKey,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Notifications] init error: $e');
    }

    runApp(const PrestoApp());
  }, (error, stack) {
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

class PrestoApp extends StatefulWidget {
  const PrestoApp({super.key});

  @override
  State<PrestoApp> createState() => _PrestoAppState();
}

class _PrestoAppState extends State<PrestoApp> {
  bool _navigatorReadySignaled = false;

  Widget _buildInitialHome() {
    if (kIsWeb) {
      final rawPath = Uri.base.path.trim();
      final normalizedPath =
          rawPath.endsWith('/') && rawPath.length > 1
              ? rawPath.substring(0, rawPath.length - 1)
              : rawPath;
      if (normalizedPath == '/page-catalog') {
        return const PageCaptureCatalogPage();
      }
    }

    return const SplashScreen();
  }

  void _signalNavigatorReady() {
    if (_navigatorReadySignaled) return;
    _navigatorReadySignaled = true;
    NotificationService().markNavigatorReady();
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name ?? '';
    final parsedRoute = Uri.tryParse(routeName);
    if (parsedRoute != null && parsedRoute.path == '/page-catalog') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const PageCaptureCatalogPage(),
      );
    }

    final target = parseAppDeepLink(settings.name);
    if (target == null) return null;

    if (target.offerId != null) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => OfferDeepLinkPage(
          offerId: target.offerId!,
          preferMarketplace: target.preferMarketplace,
        ),
      );
    }

    if (target.userId != null && target.routeName == '/profile') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => UserPublicProfilePage(userId: target.userId!),
      );
    }

    if (target.routeName == AppDeepLinkTarget.messagesRouteName ||
        target.routeName == AppDeepLinkTarget.messagesV2RouteName) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => MessagesPageV2(
          initialConversationId: target.conversationId,
          initialDraftText: target.initialDraftText,
        ),
      );
    }

    return MaterialPageRoute(
      settings: settings,
      builder: (_) => HomePage(
        initialIndex: 3,
        initialMessagesConversationId: target.conversationId,
        initialMessagesDraftText: target.initialDraftText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iliprestō',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _signalNavigatorReady();
        });
        return child ?? const SizedBox.shrink();
      },
      onGenerateRoute: _onGenerateRoute,
      routes: {
        '/publish': (_) => const PublishOfferPage(),
        '/messages': (_) => const MessagesPageV2(),
        '/messages-2': (_) => const MessagesPageV2(),
        '/account': (_) => const AccountPage(),
        '/admin': (_) => const AdminSpacePage(),
        '/page-catalog': (_) => const PageCaptureCatalogPage(),
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
        ...buildSecondaryNamedRoutes(),
      },
      theme: buildPrestoTheme(),
      home: _buildInitialHome(),
    );
  }
}

/// Dialogue de création de compte (inscription)
void _showSignupDialog(BuildContext context) {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();
  final overlayTheme = context.prestoOverlayTheme;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: overlayTheme.surfaceColor,
      surfaceTintColor: overlayTheme.surfaceTintColor,
      shape: overlayTheme.dialogShape,
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
                await UserProfileBootstrapService.ensureUserDocument(
                  user: credential.user!,
                  authMethod: 'email',
                  isNewUserHint: true,
                );
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

    _scheduleNavigation(_initialSplashDuration());
  }

  Duration _initialSplashDuration() {
    if (!kIsWeb) {
      return const Duration(milliseconds: 3500);
    }

    if (pendingPostAuthRoute == PostAuthNavigationIntentService.accountRoute) {
      return const Duration(milliseconds: 1200);
    }

    final webPath = _normalizedWebPath();
    final hasDeepLink = parseAppDeepLink(Uri.base.toString()) != null;
    if (webPath == '/account' || webPath == '/publish' || hasDeepLink) {
      return const Duration(milliseconds: 1200);
    }

    return const Duration(milliseconds: 3500);
  }

  String _normalizedWebPath() {
    final rawPath = Uri.base.path.trim();
    if (rawPath.isEmpty) {
      return '/';
    }
    return rawPath.endsWith('/') && rawPath.length > 1
        ? rawPath.substring(0, rawPath.length - 1)
        : rawPath;
  }

  Widget _destinationForCurrentLocation() {
    if (!kIsWeb) {
      return const HomePage();
    }

    final postAuthRoute = pendingPostAuthRoute;
    pendingPostAuthRoute = null;
    if (postAuthRoute == PostAuthNavigationIntentService.accountRoute) {
      return const HomePage(initialIndex: 4);
    }

    final webPath = _normalizedWebPath();
    if (webPath == '/account') {
      return const AccountPage();
    }
    if (webPath == '/publish') {
      return const PublishOfferPage();
    }

    final target = parseAppDeepLink(Uri.base.toString());
    if (target != null) {
      if (target.offerId != null) {
        return OfferDeepLinkPage(
          offerId: target.offerId!,
          preferMarketplace: target.preferMarketplace,
        );
      }

      if (target.routeName == AppDeepLinkTarget.messagesRouteName ||
          target.routeName == AppDeepLinkTarget.messagesV2RouteName) {
        return MessagesPageV2(
          initialConversationId: target.conversationId,
          initialDraftText: target.initialDraftText,
        );
      }

      return HomePage(
        initialIndex: 3,
        initialMessagesConversationId: target.conversationId,
        initialMessagesDraftText: target.initialDraftText,
      );
    }

    return const HomePage();
  }

  void _scheduleNavigation(Duration duration) {
    _navTimer?.cancel();
    _navTimer = Timer(duration, () {
      _navigateTo(_destinationForCurrentLocation());
    });
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
          child: Stack(
            children: [
              Center(
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
                            side:
                                const BorderSide(color: Colors.white, width: 2),
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
              const Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _SplashBuildStamp(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashBuildStamp extends StatelessWidget {
  const _SplashBuildStamp();

  @override
  Widget build(BuildContext context) {
    final shortSha = kAppBuildSha == 'local'
        ? 'local'
        : (kAppBuildSha.length > 12
            ? kAppBuildSha.substring(0, 12)
            : kAppBuildSha);
    final primaryLine = 'v$kAppVersion+$kAppBuildNumber • commit $shortSha';
    final secondaryParts = <String>[
      if (kAppBuildBranch.trim().isNotEmpty) 'branch ${kAppBuildBranch.trim()}',
      if (kAppBuildTag.trim().isNotEmpty) 'tag ${kAppBuildTag.trim()}',
      if (kAppBuildTimeUtc.trim().isNotEmpty)
        'build ${kAppBuildTimeUtc.trim()}',
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                primaryLine,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (secondaryParts.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  secondaryParts.join(' • '),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

