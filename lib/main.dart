// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_element_parameter

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'app/app_globals.dart';
import 'app/secondary_named_routes.dart';
import 'app/theme.dart';
import 'app/typography_settings.dart';
import 'app_core.dart';
import 'firebase_init.dart';
import 'dev/page_capture_catalog_page.dart';
import 'debug_auth.dart';
import 'pages/offers/offer_details_page.dart';
import 'pages/messages/messages_page_v2.dart';
import 'pages/home_page.dart';
import 'pages/publish_offer_page.dart';
import 'pages/admin_space_page.dart';
import 'pages/consult_offers_page.dart' show UserPublicProfilePage;
import 'pages/toolbox_je_me_lance_page.dart';
import 'services/city_search.dart';
import 'services/app_check_bootstrap.dart';
import 'services/app_route_parser.dart';
import 'services/initial_route_resolver.dart';
import 'services/firestore_bootstrap.dart';
import 'services/notification_service.dart';
import 'services/admin_audio_runtime_store.dart';
import 'services/admin_web_debug_store.dart';
import 'services/post_auth_navigation_intent_service.dart';
import 'widgets/admin_web_debug_panel.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/register_page.dart';
import 'pages/auth/forgot_password_page.dart';
import 'pages/auth/verify_email_page.dart';
import 'pages/auth/reset_password_success_page.dart';
import 'pages/account/account_security_page.dart';
import 'pages/account/change_email_page.dart';
import 'pages/account/change_password_page.dart';
import 'pages/account/delete_account_page.dart';
import 'services/app_monitoring_service.dart';
import 'services/cookie_consent_service.dart';
import 'app/presto_app_chrome.dart';
import 'core/connectivity/connectivity_status.dart';
import 'core/localization/locale_controller.dart';
import 'l10n/app_localizations.dart';

export 'pages/publish_offer_page.dart' show PublishOfferPage;

final AdminAudioRuntimeStore adminAudioRuntimeStore =
    AdminAudioRuntimeStore.instance;
final AdminWebDebugStore adminWebDebugStore = AdminWebDebugStore.instance;

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

class PrestoMonitoring {
  PrestoMonitoring._();

  static final PrestoMonitoring I = PrestoMonitoring._();

  void trackOtherStream({required String key, required int docsCount}) {
    if (kDebugMode) {
      debugPrint('[monitoring] stream=$key count=$docsCount');
    }
    adminWebDebugStore.recordEvent(
      area: 'monitoring',
      message: 'stream',
      detail: 'key=$key count=$docsCount',
    );
  }

  void trackOffersSnapshot(int docsCount) {
    trackOtherStream(key: 'offers.snapshot', docsCount: docsCount);
  }

  void trackFunctionsCall({required String name, required int ms}) {
    if (kDebugMode) {
      debugPrint('[monitoring] function=$name ms=$ms');
    }
    adminWebDebugStore.recordEvent(
      area: 'monitoring',
      message: 'function',
      detail: 'name=$name ms=$ms',
    );
  }

  void trackError(String key, Object error) {
    if (kDebugMode) {
      debugPrint('[monitoring] error=$key $error');
    }
    adminWebDebugStore.recordError(
      'monitoring',
      error,
      message: key,
    );
  }
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
const String kDebugStartPage = String.fromEnvironment(
  'PRESTO_DEBUG_START_PAGE',
  defaultValue: '',
);

SystemUiOverlayStyle prestoOverlayStyleFor(Color backgroundColor) {
  final estimated = ThemeData.estimateBrightnessForColor(backgroundColor);
  final isDarkBackground = estimated == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: backgroundColor,
    statusBarIconBrightness:
        isDarkBackground ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDarkBackground ? Brightness.dark : Brightness.light,
    // Barre système du bas sous la bottom bar : toujours blanche.
    systemNavigationBarColor: Colors.white,
    systemNavigationBarDividerColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  );
}

DateTime? _offerDateTimeFromDynamic(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String? inferRegionFromPostalCode(String postalCode) {
  final cp = postalCode.trim();
  if (cp.length < 2) return null;

  if (cp.length >= 3 && cp.startsWith('97')) {
    switch (cp.substring(0, 3)) {
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

  if (<int>{22, 29, 35, 56}.contains(two)) {
    return 'Bretagne';
  }

  if (<int>{18, 28, 36, 37, 41, 45}.contains(two)) {
    return 'Centre-Val de Loire';
  }

  if (<int>{8, 10, 51, 52, 54, 55, 57, 67, 68, 88}.contains(two)) {
    return 'Grand Est';
  }

  if (<int>{2, 59, 60, 62, 80}.contains(two)) {
    return 'Hauts-de-France';
  }

  if (<int>{75, 77, 78, 91, 92, 93, 94, 95}.contains(two)) {
    return 'Île-de-France';
  }

  if (<int>{14, 27, 50, 61, 76}.contains(two)) {
    return 'Normandie';
  }

  if (<int>{16, 17, 19, 23, 24, 33, 40, 47, 64, 79, 86, 87}.contains(two)) {
    return 'Nouvelle-Aquitaine';
  }

  if (<int>{9, 11, 12, 30, 31, 32, 34, 46, 48, 65, 66, 81, 82}.contains(two)) {
    return 'Occitanie';
  }

  if (<int>{44, 49, 53, 72, 85}.contains(two)) {
    return 'Pays de la Loire';
  }

  if (<int>{4, 5, 6, 13, 83, 84}.contains(two)) {
    return 'Provence-Alpes-Côte d\'Azur';
  }

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
  final isUrgent =
      (data['isUrgent'] as bool?) ?? (data['urgent'] as bool?) ?? false;
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
  final inferredMarketplace = categoryId.isNotEmpty ||
      cityId.isNotEmpty ||
      listingStatus.isNotEmpty ||
      visibility.isNotEmpty ||
      mediaProcessingStatus.isNotEmpty ||
      data.containsKey('favoriteCount') ||
      data.containsKey('ownerId');
  final isMarketplace = isMarketplaceValue is bool
      ? isMarketplaceValue
      : isMarketplaceValue.toString().trim().toLowerCase() == 'true' ||
          inferredMarketplace;

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
      if ((data['isUrgent'] as bool?) ?? (data['urgent'] as bool?) ?? false)
        'Urgent',
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
      avatarUrl: ((data['avatarUrl'] ??
                  data['photoUrl'] ??
                  data['photoURL'] ??
                  data['profilePhotoUrl'] ??
                  data['imageUrl']) ??
              '')
          .toString(),
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
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withValues(alpha: 0.28)),
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

/// Borne la largeur du contenu sur tablette/desktop pour éviter un affichage
/// trop étalé. Sur mobile (< [_kBreakpoint] dp), aucune contrainte n'est
/// appliquée.
class _PrestoResponsiveFrame extends StatelessWidget {
  const _PrestoResponsiveFrame({required this.child});

  final Widget child;

  static const double _kMaxContentWidth = 960;
  static const double _kBreakpoint = 1000;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= _kBreakpoint) return child;
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: SizedBox(
          width: _kMaxContentWidth,
          height: double.infinity,
          child: child,
        ),
      ),
    );
  }
}

class CardShell extends StatelessWidget {
  final Widget child;
  const CardShell({super.key, required this.child});

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
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Initialise les services non requis pour le premier rendu (notifications
/// push, etc.). Lancé sans await après runApp afin de ne pas retarder
/// l'affichage interactif. Toute erreur est isolée pour ne pas casser l'app.
Future<void> _initBackgroundServices() async {
  // Notifications push (toutes plateformes). Sur Web, l'enregistrement du token
  // dépend de FCM_WEB_VAPID_KEY.
  try {
    await NotificationService().initialize(
      navigatorKey: appNavigatorKey,
    );
    adminWebDebugStore.recordEvent(
      area: 'notifications',
      message: 'initialized',
    );
  } catch (e) {
    adminWebDebugStore.recordError('notifications', e, message: 'init-failed');
    if (kDebugMode) debugPrint('[Notifications] init error: $e');
  }
}

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    AppMonitoringService.instance.configureGlobalErrorHandling();

    // Splash orange minimal désactivé :
    // l'app démarre directement sur PrestoApp après les initialisations critiques.
    adminWebDebugStore.recordEvent(
      area: 'app',
      message: 'startup',
      detail: 'platform=${kIsWeb ? 'web' : defaultTargetPlatform.name}',
    );

    // Audit #4 — Démarrage non bloquant : la base des villes est un asset local
    // consommé uniquement par des écrans interactifs (recherche de ville). On la
    // précharge en parallèle de l'init Firebase (I/O), sans bloquer le 1er rendu.
    unawaited(CitySearch.instance.ensureLoaded());

    // La typographie distante ne bloque plus le premier rendu.
    unawaited(typographySettings.load());

    await ensureFirebaseInitialized(source: 'main');
    // Le consentement est chargé en parallèle et l’UI réagit à son état.
    unawaited(CookieConsentService.instance.load());

    await bootstrapAppCheck();

    adminWebDebugStore.recordEvent(area: 'firebase', message: 'initialized');
    await bootstrapFirestore();
    adminWebDebugStore.recordEvent(area: 'firestore', message: 'bootstrapped');

    // 📋 Diagnostics
    if (kDebugMode) {
      debugPrint('=== Firebase Initialization ===');
      debugPrint(
          '[FirebaseInit] ready platform=${firebaseInitPlatformLabel()}');
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
      if (kDebugMode) {
        debugPrint('✓ Firestore Web: Persistence (IndexedDB if available)');
      }
    }

    // ✅ Initialiser le service Firebase centralisé avec optimisations
    // await FirebaseService.instance.initialize();

    // ✅ Remote Config: charger le pipeline audio
    await PrestoRemoteConfig.init();
    if (kDebugMode) {
      debugPrint('[RC] audio_pipeline=${PrestoRemoteConfig.audioPipeline}');
    }
    adminWebDebugStore.recordEvent(
      area: 'remote-config',
      message: 'initialized',
      detail: 'audio_pipeline=${PrestoRemoteConfig.audioPipeline}',
    );

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
        //
        // Timeout défensif : juste après le retour de la redirection OAuth
        // (mobile web), le stockage persistant peut être temporairement
        // indisponible (Safari ITP, navigateur intégré) et faire pendre
        // cet appel indéfiniment, ce qui bloquerait runApp() et laisserait
        // l'utilisateur coincé sur le fond orange de démarrage.
        try {
          pendingRedirectAuthResult =
              await auth.getRedirectResult().timeout(
                    const Duration(seconds: 10),
                  );
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
              debugPrint(
                  '[Auth] pending post-auth route=$pendingPostAuthRoute');
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
        if (kDebugMode) {
          debugPrint('[Auth] User already signed in: ${auth.currentUser!.uid}');
        }
        SessionState.userId = auth.currentUser!.uid;
      } else {
        if (kDebugMode) debugPrint('[Auth] No user signed in at startup (OK)');
        SessionState.userId = null;
      }

      // Synchronise SessionState.userId globalement dès qu'Auth change
      // (couvre sign-in/sign-out depuis n'importe quelle page).
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        SessionState.userId = user?.uid;
        adminWebDebugStore.updateAuth(user);
        if (kDebugMode) {
          debugPrint('[Auth] global state changed: ${user?.uid ?? "null"}');
        }
      });
    } catch (e) {
      adminWebDebugStore.recordError('auth', e,
          message: 'startup-check-failed');
      if (kDebugMode) debugPrint('[Auth] check failed: $e');
    }

    // Configuration globale : barre système bleue Prestō sur toute l'app.
    // (Le SplashScreen surcharge en orange.)
    SystemChrome.setSystemUIOverlayStyle(prestoOverlayStyleFor(kPrestoBlue));

    // Crashlytics n'est pas supporté sur le web
    final previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      previousFlutterOnError?.call(details);
      adminWebDebugStore.recordError(
        'flutter',
        details.exception,
        stackTrace: details.stack,
        message: details.library ?? 'flutter-error',
      );
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      adminWebDebugStore.recordError(
        'platform',
        error,
        stackTrace: stack,
        message: 'platform-dispatcher',
      );
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
      return true;
    };

    if (!kIsWeb) {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);
    }

    runApp(const PrestoApp());

    // Audit #4 — Services non essentiels au premier rendu : initialisés en
    // arrière-plan après runApp pour afficher un shell interactif immédiat.
    unawaited(_initBackgroundServices());
  }, (error, stack) {
    adminWebDebugStore.recordError(
      'zone',
      error,
      stackTrace: stack,
      message: 'runZonedGuarded',
    );
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

class _PrestoAppState extends State<PrestoApp> with WidgetsBindingObserver {
  bool _navigatorReadySignaled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ConnectivityStatus.instance.start();
    unawaited(LocaleController.instance.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    adminWebDebugStore.recordEvent(
      area: 'lifecycle',
      message: 'resumed',
    );
    unawaited(
      refreshAppCheckToken(reason: 'app-resumed').catchError((Object error) {
        if (kDebugMode) {
          debugPrint('[AppCheck] resume refresh skipped: $error');
        }
      }),
    );
  }

  Widget _buildInitialHome() {
    // FIX ROUTAGE INITIAL :
    // Au lancement normal de l'app, le splash doit finir sur HomePage.
    // On ignore les anciennes intentions /account ou /login mémorisées.
    final initialWebPath =
        Uri.base.path.trim().isEmpty ? '/' : Uri.base.path.trim();
    if (initialWebPath.isEmpty ||
        initialWebPath == '/' ||
        initialWebPath == '/login') {
      pendingPostAuthRoute = null;
    }

    if (kIsWeb) {
      final rawPath = Uri.base.path.trim();
      final normalizedPath = rawPath.endsWith('/') && rawPath.length > 1
          ? rawPath.substring(0, rawPath.length - 1)
          : rawPath;
      if (!kReleaseMode && normalizedPath == '/page-catalog') {
        return const PageCaptureCatalogPage();
      }
      if (!kReleaseMode && normalizedPath == '/toolbox-fonctionnaire-test') {
        return const ToolboxJeMeLancePage();
      }
    }

    if (!kReleaseMode && kDebugStartPage == 'toolbox_fonctionnaire') {
      return const ToolboxJeMeLancePage();
    }

    return const SplashScreen();
  }

  void _signalNavigatorReady() {
    if (_navigatorReadySignaled) return;
    _navigatorReadySignaled = true;
    NotificationService().markNavigatorReady();
  }

  List<Route<dynamic>> _onGenerateInitialRoutes(String initialRouteName) {
    final parsed = Uri.tryParse(initialRouteName);
    final rawPath = (parsed?.path ?? initialRouteName).trim();
    final normalizedPath = rawPath.isEmpty
        ? '/'
        : rawPath.endsWith('/') && rawPath.length > 1
            ? rawPath.substring(0, rawPath.length - 1)
            : rawPath;

    // Sécurité Flutter Web / PWA :
    // /account démarre toujours par le splash/home.
    // /login doit afficher réellement la page connexion.
    if (normalizedPath == LoginPage.routeName) {
      return <Route<dynamic>>[
        MaterialPageRoute(
          settings: const RouteSettings(name: LoginPage.routeName),
          builder: (_) => const LoginPage(),
        ),
      ];
    }

    if (normalizedPath == '/account') {
      pendingPostAuthRoute = null;
      return <Route<dynamic>>[
        MaterialPageRoute(
          settings: const RouteSettings(name: '/account'),
          builder: (_) => const HomePage(initialIndex: 4),
        ),
      ];
    }

    return <Route<dynamic>>[
      MaterialPageRoute(
        settings: const RouteSettings(name: '/'),
        builder: (_) => _buildInitialHome(),
      ),
    ];
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name ?? '';
    final parsedRoute = Uri.tryParse(routeName);
    if (!kReleaseMode &&
        parsedRoute != null &&
        parsedRoute.path == '/page-catalog') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const PageCaptureCatalogPage(),
      );
    }
    if (!kReleaseMode &&
        parsedRoute != null &&
        parsedRoute.path == '/toolbox-fonctionnaire-test') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const ToolboxJeMeLancePage(),
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
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) => _buildMaterialApp(context),
    );
  }

  Widget _buildMaterialApp(BuildContext context) {
    return MaterialApp(
      title: 'iliprestō',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (deviceLocale, supportedLocales) =>
          LocaleController.instance.resolveDeviceLocale(deviceLocale),
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _signalNavigatorReady();
        });
        return PrestoAppChrome(
          child: AdminWebDebugPanel(
            child: _PrestoResponsiveFrame(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      onGenerateInitialRoutes: _onGenerateInitialRoutes,
      onGenerateRoute: _onGenerateRoute,
      routes: {
        LoginPage.routeName: (_) => const LoginPage(),
        RegisterPage.routeName: (_) => const RegisterPage(),
        ForgotPasswordPage.routeName: (_) => const ForgotPasswordPage(),
        VerifyEmailPage.routeName: (_) => const VerifyEmailPage(),
        ResetPasswordSuccessPage.routeName: (_) =>
            const ResetPasswordSuccessPage(email: ''),
        AccountSecurityPage.routeName: (_) => const AccountSecurityPage(),
        ChangeEmailPage.routeName: (_) => const ChangeEmailPage(),
        ChangePasswordPage.routeName: (_) => const ChangePasswordPage(),
        DeleteAccountPage.routeName: (_) => const DeleteAccountPage(),
        '/publish': (_) => const PublishOfferPage(),
        '/messages': (_) => const MessagesPageV2(),
        '/messages-2': (_) => const MessagesPageV2(),
        '/account': (_) => const HomePage(initialIndex: 4),
        '/admin': (_) => const AdminSpacePage(),
        if (!kReleaseMode)
          '/page-catalog': (_) => const PageCaptureCatalogPage(),
        if (!kReleaseMode)
          '/toolbox-fonctionnaire-test': (_) => const ToolboxJeMeLancePage(),
        ...buildSecondaryNamedRoutes(),
      },
      theme: buildPrestoTheme(),
      // L'application doit toujours démarrer par le splash puis la home.
      // Les pages protégées gèrent elles-mêmes la demande de connexion.
      home: _buildInitialHome(),
    );
  }
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

    // Racine "/" ou mobile → HomePage après 3s (la home se charge en arrière-plan).
    // Deep links → destination directe après 600ms.
    final isRoot =
        !kIsWeb || _normalizedWebPath().isEmpty || _normalizedWebPath() == '/';
    _scheduleNavigation(
      isRoot ? Duration.zero : const Duration(milliseconds: 120),
    );
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
    final resolution = resolveInitialRoute(
      kIsWeb ? Uri.base.toString() : '/',
    );

    // Une seule remise à zéro au démarrage. La reprise post-auth est ensuite
    // gérée par PostAuthNavigationIntentService, sans mutations répétées.
    pendingPostAuthRoute = null;

    switch (resolution.kind) {
      case InitialRouteKind.account:
        return const HomePage(initialIndex: 4);
      case InitialRouteKind.publish:
        return const PublishOfferPage();
      case InitialRouteKind.offer:
        final target = resolution.deepLinkTarget!;
        return OfferDeepLinkPage(
          offerId: target.offerId!,
          preferMarketplace: target.preferMarketplace,
        );
      case InitialRouteKind.profile:
        return UserPublicProfilePage(
          userId: resolution.deepLinkTarget!.userId!,
        );
      case InitialRouteKind.messages:
        final target = resolution.deepLinkTarget!;
        return MessagesPageV2(
          initialConversationId: target.conversationId,
          initialDraftText: target.initialDraftText,
        );
      case InitialRouteKind.home:
        return const HomePage();
    }
  }

  void _scheduleNavigation(Duration duration) {
    _navTimer?.cancel();
    _navTimer = Timer(duration, () {
      try {
        _navigateTo(_destinationForCurrentLocation());
      } catch (e) {
        // Navigation principale a échoué — forcer HomePage comme fallback.
        try {
          _navigateTo(const HomePage());
        } catch (_) {}
      }
      _maybePushColdStartNotificationRoute();
    });
  }

  void _maybePushColdStartNotificationRoute() {
    final route = NotificationService().consumeColdStartRoute();
    if (route == null || route.isEmpty) return;
    // Schedule on next frame so pushReplacement above has settled first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appNavigatorKey.currentState?.pushNamed(route);
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
                            "J'offre un job",
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
            color: Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
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
