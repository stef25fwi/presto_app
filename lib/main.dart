// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_element_parameter

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

import 'app/presto_overlay_theme.dart';
import 'app/theme.dart';
import 'app_core.dart';
import 'constants.dart';
import 'firebase_options.dart';
import 'dev/seed_offers.dart';
import 'debug_auth.dart';
import 'features/ai_draft/ai_draft_service.dart';
import 'features/micro_ia/micro_ia_service.dart';
import 'features/micro_ia/web_audio_recorder.dart';
import 'config/env/openai_config.dart';
import 'profile_page.dart';
import 'models/admin_access_state.dart';
import 'pages/admin_space_page.dart';
import 'pages/legal_info_page.dart';
import 'pages/offers/offer_details_page.dart';
import 'pages/messages/messages_page_v2.dart';
import 'pages/toolbox_hub_page.dart';
import 'services/admin_access_resolver.dart';
import 'services/ai/listing_audio_ai_service.dart';
import 'services/city_search.dart';
import 'services/account_social_auth_actions.dart';
import 'services/google_auth_service.dart';
import 'services/email_action_service.dart';
import 'services/firebase_functions_region.dart';
import 'services/inbox_counts.dart';
import 'services/app_route_parser.dart';
import 'services/marketplace_publish_service.dart';
import 'services/marketplace_remote_config_service.dart';
import 'services/notification_service.dart';
import 'services/offer_indexing.dart';
import 'services/admin_audio_runtime_store.dart';
import 'services/user_profile_bootstrap_service.dart';
import 'utils/crashlytics_context.dart';
import 'utils/friendly_snackbar.dart';
import 'utils/recording_path_web.dart'
    if (dart.library.io) 'utils/recording_path_io.dart';
import 'widgets/ad_banner.dart';
import 'widgets/account_profile_sections.dart';
import 'widgets/entrepreneur_toolbox_slide.dart';
import 'widgets/home_bottom_nav_item.dart';
import 'widgets/presto_info_icon_animated.dart';
import 'widgets/premium_ai_button.dart';
import 'widgets/phone_input_field.dart';
import 'widgets/photo_selector_tile.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final AdminAudioRuntimeStore _adminAudioRuntimeStore =
  AdminAudioRuntimeStore.instance;

class PrestoRemoteConfig {
  static String audioPipeline = 'HYBRID';

  static Future<void> init() async {}
}

const kPrestoOrange = Color(0xFFFF6600);
const kPrestoBlue = Color(0xFF1A73E8);
const String kOfferDeleteReasonFoundProvider =
    'J ai deja trouve un prestataire';
const String kOfferDeleteReasonFoundOnIliPresto =
    'J’ai trouvé quelqu’un sur iliprestō';
const Duration kOfferJobDoneOverlayDuration = Duration(hours: 10);

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

bool _isOfferArchivedLike(Map<String, dynamic> data) {
  final status = (data['status'] ?? '').toString().trim().toLowerCase();
  if (status == 'archived' ||
      status == 'archivé' ||
      status == 'deleted' ||
      status == 'removed' ||
      status == 'sold') {
    return true;
  }

  return data['archivedAt'] != null || data['deletedAt'] != null;
}

bool _isOfferJobDoneOverlayVisible(Map<String, dynamic> data) {
  final visibleUntil = _offerJobDoneVisibleUntil(data);
  if (visibleUntil == null || !visibleUntil.isAfter(DateTime.now())) {
    return false;
  }

  final visibleFlag = data['jobDoneOverlayVisible'];
  if (visibleFlag is bool && !visibleFlag) {
    return false;
  }

  final reason =
      (data['deletedReason'] ?? data['archiveReason'] ?? '').toString().trim();
  return visibleFlag == true || _isOfferJobDoneDeletionReason(reason);
}

/// Collection principale des annonces marketplace (nouvelle architecture).
const String _kListingsCollection = 'listings';

bool _appCheckActivationAttempted = false;
bool _appCheckActivationSucceeded = false;
Object? _appCheckActivationError;
StackTrace? _appCheckActivationStackTrace;

const String _kAppCheckWebRecaptchaSiteKey = String.fromEnvironment(
  'APPCHECK_RECAPTCHA_SITE_KEY',
  defaultValue: '6LehQ0IsAAAAAIVtHXyi-obNQFOZEnBKXAW_P2de',
);

/// Collection legacy des annonces (ancienne architecture, en lecture seule).
const String _kOffersCollection = 'offers';

Filter _publicListingsFilter() {
  return Filter.or(
    // Format marketplace nominal
    Filter.and(
      Filter('status', isEqualTo: 'active'),
      Filter('visibility', isEqualTo: 'public'),
    ),
    // Variantes historiques / legacy publication
    Filter('status', isEqualTo: 'published'),
    Filter('isPublished', isEqualTo: true),
    Filter('isActive', isEqualTo: true),
    Filter('visibility.isPublic', isEqualTo: true),
  );
}

Filter _publicOffersFilter() {
  return Filter.or(
    Filter('visibility.isPublic', isEqualTo: true),
    Filter('status', isEqualTo: 'active'),
    Filter('status', isEqualTo: 'published'),
    Filter('isActive', isEqualTo: true),
    Filter('isPublished', isEqualTo: true),
  );
}

List<QueryDocumentSnapshot<Map<String, dynamic>>> _mergeOfferDocsById(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> primaryDocs,
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> secondaryDocs,
) {
  final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

  for (final doc in primaryDocs) {
    byId[doc.id] = doc;
  }
  for (final doc in secondaryDocs) {
    byId.putIfAbsent(doc.id, () => doc);
  }

  return byId.values.toList(growable: false);
}

bool _isPublishedOfferData(Map<String, dynamic> data) {
  if (_isOfferArchivedLike(data)) return false;

  final status = (data['status'] ?? '').toString().trim().toLowerCase();
  final visibility = data['visibility'];

  // Format listings (marketplace) : status='active' + visibility='public'
  if (status == 'active' && visibility is String && visibility == 'public') {
    return true;
  }

  // Format legacy offers
  final isPublished = data['isPublished'];
  if (isPublished is bool && isPublished) return true;

  if (status == 'published' || status == 'active') return true;

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

enum _PublishAiTraceLevel { info, success, warning, error }

class _PublishAiTraceEntry {
  const _PublishAiTraceEntry({
    required this.timestamp,
    required this.level,
    required this.stage,
    required this.detail,
  });

  final DateTime timestamp;
  final _PublishAiTraceLevel level;
  final String stage;
  final String detail;
}

const double kMarketplaceOutlineWidth = 2.0;

const String kAppBuildSha =
    String.fromEnvironment('APP_BUILD_SHA', defaultValue: 'local');
const String kAppVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
const String kAppBuildNumber =
    String.fromEnvironment('APP_BUILD_NUMBER', defaultValue: '1');
const String kAppRepository =
    String.fromEnvironment('APP_REPOSITORY', defaultValue: '');
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
      : isMarketplaceValue.toString().trim().toLowerCase() == 'true' ||
          categoryId.isNotEmpty ||
          cityId.isNotEmpty ||
          listingStatus.isNotEmpty ||
          visibility.isNotEmpty;

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

    if (kIsWeb) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      await Firebase.initializeApp();
    }

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
    _appCheckActivationAttempted = true;
    _appCheckActivationSucceeded = false;
    _appCheckActivationError = null;
    _appCheckActivationStackTrace = null;
    try {
      if (kIsWeb) {
        debugPrint(
            '[APPCHECK] siteKey=${_kAppCheckWebRecaptchaSiteKey.substring(0, 10)}...');
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider(_kAppCheckWebRecaptchaSiteKey),
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
      _appCheckActivationSucceeded = true;
    } catch (e, st) {
      _appCheckActivationError = e;
      _appCheckActivationStackTrace = st;
      debugPrint('[AppCheck] activation failed: $e');
    }

    // 🔒 Auth minimale requise pour les Cloud Functions (même en anonyme)
    // Supprimé : on n'impose plus de connexion automatique au démarrage
    // L'auth anonyme sera gérée au besoin par chaque page qui en a besoin
    try {
      final auth = FirebaseAuth.instance;
      if (kDebugMode) {
        DebugAuth.installAuthStateLogs();
        unawaited(DebugAuth.debugRedirectResultAtStartup());
      }
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

    // Initialisation des notifications push sur toutes les plateformes.
    // Sur Web, l'enregistrement du token dépend de FCM_WEB_VAPID_KEY.
    try {
      await NotificationService().initialize(
        navigatorKey: appNavigatorKey,
      );
    } catch (e) {
      debugPrint('[Notifications] init error: $e');
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

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
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
      onGenerateRoute: _onGenerateRoute,
      routes: {
        '/publish': (_) => const PublishOfferPage(),
        '/messages': (_) => const MessagesPageV2(),
        '/messages-2': (_) => const MessagesPageV2(),
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

    // Sur Web, vérifier d'abord le redirect Google Sign-In
    if (kIsWeb) {
      _checkGoogleRedirectAndNavigate();
    } else {
      _scheduleNavigation(const Duration(milliseconds: 3500));
    }
  }

  void _scheduleNavigation(Duration duration) {
    _navTimer?.cancel();
    _navTimer = Timer(duration, () {
      _navigateTo(const HomePage());
    });
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
        _scheduleNavigation(const Duration(milliseconds: 1500));
      } else {
        debugPrint('ℹ️ [SPLASH] No redirect result, normal app start');
        // Pas de redirect, navigation normale après splash
        _scheduleNavigation(const Duration(milliseconds: 3500));
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [SPLASH] FirebaseAuthException during redirect check');
      debugPrint('❌ [SPLASH] Code: ${e.code}');
      debugPrint('❌ [SPLASH] Message: ${e.message}');
      // Erreur d'auth, mais on continue quand même vers HomePage
      _scheduleNavigation(const Duration(milliseconds: 3500));
    } catch (e) {
      debugPrint('❌ [SPLASH] Unexpected error: $e');
      // Erreur inattendue, navigation normale
      _scheduleNavigation(const Duration(milliseconds: 3500));
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

/// HOME ////////////////////////////////////////////////////////////////////

class HomePage extends StatefulWidget {
  final int initialIndex;
  final String? initialConsultCategoryFilter;
  final String? initialConsultSearchQuery;
  final String? initialMessagesConversationId;
  final String? initialMessagesDraftText;

  const HomePage({
    super.key,
    this.initialIndex = 0,
    this.initialConsultCategoryFilter,
    this.initialConsultSearchQuery,
    this.initialMessagesConversationId,
    this.initialMessagesDraftText,
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
  static const double _homeSlideTitleFontSize = 30;

  bool _isSeeding = false;

  /// Contrôle l'affichage des suggestions de recherche
  bool _showSearchSuggestions = true;

  /// Chargement figé à l'ouverture de la home pour stabiliser la section.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _latestOffers = const [];
  bool _isLatestOffersLoading = true;
  Object? _latestOffersError;

  /// Slogans animés (fade + slide) pour le 1er slide
  final List<String> _firstSlideSlogans = const [
    "Trouvez immédiatement quelqu’un pour faire le job.",
    "Une personne près de chez vous.",
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
      subtitle: "Trouvez une personne près de chez vous en quelques secondes.",
      badge: "",
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

    _loadLatestOffersOnOpen();

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
    _dynamicKeywordsSubscription = _recentOffersQuery().snapshots().listen(
      (snapshot) {
        final words = <String>{};
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (!_isPublishedOfferData(data)) continue;
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

    if (widget.initialConsultCategoryFilter !=
            oldWidget.initialConsultCategoryFilter ||
        widget.initialConsultSearchQuery !=
            oldWidget.initialConsultSearchQuery) {
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

  Query<Map<String, dynamic>> _recentOffersQuery({int limit = 200}) {
    return FirebaseFirestore.instance
        .collection(_kListingsCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit);
  }

  Query<Map<String, dynamic>> _legacyRecentOffersQuery({int limit = 200}) {
    return FirebaseFirestore.instance
        .collection(_kOffersCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadLatestOffers() async {
    // Query primaire : offres avec status='published', triées par date.
    // Fonctionne pour les utilisateurs connectés ET non connectés grâce aux
    // Firestore rules qui autorisent la lecture de toute offre publique.
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_kListingsCollection)
          .where(_publicListingsFilter())
          .orderBy('createdAt', descending: true)
          .limit(8)
          .get();

      if (snapshot.docs.length >= 8) return snapshot.docs;

      // Compléter avec les annonces legacy (collection offers)
      final fallback = await FirebaseFirestore.instance
          .collection(_kOffersCollection)
          .where(_publicOffersFilter())
          .orderBy('createdAt', descending: true)
          .limit(16)
          .get();

      final seen = snapshot.docs.map((d) => d.id).toSet();
      final merged = [...snapshot.docs];
      for (final doc in fallback.docs) {
        if (seen.contains(doc.id)) continue;
        merged.add(doc);
        if (merged.length >= 8) break;
      }
      return merged;
    } catch (error) {
      // Si l'index n'est pas encore prêt, fallback sur la query générique
      // avec filtre côté client.
      debugPrint('[LatestOffers] Primary query failed, falling back: $error');
      final results = await Future.wait([
        _recentOffersQuery().get(),
        _legacyRecentOffersQuery().get(),
      ]);
      final merged = _mergeOfferDocsById(results[0].docs, results[1].docs);
      merged.sort((a, b) {
        final aTs = a.data()['createdAt'];
        final bTs = b.data()['createdAt'];
        final aMs = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
        final bMs = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
        return bMs.compareTo(aMs);
      });
      return merged
          .where((doc) => _isPublishedOfferData(doc.data()))
          .take(8)
          .toList(growable: false);
    }
  }

  Future<void> _loadLatestOffersOnOpen() async {
    try {
      final docs = await _loadLatestOffers();
      if (!mounted) return;
      setState(() {
        _latestOffers = docs;
        _isLatestOffersLoading = false;
        _latestOffersError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _latestOffers = const [];
        _isLatestOffersLoading = false;
        _latestOffersError = error;
      });
    }
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
        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  for (var index = 0;
                      index < compactCategories.length;
                      index++) ...[
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
            ),
            const SizedBox(height: 6),
            IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0x401A73E8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: const Color(0xAA1A73E8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0x401A73E8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLatestOffersSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
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
          const SizedBox(height: 4),
          if (_isLatestOffersLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
                ),
              ),
            )
          else if (_latestOffersError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _friendlyFirestoreErrorMessage(_latestOffersError!),
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else if (_latestOffers.isEmpty)
            const Text(
              'Aucune offre publiée pour le moment.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Builder(
              builder: (context) {
                PrestoMonitoring.I.trackOtherStream(
                  key: 'home.latestOffers',
                  docsCount: _latestOffers.length,
                );
                return RepaintBoundary(
                  child: _AutoScrollingOffersCarousel(
                    offers: _latestOffers,
                    onOfferTap: (doc) {
                      final data = doc.data();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OfferDetailsPage(
                            offer: _buildOfferDetailsOffer(
                              offerId: doc.id,
                              data: data,
                            ),
                            currentUserId:
                                FirebaseAuth.instance.currentUser?.uid ?? '',
                            onBackToConsult: () {
                              if (!mounted) return;
                              setState(() {
                                _consultCategoryFilter = null;
                                _consultSearchQuery = null;
                                _selectedIndex = 1;
                              });
                              Navigator.of(context).pop();
                            },
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
                borderSide: const BorderSide(
                  color: kPrestoBlue,
                  width: kMarketplaceOutlineWidth,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: kPrestoBlue,
                  width: kMarketplaceOutlineWidth,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: kPrestoBlue,
                  width: kMarketplaceOutlineWidth,
                ),
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
    final overlayTheme = context.prestoOverlayTheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: overlayTheme.surfaceColor,
        surfaceTintColor: overlayTheme.surfaceTintColor,
        shape: overlayTheme.dialogShape,
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
                  final notificationType =
                      (data['type'] as String? ?? '').trim();
                  final offerId = data['offerId'] as String?;
                  final conversationId = data['conversationId'] as String?;
                  final routeName = (data['routeName'] as String? ?? '').trim();

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

                      if (!context.mounted) return;
                      Navigator.of(context).pop();

                      final normalizedConversationId =
                          (conversationId ?? '').trim();
                      final shouldOpenMessages =
                          normalizedConversationId.isNotEmpty &&
                              (notificationType == 'new_message' ||
                                  routeName.isEmpty ||
                                  routeName.startsWith('/messages/'));

                      if (shouldOpenMessages) {
                        Navigator.of(context).pushNamed(
                          buildMessagesRoute(
                            conversationId: normalizedConversationId,
                          ),
                        );
                        return;
                      }

                      if (routeName.isNotEmpty) {
                        Navigator.of(context).pushNamed(routeName);
                        return;
                      }

                      if (normalizedConversationId.isNotEmpty) {
                        Navigator.of(context).pushNamed(
                          buildMessagesRoute(
                            conversationId: normalizedConversationId,
                          ),
                        );
                        return;
                      }

                      if (offerId != null) {
                        Navigator.of(context).pushNamed('/offers/$offerId');
                        return;
                      }

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const HomePage(initialIndex: 1),
                        ),
                      );
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
    final currentUser = FirebaseAuth.instance.currentUser;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: prestoOverlayStyleFor(kPrestoBlue),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          extendBody: false,
          backgroundColor: Colors.white,
          body: IndexedStack(
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
              MessagesPageV2(
                initialConversationId: widget.initialMessagesConversationId,
                initialDraftText: widget.initialMessagesDraftText,
              ),
              const AccountPage(),
            ],
          ),
          bottomNavigationBar: MediaQuery.removeViewInsets(
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
              child: SafeArea(
                top: false,
                maintainBottomViewPadding: false,
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
                      child: currentUser == null
                          ? HomeBottomNavItem(
                              icon: Icons.chat_bubble_outline,
                              label: "Messages",
                              selected: _selectedIndex == 3,
                              onTap: () => _onBottomTap(3),
                            )
                          : _UnreadInboxBell(
                              userId: currentUser.uid,
                              monitoringKeyPrefix: 'bottomBar.messages',
                              countType: InboxCountType.unreadMessages,
                              useVisibleUnreadMessages: true,
                              builder: (context, badgeCount) =>
                                  HomeBottomNavItem(
                                icon: Icons.chat_bubble_outline,
                                label: "Messages",
                                badgeCount: badgeCount,
                                selected: _selectedIndex == 3,
                                onTap: () => _onBottomTap(3),
                              ),
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
      ),
    );
  }

  Widget _buildHomeContent() {
    const double bottomPadding = 16;

    return SafeArea(
      bottom: false,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0x331A73E8),
                        Color(0x141A73E8),
                        Color(0x0DFFFFFF),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0x331A73E8),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onLongPress: _seedSampleOffers,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 46,
                                  height: 40,
                                  child: Image.asset(
                                    'assets/images/logowebp.webp',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                Transform.translate(
                                  offset: const Offset(-4, 0),
                                  child: const Text(
                                    "iliprestō",
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: kPrestoOrange,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildSmartSearchBar(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // SLIDER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: SizedBox(
                  height: 220,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0x331A73E8),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.16),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: const Color(0x331A73E8),
                          blurRadius: 26,
                          spreadRadius: 1,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
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
                                        // ✅ Phrase principale en très gros sur toute la largeur
                                        Text(
                                          bigText,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w900,
                                            height: 1.18,
                                            shadows: [
                                              Shadow(
                                                color: Color(0x4D000000),
                                                blurRadius: 6,
                                                offset: Offset(0, 1.5),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          "Une personne près de chez vous, en quelques minutes.",
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            height: 1.3,
                                            shadows: [
                                              Shadow(
                                                color: Color(0x40000000),
                                                blurRadius: 4,
                                                offset: Offset(0, 1),
                                              ),
                                            ],
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
                                                shadows: [
                                                  Shadow(
                                                    color: Color(0x4D000000),
                                                    blurRadius: 6,
                                                    offset: Offset(0, 1.5),
                                                  ),
                                                ],
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
                                                shadows: [
                                                  Shadow(
                                                    color: Color(0x40000000),
                                                    blurRadius: 4,
                                                    offset: Offset(0, 1),
                                                  ),
                                                ],
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
              ),
              const SizedBox(height: 6),

              _buildHomeCategoriesSection(),

              const SizedBox(height: 10),

              _buildLatestOffersSection(),

              const SizedBox(height: 20),
            ],
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
                width: kMarketplaceOutlineWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: const Color(0x2B1A73E8),
                  blurRadius: 18,
                  spreadRadius: 0.5,
                  offset: const Offset(0, 6),
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
                color: Color(0xFF6B7280),
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

class _PulseWaveLayer extends StatefulWidget {
  final double width;
  final int delay;

  const _PulseWaveLayer({
    required this.width,
    required this.delay,
  });

  @override
  State<_PulseWaveLayer> createState() => _PulseWaveLayerState();
}

class _PulseWaveLayerState extends State<_PulseWaveLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );
    _scale = Tween<double>(begin: 0.92, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _opacity = Tween<double>(begin: 0.22, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat();
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
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Container(
                width: widget.width,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: const Color(0xFFE53935),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FieldPendingDots extends StatelessWidget {
  const _FieldPendingDots();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FieldPendingDot(delay: 0),
            SizedBox(width: 4),
            _FieldPendingDot(delay: 180),
            SizedBox(width: 4),
            _FieldPendingDot(delay: 360),
          ],
        ),
      ),
    );
  }
}

class _FieldPendingDot extends StatefulWidget {
  final int delay;

  const _FieldPendingDot({required this.delay});

  @override
  State<_FieldPendingDot> createState() => _FieldPendingDotState();
}

class _FieldPendingDotState extends State<_FieldPendingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _opacity = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
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
      opacity: _opacity,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: kPrestoBlue,
          shape: BoxShape.circle,
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

class _UnreadInboxBell extends StatelessWidget {
  final String userId;
  final String? monitoringKeyPrefix;
  final InboxCountType countType;
  final bool useVisibleUnreadMessages;
  final Widget Function(BuildContext context, int badgeCount) builder;

  const _UnreadInboxBell({
    required this.userId,
    required this.builder,
    this.monitoringKeyPrefix,
    this.countType = InboxCountType.totalUnread,
    this.useVisibleUnreadMessages = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: useVisibleUnreadMessages
          ? streamVisibleUnreadMessageCount(userId: userId)
          : streamInboxCount(userId: userId, type: countType),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          if (error != null) {
            PrestoMonitoring.I.trackError(
              '${monitoringKeyPrefix ?? 'messages'}.badge',
              error,
            );
          }
          return builder(context, 0);
        }

        final badgeCount = snapshot.data ?? 0;

        if (monitoringKeyPrefix != null) {
          PrestoMonitoring.I.trackOtherStream(
            key: '${monitoringKeyPrefix!}.badge',
            docsCount: badgeCount,
          );
        }

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
  static const Color _offersBg = Colors.white;
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
    return resolveOfferCategoryId(s) ?? _slugId(s);
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
  final Set<String> _manualAutoApplyCriteria = <String>{};
  List<CityRecord> _filterCitySuggestions = [];
  int _filterCityHighlightedIndex = -1;
  Timer? _filterCityDebounce;

  final ScrollController _scrollController = ScrollController();

  bool _showFilters = false; // Panneau de filtres rétracté au départ
  int _lastResultCount = 0;
  int? _resolvedVisibleOffersCount;
  int _visibleOffersCountRequestId = 0;
  String _headerTitle = 'Je consulte les offres';
  static const int _autoApplyFiltersThreshold = 3;

  late final Map<String, String> _deptToRegion = _buildDeptToRegion();

  // ✅ Cache de normalisation pour améliorer la performance de recherche
  final Map<String, String> _normalizedTextCache = {};

  // ✅ Cache des résultats Firestore pour éviter les re-queries
  Map<String, List<DocumentSnapshot<Map<String, dynamic>>>>? _queryResultsCache;
  String? _lastCachedQuerySignature;
  Timer? _cacheInvalidationTimer;
  Timer? _jobDoneOverlayTimer;
  DateTime? _nextJobDoneOverlayRefreshAt;

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
              Navigator.of(context).pushNamed(buildMessagesRoute());
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        precacheImage(const AssetImage('assets/images/jobfait.webp'), context);
      }
    });

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshVisibleOffersCount();
    });

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
    _jobDoneOverlayTimer?.cancel();
    super.dispose();
  }

  Query<Map<String, dynamic>> _buildOffersQuery() {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection(_kListingsCollection).where(
              _publicListingsFilter(),
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

  Query<Map<String, dynamic>> _buildLegacyOffersQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection(_kOffersCollection)
        .where(_publicOffersFilter());

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

    final hasClientFilters = categoryId != null ||
        cityId != null ||
        cityCategoryKey != null ||
        hasSubcategory ||
        hasDept ||
        wantsBudgetRange ||
        (_activeSearchQuery?.trim().isNotEmpty ?? false);

    query = query.limit(hasClientFilters ? _maxLimit : _pageLimit);
    return query;
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _watchCombinedOffers() {
    return Stream.multi((controller) {
      QuerySnapshot<Map<String, dynamic>>? listingsSnapshot;
      QuerySnapshot<Map<String, dynamic>>? legacyOffersSnapshot;

      void emitMerged() {
        controller.add(
          _mergeOfferDocsById(
            listingsSnapshot?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[],
            legacyOffersSnapshot?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[],
          ),
        );
      }

      final listingsSub = _buildOffersQuery().snapshots().listen(
        (snapshot) {
          listingsSnapshot = snapshot;
          emitMerged();
        },
        onError: (error, stackTrace) {
          debugPrint('[OFFERS][LISTINGS] snapshot error: $error');
          if (legacyOffersSnapshot == null) {
            controller.addError(error, stackTrace);
            return;
          }
          emitMerged();
        },
      );

      final offersSub = _buildLegacyOffersQuery().snapshots().listen(
        (snapshot) {
          legacyOffersSnapshot = snapshot;
          emitMerged();
        },
        onError: (error, stackTrace) {
          debugPrint('[OFFERS][LEGACY] snapshot error: $error');
          if (listingsSnapshot == null) {
            controller.addError(error, stackTrace);
            return;
          }
          emitMerged();
        },
      );

      controller.onCancel = () async {
        await listingsSub.cancel();
        await offersSub.cancel();
      };
    });
  }

  bool _offerIsActive(Map<String, dynamic> data) {
    return _isOfferJobDoneOverlayVisible(data) || _isPublishedOfferData(data);
  }

  void _scheduleJobDoneOverlayRefresh(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    DateTime? earliestExpiry;

    for (final doc in docs) {
      final expiry = _offerJobDoneVisibleUntil(doc.data());
      if (expiry == null || !expiry.isAfter(DateTime.now())) {
        continue;
      }
      if (!_isOfferJobDoneOverlayVisible(doc.data())) {
        continue;
      }
      if (earliestExpiry == null || expiry.isBefore(earliestExpiry)) {
        earliestExpiry = expiry;
      }
    }

    if (earliestExpiry == null) {
      _jobDoneOverlayTimer?.cancel();
      _jobDoneOverlayTimer = null;
      _nextJobDoneOverlayRefreshAt = null;
      return;
    }

    if (_nextJobDoneOverlayRefreshAt == earliestExpiry &&
        _jobDoneOverlayTimer != null) {
      return;
    }

    _jobDoneOverlayTimer?.cancel();
    _nextJobDoneOverlayRefreshAt = earliestExpiry;

    final delay = earliestExpiry.difference(DateTime.now());
    _jobDoneOverlayTimer = Timer(
      delay.isNegative ? Duration.zero : delay + const Duration(seconds: 1),
      () {
        if (!mounted) return;
        setState(() {
          _nextJobDoneOverlayRefreshAt = null;
        });
        _refreshVisibleOffersCount();
      },
    );
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

  Future<void> _refreshVisibleOffersCount() async {
    final int requestId = ++_visibleOffersCountRequestId;

    if (mounted) {
      setState(() {
        _resolvedVisibleOffersCount = null;
      });
    }

    try {
      int visibleCount;

      if (!_hasActiveClientFilters) {
        // ⚡ Aucun filtre client actif → count aggregation (0 lecture doc)
        final countSnaps = await Future.wait([
          FirebaseFirestore.instance
              .collection(_kListingsCollection)
              .where(_publicListingsFilter())
              .count()
              .get(),
          FirebaseFirestore.instance
              .collection(_kOffersCollection)
              .where(_publicOffersFilter())
              .count()
              .get(),
        ]);
        visibleCount = (countSnaps[0].count ?? 0) + (countSnaps[1].count ?? 0);
      } else {
        // Filtres actifs → on doit charger les docs pour filtrer côté client
        // Limiter à 500 docs maximum pour protéger le quota
        final snapshots = await Future.wait([
          _buildOffersQuery().limit(500).get(),
          _buildLegacyOffersQuery().limit(500).get(),
        ]);
        final merged =
            _mergeOfferDocsById(snapshots[0].docs, snapshots[1].docs);
        visibleCount =
            merged.where((doc) => _matchesOfferFilters(doc.data())).length;
      }

      if (!mounted || requestId != _visibleOffersCountRequestId) {
        return;
      }

      setState(() {
        _resolvedVisibleOffersCount = visibleCount;
      });
    } catch (e) {
      if (!mounted || requestId != _visibleOffersCountRequestId) {
        return;
      }
      setState(() {
        _resolvedVisibleOffersCount = _lastResultCount;
      });
      debugPrint('[ConsultOffers] Erreur calcul compteur total: $e');
    }
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

    _refreshVisibleOffersCount();
  }

  void _trackManualFilterCriterion(
    String key, {
    required bool isActive,
  }) {
    if (isActive) {
      _manualAutoApplyCriteria.add(key);
    } else {
      _manualAutoApplyCriteria.remove(key);
    }
  }

  void _pruneManualAutoApplyCriteria() {
    if ((_filterCategory ?? '').trim().isEmpty) {
      _manualAutoApplyCriteria.remove('category');
    }
    if ((_filterRegionCode ?? '').trim().isEmpty) {
      _manualAutoApplyCriteria.remove('region');
    }
    if ((_filterDepartmentCode ?? '').trim().isEmpty) {
      _manualAutoApplyCriteria.remove('department');
    }
    if ((_filterCityName ?? '').trim().isEmpty) {
      _manualAutoApplyCriteria.remove('city');
    }
  }

  void _onAnyFilterChanged() {
    if (_manualAutoApplyCriteria.length < _autoApplyFiltersThreshold) {
      return;
    }

    // ✅ Auto-apply avec debounce à partir de 3 critères sélectionnés
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
      _manualAutoApplyCriteria.clear();
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

    _refreshVisibleOffersCount();

    // 4) ✅ Pas de scroll forcé: on conserve la position courante
  }

  void _mutateActiveFilters(VoidCallback mutation) {
    setState(() {
      mutation();
      _pruneManualAutoApplyCriteria();
      _budgetRangeWarning = null;
      _lastDoc = null;
      _pageLimit = _initialLimit;
      _lastPaginationRequestAt = null;
      _headerTitle = _resolveConsultOffersTitle();
    });

    _refreshVisibleOffersCount();
  }

  Widget _buildRemovableFilterChip({
    required String label,
    required VoidCallback onDeleted,
  }) {
    return InputChip(
      label: Text(label),
      onDeleted: onDeleted,
      deleteIcon: const Icon(
        Icons.close_rounded,
        size: 18,
      ),
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF474D70),
      ),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE4D8DA)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  List<Widget> _buildActiveFilterChipItems() {
    final chips = <Widget>[];

    final effectiveCategory = (_filterCategory?.trim().isNotEmpty ?? false)
        ? _filterCategory!.trim()
        : (((_selectedCategory?.trim().isNotEmpty ?? false) &&
                _selectedCategory != 'Toutes catégories')
            ? _selectedCategory!.trim()
            : null);
    if (effectiveCategory != null) {
      chips.add(
        _buildRemovableFilterChip(
          label: 'Catégorie: $effectiveCategory',
          onDeleted: () {
            _mutateActiveFilters(() {
              _filterCategory = null;
              _selectedCategory = 'Toutes catégories';
            });
          },
        ),
      );
    }

    final effectiveRegionCode = (_filterRegionCode?.trim().isNotEmpty ?? false)
        ? _filterRegionCode!.trim()
        : ((_selectedRegionCode?.trim().isNotEmpty ?? false)
            ? _selectedRegionCode!.trim()
            : null);
    if (effectiveRegionCode != null) {
      final regionLabel = kRegions[effectiveRegionCode] ?? effectiveRegionCode;
      chips.add(
        _buildRemovableFilterChip(
          label: 'Région: $regionLabel',
          onDeleted: () {
            _mutateActiveFilters(() {
              _filterRegionCode = null;
              _selectedRegionCode = null;
            });
          },
        ),
      );
    }

    if (_filterDepartmentCode?.trim().isNotEmpty ?? false) {
      final departmentCode = _filterDepartmentCode!.trim();
      final departmentLabel = kDepartments[departmentCode] ?? departmentCode;
      chips.add(
        _buildRemovableFilterChip(
          label: 'Département: $departmentLabel',
          onDeleted: () {
            _mutateActiveFilters(() {
              _filterDepartmentCode = null;
            });
          },
        ),
      );
    }

    if (_filterCityName?.trim().isNotEmpty ?? false) {
      final cityName = _filterCityName!.trim();
      chips.add(
        _buildRemovableFilterChip(
          label: 'Ville: $cityName',
          onDeleted: () {
            _mutateActiveFilters(() {
              _filterCityController.clear();
              _filterPostalCodeController.clear();
              _locationController.clear();
              _postalCodeController.clear();
              _filterCityName = null;
              _filterCitySuggestions = [];
              _filterCityHighlightedIndex = -1;
            });
          },
        ),
      );
    }

    if (_selectedSubCategory?.trim().isNotEmpty ?? false) {
      final subCategory = _selectedSubCategory!.trim();
      chips.add(
        _buildRemovableFilterChip(
          label: 'Sous-catégorie: $subCategory',
          onDeleted: () {
            _mutateActiveFilters(() {
              _selectedSubCategory = null;
            });
          },
        ),
      );
    }

    if (_activeSearchQuery?.trim().isNotEmpty ?? false) {
      final searchQuery = _activeSearchQuery!.trim();
      chips.add(
        _buildRemovableFilterChip(
          label: 'Recherche: $searchQuery',
          onDeleted: () {
            _mutateActiveFilters(() {
              _activeSearchQuery = null;
              _keywordCtrl.clear();
            });
          },
        ),
      );
    }

    final minBudget = _parseBudgetBound(_budgetMinCtrl.text);
    final maxBudget = _parseBudgetBound(_budgetMaxCtrl.text);
    if (_advancedFilters &&
        _budgetRangeWarning == null &&
        (minBudget != null || maxBudget != null)) {
      final minLabel = _budgetMinCtrl.text.trim();
      final maxLabel = _budgetMaxCtrl.text.trim();
      final budgetLabel = minBudget != null && maxBudget != null
          ? 'Budget: $minLabel - $maxLabel €'
          : minBudget != null
              ? 'Budget: dès $minLabel €'
              : 'Budget: jusqu’à $maxLabel €';
      chips.add(
        _buildRemovableFilterChip(
          label: budgetLabel,
          onDeleted: () {
            _mutateActiveFilters(() {
              _budgetMinCtrl.clear();
              _budgetMaxCtrl.clear();
            });
          },
        ),
      );
    }

    return chips;
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
    final activeFilterChips = _buildActiveFilterChipItems();
    final activeFiltersCount = activeFilterChips.length;

    final int displayedResultCount =
        _resolvedVisibleOffersCount ?? _lastResultCount;
    final String offersLabel = _resolvedVisibleOffersCount == null
        ? 'Chargement du total...'
        : '$displayedResultCount annonce${displayedResultCount > 1 ? 's' : ''}';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
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
                ],
              );
            },
          ),
          if (activeFiltersCount > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...activeFilterChips,
                OutlinedButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Réinitialiser'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _offersOrange,
                    side: const BorderSide(color: Color(0xFFD9C5C8)),
                    backgroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTitle = _headerTitle;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: prestoOverlayStyleFor(kPrestoBlue),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: _offersBg,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: kToolbarHeight,
                  color: kPrestoOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      baseTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: kPrestoAppBarTitleStyle.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // ✅ Tuiles cliquables pour filtres actifs
                _buildActiveFilterChips(),
                _buildFilterPanel(),
                Expanded(
                  child: StreamBuilder<
                      List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                    stream: _watchCombinedOffers().map((docs) {
                      PrestoMonitoring.I.trackOffersSnapshot(docs.length);
                      return docs;
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

                      final rawDocs = snapshot.data ?? const [];
                      _lastSnapshotRawCount = rawDocs.length;

                      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                          rawDocs
                              .where((d) => _matchesOfferFilters(d.data()))
                              .toList();

                      _scheduleJobDoneOverlayRefresh(rawDocs);

                      docs.sort((a, b) {
                        final aTs = a.data()['createdAt'];
                        final bTs = b.data()['createdAt'];
                        final aMs =
                            aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
                        final bMs =
                            bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
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
                                final showJobDoneOverlay =
                                    _isOfferJobDoneOverlayVisible(data);
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
                                      onTap: showJobDoneOverlay
                                          ? null
                                          : () {
                                              _logOfferClicked(offerId, title);
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      OfferDetailsPage(
                                                    offer:
                                                        _buildOfferDetailsOffer(
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
                                        isUrgent:
                                            isUrgent && !showJobDoneOverlay,
                                        icon: _categoryIcon(category),
                                        showJobDoneOverlay: showJobDoneOverlay,
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
            _trackManualFilterCriterion(
              'region',
              isActive: (code ?? '').trim().isNotEmpty,
            );
            _trackManualFilterCriterion('department', isActive: false);
            _trackManualFilterCriterion('city', isActive: false);

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
            _trackManualFilterCriterion(
              'department',
              isActive: (code ?? '').trim().isNotEmpty,
            );
            _trackManualFilterCriterion('city', isActive: false);

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
          _trackManualFilterCriterion('city', isActive: true);

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
                        _trackManualFilterCriterion('city', isActive: false);
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
          _trackManualFilterCriterion(
            'category',
            isActive: (value ?? '').trim().isNotEmpty,
          );
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
      // Essayer d'abord dans listings (marketplace), puis fallback offers (legacy)
      final listingsRef = FirebaseFirestore.instance
          .collection(_kListingsCollection)
          .doc(offerId);
      final listingsSnap = await listingsRef.get();
      final targetRef = listingsSnap.exists
          ? listingsRef
          : FirebaseFirestore.instance
              .collection(_kOffersCollection)
              .doc(offerId);
      await targetRef.update({
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
      final listingsRef = FirebaseFirestore.instance
          .collection(_kListingsCollection)
          .doc(offerId);
      final listingsSnap = await listingsRef.get();
      if (listingsSnap.exists) {
        final callable = prestoFirebaseFunctions.httpsCallable(
          'deleteListing',
          options: HttpsCallableOptions(
            timeout: const Duration(seconds: 30),
          ),
        );
        await callable.call<dynamic>({'listingId': offerId});
      } else {
        await FirebaseFirestore.instance
            .collection(_kOffersCollection)
            .doc(offerId)
            .delete();
      }
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
  final bool showJobDoneOverlay;

  const _OfferBrowseTileData({
    required this.title,
    required this.subtitle,
    required this.publishedText,
    required this.price,
    required this.missionDelayLabel,
    required this.isUrgent,
    required this.icon,
    required this.showJobDoneOverlay,
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
      duration: const Duration(milliseconds: 920),
    );
    _pulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 42,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.18).chain(
          CurveTween(curve: Curves.easeInCubic),
        ),
        weight: 26,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.18, end: 0.78).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 32,
      ),
    ]).animate(_controller);
    _syncUrgentAnimation();
  }

  @override
  void didUpdateWidget(covariant _OfferBrowseTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.isUrgent != widget.data.isUrgent ||
        oldWidget.data.showJobDoneOverlay != widget.data.showJobDoneOverlay) {
      _syncUrgentAnimation();
    }
  }

  void _syncUrgentAnimation() {
    if (widget.data.isUrgent && !widget.data.showJobDoneOverlay) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      return;
    }

    _controller.stop();
    _controller.value = 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.data.isUrgent || widget.data.showJobDoneOverlay) {
      return _buildTileFrame(pulse: 0);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _buildTileFrame(pulse: _pulse.value),
    );
  }

  Widget _buildTileFrame({required double pulse}) {
    const outerRadius = 24.0;
    const innerUrgentInset = 3.0;
    const innerUrgentWidth = 4.0;
    const cornerAccentSize = 54.0;

    final showUrgentContour = widget.data.isUrgent;
    final blink = pulse.clamp(0.0, 1.0);
    final urgentBorderColor = const Color(0xFF1A73E8).withValues(
      alpha: 0.26 + (0.58 * blink),
    );

    return RepaintBoundary(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: IgnorePointer(
              child: Container(
                width: cornerAccentSize,
                height: cornerAccentSize,
                decoration: const BoxDecoration(
                  color: kPrestoBlue,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                  ),
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(outerRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(outerRadius),
              onTap: widget.onTap,
              child: Ink(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(outerRadius),
                  border: Border.all(
                    color: _ConsultOffersPageState._offersCardBorder,
                    width: kMarketplaceOutlineWidth,
                  ),
                  boxShadow: [
                    const BoxShadow(
                      color: Color(0x0C000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    if (showUrgentContour)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Padding(
                            padding: const EdgeInsets.all(innerUrgentInset),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  outerRadius - innerUrgentInset,
                                ),
                                border: Border.all(
                                  color: urgentBorderColor,
                                  width: innerUrgentWidth,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Padding(
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
                                constraints:
                                    const BoxConstraints(maxWidth: 148),
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
                                        color: _ConsultOffersPageState
                                            ._offersOrange,
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
                    if (widget.data.showJobDoneOverlay)
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.78),
                                borderRadius:
                                    BorderRadius.circular(outerRadius),
                              ),
                              alignment: Alignment.center,
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Image.asset(
                                  'assets/images/jobfait.webp',
                                  height: 132,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality
                                      .none, // Maximum performance sur le web
                                ),
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
        ],
      ),
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.65),
          width: kMarketplaceOutlineWidth,
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
    // Charger depuis la collection listings (marketplace) et offers (legacy)
    final listingsCol =
        FirebaseFirestore.instance.collection(_kListingsCollection);
    final offersCol = FirebaseFirestore.instance.collection(_kOffersCollection);

    final results = await Future.wait([
      listingsCol
          .where('ownerId', isEqualTo: widget.userId)
          .where(_publicListingsFilter())
          .get(),
      offersCol
          .where('uid', isEqualTo: widget.userId)
          .where(_publicOffersFilter())
          .get(),
      offersCol
          .where('userId', isEqualTo: widget.userId)
          .where(_publicOffersFilter())
          .get(),
    ]);

    final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final snap in results) {
      for (final d in snap.docs) {
        byId[d.id] = d;
      }
    }

    final docs = byId.values.toList(growable: false);

    // Toute annonce publiée doit être visible dans le profil public.
    final filtered = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in docs) {
      final data = doc.data();
      if (!_isPublishedOfferData(data)) continue;
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
                            backgroundColor: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Image.asset(
                                'assets/images/logowebp.webp',
                                fit: BoxFit.contain,
                              ),
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
  final String? initialConversationId;
  final String? initialDraftText;

  const MessagesPage({
    super.key,
    this.initialConversationId,
    this.initialDraftText,
  });

  @override
  Widget build(BuildContext context) {
    return MessagesPageV2(
      initialConversationId: initialConversationId,
      initialDraftText: initialDraftText,
    );
  }
}

class OfferDeepLinkPage extends StatelessWidget {
  final String offerId;
  final bool preferMarketplace;

  const OfferDeepLinkPage({
    super.key,
    required this.offerId,
    this.preferMarketplace = false,
  });

  Future<Map<String, dynamic>?> _loadOfferPayload() async {
    final firestore = FirebaseFirestore.instance;

    Future<Map<String, dynamic>?> loadDocument(
      String collectionName, {
      required bool isMarketplace,
    }) async {
      final snapshot =
          await firestore.collection(collectionName).doc(offerId).get();
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      return <String, dynamic>{
        ...data,
        'id': offerId,
        'offerId': offerId,
        'isMarketplace': isMarketplace,
      };
    }

    if (preferMarketplace) {
      return await loadDocument('listings', isMarketplace: true) ??
          await loadDocument('offers', isMarketplace: false);
    }

    return await loadDocument('offers', isMarketplace: false) ??
        await loadDocument('listings', isMarketplace: true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadOfferPayload(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: kPrestoOrange,
              foregroundColor: Colors.white,
              title: const Text('Annonce introuvable'),
            ),
            body: const Center(
              child: Text('Cette annonce n\'est plus disponible.'),
            ),
          );
        }

        final isMarketplace = data['isMarketplace'] == true;
        return OfferDetailsPage(
          offer: isMarketplace
              ? data
              : _buildOfferDetailsOffer(
                  offerId: offerId,
                  data: data,
                ),
          currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
        );
      },
    );
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
  static final MarketplacePublishService _marketplacePublishService =
      MarketplacePublishService();
  static const int _publishPhotoHardLimit = 2;
  static const int _defaultMaxListingPhotos = _publishPhotoHardLimit;
  static const int _minimumMaxListingPhotos = 1;

  final MarketplaceRemoteConfigService _marketplaceRemoteConfigService =
      MarketplaceRemoteConfigService();
  int _maxListingPhotos = _defaultMaxListingPhotos;

  String _formatMicroIaRuntimeError(Object error) {
    if (error is MicroIaClientAuthException) {
      return error.message;
    }

    if (error is FirebaseFunctionsException) {
      final code = error.code.trim();
      final message = (error.message ?? '').trim();
      if (code == 'unauthenticated') {
        return 'Connecte-toi pour utiliser la dictée.';
      }
      if (code == 'permission-denied') {
        return 'Cette dictée ne correspond plus à ta session. Recharge la page puis réessaie.';
      }
      if (code == 'not-found') {
        return 'Service vocal temporairement indisponible. Réessaie dans quelques instants.';
      }
      if (code == 'unavailable' || code == 'deadline-exceeded') {
        return 'Serveur vocal occupé. Réessaie dans quelques secondes.';
      }
      if (message.isNotEmpty) {
        return _translatePublishIssue(message);
      }
      return _translatePublishIssue(code);
    }

    if (error is FirebaseException) {
      if (error.code == 'network-error' ||
          error.code == 'retry-limit-exceeded' ||
          error.code == 'unknown') {
        return 'Erreur réseau lors de l’envoi de l’audio. Vérifie ta connexion puis réessaie.';
      }
      if (error.code == 'unauthorized' || error.code == 'permission-denied') {
        return 'Accès au stockage refusé. Recharge la page puis réessaie.';
      }
      return 'Erreur de stockage (${error.code}). Réessaie.';
    }

    final message = error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('StateError: ', '')
        .trim();
    final normalized = message.toLowerCase();
    if (normalized.contains('bad state') ||
        normalized.contains('recorder not started')) {
      return 'Le micro a été interrompu. Réessaie.';
    }
    if (normalized.contains('unable to decode audio data') ||
        normalized.contains('unknown content type') ||
        normalized.contains('not supported')) {
      return 'Le navigateur n’a pas pu lire l’audio. Réessaie ou recharge la page.';
    }
    if (normalized.contains('network') ||
        normalized.contains('connection') ||
        normalized.contains('fetch')) {
      return 'Problème de connexion réseau. Vérifie ta connexion puis réessaie.';
    }
    return message;
  }

  Future<bool> _ensureAppCheckReady({
    required String flow,
    bool showBlockingMessage = true,
  }) async {
    if (!_useCloudStt) return true;

    if (!_appCheckActivationAttempted || _appCheckActivationSucceeded) {
      _appendPublishAiTrace(
        'appcheck',
        'App Check OK pour $flow',
        level: _PublishAiTraceLevel.success,
      );
      return true;
    }

    try {
      if (kIsWeb) {
        debugPrint('[AppCheck] retry activation for $flow');
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider(_kAppCheckWebRecaptchaSiteKey),
        );
      } else {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider:
              kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
        );
      }
      _appCheckActivationAttempted = true;
      _appCheckActivationSucceeded = true;
      _appCheckActivationError = null;
      _appCheckActivationStackTrace = null;
      _appendPublishAiTrace(
        'appcheck',
        'App Check reactive avec succes pour $flow',
        level: _PublishAiTraceLevel.success,
      );
      return true;
    } catch (e, st) {
      _appCheckActivationAttempted = true;
      _appCheckActivationSucceeded = false;
      _appCheckActivationError = e;
      _appCheckActivationStackTrace = st;
    }

    final activationError = _appCheckActivationError;
    final activationStackTrace = _appCheckActivationStackTrace;
    final exception = Exception(
      'App Check activation unavailable: ${activationError ?? 'unknown error'}',
    );

    try {
      await CrashlyticsContext.recordError(
        exception,
        activationStackTrace ?? StackTrace.current,
        reason: 'App Check activation unavailable before micro IA flow',
        fatal: false,
        keys: {
          'component': 'Main',
          'flow': flow,
          'step': 'appCheck',
          'activationAttempted': _appCheckActivationAttempted.toString(),
          'activationSucceeded': _appCheckActivationSucceeded.toString(),
        },
      );

      debugPrint('[AppCheck] blocking $flow: $activationError');
    } catch (_) {}

    _appendPublishAiTrace(
      'appcheck',
      'Blocage sur $flow: ${activationError ?? 'activation indisponible'}',
      level: _PublishAiTraceLevel.error,
    );

    if (mounted && showBlockingMessage) {
      showSuccessSnackBar(
        context,
        'App Check indisponible apres nouvelle tentative. Le bouton IA reste bloque tant que la verification de securite n\'est pas active. Recharge l\'application puis reessaie.',
      );
    }
    return false;
  }

  Future<String> _transcribePublishAudio({
    required String ownerUid,
    required Uint8List audioBytes,
    required String contentType,
    required String extension,
  }) async {
    _appendPublishAiTrace(
      'upload_audio',
      'Préparation upload ${audioBytes.length} bytes, $contentType, .$extension',
    );
    _logMicroIaDebug(
      'UPLOAD',
      'chunk=final bytes=${audioBytes.length} contentType=$contentType extension=$extension',
    );
    final storagePath = await _listingAudioAiService.uploadAudioBytes(
      ownerUid: ownerUid,
      audioBytes: audioBytes,
      contentType: contentType,
      extension: extension,
    );
    _appendPublishAiTrace(
      'upload_audio',
      'Audio uploadé vers $storagePath',
      level: _PublishAiTraceLevel.success,
    );

    _appendPublishAiTrace(
      'microia_callable',
      'Appel microIaProcessAudio en cours',
    );
    final out = await MicroIaService.processAudio(
      storagePath: storagePath,
      languageCode: OpenAiConfig.defaultLanguageCode,
      debugLabel: 'publish_final_audio',
    ).timeout(const Duration(seconds: 90));

    final transcript = (out['text'] ?? '').toString().trim();
    if (transcript.isEmpty) {
      _appendPublishAiTrace(
        'microia_callable',
        'Réponse reçue mais transcription vide',
        level: _PublishAiTraceLevel.error,
      );
      throw Exception('Aucun texte reconnu');
    }

    final modeUsed = (out['modeUsed'] ?? '').toString().trim();
    if (modeUsed.isNotEmpty) {
      _adminAudioRuntimeStore.confirmLatestBackendResult(
        backendModeUsed: modeUsed,
        detail:
            'Réponse backend confirmée via $modeUsed (${transcript.length} caractères)',
        transcriptLength: transcript.length,
      );
    }
    _appendPublishAiTrace(
      'microia_callable',
      modeUsed.isEmpty
          ? 'Transcription reçue (${transcript.length} caractères)'
          : 'Transcription reçue via $modeUsed (${transcript.length} caractères)',
      level: _PublishAiTraceLevel.success,
    );

    return transcript;
  }

  Future<void> _applyPublishDraftFromTranscript(String transcript) async {
    _latestRecognizedTranscript = transcript;
    _appendPublishAiTrace(
      'draft_local',
      'Pré-remplissage local depuis la transcription (${transcript.length} caractères)',
    );
    _applyFastDraftFromTranscript(transcript);

    _appendPublishAiTrace(
      'draft_remote',
      'Appel generateOfferDraft depuis la transcription',
    );
    final draft = await _aiService.generateOfferDraft(text: transcript);
    _appendPublishAiTrace(
      'draft_remote',
      'Réponse generateOfferDraft reçue',
      level: draft['success'] == true
          ? _PublishAiTraceLevel.success
          : _PublishAiTraceLevel.warning,
    );

    if (!mounted) return;

    if (draft['success'] == true) {
      _applyDraftToForm(draft);
      _appendPublishAiTrace(
        'draft_remote',
        'Champs du formulaire remplis par le draft IA',
        level: _PublishAiTraceLevel.success,
      );
      showSuccessSnackBar(context, 'Transcription réussie et champs remplis');
      return;
    }

    final code = (draft['code'] ?? '').toString();
    throw Exception(
      code == 'deadline-exceeded'
          ? 'Connexion lente, réessaie.'
          : (draft['error'] ?? 'Erreur IA inconnue').toString(),
    );
  }

  /// Bouton micro: utiliser le flux audio classique, qui traite l'audio au stop
  /// et remplit les champs via le pipeline STT + draft.

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
    'Urgent',
    'Dans la journée',
    'Demain',
    'Sous 48h',
    'Cette semaine',
    'À convenir',
  ];
  String? _missionDelay;

  // Photos marketplace
  final List<XFile> _selectedPhotos = [];
  final List<Uint8List?> _selectedPhotoBytes = [];
  final List<String> _uploadedPhotoUrls = [];

  final FirebaseFunctions _functions = prestoFirebaseFunctions;

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
  String _latestRecognizedTranscript = '';
  bool _isApplyingProgrammaticPublishUpdate = false;
  bool _titleEditedByUser = false;
  bool _descriptionEditedByUser = false;
  bool _locationEditedByUser = false;
  bool _postalCodeEditedByUser = false;
  bool _categoryEditedByUser = false;
  bool _delayEditedByUser = false;
  bool _budgetEditedByUser = false;
  final List<_PublishAiTraceEntry> _publishAiTraceEntries =
      <_PublishAiTraceEntry>[];
  final ValueNotifier<int> _publishAiTraceVersion = ValueNotifier<int>(0);
  bool _publishAiTraceDisposed = false;
  int _publishAiTraceAttempt = 0;
  String? _shakingPublishFieldId;
  int _publishShakeTick = 0;

  final GlobalKey _titleFieldKey = GlobalKey();
  final GlobalKey _categoryFieldKey = GlobalKey();
  final GlobalKey _descriptionFieldKey = GlobalKey();
  final GlobalKey _cityFieldKey = GlobalKey();
  final GlobalKey _phoneFieldKey = GlobalKey();
  final GlobalKey _delayFieldKey = GlobalKey();
  final GlobalKey _budgetFieldKey = GlobalKey();

  // Service IA structuré pour le formulaire publier
  final AiDraftService _aiService = AiDraftService();
  final ListingAudioAiService _listingAudioAiService = ListingAudioAiService();
  final AdminAccessResolver _publishAdminAccessResolver =
      AdminAccessResolver();
  final AudioRecorder _recorder = AudioRecorder();
  final WebAudioRecorder _webRec = WebAudioRecorder();
  String? _recordingPath;
  // Toujours actif (améliore la qualité via Google STT côté serveur)
  final bool _useCloudStt = true;
  int _adminAudioRuntimeAccessState = 0;
  String _adminAudioRuntimeMode = 'HYBRID';
  String _adminAudioRuntimeLabel = 'Mode serveur';
  String _adminAudioRuntimeDetail = 'En attente de verification admin';

  void _runWithoutMarkingUserEdits(VoidCallback action) {
    final previous = _isApplyingProgrammaticPublishUpdate;
    _isApplyingProgrammaticPublishUpdate = true;
    try {
      action();
    } finally {
      _isApplyingProgrammaticPublishUpdate = previous;
    }
  }

  void _notifyPublishAiTraceChanged() {
    if (_publishAiTraceDisposed) return;
    _publishAiTraceVersion.value++;
    if (mounted) {
      setState(() {});
    }
  }

  void _resetPublishAiTrace(String flowLabel) {
    _publishAiTraceAttempt += 1;
    _publishAiTraceEntries
      ..clear()
      ..add(
        _PublishAiTraceEntry(
          timestamp: DateTime.now(),
          level: _PublishAiTraceLevel.info,
          stage: 'start',
          detail: 'Essai #$_publishAiTraceAttempt lance via $flowLabel',
        ),
      );
    _notifyPublishAiTraceChanged();
  }

  void _appendPublishAiTrace(
    String stage,
    String detail, {
    _PublishAiTraceLevel level = _PublishAiTraceLevel.info,
  }) {
    if (_publishAiTraceEntries.length >= 120) {
      _publishAiTraceEntries.removeAt(0);
    }
    _publishAiTraceEntries.add(
      _PublishAiTraceEntry(
        timestamp: DateTime.now(),
        level: level,
        stage: stage,
        detail: detail,
      ),
    );
    _notifyPublishAiTraceChanged();
  }

  void _clearPublishAiTrace() {
    _publishAiTraceEntries.clear();
    _notifyPublishAiTraceChanged();
  }

  String _publishAiDebugValue(Object? value) {
    if (value == null) return '-';
    if (value is bool) return value ? 'yes' : 'no';
    final text = value.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  void _appendAdminAccessDiagnosticTrace(
    String stage,
    Map<String, dynamic> payload, {
    _PublishAiTraceLevel level = _PublishAiTraceLevel.info,
  }) {
    final debug = payload['debug'] is Map
        ? Map<String, dynamic>.from(payload['debug'] as Map)
        : const <String, dynamic>{};
    final parts = <String>[
      'uid=${_publishAiDebugValue(payload['uid'])}',
      'isAdmin=${_publishAiDebugValue(payload['isAdmin'])}',
      'source=${_publishAiDebugValue(payload['source'])}',
    ];

    if (debug.isNotEmpty) {
      parts.addAll(<String>[
        'tokenAdmin=${_publishAiDebugValue(debug['tokenHasAdmin'])}',
        'userDoc=${_publishAiDebugValue(debug['userDocExists'])}',
        'userAdmin=${_publishAiDebugValue(debug['userHasAdmin'])}',
        'adminDoc=${_publishAiDebugValue(debug['adminDocExists'])}',
        'adminEnabled=${_publishAiDebugValue(debug['adminDocEnabled'])}',
      ]);
    }

    _appendPublishAiTrace(stage, parts.join(' | '), level: level);
  }

  void _appendAdminAccessStateTrace(
    String stage,
    AdminAccessState state, {
    _PublishAiTraceLevel level = _PublishAiTraceLevel.info,
  }) {
    final parts = <String>[
      'uid=${_publishAiDebugValue(state.uid)}',
      'effectiveAdmin=${_publishAiDebugValue(state.effectiveIsAdmin)}',
      'source=${_publishAiDebugValue(state.sourceOfTruth)}',
      'tokenAdmin=${_publishAiDebugValue(state.tokenHasAdmin)}',
      'profileAdmin=${_publishAiDebugValue(state.profileHasAdmin)}',
      'serverOk=${_publishAiDebugValue(state.serverCheckSucceeded)}',
      'serverAdmin=${_publishAiDebugValue(state.serverIsAdmin)}',
    ];

    if ((state.serverErrorCode ?? '').trim().isNotEmpty) {
      parts.add('serverError=${_publishAiDebugValue(state.serverErrorCode)}');
    }

    _appendPublishAiTrace(stage, parts.join(' | '), level: level);
  }

  String _publishAdminRuntimeDetail(AdminAccessState state) {
    if (state.serverCheckSucceeded && state.serverIsAdmin == true) {
      return 'Accès admin confirmé';
    }
    if (state.effectiveIsAdmin) {
      final source = state.sourceOfTruth.trim().isEmpty
          ? 'token/profil'
          : state.sourceOfTruth;
      return 'Accès admin confirmé via $source';
    }
    if ((state.serverErrorMessage ?? '').trim().isNotEmpty) {
      return state.serverErrorMessage!.trim();
    }
    if ((state.serverErrorCode ?? '').trim().isNotEmpty) {
      return 'Vérification admin indisponible (${state.serverErrorCode})';
    }
    return 'Accès admin non confirmé';
  }

  String _formatPublishAiTraceTime(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}.${three(value.millisecond)}';
  }

  IconData _iconForPublishAiTraceLevel(_PublishAiTraceLevel level) {
    switch (level) {
      case _PublishAiTraceLevel.success:
        return Icons.check_circle_rounded;
      case _PublishAiTraceLevel.warning:
        return Icons.warning_amber_rounded;
      case _PublishAiTraceLevel.error:
        return Icons.error_rounded;
      case _PublishAiTraceLevel.info:
        return Icons.radio_button_checked_rounded;
    }
  }

  Color _colorForPublishAiTraceLevel(_PublishAiTraceLevel level) {
    switch (level) {
      case _PublishAiTraceLevel.success:
        return const Color(0xFF2E7D32);
      case _PublishAiTraceLevel.warning:
        return const Color(0xFFF9A825);
      case _PublishAiTraceLevel.error:
        return const Color(0xFFC62828);
      case _PublishAiTraceLevel.info:
        return kPrestoBlue;
    }
  }

  String _currentPublishAiRuntimeState() {
    if (_isListening) return 'Ecoute micro';
    if (_isAnalyzing) return 'Analyse en cours';
    return 'En attente';
  }

  void _logMicroIaDebug(String stage, String message) {
    debugPrint('[MICIA][$stage] $message');
  }

  Future<MicroIaSecureContext?> _requirePublishAiSecureContext({
    required String stage,
    bool forceRefreshToken = false,
    bool showUserMessage = true,
  }) async {
    try {
      final secureContext = await MicroIaService.prepareSecureCallableContext(
        forceRefreshToken: forceRefreshToken,
      );
      _appendPublishAiTrace(
        'auth',
        'Session OK uid=${secureContext.uid} token=ok appcheck=${secureContext.hasAppCheckToken ? 'ok' : 'missing'}',
        level: _PublishAiTraceLevel.success,
      );
      _logMicroIaDebug(
        'AUTH',
        'uid=${secureContext.uid} email=${secureContext.email ?? ''} stage=$stage',
      );
      _logMicroIaDebug('TOKEN', 'fetched=yes stage=$stage');
      _logMicroIaDebug(
        'APPCHECK',
        'token=${secureContext.hasAppCheckToken ? 'yes' : 'no'} stage=$stage',
      );
      return secureContext;
    } on MicroIaClientAuthException catch (error) {
      _appendPublishAiTrace(
        'auth',
        error.message,
        level: _PublishAiTraceLevel.error,
      );
      _logMicroIaDebug('AUTH', 'user=null code=${error.code} stage=$stage');
      _logMicroIaDebug('TOKEN', 'fetched=no stage=$stage');
      if (showUserMessage && mounted) {
        showSuccessSnackBar(context, error.message);
      }
      return null;
    } catch (error) {
      final message = _formatMicroIaRuntimeError(error);
      _appendPublishAiTrace(
        'auth',
        message,
        level: _PublishAiTraceLevel.error,
      );
      _logMicroIaDebug('AUTH', 'unexpected_error stage=$stage err=$message');
      if (showUserMessage && mounted) {
        showSuccessSnackBar(context, message);
      }
      return null;
    }
  }

  String _adminAudioModeLabel(String mode) {
    switch (mode.toUpperCase()) {
      case 'GOOGLE_ONLY':
        return 'Google STT';
      case 'WHISPER_ONLY':
        return 'Whisper';
      case 'HYBRID':
      default:
        return 'Hybride';
    }
  }

  String _classicAdminAudioRuntimeDetail() {
    switch (_adminAudioRuntimeMode.toUpperCase()) {
      case 'GOOGLE_ONLY':
        return 'Micro classique -> transcription Google STT uniquement';
      case 'WHISPER_ONLY':
        return 'Micro classique -> transcription Whisper uniquement';
      case 'HYBRID':
      default:
        return 'Micro classique -> Google STT puis nettoyage IA, avec fallback Whisper/Google';
    }
  }

  Future<void> _refreshAdminAudioRuntimeAccess() async {
    final user = await _resolveSignedInUser();
    if (user == null) {
      _appendPublishAiTrace(
        'admin_check',
        'Aucun utilisateur FirebaseAuth disponible pour la verification admin',
        level: _PublishAiTraceLevel.warning,
      );
      if (!mounted) return;
      setState(() {
        _adminAudioRuntimeAccessState = 0;
      });
      return;
    }

    try {
      final accessState = await _publishAdminAccessResolver.resolveAdminAccess(
        forceRefresh: true,
      );
      _appendAdminAccessStateTrace(
        'admin_check',
        accessState,
        level: accessState.effectiveIsAdmin
            ? _PublishAiTraceLevel.success
            : _PublishAiTraceLevel.warning,
      );

      if (!accessState.effectiveIsAdmin) {
        if (!mounted) return;
        setState(() {
          _adminAudioRuntimeAccessState = -1;
          if (_adminAudioRuntimeLabel == 'Mode serveur') {
            _adminAudioRuntimeDetail = _publishAdminRuntimeDetail(accessState);
          }
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _adminAudioRuntimeAccessState = 1;
        if (_adminAudioRuntimeLabel == 'Mode serveur') {
          _adminAudioRuntimeDetail = _publishAdminRuntimeDetail(accessState);
        }
      });
      unawaited(_adminAudioRuntimeStore.enableCloudSync());

      try {
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
        final configCallable = _functions.httpsCallable(
          'adminGetMicroIaConfig',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        );
        final configRes = await configCallable.call<dynamic>({});
        final data = Map<String, dynamic>.from(configRes.data as Map);
        final mode = (data['mode'] ?? 'HYBRID').toString().toUpperCase();
        _appendPublishAiTrace(
          'admin_config',
          'mode=${_publishAiDebugValue(mode)} source=${_publishAiDebugValue(data['source'])}',
          level: _PublishAiTraceLevel.success,
        );

        if (!mounted) return;
        setState(() {
          _adminAudioRuntimeMode = mode;
          if (_adminAudioRuntimeLabel == 'Mode serveur') {
            _adminAudioRuntimeDetail =
                'Mode configure: ${_adminAudioModeLabel(mode)}';
          }
        });
        unawaited(_adminAudioRuntimeStore.enableCloudSync());
        _adminAudioRuntimeStore.updateConfiguredMode(mode);
      } on FirebaseFunctionsException catch (e) {
        _appendPublishAiTrace(
          'admin_config',
          'Erreur config code=${e.code} message=${_publishAiDebugValue(e.message)}',
          level: _PublishAiTraceLevel.warning,
        );
        if (!mounted) return;
        setState(() {
          _adminAudioRuntimeAccessState = 1;
          if (_adminAudioRuntimeLabel == 'Mode serveur') {
            _adminAudioRuntimeDetail =
                '${_publishAdminRuntimeDetail(accessState)}. Config serveur indisponible';
          }
        });
      } catch (error) {
        _appendPublishAiTrace(
          'admin_config',
          'Erreur config inattendue: ${_publishAiDebugValue(error)}',
          level: _PublishAiTraceLevel.warning,
        );
      }
    } on FirebaseFunctionsException catch (e) {
      _appendPublishAiTrace(
        'admin_check',
        'Erreur callable code=${e.code} message=${_publishAiDebugValue(e.message)} uid=${user.uid}',
        level: _PublishAiTraceLevel.error,
      );
      if ((e.code == 'permission-denied' || e.code == 'unauthenticated') &&
          user.uid.isNotEmpty) {
        await _ensureProtectedSessionReady(forceRefreshToken: true);
        if (!mounted) return;
        try {
          final retryCallable = _functions.httpsCallable(
            'getMyAdminAccessStatus',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
          );
          final retryRes = await retryCallable.call<dynamic>({});
          final retryData = Map<String, dynamic>.from(retryRes.data as Map);
          _appendAdminAccessDiagnosticTrace(
            'admin_retry',
            retryData,
            level: retryData['isAdmin'] == true
                ? _PublishAiTraceLevel.success
                : _PublishAiTraceLevel.warning,
          );
          if (retryData['isAdmin'] != true) {
            throw FirebaseFunctionsException(
              code: 'permission-denied',
              message: 'Accès admin non confirmé après nouvelle tentative.',
            );
          }
          if (!mounted) return;
          setState(() {
            _adminAudioRuntimeAccessState = 1;
            if (_adminAudioRuntimeLabel == 'Mode serveur') {
              _adminAudioRuntimeDetail = 'Accès admin confirmé';
            }
          });
          return;
        } on FirebaseFunctionsException {
          // Laisse la gestion standard ci-dessous.
        } catch (_) {
          // Laisse la gestion standard ci-dessous.
        }
      }
      if (!mounted) return;
      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        setState(() {
          _adminAudioRuntimeAccessState = -1;
          if (_adminAudioRuntimeLabel == 'Mode serveur') {
            _adminAudioRuntimeDetail =
                'Vérification admin serveur indisponible. Recharge la session.';
          }
        });
      }
    } catch (_) {
      _appendPublishAiTrace(
        'admin_check',
        'Erreur inattendue pendant la verification admin',
        level: _PublishAiTraceLevel.error,
      );
      if (!mounted) return;
      setState(() {
        _adminAudioRuntimeAccessState = -1;
        if (_adminAudioRuntimeLabel == 'Mode serveur') {
          _adminAudioRuntimeDetail =
              'Vérification admin impossible pour cette session';
        }
      });
    }
  }

  void _rememberAdminAudioRuntime({
    required String flowKey,
    required String label,
    required String detail,
    String status = 'pending',
    String? backendModeUsed,
  }) {
    _adminAudioRuntimeLabel = label;
    _adminAudioRuntimeDetail = detail;
    _adminAudioRuntimeStore.recordRuntime(
      flowKey: flowKey,
      label: label,
      detail: detail,
      status: status,
      backendModeUsed: backendModeUsed,
    );
  }

  Widget _buildAdminAudioRuntimeIndicator() {
    if (_adminAudioRuntimeAccessState != 1) {
      return const SizedBox.shrink();
    }

    final accent = _isListening
        ? kPrestoOrange
        : (_isAnalyzing ? kPrestoBlue : const Color(0xFF455A64));
    final stateLabel = _isListening
        ? 'LIVE'
        : (_isAnalyzing ? 'ANALYSE' : 'ADMIN');

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _adminAudioRuntimeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withOpacity(0.24)),
                  ),
                  child: Text(
                    stateLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _adminAudioRuntimeDetail,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withOpacity(0.2)),
                  ),
                  child: Text(
                    'Mode serveur: ${_adminAudioModeLabel(_adminAudioRuntimeMode)}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withOpacity(0.2)),
                  ),
                  child: Text(
                    'Etat: ${_currentPublishAiRuntimeState()}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPublishAiTraceDialog() async {
    if (!mounted) return;
    final overlayTheme = context.prestoOverlayTheme;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return ValueListenableBuilder<int>(
          valueListenable: _publishAiTraceVersion,
          builder: (context, _, __) {
            final entries = List<_PublishAiTraceEntry>.unmodifiable(
              _publishAiTraceEntries,
            );

            return Dialog(
              backgroundColor: overlayTheme.surfaceColor,
              surfaceTintColor: overlayTheme.surfaceTintColor,
              insetPadding: const EdgeInsets.all(16),
              shape: overlayTheme.dialogShape,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Diagnostic micro IA',
                              style: kPrestoSectionTitleStyle,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Fermer',
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: kPrestoBlue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: kPrestoBlue.withOpacity(0.18),
                              ),
                            ),
                            child: Text(
                              'Etat: ${_currentPublishAiRuntimeState()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: kPrestoBlue,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Entrees: ${entries.length}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      if (_latestRecognizedTranscript.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.035),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Text(
                            'Dernière transcription: ${_latestRecognizedTranscript.trim()}',
                            style: const TextStyle(fontSize: 12, height: 1.35),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: entries.isEmpty ? null : _clearPublishAiTrace,
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Effacer'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: entries.isEmpty
                            ? const Center(
                                child: Text(
                                  'Aucun diagnostic pour le moment.',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              )
                            : ListView.separated(
                                itemCount: entries.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final entry = entries[index];
                                  final color = _colorForPublishAiTraceLevel(
                                    entry.level,
                                  );
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: color.withOpacity(0.18),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Icon(
                                            _iconForPublishAiTraceLevel(entry.level),
                                            color: color,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${_formatPublishAiTraceTime(entry.timestamp)}  ${entry.stage}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: color,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                entry.detail,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPublishAiTraceActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: _showPublishAiTraceDialog,
          icon: const Icon(Icons.bug_report_outlined),
          label: const Text('Diagnostic IA'),
        ),
        if (_publishAiTraceEntries.isNotEmpty)
          TextButton(
            onPressed: _clearPublishAiTrace,
            child: const Text('Effacer'),
          ),
      ],
    );
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    _runWithoutMarkingUserEdits(() {
      controller.value = controller.value.copyWith(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
        composing: TextRange.empty,
      );
    });
  }

  void _handlePublishTitleChanged() {
    if (_isApplyingProgrammaticPublishUpdate) return;
    _titleEditedByUser = true;
  }

  void _handlePublishDescriptionChanged() {
    if (_isApplyingProgrammaticPublishUpdate) return;
    _descriptionEditedByUser = true;
  }

  void _handlePublishLocationChanged() {
    if (_isApplyingProgrammaticPublishUpdate) return;
    _locationEditedByUser = true;
  }

  void _handlePublishPostalCodeChanged() {
    if (_isApplyingProgrammaticPublishUpdate) return;
    _postalCodeEditedByUser = true;
  }

  void _handlePublishBudgetChanged() {
    if (_isApplyingProgrammaticPublishUpdate) return;
    _budgetEditedByUser = true;
  }

  String? _normalizeDraftMissionDelay(String? rawUrgency) {
    final urgency = (rawUrgency ?? '').trim().toLowerCase();
    switch (urgency) {
      case 'immediat':
        return 'Urgent';
      case '24h':
        return 'Dans la journée';
      case '7j':
        return 'Cette semaine';
      case 'flexible':
        return 'À convenir';
      default:
        return null;
    }
  }

  bool _transcriptMentionsBudget(String transcript) {
    final lower = transcript.toLowerCase();
    return RegExp(r'\b\d{2,5}(?:[.,]\d{1,2})?\s*(€|euros?)\b')
            .hasMatch(lower) ||
        lower.contains('budget') ||
        lower.contains('tarif') ||
        lower.contains('prix') ||
        lower.contains('à négocier') ||
        lower.contains('a negocier');
  }

  bool _transcriptMentionsUrgency(String transcript) {
    final lower = transcript.toLowerCase();
    return lower.contains('urgent') ||
        lower.contains('urgence') ||
        lower.contains("aujourd'hui") ||
        lower.contains('aujourd hui') ||
        lower.contains('demain') ||
        lower.contains('ce soir') ||
        lower.contains('48h') ||
        lower.contains('cette semaine') ||
        lower.contains('rapidement') ||
        lower.contains('dès que possible') ||
        lower.contains('des que possible') ||
        lower.contains('immédiat') ||
        lower.contains('immediat');
  }

  String? _extractMissionDelayFromTranscript(String transcript) {
    final lower = transcript.toLowerCase();

    if (lower.contains('urgent') ||
        lower.contains('urgence') ||
        lower.contains('immédiat') ||
        lower.contains('immediat')) {
      return 'Urgent';
    }
    if (lower.contains("aujourd'hui") ||
        lower.contains('aujourd hui') ||
        lower.contains('dans la journée') ||
        lower.contains('dans la journee') ||
        lower.contains('24h')) {
      return 'Dans la journée';
    }
    if (lower.contains('demain')) {
      return 'Demain';
    }
    if (lower.contains('48h') || lower.contains('sous 48h')) {
      return 'Sous 48h';
    }
    if (lower.contains('cette semaine') ||
        lower.contains('dans la semaine') ||
        lower.contains('7 jours') ||
        lower.contains('7j')) {
      return 'Cette semaine';
    }
    if (lower.contains('à convenir') ||
        lower.contains('a convenir') ||
        lower.contains('quand vous pouvez') ||
        lower.contains('quand tu peux') ||
        lower.contains('flexible') ||
        lower.contains('pas urgent')) {
      return 'À convenir';
    }

    return null;
  }

  bool _transcriptRequestsNegotiatedBudget(String transcript) {
    final lower = transcript.toLowerCase();
    return lower.contains('à négocier') ||
        lower.contains('a negocier') ||
        lower.contains('à discuter') ||
        lower.contains('a discuter') ||
        lower.contains('prix flexible') ||
        lower.contains('budget flexible');
  }

  double? _extractBudgetAmountFromTranscript(String transcript) {
    final matches = RegExp(
      r'\b(\d{2,5}(?:[.,]\d{1,2})?)\s*(€|euros?)\b',
      caseSensitive: false,
    ).allMatches(transcript);

    for (final match in matches) {
      final raw = (match.group(1) ?? '').replaceAll(',', '.');
      final value = double.tryParse(raw);
      if (value != null && value > 0) {
        return value;
      }
    }

    return null;
  }

  String _buildRichDraftDescription(Map<String, dynamic> draft) {
    final shortDescription =
        ((draft['description_courte'] ?? draft['description']) as String? ?? '')
            .trim();
    final details = (draft['details'] is List)
        ? (draft['details'] as List)
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];
    final availabilities =
        ((draft['disponibilites'] ?? '') as String?)?.trim() ?? '';

    final lines = <String>[];
    if (shortDescription.isNotEmpty) {
      lines.add(shortDescription);
    }
    if (details.isNotEmpty) {
      lines.addAll(details.map((detail) => '- $detail'));
    }
    if (availabilities.isNotEmpty) {
      lines.add('Disponibilités : $availabilities');
    }
    return lines.join('\n').trim();
  }

  void _applyRichDraftToForm(Map<String, dynamic> draft) {
    final title = (draft['title'] ?? draft['titre'] ?? '').toString().trim();
    final description = _buildRichDraftDescription(draft);
    final category = _resolvePublishCategoryLabel(
      (draft['category'] ?? draft['categorie'] ?? '').toString(),
    );
    final missionDelay = _normalizeDraftMissionDelay(
      (draft['urgence'] ?? '').toString(),
    );
    final budget = draft['budget'] is Map
        ? Map<String, dynamic>.from(draft['budget'] as Map)
        : const <String, dynamic>{};
    final budgetMin = budget['min'];
    final budgetMax = budget['max'];
    final parsedMin = budgetMin is num ? budgetMin.toDouble() : null;
    final parsedMax = budgetMax is num ? budgetMax.toDouble() : null;
    final inferredBudget = parsedMin ?? parsedMax;
    final rawBudgetType = (budget['type'] ?? draft['budgetType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final wantsNegotiation = rawBudgetType == 'a_negocier' ||
        rawBudgetType == 'à négocier' ||
        rawBudgetType == 'negotiable';

    setState(() {
      if (!_titleEditedByUser && title.isNotEmpty) {
        _setControllerText(_titleController, title);
      }
      if (!_descriptionEditedByUser && description.isNotEmpty) {
        _setControllerText(_descriptionController, description);
      }
      if (!_categoryEditedByUser && category != null && category.isNotEmpty) {
        _category = category;
        _selectedSubCategory = null;
      }
      if (!_delayEditedByUser && missionDelay != null) {
        _missionDelay = missionDelay;
        _isUrgent = missionDelay == 'Urgent';
      }
      if (!_budgetEditedByUser) {
        if (inferredBudget != null) {
          _budgetType = 'Fixe';
          final formattedBudget = inferredBudget % 1 == 0
              ? inferredBudget.toInt().toString()
              : inferredBudget.toStringAsFixed(2);
          _setControllerText(_budgetController, formattedBudget);
        } else if (wantsNegotiation) {
          _budgetType = 'À négocier';
          _setControllerText(_budgetController, '');
        }
      }
    });

    _applyDetectedCityData(
      city: (draft['city'] ?? draft['ville'] ?? '').toString(),
      postalCode: (draft['postalCode'] ?? '').toString(),
    );
    _applyKeywordCategoryPairFromText('$title\n$description');
  }

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

  String? _resolvePublishCategoryLabel(String? rawCategory) {
    final canonical = canonicalizeOfferCategory(rawCategory);
    if (canonical == null || canonical.trim().isEmpty) return null;

    final normalizedCanonical = normalizeOfferText(canonical);
    for (final category in _categories) {
      if (normalizeOfferText(category) == normalizedCanonical) {
        return category;
      }
    }
    return null;
  }

  CityRecord? _resolveCanonicalCityRecord({
    String? city,
    String? postalCode,
  }) {
    final rawCity = (city ?? '').trim();
    final rawPostalCode = (postalCode ?? '').trim();

    if (rawPostalCode.isNotEmpty) {
      final exactPostal =
          CitySearch.instance.pickBestForPostalCode(rawPostalCode);
      if (exactPostal != null) {
        if (rawCity.isEmpty ||
            normalizeOfferText(exactPostal.name) ==
                normalizeOfferText(rawCity)) {
          return exactPostal;
        }

        final cityMatches = CitySearch.instance.search(rawCity, limit: 10);
        for (final candidate in cityMatches) {
          if (candidate.cp == rawPostalCode) {
            return candidate;
          }
        }
      }
    }

    if (rawCity.isEmpty) return null;
    final candidates = CitySearch.instance.search(rawCity, limit: 10);
    if (candidates.isEmpty) return null;

    if (rawPostalCode.isNotEmpty) {
      for (final candidate in candidates) {
        if (candidate.cp == rawPostalCode) {
          return candidate;
        }
      }
    }

    return candidates.first;
  }

  void _canonicalizeLocationInputs() {
    final best = _resolveCanonicalCityRecord(
      city: _locationController.text,
      postalCode: _postalCodeController.text,
    );
    if (best == null) return;

    final sameCity = _locationController.text.trim() == best.name;
    final samePostalCode = _postalCodeController.text.trim() == best.cp;
    if (sameCity && samePostalCode) return;

    _applyCity(best);
  }

  void _applyDetectedCityData({
    String? city,
    String? postalCode,
  }) {
    final rawCity = (city ?? '').trim();
    final rawPostalCode = (postalCode ?? '').trim();

    final best = _resolveCanonicalCityRecord(
      city: rawCity,
      postalCode: rawPostalCode,
    );

    if (best != null) {
      _applyCity(best);
      return;
    }

    setState(() {
      if (!_locationEditedByUser && rawCity.isNotEmpty) {
        _setControllerText(_locationController, rawCity);
      }
      if (!_postalCodeEditedByUser && rawPostalCode.isNotEmpty) {
        _setControllerText(_postalCodeController, rawPostalCode);
        final dept = departmentFromPostalCode(rawPostalCode);
        if (dept != null && dept.isNotEmpty) {
          _selectedDeptCode = dept;
          _selectedPhoneCountryCode = _countryCodeForDept(dept);
        }
      }
    });
  }

  void _applyKeywordCategoryPairFromText(String text) {
    final match = resolvePublishCategoryPairFromText(text);
    if (match == null) return;

    final currentCategory = (_category ?? '').trim();
    final currentSubCategory = (_selectedSubCategory ?? '').trim();
    final sameCategory = currentCategory.isNotEmpty &&
        normalizeOfferText(currentCategory) ==
            normalizeOfferText(match.category);
    final canSetCategory = !_categoryEditedByUser && currentCategory.isEmpty;
    final canSetSubCategory = !_categoryEditedByUser &&
        currentSubCategory.isEmpty &&
        (canSetCategory || sameCategory);
    final canSetTitle = !_titleEditedByUser &&
        _titleController.text.trim().isEmpty &&
        (match.suggestedTitle ?? '').trim().isNotEmpty;

    if (!canSetCategory && !canSetSubCategory && !canSetTitle) {
      return;
    }

    setState(() {
      if (canSetTitle) {
        _setControllerText(_titleController, match.suggestedTitle!.trim());
      }

      if (canSetCategory) {
        _category = match.category;
        _selectedSubCategory = null;
      }

      final effectiveCategory = (_category ?? '').trim();
      final availableSubcategories =
          kCategorySubcategories[match.category] ?? const <String>[];
      if (currentSubCategory.isEmpty &&
          normalizeOfferText(effectiveCategory) ==
              normalizeOfferText(match.category) &&
          availableSubcategories.contains(match.subCategory)) {
        _selectedSubCategory = match.subCategory;
      }
    });
  }

  /// Remplissage immédiat (latence perçue ↓) dès que la transcription est prête.
  /// L'IA pourra ensuite affiner et remplacer.
  void _applyFastDraftFromTranscript(String transcript) {
    final t = transcript.trim();
    if (t.isEmpty) return;

    if (!_descriptionEditedByUser) {
      _setControllerText(_descriptionController, t);
    }

    if (!_titleEditedByUser) {
      final firstLine = t.split('\n').first.trim();
      final firstSentence = firstLine.split(RegExp(r'[.!?]')).first.trim();
      final candidate = (firstSentence.isNotEmpty ? firstSentence : firstLine);

      final title = candidate.length > 72
          ? '${candidate.substring(0, 72).trim()}…'
          : candidate;
      if (title.isNotEmpty) {
        _setControllerText(_titleController, title);
      }
    }

    if (!_postalCodeEditedByUser) {
      final cp = _extractPostalCodeFromTranscript(t);
      if (cp != null && cp.isNotEmpty) {
        _setControllerText(_postalCodeController, cp);
      }
    }

    final effectiveCp = _postalCodeController.text.trim().isEmpty
        ? null
        : _postalCodeController.text.trim();

    if (!_locationEditedByUser) {
      final cityRec = _extractCityRecordFromTranscript(t, cp: effectiveCp);
      if (cityRec != null) {
        _setControllerText(_locationController, cityRec.name);

        if (!_postalCodeEditedByUser &&
            _postalCodeController.text.trim().isEmpty &&
            cityRec.cp.isNotEmpty) {
          _setControllerText(_postalCodeController, cityRec.cp);
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

    final inferredMissionDelay = _extractMissionDelayFromTranscript(t);
    if (!_delayEditedByUser && inferredMissionDelay != null) {
      setState(() {
        _missionDelay = inferredMissionDelay;
        _isUrgent = inferredMissionDelay == 'Urgent';
      });
    }

    if (!_budgetEditedByUser) {
      if (_transcriptRequestsNegotiatedBudget(t)) {
        setState(() {
          _budgetType = 'À négocier';
          _setControllerText(_budgetController, '');
        });
      } else {
        final inferredBudget = _extractBudgetAmountFromTranscript(t);
        if (inferredBudget != null) {
          final formattedBudget = inferredBudget % 1 == 0
              ? inferredBudget.toInt().toString()
              : inferredBudget.toStringAsFixed(2);
          setState(() {
            _budgetType = 'Fixe';
            _setControllerText(_budgetController, formattedBudget);
          });
        }
      }
    }

    _applyKeywordCategoryPairFromText(t);
  }

  /// Apply draft payload returned by the publish IA pipeline.
  void _applyDraftToForm(Map<String, dynamic> draft) {
    _applyRichDraftToForm(draft);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_adminAudioRuntimeStore.ensureInitialized());
    unawaited(_loadMarketplacePhotoLimit());
    unawaited(_prefillPublishPhoneFromProfileIfNeeded());
    unawaited(_refreshAdminAudioRuntimeAccess());

    _scrollController.addListener(() {
      widget.onScroll?.call(_scrollController.offset);
    });

    _titleController.addListener(_recompute);
    _titleController.addListener(_handlePublishTitleChanged);
    _descriptionController.addListener(_recompute);
    _descriptionController.addListener(_handlePublishDescriptionChanged);
    _locationController.addListener(_recompute);
    _locationController.addListener(_handlePublishLocationChanged);
    _postalCodeController.addListener(_handlePublishPostalCodeChanged);
    _phoneController.addListener(_recompute);
    _budgetController.addListener(_recompute);
    _budgetController.addListener(_handlePublishBudgetChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) => _recompute());
  }

  Future<void> _loadMarketplacePhotoLimit() async {
    try {
      await _marketplaceRemoteConfigService.initialize();
      final configuredLimit = _marketplaceRemoteConfigService.listingMaxPhotos;
      final normalizedLimit = configuredLimit < _minimumMaxListingPhotos
          ? _minimumMaxListingPhotos
          : configuredLimit > _publishPhotoHardLimit
              ? _publishPhotoHardLimit
              : configuredLimit;
      if (!mounted || normalizedLimit == _maxListingPhotos) {
        return;
      }
      setState(() {
        _maxListingPhotos = normalizedLimit;
      });
    } catch (_) {
      // Garde la valeur par défaut si la remote config n'est pas disponible.
    }
  }

  int get _visiblePhotoTileCount {
    if (_selectedPhotos.length >= _maxListingPhotos) {
      return _maxListingPhotos;
    }
    return _selectedPhotos.length + 1;
  }

  bool _isValidPhoneFR(String raw) {
    final sanitized = raw.replaceAll(RegExp(r'\s+'), '');
    if (sanitized.isEmpty) return false;

    if (sanitized.startsWith('+')) {
      return RegExp(r'^\+[0-9]{8,15}$').hasMatch(sanitized);
    }

    return RegExp(r'^[0-9]{6,15}$').hasMatch(sanitized);
  }

  String _firstNonEmptyPublishPhone(
    Map<String, dynamic>? data,
    List<String> keys, {
    List<String> fallbackValues = const <String>[],
  }) {
    if (data != null) {
      for (final key in keys) {
        final raw = data[key];
        final value = raw?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          return value;
        }
      }
    }

    for (final fallback in fallbackValues) {
      final value = fallback.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  void _applyPublishPhoneFromProfile(
    String rawPhone, {
    String? explicitCountryCode,
  }) {
    final trimmed = rawPhone.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final compact = trimmed.replaceAll(RegExp(r'\s+'), '');
    final allDigits = compact.replaceAll(RegExp(r'\D'), '');

    final normalizedExplicitCode = (explicitCountryCode ?? '').trim();
    final knownCodes =
        kPhoneCountryCodes.map((country) => country.code).toList();

    String selectedCode = normalizedExplicitCode;
    if (selectedCode.isEmpty || !knownCodes.contains(selectedCode)) {
      for (final code in knownCodes) {
        if (compact.startsWith(code)) {
          selectedCode = code;
          break;
        }
      }
    }

    if (selectedCode.isEmpty) {
      selectedCode = _selectedPhoneCountryCode;
    }
    if (!knownCodes.contains(selectedCode)) {
      selectedCode = '+33';
    }

    final codeDigits = selectedCode.replaceAll(RegExp(r'\D'), '');
    var localDigits = allDigits;
    if (codeDigits.isNotEmpty && allDigits.startsWith(codeDigits)) {
      localDigits = allDigits.substring(codeDigits.length);
    }

    _selectedPhoneCountryCode = selectedCode;
    _phoneController.text = localDigits.isNotEmpty ? localDigits : trimmed;
  }

  Future<void> _prefillPublishPhoneFromProfileIfNeeded() async {
    if (_phoneController.text.trim().isNotEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await userRef
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        doc = await userRef
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 3));
      }

      final data = doc.data();
      final rawPhone = _firstNonEmptyPublishPhone(
        data,
        const ['phone', 'phoneNumber', 'phone_number'],
        fallbackValues: <String>[user.phoneNumber ?? ''],
      );
      final phoneCountryCode =
          data == null ? null : data['phoneCountryCode']?.toString().trim();

      if (rawPhone.isEmpty ||
          !mounted ||
          _phoneController.text.trim().isNotEmpty) {
        return;
      }

      setState(() {
        _applyPublishPhoneFromProfile(
          rawPhone,
          explicitCountryCode: phoneCountryCode,
        );
      });
      _recompute();
    } catch (error) {
      debugPrint('[Publish] Préremplissage téléphone impossible: $error');
    }
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

  bool _showAiPendingForController(TextEditingController controller) {
    return _isAnalyzing && controller.text.trim().isEmpty;
  }

  bool get _showAiPendingForCategory {
    return _isAnalyzing && (_category == null || _category!.trim().isEmpty);
  }

  Widget _withAiPendingOverlay({
    required Widget child,
    required bool showPending,
    Alignment alignment = Alignment.centerRight,
    EdgeInsets padding = const EdgeInsets.only(right: 42),
  }) {
    if (!showPending) return child;

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: alignment,
              child: Padding(
                padding: padding,
                child: const _FieldPendingDots(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? _validatePublishTitle(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Merci de saisir un titre';
    }
    if (trimmed.length < 10) {
      return 'Le titre doit contenir au moins 10 caractères';
    }
    if (trimmed.length > 120) {
      return 'Le titre doit contenir au maximum 120 caractères';
    }
    return null;
  }

  String? _validatePublishDescription(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Merci de décrire votre besoin';
    }
    if (trimmed.length < 30) {
      return 'La description doit contenir au moins 30 caractères';
    }
    if (trimmed.length > 4000) {
      return 'La description doit contenir au maximum 4000 caractères';
    }
    return null;
  }

  String? _validateCanonicalCity(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Merci de saisir une ville';
    }

    final best = _resolveCanonicalCityRecord(
      city: trimmed,
      postalCode: _postalCodeController.text,
    );
    if (best == null) {
      return 'Choisissez une ville valide dans la liste';
    }
    return null;
  }

  String? _validatePostalCode(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (!RegExp(r'^(97\d{3}|98\d{3}|\d{5})$').hasMatch(trimmed)) {
      return 'Code postal invalide';
    }

    final best = _resolveCanonicalCityRecord(
      city: _locationController.text,
      postalCode: trimmed,
    );
    if (best == null) {
      return 'Le code postal ne correspond pas à la ville';
    }
    return null;
  }

  String _translatePublishIssue(String issue) {
    final trimmed = issue.trim();
    if (trimmed == 'Title must contain at least 10 characters') {
      return 'Le titre doit contenir au moins 10 caractères.';
    }
    if (trimmed == 'Title must contain at most 120 characters') {
      return 'Le titre doit contenir au maximum 120 caractères.';
    }
    if (trimmed == 'Description must contain at least 30 characters') {
      return 'La description doit contenir au moins 30 caractères.';
    }
    if (trimmed == 'Description must contain at most 4000 characters') {
      return 'La description doit contenir au maximum 4000 caractères.';
    }
    if (trimmed == 'Price must be a positive number') {
      return 'Le budget doit être supérieur ou égal à 0.';
    }
    if (trimmed == 'categoryId is required') {
      return 'Choisissez une catégorie valide.';
    }
    if (trimmed == 'Category is invalid or inactive' ||
        trimmed == 'category is invalid or inactive') {
      return 'La catégorie sélectionnée n’est plus disponible. Choisissez une autre catégorie.';
    }
    if (trimmed == 'cityId is required') {
      return 'Choisissez une ville valide.';
    }
    if (trimmed == 'City is invalid or inactive' ||
        trimmed == 'city is invalid or inactive') {
      return 'La ville sélectionnée n’est plus disponible. Choisissez une ville valide dans la liste.';
    }
    if (trimmed == 'reCAPTCHA assessment rejected the listing submission') {
      return 'La vérification anti-abus a échoué. Réessaie dans quelques secondes.';
    }
    if (trimmed == 'Authentication required.' || trimmed == 'unauthenticated') {
      return 'Connecte-toi pour utiliser la dictée.';
    }
    if (trimmed == 'storagePath does not belong to authenticated user.' ||
        trimmed == 'permission-denied') {
      return 'Cette dictée ne correspond plus à ta session. Recharge la page puis réessaie.';
    }
    if (trimmed == 'Audio file is empty.') {
      return 'Le micro n\'a capté aucun son exploitable. Réessaie en parlant plus près du micro.';
    }
    if (trimmed.startsWith('Audio trop court/faible')) {
      return 'L\'audio est trop court pour être transcrit. Parle un peu plus longtemps puis réessaie.';
    }
    if (trimmed.startsWith('Type audio invalide')) {
      return 'Le format audio envoyé au serveur est invalide. Recharge la page puis réessaie.';
    }
    if (trimmed == 'Too many listing submissions, please retry later') {
      return 'Trop de tentatives de publication en peu de temps. Réessaie plus tard.';
    }
    if (trimmed == 'Draft not found') {
      return 'Le brouillon de publication est introuvable. Relance la publication.';
    }
    if (trimmed == 'You do not own this draft') {
      return 'Ce brouillon ne correspond pas à ton compte connecté.';
    }
    if (trimmed.startsWith('Photo #') &&
        trimmed.endsWith('must be processed as WebP before submission')) {
      final number = RegExp(r'Photo #(\d+)').firstMatch(trimmed)?.group(1);
      return number == null
          ? 'Une photo doit être retraitée avant publication. Réessayez.'
          : 'La photo $number doit être retraitée avant publication. Réessayez.';
    }
    if (trimmed == 'Draft payload is invalid') {
      return 'Le formulaire de publication est invalide.';
    }
    return trimmed;
  }

  String _formatPublishError(Object error) {
    if (error is FirebaseFunctionsException) {
      final details = error.details;
      if (details is Map) {
        final rawIssues = details['issues'];
        if (rawIssues is List) {
          final issues = rawIssues
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .map(_translatePublishIssue)
              .toList(growable: false);
          if (issues.isNotEmpty) {
            return issues.join(' ');
          }
        }
      }

      final message = (error.message ?? error.code).trim();
      return _translatePublishIssue(message);
    }

    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('StateError: ', '');
  }

  bool _requiredOk() {
    final titleOk = _validatePublishTitle(_titleController.text) == null;
    final descOk =
        _validatePublishDescription(_descriptionController.text) == null;
    final cityOk = _locationController.text.trim().isNotEmpty;
    final catOk = (_category ?? '').trim().isNotEmpty;
    const subOk = true;
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

  Iterable<String> get _requiredPublishFieldOrder => const <String>[
        'title',
        'category',
        'description',
        'city',
        'phone',
        'delay',
        'budget',
      ];

  GlobalKey _publishFieldKeyFor(String fieldId) {
    switch (fieldId) {
      case 'title':
        return _titleFieldKey;
      case 'category':
        return _categoryFieldKey;
      case 'description':
        return _descriptionFieldKey;
      case 'city':
        return _cityFieldKey;
      case 'phone':
        return _phoneFieldKey;
      case 'delay':
        return _delayFieldKey;
      case 'budget':
        return _budgetFieldKey;
      default:
        return GlobalKey();
    }
  }

  String _publishFieldLabel(String fieldId) {
    switch (fieldId) {
      case 'title':
        return 'titre';
      case 'category':
        return 'catégorie';
      case 'description':
        return 'description';
      case 'city':
        return 'ville';
      case 'phone':
        return 'téléphone';
      case 'delay':
        return 'délai';
      case 'budget':
        return 'budget';
      default:
        return fieldId;
    }
  }

  bool _isPublishFieldInvalid(String fieldId) {
    switch (fieldId) {
      case 'title':
        return _validatePublishTitle(_titleController.text) != null;
      case 'category':
        return (_category ?? '').trim().isEmpty;
      case 'description':
        return _validatePublishDescription(_descriptionController.text) != null;
      case 'city':
        return _validateCanonicalCity(_locationController.text) != null;
      case 'phone':
        return !_isValidPhoneFR(_phoneController.text);
      case 'delay':
        return (_missionDelay ?? '').trim().isEmpty;
      case 'budget':
        if (_budgetType == 'À négocier') return false;
        final budget = _parseBudget(_budgetController.text);
        return budget == null || budget <= 0;
      default:
        return false;
    }
  }

  List<String> _missingPublishFieldLabels() {
    return _requiredPublishFieldOrder
        .where(_isPublishFieldInvalid)
        .map(_publishFieldLabel)
        .toList(growable: false);
  }

  Future<void> _scrollToFirstInvalidPublishField() async {
    for (final fieldId in _requiredPublishFieldOrder) {
      if (!_isPublishFieldInvalid(fieldId)) continue;
      _triggerPublishFieldShake(fieldId);
      final targetContext = _publishFieldKeyFor(fieldId).currentContext;
      if (targetContext != null) {
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: 0.18,
        );
      }
      break;
    }
  }

  void _triggerPublishFieldShake(String fieldId) {
    final tick = _publishShakeTick + 1;
    if (mounted) {
      setState(() {
        _publishShakeTick = tick;
        _shakingPublishFieldId = fieldId;
      });
    }

    Future<void>.delayed(const Duration(milliseconds: 520), () {
      if (!mounted) return;
      if (_publishShakeTick != tick) return;
      setState(() {
        _shakingPublishFieldId = null;
      });
    });
  }

  Widget _withPublishFieldHighlight({
    required String fieldId,
    required Widget child,
  }) {
    final invalid = _attemptedSubmit && _isPublishFieldInvalid(fieldId);
    final isShaking = _shakingPublishFieldId == fieldId;

    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('publish-field-$fieldId-$_publishShakeTick'),
      tween: Tween<double>(begin: 0, end: isShaking ? 1 : 0),
      duration: const Duration(milliseconds: 420),
      builder: (context, value, animatedChild) {
        final dx =
            isShaking ? math.sin(value * math.pi * 6) * (1 - value) * 12 : 0.0;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: animatedChild,
        );
      },
      child: AnimatedContainer(
        key: _publishFieldKeyFor(fieldId),
        duration: const Duration(milliseconds: 180),
        padding: invalid ? const EdgeInsets.all(6) : EdgeInsets.zero,
        decoration: invalid
            ? BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDC2626), width: 1.4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1FDC2626),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              )
            : null,
        child: child,
      ),
    );
  }

  Widget _buildPublishValidationBanner() {
    final missing = _missingPublishFieldLabels();
    if (!_attemptedSubmit || missing.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFC78F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFB45309),
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Complète les champs mis en évidence : ${missing.join(', ')}.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
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
    final user = await _resolveSignedInUser();
    if (user != null) return true;
    if (!mounted) return false;
    final overlayTheme = context.prestoOverlayTheme;

    final startInSignup = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: overlayTheme.surfaceColor,
      shape: overlayTheme.sheetShape,
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

    return (await _resolveSignedInUser()) != null;
  }

  Future<User?> _resolveSignedInUser() async {
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    if (currentUser != null) {
      SessionState.userId = currentUser.uid;
      return currentUser;
    }

    try {
      final streamedUser = await auth
          .authStateChanges()
          .firstWhere((candidate) => candidate != null)
          .timeout(const Duration(seconds: 5));
      if (streamedUser != null) {
        SessionState.userId = streamedUser.uid;
      }
      return streamedUser;
    } catch (_) {
      return null;
    }
  }

  Future<User?> _ensureProtectedSessionReady({
    bool forceRefreshToken = false,
  }) async {
    final user = await _resolveSignedInUser();
    if (user == null) return null;

    try {
      await user.getIdToken(forceRefreshToken);
    } catch (_) {}

    SessionState.userId = user.uid;
    return FirebaseAuth.instance.currentUser ?? user;
  }

  Future<void> _onPublishPressed() async {
    final loggedIn = await _ensureLoggedInForPublish();
    if (!loggedIn) return;

    await _prefillPublishPhoneFromProfileIfNeeded();

    _canonicalizeLocationInputs();

    setState(() {
      _attemptedSubmit = true;
      _publishLocked = true;
    });

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || !_requiredOk()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToFirstInvalidPublishField();
      });
      return;
    }

    await _submitForm();
  }

  Future<void> _startMic() async {
    if (_isListening) return;
    if (_adminAudioRuntimeAccessState == 0) {
      unawaited(_refreshAdminAudioRuntimeAccess());
    }
    _resetPublishAiTrace(kIsWeb ? 'micro web classique' : 'micro mobile classique');
    _appendPublishAiTrace('start_mic', 'Demande de démarrage du micro classique');

    final appCheckReady = await _ensureAppCheckReady(
      flow: kIsWeb ? 'webMic' : 'mobileMic',
    );
    if (!appCheckReady) return;

    // ✅ Micro global: on ne fait PLUS speech_to_text (trop variable)
    // On enregistre l'audio puis _stopMic() déclenche le pipeline IA unifié.
    if (kIsWeb) {
      try {
        final secureContext = await _requirePublishAiSecureContext(
          stage: 'webMic.start',
          forceRefreshToken: true,
        );
        if (secureContext == null) return;
        final uid = secureContext.uid;

        await CrashlyticsContext.setUserId(uid);
        await CrashlyticsContext.setKey('flow', 'webMic');

        await _webRec.start();
        _rememberAdminAudioRuntime(
          flowKey: 'classic_web',
          label: 'Micro classique web',
          detail: _classicAdminAudioRuntimeDetail(),
        );
        if (!mounted) return;
        setState(() => _isListening = true);
        _appendPublishAiTrace(
          'start_mic',
          'Micro web démarré',
          level: _PublishAiTraceLevel.success,
        );
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
        _appendPublishAiTrace(
          'start_mic',
          _formatMicroIaRuntimeError(e),
          level: _PublishAiTraceLevel.error,
        );
        showSuccessSnackBar(
          context,
          'Micro web indisponible: ${_formatMicroIaRuntimeError(e)}',
        );
      }
      return;
    }

    // Préparer l'enregistreur haute qualité (WAV)
    try {
      final secureContext = await _requirePublishAiSecureContext(
        stage: 'mobileMic.start',
        forceRefreshToken: true,
      );
      if (secureContext == null) return;

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
        _appendPublishAiTrace(
          'permission_micro',
          'Permission micro refusée',
          level: _PublishAiTraceLevel.error,
        );
        if (!mounted) return;
        showSuccessSnackBar(context, 'Permission micro requise');
        return;
      }
    } catch (e) {
      debugPrint('Recorder start error: $e');
      _appendPublishAiTrace(
        'start_mic',
        _formatMicroIaRuntimeError(e),
        level: _PublishAiTraceLevel.error,
      );
    }

    setState(() {
      _rememberAdminAudioRuntime(
        flowKey: 'classic_mobile',
        label: 'Micro classique mobile',
        detail: _classicAdminAudioRuntimeDetail(),
      );
      _isListening = true;
    });
    _appendPublishAiTrace(
      'start_mic',
      kIsWeb ? 'Micro en écoute' : 'Enregistrement mobile lancé en AAC/m4a',
      level: _PublishAiTraceLevel.success,
    );
  }

  Future<void> _stopMic() async {
    if (!_isListening) return;
    if (_isAnalyzing) return;
    _appendPublishAiTrace('stop_mic', 'Arrêt demandé pour le micro classique');

    if (kIsWeb) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _isAnalyzing = true;
      });

      try {
        final secureContext = await _requirePublishAiSecureContext(
          stage: 'webMic.stop',
          forceRefreshToken: true,
          showUserMessage: false,
        );
        final uid = secureContext?.uid;
        if (uid == null) throw const MicroIaClientAuthException(
          code: 'auth-missing',
          message: 'Connecte-toi pour utiliser la dictée IA.',
        );

        final blob = await _webRec.stopToBlob();
        final audioUpload = await webBlobToMicroIaUpload(
          blob,
          preferRawBytes: true,
        );
        _appendPublishAiTrace(
          'web_audio',
          'Blob converti: ${audioUpload.bytes.length} bytes, ${audioUpload.contentType}, .${audioUpload.extension}',
        );
        if (audioUpload.bytes.isEmpty) {
          throw Exception('Audio invalide (fichier vide).');
        }
        if (audioUpload.usedClientSideWavConversion &&
            audioUpload.bytes.length < 30000) {
          throw Exception(
              'Audio invalide (WAV trop petit: ${audioUpload.bytes.length} bytes).');
        }

        final transcript = await _transcribePublishAudio(
          ownerUid: uid,
          audioBytes: audioUpload.bytes,
          contentType: audioUpload.contentType,
          extension: audioUpload.extension,
        );

        if (!mounted) return;

        await _applyPublishDraftFromTranscript(transcript);
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
        _appendPublishAiTrace(
          'stop_mic',
          _formatMicroIaRuntimeError(e),
          level: _PublishAiTraceLevel.error,
        );
        if (isTimeoutError(e)) {
          showTimeoutSnackBar(context);
        } else {
          showSuccessSnackBar(
            context,
            'Erreur transcription (web): ${_formatMicroIaRuntimeError(e)}',
          );
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
      _appendPublishAiTrace(
        'mobile_audio',
        recordedPath == null
            ? 'Aucun fichier audio retourné par le recorder'
            : 'Fichier enregistré: $recordedPath',
        level: recordedPath == null
            ? _PublishAiTraceLevel.warning
            : _PublishAiTraceLevel.success,
      );
    } catch (e) {
      debugPrint('Recorder stop error: $e');
      _appendPublishAiTrace(
        'mobile_audio',
        _formatMicroIaRuntimeError(e),
        level: _PublishAiTraceLevel.error,
      );
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
        _appendPublishAiTrace(
          'stop_mic',
          _formatMicroIaRuntimeError(e),
          level: _PublishAiTraceLevel.error,
        );
        if (!mounted) return;
        if (isTimeoutError(e)) {
          showTimeoutSnackBar(context);
        } else {
          showSuccessSnackBar(
            context,
            'Erreur transcription: ${_formatMicroIaRuntimeError(e)}',
          );
        }
      } finally {
        if (mounted) setState(() => _isAnalyzing = false);
      }
      return;
    }

    if (!mounted) return;
    _appendPublishAiTrace(
      'stop_mic',
      'Arrêt sans audio exploitable',
      level: _PublishAiTraceLevel.warning,
    );
    showSuccessSnackBar(context, 'Aucun audio disponible');
  }

  /// Construire le bouton d'enregistrement au micro avec indicateur visuel
  Widget _buildMicRecordingButton() {
    return PremiumAiButton(
      onPressed: _stopMic,
      label: 'Arrêter',
      icon: Icons.stop_circle_rounded,
      gradientColors: const [
        Color(0xFFFF5A4F),
        Color(0xFFE53935),
      ],
      shadowColor: const Color(0xFFE53935),
    );
  }

  Widget _buildPublishAiStatusArea() {
    final showCloudBadge = _useCloudStt && !kIsWeb;

    if (_isListening) {
      return Center(
        key: const ValueKey('publish-ai-listening'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE53935).withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFFE53935).withOpacity(0.24),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                showCloudBadge ? Icons.cloud_upload_rounded : Icons.mic_rounded,
                size: 16,
                color: const Color(0xFFE53935),
              ),
              const SizedBox(width: 8),
              const Text(
                'Enregistrement en cours',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE53935),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isAnalyzing) {
      return Center(
        key: const ValueKey('publish-ai-analyzing'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: kPrestoBlue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: kPrestoBlue.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              showCloudBadge
                  ? const Icon(Icons.cloud_sync, size: 16, color: kPrestoBlue)
                  : SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(kPrestoBlue),
                      ),
                    ),
              const SizedBox(width: 8),
              Text(
                showCloudBadge
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
      );
    }

    return const SizedBox(
      key: ValueKey('publish-ai-idle'),
      width: double.infinity,
    );
  }

  Future<void> _uploadAndTranscribe(String localPath) async {
    // Upload vers Firebase Storage puis appel de la Cloud Function.
    // Le traitement reste côté backend pour conserver les secrets serveur.
    final secureContext = await _requirePublishAiSecureContext(
      stage: 'uploadAndTranscribe',
      forceRefreshToken: true,
      showUserMessage: false,
    );
    final uid = secureContext?.uid;
    if (uid == null) {
      _appendPublishAiTrace(
        'auth',
        'Utilisateur non connecté au moment de l\'upload',
        level: _PublishAiTraceLevel.error,
      );
      throw 'Utilisateur non connecté';
    }
    final xfile = XFile(localPath);
    final audioBytes = await xfile.readAsBytes();
    if (audioBytes.isEmpty) {
      _appendPublishAiTrace(
        'mobile_audio',
        'Fichier audio introuvable ou vide: $localPath',
        level: _PublishAiTraceLevel.error,
      );
      throw 'Fichier audio introuvable';
    }
    final lower = localPath.toLowerCase();
    final isM4a = lower.endsWith('.m4a');
    final isMp4 = lower.endsWith('.mp4');
    final ext = isM4a ? 'm4a' : (isMp4 ? 'mp4' : 'wav');
    final contentType = (isM4a || isMp4) ? 'audio/mp4' : 'audio/wav';
    _appendPublishAiTrace(
      'mobile_audio',
      'Lecture locale OK: ${audioBytes.length} bytes, $contentType, .$ext',
      level: _PublishAiTraceLevel.success,
    );
    final transcript = await _transcribePublishAudio(
      ownerUid: uid,
      audioBytes: audioBytes,
      contentType: contentType,
      extension: ext,
    );

    if (!mounted) return;

    await _applyPublishDraftFromTranscript(transcript);
  }

  /// Appelle la Cloud Function pour analyser la description avec OpenAI
  Future<void> _onTapAiAnalyze() async {
    final input = _descriptionController.text.trim();
    if (input.isEmpty) {
      showSuccessSnackBar(context, "Veuillez d'abord saisir une description");
      return;
    }

    final appCheckReady = await _ensureAppCheckReady(flow: 'publishAiAnalyze');
    if (!appCheckReady) return;

    setState(() => _isAnalyzing = true);

    try {
      _appendPublishAiTrace(
        'draft_remote',
        'Appel generateOfferDraft depuis le bouton IA',
      );
      final draft = await _aiService.generateOfferDraft(text: input);

      if (!mounted) return;

      if (draft['success'] == true) {
        _applyDraftToForm(draft);
        _applyKeywordCategoryPairFromText(input);

        showSuccessSnackBar(
          context,
          '✨ Analyse IA complétée\nChamps remplis automatiquement',
        );
        return;
      }

      final code = (draft['code'] ?? '').toString();
      showSuccessSnackBar(
        context,
        code == 'deadline-exceeded'
            ? 'Connexion lente, réessaie.'
            : 'Erreur IA: ${(draft['error'] ?? 'inconnue').toString()}',
      );
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        "Erreur lors de l'analyse : ${_formatMicroIaRuntimeError(e)}",
      );
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  void dispose() {
    _publishAiTraceDisposed = true;
    _publishAiTraceVersion.dispose();
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
      _latestRecognizedTranscript = '';
      _titleEditedByUser = false;
      _descriptionEditedByUser = false;
      _locationEditedByUser = false;
      _postalCodeEditedByUser = false;
      _categoryEditedByUser = false;
      _delayEditedByUser = false;
      _budgetEditedByUser = false;
      _isApplyingProgrammaticPublishUpdate = false;
      _publishAiTraceEntries.clear();
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
    unawaited(_prefillPublishPhoneFromProfileIfNeeded());
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

  void _applyCity(CityRecord city, {bool markAsUserEdited = false}) {
    setState(() {
      if (markAsUserEdited || !_locationEditedByUser) {
        _setControllerText(_locationController, city.name);
      }
      if (markAsUserEdited || !_postalCodeEditedByUser) {
        _setControllerText(_postalCodeController, city.cp);
      }

      _selectedDeptCode = city.dept;
      _selectedRegionCode = city.region;
      _selectedPhoneCountryCode = _countryCodeForDept(city.dept);
      if (markAsUserEdited) {
        _locationEditedByUser = true;
        _postalCodeEditedByUser = true;
      }

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
            onTap: () => _applyCity(city, markAsUserEdited: true),
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
    final overlayTheme = context.prestoOverlayTheme;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: overlayTheme.surfaceColor,
          surfaceTintColor: overlayTheme.surfaceTintColor,
          shape: overlayTheme.dialogShape,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: overlayTheme.dialogRadius,
                child: Container(
                  color: overlayTheme.surfaceColor,
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
    final overlayTheme = context.prestoOverlayTheme;

    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: overlayTheme.surfaceColor,
      shape: overlayTheme.sheetShape,
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
                  title: Text(kIsWeb ? 'Fichiers / galerie' : 'Galerie'),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
                ),
                ListTile(
                  enabled: !kIsWeb,
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Appareil photo'),
                  subtitle: kIsWeb
                      ? const Text('Disponible sur mobile uniquement')
                      : null,
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
    if (_selectedPhotos.length >= _maxListingPhotos &&
        photoIndex >= _selectedPhotos.length) {
      final photoLabel = _maxListingPhotos > 1 ? 'photos' : 'photo';
      showSuccessSnackBar(
        context,
        'Maximum $_maxListingPhotos $photoLabel autorisées',
      );
      return;
    }

    try {
      final source = await _selectPhotoSource();
      if (source == null) return;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

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

  void _removePhotoAt(int photoIndex) {
    if (photoIndex < 0 || photoIndex >= _selectedPhotos.length) {
      return;
    }

    setState(() {
      _selectedPhotos.removeAt(photoIndex);
      if (photoIndex < _selectedPhotoBytes.length) {
        _selectedPhotoBytes.removeAt(photoIndex);
      }
      if (photoIndex < _uploadedPhotoUrls.length) {
        _uploadedPhotoUrls.removeAt(photoIndex);
      }
    });
  }

  String _storageExtFromPhoto(XFile photo) {
    final mime = (photo.mimeType ?? '').toLowerCase().trim();
    if (mime == 'image/webp') return 'webp';
    if (mime == 'image/png') return 'png';
    if (mime == 'image/heic' || mime == 'image/heif') return 'heic';
    if (mime == 'image/gif') return 'gif';

    final path = photo.path.toLowerCase();
    if (path.endsWith('.webp')) return 'webp';
    if (path.endsWith('.png')) return 'png';
    if (path.endsWith('.heic') || path.endsWith('.heif')) return 'heic';
    if (path.endsWith('.gif')) return 'gif';
    return 'jpg';
  }

  String _storageContentTypeFromPhoto(XFile photo) {
    final mime = (photo.mimeType ?? '').toLowerCase().trim();
    if (mime.startsWith('image/')) return mime;

    final ext = _storageExtFromPhoto(photo);
    switch (ext) {
      case 'webp':
        return 'image/webp';
      case 'png':
        return 'image/png';
      case 'heic':
        return 'image/heic';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
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
        final sourceExt = _storageExtFromPhoto(photo);
        final sourceContentType = _storageContentTypeFromPhoto(photo);
        final rawPath = 'offers_raw/$uid/${ts}_$i.$sourceExt';

        final ref = FirebaseStorage.instance.ref().child(rawPath);
        final bytes = await photo.readAsBytes();
        await ref.putData(
          bytes,
          SettableMetadata(contentType: sourceContentType),
        );

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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }
      final budgetValue = _budgetType == 'À négocier'
          ? 0.0
          : (_parseBudget(_budgetController.text) ?? 0.0);
      final publishResult = await _marketplacePublishService.publish(
        ownerId: user.uid,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category:
            _resolvePublishCategoryLabel(_category) ?? (_category ?? '').trim(),
        city: _locationController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        phone:
            '${_selectedPhoneCountryCode.trim()} ${_phoneController.text.trim()}'
                .trim(),
        subCategory: _selectedSubCategory,
        missionDelay: _missionDelay,
        isUrgent: _isUrgent,
        price: budgetValue,
        budgetType: _budgetType,
        photos: List<XFile>.from(_selectedPhotos),
      );

      // ✅ Analytics: publication
      await _logOfferPublished(
        offerId: publishResult.listingId,
        title: _titleController.text.trim(),
        category: (_category ?? '').toString().trim(),
        budget: _budgetController.text.trim(),
        budgetType: _budgetType,
      );

      // Créer des notifications pour les utilisateurs ayant cette catégorie en favori
      await _createNotificationsForFavorites(
        publishResult.listingId,
        _category ?? '',
        _selectedSubCategory,
        _titleController.text.trim(),
        user.uid,
      );

      if (!mounted) return;

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
            offer: publishResult.detailData,
            currentUserId: user.uid,
            onBackToConsult: () {
              appNavigatorKey.currentState?.pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const HomePage(initialIndex: 1),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = _formatPublishError(e);
      showErrorSnackBar(context, 'Erreur lors de la publication : $message');
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
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white,
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
                final overlayTheme = context.prestoOverlayTheme;
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: overlayTheme.surfaceColor,
                    surfaceTintColor: overlayTheme.surfaceTintColor,
                    shape: overlayTheme.dialogShape,
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
        body: SafeArea(
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
                StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  initialData: FirebaseAuth.instance.currentUser,
                  builder: (context, snapshot) {
                    final signedInUser = snapshot.data;
                    return Column(
                      children: [
                        Center(
                          child: _isListening
                              ? _buildMicRecordingButton()
                              : PremiumAiButton(
                                  onPressed: _isAnalyzing || signedInUser == null
                                      ? null
                                      : () {
                                          unawaited(_startMic());
                                        },
                                  label: 'Décrire mon besoin (IA)',
                                ),
                        ),
                        if (!_isListening && signedInUser == null) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              unawaited(_ensureLoggedInForPublish());
                            },
                            icon: const Icon(Icons.login_rounded),
                            label: const Text(
                              'Connectez-vous pour utiliser la dictée IA',
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 56,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _buildPublishAiStatusArea(),
                  ),
                ),
                if (_adminAudioRuntimeAccessState == 1) ...[
                  const SizedBox(height: 8),
                  _buildAdminAudioRuntimeIndicator(),
                ],
                _buildPublishAiTraceActions(),
                const SizedBox(height: 16),

                // TITRE
                _withPublishFieldHighlight(
                  fieldId: 'title',
                  child: _withAiPendingOverlay(
                    showPending: _showAiPendingForController(_titleController),
                    child: TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        label: _requiredLabel('Titre de l’offre'),
                        border: const OutlineInputBorder(),
                        hintText: 'Ex : Monter un meuble IKEA',
                      ),
                      validator: _validatePublishTitle,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // CATÉGORIE
                _withPublishFieldHighlight(
                  fieldId: 'category',
                  child: _withAiPendingOverlay(
                    showPending: _showAiPendingForCategory,
                    child: DropdownButtonFormField<String>(
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
                          _categoryEditedByUser = true;
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
                  ),
                ),
                const SizedBox(height: 16),

                // SOUS-CATÉGORIE (dropdown dynamique)
                if (_category != null)
                  DropdownButtonFormField<String>(
                    value: _selectedSubCategory,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    decoration: InputDecoration(
                      labelText: 'Sous-catégorie',
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
                    validator: (_) => null,
                  ),
                if (_category != null) const SizedBox(height: 16),

                // DESCRIPTION
                _withPublishFieldHighlight(
                  fieldId: 'description',
                  child: _withAiPendingOverlay(
                    showPending:
                        _showAiPendingForController(_descriptionController),
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.only(top: 14, right: 42),
                    child: TextFormField(
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
                      validator: _validatePublishDescription,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // PHOTOS
                Row(
                  children: [
                    Text(
                      'Photos de l\'offre',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '(optionnel, 2 photos maximum)',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _visiblePhotoTileCount,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final hasPhoto = index < _selectedPhotos.length;
                    return PhotoSelectorTile(
                      label: 'Photo ${index + 1}',
                      file: hasPhoto ? _selectedPhotos[index] : null,
                      bytes: hasPhoto && index < _selectedPhotoBytes.length
                          ? _selectedPhotoBytes[index]
                          : null,
                      onTap: () => _onPhotoTileTap(index),
                      onLongPress: () => _pickImage(index),
                      onRemove: hasPhoto ? () => _removePhotoAt(index) : null,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // VILLE + CP + AUTOCOMPLÉTION
                const Text(
                  'Localisation',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _withPublishFieldHighlight(
                  fieldId: 'city',
                  child: _withAiPendingOverlay(
                    showPending:
                        _showAiPendingForController(_locationController),
                    child: TextFormField(
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
                      validator: _validateCanonicalCity,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _withAiPendingOverlay(
                  showPending:
                      _showAiPendingForController(_postalCodeController),
                  child: TextFormField(
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
                    validator: _validatePostalCode,
                  ),
                ),
                _buildCitySuggestionsOverlay(),
                const SizedBox(height: 16),

                // TÉLÉPHONE avec sélection indicatif
                _withPublishFieldHighlight(
                  fieldId: 'phone',
                  child: PhoneInputFieldCompact(
                    controller: _phoneController,
                    label: _requiredLabel('Téléphone (pour être rappelé)'),
                    hintText:
                        phoneHintForCountryCode(_selectedPhoneCountryCode),
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
                ),
                const SizedBox(height: 16),

                // DÉLAI POUR EFFECTUER LA MISSION
                _withPublishFieldHighlight(
                  fieldId: 'delay',
                  child: DropdownButtonFormField<String>(
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
                      setState(() {
                        _delayEditedByUser = true;
                        _missionDelay = value;
                        _isUrgent = value == 'Urgent';
                      });
                      _recompute();
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Merci de choisir un délai';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _withPublishFieldHighlight(
                  fieldId: 'budget',
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _budgetType,
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          decoration: InputDecoration(
                            labelText: 'Type de budget',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                          items: _budgetTypes
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _budgetEditedByUser = true;
                              _budgetType = value;
                            });
                            _recompute();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _budgetController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            label: _budgetType == 'À négocier'
                                ? const Text('Budget')
                                : _requiredLabel('Budget (€)'),
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
                ),
                const SizedBox(height: 24),

                const Text(
                  '* Champs obligatoires',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 10),
                _buildPublishValidationBanner(),
                if (_attemptedSubmit && _missingPublishFieldLabels().isNotEmpty)
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
  final AdminAccessResolver _adminAccessResolver = AdminAccessResolver();

  final FirebaseFunctions _functions = prestoFirebaseFunctions;

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
  String _profilePhoneCountryCode = '+33';
  StreamSubscription<User?>? _profileAuthSub;
  String? _activeProfileUid;

  Set<String> _favoriteCategories = <String>{};
  Set<String> _selectedFavoriteCategories = <String>{};
  Set<String> _selectedFavoriteSubcategories = <String>{};
  Set<String> _draftFavoriteSelections = <String>{};
  bool _profileLoaded = false;
  bool _profileLoadRequested = false;
  bool _isSavingProfile = false;
  bool _isSigningOut = false;
  bool _isEditingProfile = false; // ✅ Mode édition du profil
  bool _isPublishedOffersExpanded = false;
  bool _isFavoriteOffersExpanded = false;
  bool _profileLoadError = false;
  int _profileLoadRetries = 0;
  static const int _maxProfileLoadRetries = 3;
  int _lastMissingRequiredCount = -1;

  static const List<String> _requiredProfileFieldLabels = <String>[
    'Pseudo',
    'Ville',
    'Numéro de téléphone',
  ];

  Future<AdminAccessState>? _adminAccessFuture;
  String? _adminAccessFutureUid;
  AdminAccessState? _lastAdminAccessState;
  Future<Map<String, dynamic>>? _adminCfgFuture;
  String? _adminCfgFutureUid;
  DateTime? _adminLastCheckedAt;

  void _resetAdminAccessState() {
    _adminAccessFuture = null;
    _adminAccessFutureUid = null;
    _lastAdminAccessState = null;
    _adminCfgFuture = null;
    _adminCfgFutureUid = null;
    _adminLastCheckedAt = null;
  }

  bool _shouldShowAdminDebugCard(
    User user, {
    AdminAccessState? state,
  }) {
    final resolvedState = state ?? _lastAdminAccessState;
    final email = (user.email ?? '').trim().toLowerCase();
    return email == 'sahai.stephane@gmail.com' ||
        (resolvedState?.effectiveIsAdmin ?? false) ||
        resolvedState?.serverErrorCode != null;
  }

  String _adminDebugText(dynamic value) {
    if (value == null) return '-';
    if (value is bool) return value ? 'oui' : 'non';
    if (value is Iterable) {
      final items = value.map((entry) => entry.toString()).toList();
      return items.isEmpty ? '-' : items.join(', ');
    }
    final text = value.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  String _adminLocalSource(AdminAccessState state) {
    final sources = <String>[];
    if (state.tokenHasAdmin) {
      sources.add('token');
    }
    if (state.profileHasAdmin) {
      sources.add('profil');
    }
    if (state.adminDocHasAdmin) {
      sources.add('adminDoc');
    }
    if (sources.isEmpty) {
      return '';
    }
    return sources.join('+');
  }

  List<String> _adminStatusMessages(AdminAccessState state) {
    final messages = <String>[];
    if (!state.isAuthenticated) {
      messages.add('Utilisateur non authentifié');
    }

    if (state.tokenHasAdmin) {
      messages.add('Accès admin confirmé par le token');
    }

    if (state.tokenHasAdmin && state.profileLoaded && !state.profileHasAdmin) {
      messages.add('Profil Firestore non synchronisé avec les claims admin');
    }

    if (state.serverCheckAttempted && !state.serverCheckSucceeded) {
      messages.add(
        state.serverErrorCode == 'unauthenticated'
            ? 'Vérification serveur temporairement indisponible'
            : 'Vérification serveur indisponible',
      );
    }
    if (state.effectiveIsAdmin &&
        state.serverCheckAttempted &&
        !state.serverCheckSucceeded) {
      messages.add('Accès admin confirmé malgré échec serveur');
    }
    return messages;
  }

  bool _adminShouldUseLocalFallback(AdminAccessState state) {
    if (!state.effectiveIsAdmin) {
      return false;
    }
    if (state.serverCheckAttempted && !state.serverCheckSucceeded) {
      return true;
    }
    return state.serverCheckSucceeded &&
        state.serverIsAdmin != true &&
        state.hasLocalAdminEvidence;
  }

  String _adminFallbackMessage(AdminAccessState state) {
    final messages = _adminStatusMessages(state);
    if (messages.isEmpty) {
      return 'Accès admin local confirmé. La vérification serveur reste complémentaire pour ce profil.';
    }
    return messages.join('. ');
  }

  void _refreshAdminAccessForUser(
    String uid, {
    bool forceRefresh = false,
  }) {
    _adminAccessFutureUid = uid;
    final future = _adminAccessResolver.resolveAdminAccess(
      forceRefresh: forceRefresh,
    );
    _adminAccessFuture = future;
    unawaited(
      future.then((state) {
        if (!mounted || _adminAccessFuture != future) {
          return;
        }
        setState(() {
          _lastAdminAccessState = state;
          _adminLastCheckedAt = state.serverCheckedAt ?? _adminLastCheckedAt;
        });
        if (state.effectiveIsAdmin) {
          unawaited(_adminAudioRuntimeStore.enableCloudSync());
        }
      }).catchError((Object error, StackTrace stackTrace) {
        debugPrint('[AdminProfile] admin access resolution failed: $error');
      }),
    );
  }

  Map<String, dynamic> _adminServerDebug(AdminAccessState state) {
    return state.serverDebug;
  }

  String _adminStateErrorDetail(AdminAccessState state) {
    final code = state.serverErrorCode?.trim();
    final message = state.serverErrorMessage?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    switch (code) {
      case 'permission-denied':
        return 'Accès refusé par la fonction admin.';
      case 'unauthenticated':
        return 'La session n’a pas encore été validée côté serveur. Recharge la page ou reconnecte-toi.';
      case 'unavailable':
        return 'Le service admin est indisponible ou le réseau ne répond pas.';
      case 'deadline-exceeded':
        return 'La vérification admin a dépassé le délai autorisé.';
      case 'internal':
        return 'La fonction admin a renvoyé une erreur interne.';
      case 'unknown':
        return 'La vérification admin a échoué de manière inattendue.';
    }
    return 'Détail indisponible.';
  }

  String _adminConfigSourceLabel(AdminAccessState state) {
    if (state.sourceOfTruth == 'none') {
      return 'inconnu';
    }
    return state.sourceOfTruth;
  }

  Future<Map<String, dynamic>> _adminGetMicroIaConfig() async {
    final sw = Stopwatch()..start();
    final callable = _functions.httpsCallable(
      'adminGetMicroIaConfig',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    try {
      await _auth.currentUser?.getIdToken(true);
      final res = await callable.call<dynamic>({});
      sw.stop();
      PrestoMonitoring.I.trackFunctionsCall(
          name: 'adminGetMicroIaConfig', ms: sw.elapsedMilliseconds);
      unawaited(_adminAudioRuntimeStore.enableCloudSync());
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      PrestoMonitoring.I.trackError('adminGetMicroIaConfig', e);
      rethrow;
    }
  }

  void _refreshAdminConfigForUser(String uid) {
    _adminCfgFutureUid = uid;
    _adminCfgFuture = _adminGetMicroIaConfig();
  }

  bool _isAdminAccessDenied(Object? error) {
    if (error is FirebaseFunctionsException) {
      return error.code == 'permission-denied' ||
          error.code == 'unauthenticated';
    }

    final errStr = error?.toString() ?? '';
    return errStr.contains('permission-denied') ||
        errStr.contains('unauthenticated');
  }

  bool _isAdminAccessUnauthenticated(Object? error) {
    if (error is FirebaseFunctionsException) {
      return error.code == 'unauthenticated';
    }

    final errStr = error?.toString() ?? '';
    return errStr.contains('unauthenticated');
  }

  String _adminErrorDetail(Object? error) {
    if (error is FirebaseFunctionsException) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }

      switch (error.code) {
        case 'permission-denied':
          return 'Accès refusé par la fonction admin.';
        case 'unauthenticated':
          return 'La session n’a pas encore été validée côté serveur. Recharge la page ou reconnecte-toi.';
        case 'unavailable':
          return 'Le service admin est indisponible ou le réseau ne répond pas.';
        case 'deadline-exceeded':
          return 'La vérification admin a dépassé le délai autorisé.';
        case 'internal':
          return 'La fonction admin a renvoyé une erreur interne.';
      }
    }

    final errStr = error?.toString().trim() ?? '';
    final errLower = errStr.toLowerCase();
    if (errLower.contains('socketexception') ||
        errLower.contains('network') ||
        errLower.contains('failed host lookup')) {
      return 'Échec réseau pendant la vérification admin.';
    }
    if (errLower.contains('timeout') ||
        errLower.contains('deadline-exceeded')) {
      return 'La vérification admin a expiré.';
    }
    if (errStr.isEmpty) {
      return 'Détail indisponible.';
    }
    return errStr;
  }

  String _adminModeStatusLabel(String mode) {
    switch (mode) {
      case 'GOOGLE_ONLY':
        return 'Google uniquement';
      case 'WHISPER_ONLY':
        return 'Whisper uniquement';
      case 'HYBRID':
      default:
        return 'Hybride';
    }
  }

  String _formatAdminCheckTime(DateTime? value) {
    if (value == null) return 'inconnu';
    String two(int v) => v.toString().padLeft(2, '0');
    final local = value.toLocal();
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  Widget _buildAdminDebugCard(
    User user, {
    required AdminAccessState state,
  }) {
    final serverDebug = _adminServerDebug(state);
    final serverCheckedAt = state.serverCheckedAt ?? _adminLastCheckedAt;
    final localSource = _adminLocalSource(state);
    final statusMessages = _adminStatusMessages(state);
    final recentSteps = state.debugSteps.length > 5
        ? state.debugSteps.sublist(state.debugSteps.length - 5)
        : state.debugSteps;
    final lines = <String>[
      'uid=${user.uid}',
      'email=${_adminDebugText(state.email ?? user.email)}',
      'localHint=${_adminDebugText(state.hasLocalAdminEvidence)}',
      'localSource=${_adminDebugText(localSource)}',
      'tokenHasAdmin=${_adminDebugText(state.tokenHasAdmin)}',
      'tokenRoles=${_adminDebugText(state.tokenRoles)}',
      'profileHasAdmin=${_adminDebugText(state.profileHasAdmin)}',
      'profileRoles=${_adminDebugText(state.profileRoles)}',
      'profilePrimaryRole=${_adminDebugText(state.profilePrimaryRole)}',
      'adminDocHasAdmin=${_adminDebugText(state.adminDocHasAdmin)}',
      'serverIsAdmin=${_adminDebugText(state.serverIsAdmin)}',
      'serverSource=${_adminDebugText(state.serverSource)}',
      'serverCheckedAt=${_formatAdminCheckTime(serverCheckedAt)}',
      'server.tokenHasAdmin=${_adminDebugText(serverDebug['tokenHasAdmin'])}',
      'server.userDocExists=${_adminDebugText(serverDebug['userDocExists'])}',
      'server.userHasAdmin=${_adminDebugText(serverDebug['userHasAdmin'])}',
      'server.userRoles=${_adminDebugText(serverDebug['userRoles'])}',
      'server.userPrimaryRole=${_adminDebugText(serverDebug['userPrimaryRole'])}',
      'server.adminDocExists=${_adminDebugText(serverDebug['adminDocExists'])}',
      'server.adminDocEnabled=${_adminDebugText(serverDebug['adminDocEnabled'])}',
      'server.errorCode=${_adminDebugText(state.serverErrorCode)}',
      'server.errorMessage=${_adminDebugText(state.serverErrorMessage)}',
      'sourceOfTruth=${_adminDebugText(state.sourceOfTruth)}',
      'lastStage=${_adminDebugText(state.lastStage)}',
      if (statusMessages.isNotEmpty) 'messages=${statusMessages.join(' | ')}',
      if (recentSteps.isNotEmpty) 'debugSteps=${recentSteps.join(' | ')}',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9DDEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report_rounded, color: Colors.black54),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Diagnostic admin visible',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _refreshAdminAccessForUser(user.uid, forceRefresh: true);
                    _adminCfgFuture = null;
                    _adminCfgFutureUid = null;
                  });
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Relancer'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            lines.join('\n'),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.35,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminLoadingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPrestoBlue.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrestoBlue.withOpacity(0.18)),
      ),
      child: Row(
        children: const [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verification admin en cours',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Chargement des droits et de la configuration Micro-IA pour ce profil.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminLoadRetryCard({
    required User user,
    required String title,
    required String message,
    String? detail,
    bool showOpenButton = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          if (detail != null && detail.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Détail: ${detail.trim()}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black45,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _refreshAdminAccessForUser(user.uid, forceRefresh: true);
                _refreshAdminConfigForUser(user.uid);
              });
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
          if (showOpenButton) ...[
            const SizedBox(height: 10),
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
                ),
              ),
            ),
          ],
        ],
      ),
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
    unawaited(_adminAudioRuntimeStore.ensureInitialized());
    // _isLoginMode = !widget.startInSignup; // Plus utilisé avec PrestoPremiumAuthPage
    _scrollController.addListener(() {
      widget.onScroll?.call(_scrollController.offset);
    });
    _profilePseudoController.addListener(_handleProfileCompletenessChanged);
    _profileCityController.addListener(_handleProfileCompletenessChanged);
    _profilePhoneController.addListener(_handleProfileCompletenessChanged);
    _profileAuthSub = _auth.idTokenChanges().listen((user) {
      if (!mounted) return;
      unawaited(_handleProfileAuthStateChanged(user));
    });

    // Sur Web, vérifie si l'utilisateur revient d'un redirect Google Sign-In
    if (kIsWeb) {
      _checkGoogleRedirectResult();
    }
  }

  void _handleProfileCompletenessChanged() {
    if (!mounted) return;
    final nextMissingCount = _missingRequiredProfileFields().length;
    if (nextMissingCount == _lastMissingRequiredCount) {
      return;
    }
    setState(() {
      _lastMissingRequiredCount = nextMissingCount;
    });
  }

  void _resetProfileState({
    bool clearControllers = true,
  }) {
    _activeProfileUid = null;
    _profileLoaded = false;
    _profileLoadRequested = false;
    _profileLoadError = false;
    _profileLoadRetries = 0;
    _lastMissingRequiredCount = -1;
    _isEditingProfile = false;
    _profilePhoneCountryCode = '+33';
    _favoriteCategories = <String>{};
    _selectedFavoriteCategories = <String>{};
    _selectedFavoriteSubcategories = <String>{};
    _draftFavoriteSelections = <String>{};
    _resetAdminAccessState();

    if (clearControllers) {
      _profilePseudoController.clear();
      _profileCityController.clear();
      _profilePhoneController.clear();
    }
  }

  Future<void> _handleProfileAuthStateChanged(User? user) async {
    if (!mounted) return;

    if (user == null) {
      SessionState.userId = null;
      setState(() {
        _resetProfileState();
      });
      return;
    }

    SessionState.userId = user.uid;

    try {
      await UserProfileBootstrapService.ensureUserDocument(
        user: user,
        authMethod: 'session_restore',
      );
    } catch (error) {
      debugPrint('[AuthBootstrap] account session restore failed: $error');
    }

    if (_activeProfileUid == user.uid &&
        (_profileLoaded || _profileLoadRequested)) {
      if (!mounted) return;
      setState(() {
        _refreshAdminAccessForUser(user.uid);
      });
      return;
    }

    setState(() {
      _resetProfileState(clearControllers: false);
      _activeProfileUid = user.uid;
      final displayName = user.displayName?.trim() ?? '';
      _profilePseudoController.text = displayName;
      _profileLoadRequested = true;
      _refreshAdminAccessForUser(user.uid, forceRefresh: true);
    });

    await _loadUserProfile(user);
  }

  bool _hasProfileValuesInMemory() {
    return _profilePseudoController.text.trim().isNotEmpty ||
        _profileCityController.text.trim().isNotEmpty ||
        _profilePhoneController.text.trim().isNotEmpty;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchUserProfileDocument(
    String uid,
  ) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    try {
      return await userRef
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint('[Profile] Fallback cache pour le profil: $error');
      return userRef
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 3));
    }
  }

  String _firstNonEmptyProfileValue(
    Map<String, dynamic>? data,
    List<String> keys, {
    List<String> fallbackValues = const <String>[],
  }) {
    if (data != null) {
      for (final key in keys) {
        final raw = data[key];
        final value = raw?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          return value;
        }
      }
    }

    for (final fallback in fallbackValues) {
      final value = fallback.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  String _normalizeProfilePhoneForSave(String countryCode, String rawPhone) {
    final codeDigits = countryCode.replaceAll(RegExp(r'\D'), '');
    var phoneDigits = rawPhone.replaceAll(RegExp(r'\D'), '');

    if (codeDigits.isEmpty || phoneDigits.isEmpty) {
      return '';
    }

    if (phoneDigits.startsWith('00')) {
      phoneDigits = phoneDigits.substring(2);
    }

    if (phoneDigits.startsWith(codeDigits)) {
      return '+$phoneDigits';
    }

    if (phoneDigits.startsWith('0')) {
      phoneDigits = phoneDigits.substring(1);
    }

    return '+$codeDigits$phoneDigits';
  }

  void _applyLoadedProfilePhone(String rawPhone) {
    final trimmed = rawPhone.trim();
    if (trimmed.isEmpty) {
      _profilePhoneCountryCode = '+33';
      _profilePhoneController.text = '';
      return;
    }

    final compact = trimmed.replaceAll(RegExp(r'\s+'), '');
    const knownCodes = <String>['+590', '+596', '+594', '+689', '+262', '+33'];

    for (final code in knownCodes) {
      if (!compact.startsWith(code)) continue;

      final codeDigits = code.replaceAll(RegExp(r'\D'), '');
      final allDigits = compact.replaceAll(RegExp(r'\D'), '');
      final localDigits = allDigits.substring(codeDigits.length);

      _profilePhoneCountryCode = code;
      _profilePhoneController.text = localDigits;
      return;
    }

    _profilePhoneCountryCode = '+33';
    _profilePhoneController.text = trimmed;
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
      var shouldShow = true;
      if (e.code == 'unauthorized-domain') {
        msg =
            "Domaine non autorisé. Ajoute ce domaine dans Firebase Console → Authentication → Authorized domains.";
      } else if (e.code == 'operation-not-allowed') {
        msg =
            "Google Sign-In non activé. Active-le dans Firebase Console → Authentication → Sign-in method.";
      } else if (e.code != 'invalid-credential' && e.code != 'no-auth-event') {
        msg = "Erreur Google : ${e.message ?? e.code}";
      } else {
        shouldShow = false;
      }

      if (shouldShow) {
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
    _profileAuthSub?.cancel();
    _profilePseudoController.removeListener(_handleProfileCompletenessChanged);
    _profileCityController.removeListener(_handleProfileCompletenessChanged);
    _profilePhoneController.removeListener(_handleProfileCompletenessChanged);
    _profilePseudoController.dispose();
    _profileCityController.dispose();
    _profilePhoneController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Ancienne méthode - maintenant gérée par PrestoPremiumAuthPage

  Future<void> _loadUserProfile(User user, {int attempt = 0}) async {
    final previousPseudo = _profilePseudoController.text.trim();
    final previousCity = _profileCityController.text.trim();
    final previousPhoneCountryCode = _profilePhoneCountryCode;
    final previousPhone = _profilePhoneController.text.trim();
    final previousFavoriteCategories = _favoriteCategories.toSet();
    final previousSelectedFavoriteCategories =
        _selectedFavoriteCategories.toSet();
    final previousSelectedFavoriteSubcategories =
        _selectedFavoriteSubcategories.toSet();
    final previousDraftFavoriteSelections = _draftFavoriteSelections.toSet();

    try {
      await EmailActionService.syncCurrentUserEmailVerificationState();
    } catch (e) {
      debugPrint('[Profile] Erreur synchro emailVerified: $e');
    }

    try {
      final doc = await _fetchUserProfileDocument(user.uid);

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _profilePseudoController.text = _firstNonEmptyProfileValue(
          data,
          const ['pseudo', 'displayName', 'userName', 'user_name', 'name'],
          fallbackValues: <String>[user.displayName ?? '', previousPseudo],
        );
        _profileCityController.text = _firstNonEmptyProfileValue(
          data,
          const ['city', 'location', 'serviceArea', 'service_area'],
          fallbackValues: <String>[previousCity],
        );

        final loadedPhone = _firstNonEmptyProfileValue(
          data,
          const ['phone', 'phoneNumber', 'phone_number'],
          fallbackValues: <String>[user.phoneNumber ?? ''],
        );
        if (loadedPhone.isNotEmpty) {
          _applyLoadedProfilePhone(loadedPhone);
        } else if (previousPhone.isNotEmpty) {
          _profilePhoneCountryCode = previousPhoneCountryCode;
          _profilePhoneController.text = previousPhone;
        } else {
          _applyLoadedProfilePhone('');
        }

        final favs = (data['favoriteCategories'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();
        final hasFavoriteCategoriesKey = data.containsKey('favoriteCategories');
        _favoriteCategories = hasFavoriteCategoriesKey
            ? favs.toSet()
            : previousFavoriteCategories;
        _draftFavoriteSelections = hasFavoriteCategoriesKey
            ? _favoriteCategories.toSet()
            : previousDraftFavoriteSelections;
        final selectedCats =
            (data['selectedFavoriteCategories'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();
        final hasSelectedFavoriteCategoriesKey =
            data.containsKey('selectedFavoriteCategories');
        _selectedFavoriteCategories = hasSelectedFavoriteCategoriesKey
            ? selectedCats.toSet()
            : previousSelectedFavoriteCategories;
        final selectedSubcats =
            (data['selectedFavoriteSubcategories'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();
        final hasSelectedFavoriteSubcategoriesKey =
            data.containsKey('selectedFavoriteSubcategories');
        _selectedFavoriteSubcategories = hasSelectedFavoriteSubcategoriesKey
            ? selectedSubcats.toSet()
            : previousSelectedFavoriteSubcategories;

        final hasStoredFavorites = hasFavoriteCategoriesKey ||
            hasSelectedFavoriteCategoriesKey ||
            hasSelectedFavoriteSubcategoriesKey;
        final mergedFavoriteSelections = <String>{
          ...favs,
          ...selectedCats,
          ...selectedSubcats,
        };
        if (hasStoredFavorites) {
          _favoriteCategories = mergedFavoriteSelections;
          _draftFavoriteSelections = mergedFavoriteSelections.toSet();
        }

        // ✅ Si les champs sont remplis, ne pas être en mode édition par défaut
        final hasProfile = _hasProfileValuesInMemory();
        _isEditingProfile = !hasProfile;
        _profileLoadError = false;
        _profileLoadRetries = 0;
      } else {
        _profilePseudoController.text =
            user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : previousPseudo;
        _profileCityController.text = previousCity;
        if (previousPhone.isNotEmpty) {
          _profilePhoneCountryCode = previousPhoneCountryCode;
          _profilePhoneController.text = previousPhone;
        }
        _favoriteCategories = previousFavoriteCategories;
        _selectedFavoriteCategories = previousSelectedFavoriteCategories;
        _selectedFavoriteSubcategories = previousSelectedFavoriteSubcategories;
        _draftFavoriteSelections = previousDraftFavoriteSelections;
        _isEditingProfile = !_hasProfileValuesInMemory();
        _profileLoadError = false;
      }
    } catch (e) {
      debugPrint('[Profile] Erreur chargement profil: $e');

      // Retry automatique jusqu'à 3 fois
      if (attempt < _maxProfileLoadRetries) {
        _profileLoadRetries = attempt + 1;
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          await _loadUserProfile(user, attempt: attempt + 1);
          return;
        }
      }

      if (previousPseudo.isNotEmpty && _profilePseudoController.text.isEmpty) {
        _profilePseudoController.text = previousPseudo;
      }
      if (previousCity.isNotEmpty && _profileCityController.text.isEmpty) {
        _profileCityController.text = previousCity;
      }
      if (previousPhone.isNotEmpty && _profilePhoneController.text.isEmpty) {
        _profilePhoneCountryCode = previousPhoneCountryCode;
        _profilePhoneController.text = previousPhone;
      }

      _favoriteCategories = previousFavoriteCategories;
      _selectedFavoriteCategories = previousSelectedFavoriteCategories;
      _selectedFavoriteSubcategories = previousSelectedFavoriteSubcategories;
      _draftFavoriteSelections = previousDraftFavoriteSelections;
      _profileLoadError = true;
      _isEditingProfile = !_hasProfileValuesInMemory();
    }

    if (mounted) {
      setState(() {
        _lastMissingRequiredCount = _missingRequiredProfileFields().length;
        _profileLoaded = true;
        _profileLoadRequested = true;
      });
    }
  }

  bool _validateProfile() {
    final pseudo = _profilePseudoController.text.trim();
    final city = _profileCityController.text.trim();
    final phone = _profilePhoneController.text.trim();
    final normalizedPhone =
        _normalizeProfilePhoneForSave(_profilePhoneCountryCode, phone);

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

    if (city.isEmpty) {
      showErrorSnackBar(context, "La ville est obligatoire");
      return false;
    }

    if (phone.isEmpty) {
      showErrorSnackBar(context, "Le numéro de téléphone est obligatoire");
      return false;
    }

    if (!RegExp(r'^\+[0-9]{10,15}$').hasMatch(normalizedPhone)) {
      showErrorSnackBar(
          context, "Le numéro de téléphone doit contenir 10-15 chiffres");
      return false;
    }

    return true;
  }

  List<String> _missingRequiredProfileFields() {
    final missing = <String>[];

    if (_profilePseudoController.text.trim().isEmpty) {
      missing.add('pseudo');
    }
    if (_profileCityController.text.trim().isEmpty) {
      missing.add('ville');
    }
    if (_profilePhoneController.text.trim().isEmpty) {
      missing.add('numéro de téléphone');
    }

    return missing;
  }

  double _calculateProfileCompleteness() {
    final missingCount = _missingRequiredProfileFields().length;
    final filled = _requiredProfileFieldLabels.length - missingCount;
    return filled / _requiredProfileFieldLabels.length;
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
      final normalizedPhone =
          _normalizeProfilePhoneForSave(_profilePhoneCountryCode, phone);

      final profileData = <String, dynamic>{
        'pseudo': pseudo,
        'displayName': pseudo,
        'userName': pseudo,
        'user_name': pseudo,
        'name': pseudo,
        'city': city,
        'location': city,
        'serviceArea': city,
        'service_area': city,
        'phone': normalizedPhone,
        'phoneNumber': normalizedPhone,
        'phone_number': normalizedPhone,
        'phoneCountryCode': _profilePhoneCountryCode,
        'favoriteCategories': _favoriteCategories.toList(),
        'selectedFavoriteCategories': _selectedFavoriteCategories.toList(),
        'selectedFavoriteSubcategories':
            _selectedFavoriteSubcategories.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
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
          await user.reload().timeout(
                const Duration(seconds: 5),
              );
        } catch (e) {
          debugPrint('[Profile] Erreur mise à jour displayName: $e');
          // Continue même si échoue
        }
      }

      final refreshedUser = FirebaseAuth.instance.currentUser ?? user;
      try {
        await _loadUserProfile(refreshedUser);
      } catch (e) {
        debugPrint('[Profile] Erreur rechargement profil après sauvegarde: $e');
      }

      // ✅ Vérifier l'email si pas encore vérifié
      if (!refreshedUser.emailVerified && refreshedUser.email != null) {
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
    } on FirebaseException catch (e) {
      if (mounted) {
        String errorMsg = 'Erreur lors de la sauvegarde du profil';
        if (e.code == 'permission-denied') {
          errorMsg = 'Vous n\'êtes pas autorisé à modifier ce profil';
        } else if (e.code == 'unavailable') {
          errorMsg = 'Service indisponible. Réessayez dans un instant';
        } else if (e.code == 'deadline-exceeded') {
          errorMsg = 'Délai d\'attente dépassé. Vérifiez votre connexion';
        } else if ((e.message ?? '').trim().isNotEmpty) {
          errorMsg = e.message!.trim();
        }
        showErrorSnackBar(context, errorMsg);
      }
      return false;
    } on TimeoutException {
      if (mounted) {
        showErrorSnackBar(
          context,
          'Délai d\'attente dépassé. Vérifiez votre connexion',
        );
      }
      return false;
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Erreur lors de la sauvegarde du profil');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  void _mutateDraftCategory(
    String category, {
    Set<String>? selections,
  }) {
    final targetSelections = selections ?? _draftFavoriteSelections;

    if (targetSelections.contains(category)) {
      targetSelections.remove(category);
      targetSelections.removeWhere((e) => e.startsWith('$category — '));
    } else {
      targetSelections.add(category);
    }
  }

  void _mutateDraftSubcategory({
    required String category,
    required String subcategory,
    Set<String>? selections,
  }) {
    final targetSelections = selections ?? _draftFavoriteSelections;
    final label = '$category — $subcategory';
    if (targetSelections.contains(label)) {
      targetSelections.remove(label);
    } else {
      targetSelections.add(category);
      targetSelections.add(label);
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
    var workingSelections = _draftFavoriteSelections.toSet();
    final overlayTheme = context.prestoOverlayTheme;

    final validatedSelections = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: overlayTheme.surfaceColor,
      shape: overlayTheme.sheetShape,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.65,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Text(
                        'Choisir des catégories',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: _allFavoriteCategories.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (_, index) {
                          final cat = _allFavoriteCategories[index];
                          final selected = workingSelections.contains(cat);

                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            selected: selected,
                            selectedTileColor: overlayTheme.selectionFillColor,
                            iconColor: overlayTheme.selectionAccentColor,
                            title: Text(
                              cat,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            trailing: selected
                                ? Icon(
                                    Icons.check,
                                    color: overlayTheme.selectionAccentColor,
                                  )
                                : null,
                            onTap: () {
                              sheetSetState(() {
                                workingSelections = workingSelections.toSet();
                                _mutateDraftCategory(
                                  cat,
                                  selections: workingSelections,
                                );
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.of(ctx).pop(workingSelections.toSet()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrestoBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Valider',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (validatedSelections != null && mounted) {
      setState(() {
        _draftFavoriteSelections = validatedSelections.toSet();
      });
    }
  }

  Future<void> _openSubcategoryPickerSheet() async {
    var workingSelections = _draftFavoriteSelections.toSet();
    final overlayTheme = context.prestoOverlayTheme;

    final validatedSelections = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: overlayTheme.surfaceColor,
      shape: overlayTheme.sheetShape,
      builder: (ctx) {
        final selectedCategories =
            workingSelections.where((e) => !e.contains('—')).toList();
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
            final visibleCategories =
                workingSelections.where((e) => !e.contains('—')).toList();
            final items =
                <({String category, String? subcategory, bool isHeader})>[];
            for (final category in visibleCategories) {
              items
                  .add((category: category, subcategory: null, isHeader: true));
              final subs =
                  _subCategoriesByCategory[category] ?? const <String>[];
              for (final sub in subs) {
                items.add(
                    (category: category, subcategory: sub, isHeader: false));
              }
            }

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.65,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Text(
                        'Choisir des sous-catégories',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (_, index) {
                          final item = items[index];
                          if (item.isHeader) {
                            return Padding(
                              padding:
                                  const EdgeInsets.only(top: 10, bottom: 6),
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
                          final selected = workingSelections.contains(label);

                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            selected: selected,
                            selectedTileColor: overlayTheme.selectionFillColor,
                            iconColor: overlayTheme.selectionAccentColor,
                            title: Text(
                              sub,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            trailing: selected
                                ? Icon(
                                    Icons.check,
                                    color: overlayTheme.selectionAccentColor,
                                  )
                                : null,
                            onTap: () {
                              sheetSetState(() {
                                workingSelections = workingSelections.toSet();
                                _mutateDraftSubcategory(
                                  category: item.category,
                                  subcategory: sub,
                                  selections: workingSelections,
                                );
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.of(ctx).pop(workingSelections.toSet()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrestoBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Valider',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (validatedSelections != null && mounted) {
      setState(() {
        _draftFavoriteSelections = validatedSelections.toSet();
      });
    }
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
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);
    try {
      await NotificationService().detachCurrentDevice();
      await _auth.signOut().timeout(const Duration(seconds: 10));
      SessionState.userId = null;
      sessionState.logOut();
      await CrashlyticsContext.setUserId(null);

      if (!mounted) return;
      showSuccessSnackBar(context, 'Déconnecté');
    } on TimeoutException {
      if (!mounted) return;
      showErrorSnackBar(context, 'La déconnexion a expiré. Réessayez.');
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur de déconnexion : $error');
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  // Ancienne méthode _buildProfile supprimée - remplacée par PrestoPremiumAuthPage pour l'auth

  Widget _buildAccountSectionCard({
    required IconData icon,
    required String title,
    required String description,
    required Widget child,
    bool isExpanded = true,
    VoidCallback? onToggle,
  }) {
    final isCollapsible = onToggle != null;
    final header = Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: kPrestoBlue.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: kPrestoBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF16324F),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (isCollapsible)
          Icon(
            isExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: const Color(0xFF16324F),
          ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPrestoBlue.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCollapsible)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(16),
                child: header,
              ),
            )
          else
            header,
          if (!isCollapsible || isExpanded) ...[
            const SizedBox(height: 14),
            child,
          ],
        ],
      ),
    );
  }

  Widget _buildProfile(User user) {
    // ✅ SessionState.userId est maintenant synchronisé automatiquement via authStateChanges()
    // Lier les crash reports à l'utilisateur connecté
    CrashlyticsContext.setUserId(user.uid);

    if (_activeProfileUid != user.uid ||
        (!_profileLoaded && !_profileLoadRequested)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_handleProfileAuthStateChanged(user));
      });
    }

    final pseudo = _profilePseudoController.text.trim();
    final displayName = pseudo.isNotEmpty
        ? pseudo
        : (user.displayName ?? "Utilisateur iliprestō");
    final draftCategoryLabels = _draftFavoriteSelections
        .where((entry) => !entry.contains('—'))
        .toList()
      ..sort();
    final draftSubcategoryLabels = _draftFavoriteSelections
        .where((entry) => entry.contains('—'))
        .toList()
      ..sort();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
                            backgroundColor: Colors.white,
                            backgroundImage: user.photoURL != null &&
                                    user.photoURL!.trim().isNotEmpty
                                ? NetworkImage(user.photoURL!.trim())
                                : const AssetImage(
                                    'assets/images/logowebp.webp',
                                  ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Bon retour sur iliprestō',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
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
                            Builder(
                              builder: (context) {
                                final completeness =
                                    _calculateProfileCompleteness();
                                final missingFields =
                                    _missingRequiredProfileFields();
                                final isComplete = missingFields.isEmpty;

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          value: completeness,
                                          minHeight: 6,
                                          backgroundColor: Colors.grey.shade300,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            completeness >= 1.0
                                                ? Colors.green
                                                : completeness >= 0.75
                                                    ? Colors.orange
                                                    : Colors.red,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${(completeness * 100).toStringAsFixed(0)}% complet',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Champs requis : ${_requiredProfileFieldLabels.join(', ')}.',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isComplete
                                            ? 'Tous les champs requis sont renseignés.'
                                            : 'Champ${missingFields.length > 1 ? 's' : ''} requis manquant${missingFields.length > 1 ? 's' : ''} : ${missingFields.join(', ')}.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isComplete
                                              ? Colors.green.shade700
                                              : Colors.red.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
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
                      phoneCountryCode: _profilePhoneCountryCode,
                      isEditing: _isEditingProfile,
                      isSaving: _isSavingProfile,
                      onStartEditing: () {
                        setState(() => _isEditingProfile = true);
                      },
                      onPhoneCountryCodeChanged: (code) {
                        if (!mounted || _profilePhoneCountryCode == code)
                          return;
                        setState(() => _profilePhoneCountryCode = code);
                      },
                      onSave: () {
                        _saveProfile(user);
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildAccountSectionCard(
                      icon: Icons.campaign_outlined,
                      title: 'Gérer mes annonces',
                      description:
                          'Retrouve tes annonces par statut, modifie-les ou supprime-les avec confirmation.',
                      isExpanded: _isPublishedOffersExpanded,
                      onToggle: () {
                        setState(() {
                          _isPublishedOffersExpanded =
                              !_isPublishedOffersExpanded;
                        });
                      },
                      child: RepaintBoundary(
                        child: UserOffersSection(
                          userId: user.uid,
                          showTitle: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAccountSectionCard(
                      icon: Icons.favorite_border_rounded,
                      title: 'Mes annonces favorites',
                      description:
                          'Retrouve les annonces enregistrées pour plus tard.',
                      isExpanded: _isFavoriteOffersExpanded,
                      onToggle: () {
                        setState(() {
                          _isFavoriteOffersExpanded =
                              !_isFavoriteOffersExpanded;
                        });
                      },
                      child: RepaintBoundary(
                        child: FavoriteOffersSection(
                          userId: user.uid,
                          showTitle: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAccountSectionCard(
                      icon: Icons.tune_rounded,
                      title: 'Mes alertes "Nouvelle annonce"',
                      description:
                          'Organise les alertes qui correspondent à tes préférences.',
                      child: RepaintBoundary(
                        child: AccountFavoriteCategoriesSection(
                          categoriesCount: draftCategoryLabels.length,
                          subcategoriesCount: draftSubcategoryLabels.length,
                          selectedCategories: draftCategoryLabels,
                          selectedSubcategories: draftSubcategoryLabels,
                          isSaving: _isSavingProfile,
                          showTitle: false,
                          onOpenCategoryPicker: _openCategoryPickerSheet,
                          onOpenSubcategoryPicker: _openSubcategoryPickerSheet,
                          onApply: () => _applyDraftFavorites(user),
                        ),
                      ),
                    ),
                    RepaintBoundary(
                      child: const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 28),
                    _buildAdminSpaceEntry(user),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSigningOut ? null : _signOut,
                        icon: _isSigningOut
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.logout),
                        label: Text(
                          _isSigningOut ? 'Déconnexion...' : 'Se déconnecter',
                          style: const TextStyle(
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
    );
  }

  Widget _buildAdminSpaceEntry(User user) {
    if (_adminAccessFuture == null || _adminAccessFutureUid != user.uid) {
      _refreshAdminAccessForUser(user.uid);
    }

    return FutureBuilder<AdminAccessState>(
      future: _adminAccessFuture,
      builder: (context, accessSnapshot) {
        final resolvedState = accessSnapshot.data ?? _lastAdminAccessState;

        if (accessSnapshot.hasError) {
          final retryCard = _buildAdminLoadRetryCard(
            user: user,
            title: 'Espace admin indisponible',
            message:
                'Le chargement du profil admin a échoué temporairement. Réessaie pour vérifier l’accès.',
            detail: _adminErrorDetail(accessSnapshot.error),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              retryCard,
              if (resolvedState != null &&
                  _shouldShowAdminDebugCard(user, state: resolvedState))
                _buildAdminDebugCard(user, state: resolvedState),
            ],
          );
        }

        if (accessSnapshot.connectionState == ConnectionState.waiting &&
            resolvedState == null) {
          final loadingCard = _buildAdminLoadingCard();
          if (_shouldShowAdminDebugCard(user)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                loadingCard,
                if (resolvedState != null)
                  _buildAdminDebugCard(user, state: resolvedState),
              ],
            );
          }
          return loadingCard;
        }

        final accessState = resolvedState ?? AdminAccessState.initial();

        if (accessSnapshot.connectionState == ConnectionState.waiting) {
          final loadingCard = _buildAdminLoadingCard();
          if (_shouldShowAdminDebugCard(user, state: accessState)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                loadingCard,
                _buildAdminDebugCard(user, state: accessState),
              ],
            );
          }
          return loadingCard;
        }

        if (!accessState.effectiveIsAdmin) {
          if (_shouldShowAdminDebugCard(user, state: accessState)) {
            return _buildAdminDebugCard(user, state: accessState);
          }
          return const SizedBox.shrink();
        }

        if (_adminShouldUseLocalFallback(accessState)) {
          final fallbackCard = _buildAdminLocalFallbackCard(
            user: user,
            state: accessState,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              fallbackCard,
              if (_shouldShowAdminDebugCard(user, state: accessState))
                _buildAdminDebugCard(user, state: accessState),
            ],
          );
        }

        if (_adminCfgFuture == null || _adminCfgFutureUid != user.uid) {
          _refreshAdminConfigForUser(user.uid);
        }

        return FutureBuilder<Map<String, dynamic>>(
          future: _adminCfgFuture,
          builder: (context, cfgSnapshot) {
            final cfg = cfgSnapshot.data ?? const <String, dynamic>{};
            final mode = (cfg['mode'] ?? _adminAudioRuntimeStore.configuredMode)
                .toString();
            if (cfgSnapshot.hasData) {
              _adminAudioRuntimeStore.updateConfiguredMode(mode);
            }

            final configLoaded = cfgSnapshot.hasData;
            final configError = cfgSnapshot.hasError;

            final adminCard = Container(
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          'Verifie',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    configLoaded
                        ? 'Acces admin confirme pour ce profil. Source: ${_adminConfigSourceLabel(accessState)}. Mode serveur actuel: ${_adminModeStatusLabel(mode)}.'
                        : 'Acces admin confirme pour ce profil. La configuration serveur est en cours de chargement.',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Dernier controle: ${_formatAdminCheckTime(_adminLastCheckedAt)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black45,
                      fontSize: 12,
                    ),
                  ),
                  if (configError) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Config Micro-IA indisponible: ${_adminErrorDetail(cfgSnapshot.error)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (accessState.sourceOfTruth != 'none') ...[
                    const SizedBox(height: 6),
                    Text(
                      'Source droits admin: ${_adminConfigSourceLabel(accessState)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (configLoaded ? kPrestoBlue : Colors.orange)
                              .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          configLoaded
                              ? 'Config Micro-IA chargee'
                              : 'Config Micro-IA en attente',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: (configLoaded ? kPrestoBlue : Colors.orange)
                                .withOpacity(0.92),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: kPrestoOrange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Pipeline: ${_adminModeStatusLabel(mode)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: kPrestoOrange.withOpacity(0.92),
                          ),
                        ),
                      ),
                    ],
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
            if (_shouldShowAdminDebugCard(
              user,
              state: accessState,
            )) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  adminCard,
                  _buildAdminDebugCard(user, state: accessState),
                ],
              );
            }
            return adminCard;
          },
        );
      },
    );
  }

  Widget _buildAdminLocalFallbackCard({
    required User user,
    required AdminAccessState state,
    String? detail,
  }) {
    final localSource = _adminLocalSource(state);
    final sourceLabel = localSource.isNotEmpty ? ' via $localSource' : '';
    final fallbackDetail = detail?.trim().isNotEmpty == true
        ? detail!.trim()
        : (state.serverErrorCode != null ? _adminStateErrorDetail(state) : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  'Mode secours',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_adminFallbackMessage(state)}${sourceLabel.isNotEmpty ? ' Détection locale$sourceLabel.' : ''}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Dernier contrôle: ${_formatAdminCheckTime(_adminLastCheckedAt)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black45,
              fontSize: 12,
            ),
          ),
          if (fallbackDetail != null && fallbackDetail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Détail: $fallbackDetail',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade700,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _refreshAdminAccessForUser(user.uid, forceRefresh: true);
                      _refreshAdminConfigForUser(user.uid);
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Relancer le contrôle'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
      stream: _auth.idTokenChanges(),
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
  final bool showTitle;

  const UserOffersSection({
    super.key,
    required this.userId,
    this.showTitle = true,
  });

  @override
  State<UserOffersSection> createState() => _UserOffersSectionState();
}

class FavoriteOffersSection extends StatefulWidget {
  final String userId;
  final bool showTitle;

  const FavoriteOffersSection({
    super.key,
    required this.userId,
    this.showTitle = true,
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
          (offerId) async {
            // Chercher d'abord dans listings (marketplace), puis offers (legacy)
            final listingSnap = await FirebaseFirestore.instance
                .collection(_kListingsCollection)
                .doc(offerId)
                .get();
            if (listingSnap.exists) return listingSnap;
            return FirebaseFirestore.instance
                .collection(_kOffersCollection)
                .doc(offerId)
                .get();
          },
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
        if (widget.showTitle) ...[
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        ],
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
                          cacheWidth: 144,
                          cacheHeight: 144,
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

enum _OfferManagementSection {
  pending,
  published,
  rejected,
  archived,
}

class _ManagedOfferItem {
  final String offerId;
  final Map<String, dynamic> data;
  final _OfferManagementSection section;

  const _ManagedOfferItem({
    required this.offerId,
    required this.data,
    required this.section,
  });
}

class _UserOffersSectionState extends State<UserOffersSection> {
  List<_ManagedOfferItem> _offers = const [];
  bool _isLoading = true;
  String? _error;
  String? _busyOfferId;
  bool _publishedSectionExpanded = false;
  bool _rejectedSectionExpanded = false;
  bool _archivedSectionExpanded = false;

  bool _isPermissionDeniedError(Object error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied';
    }

    final text = error.toString().toLowerCase();
    return text.contains('permission-denied') ||
        text.contains('permission denied');
  }

  bool _isOfferPublished(Map<String, dynamic> data) {
    if (_isOfferArchivedLike(data)) return false;

    final isPublished = data['isPublished'];
    if (isPublished is bool && isPublished) return true;

    final moderation = data['moderation'];
    if (moderation is Map) {
      final moderationStatus =
          (moderation['status'] ?? '').toString().trim().toLowerCase();
      if (moderationStatus == 'approved') return true;
    }

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

  bool _isOfferRejected(Map<String, dynamic> data) {
    final moderation = data['moderation'];
    if (moderation is Map) {
      final moderationStatus =
          (moderation['status'] ?? '').toString().trim().toLowerCase();
      if (moderationStatus == 'rejected') return true;
    }

    final status = (data['status'] ?? '').toString().trim().toLowerCase();
    return status == 'rejected' || status == 'refused' || status == 'declined';
  }

  bool _isOfferArchived(Map<String, dynamic> data) {
    return _isOfferArchivedLike(data);
  }

  bool _isOfferPending(Map<String, dynamic> data) {
    if (_isOfferArchived(data) ||
        _isOfferRejected(data) ||
        _isOfferPublished(data)) {
      return false;
    }

    final moderation = data['moderation'];
    if (moderation is Map) {
      final moderationStatus =
          (moderation['status'] ?? '').toString().trim().toLowerCase();
      if (moderationStatus == 'pending' || moderationStatus == 'error') {
        return true;
      }
    }

    final status = (data['status'] ?? '').toString().trim().toLowerCase();
    return status == 'submitted' ||
        status == 'pending' ||
        status == 'in_moderation' ||
        status == 'pending_moderation';
  }

  _OfferManagementSection _resolveSection(Map<String, dynamic> data) {
    if (_isOfferArchived(data)) {
      return _OfferManagementSection.archived;
    }
    if (_isOfferRejected(data)) {
      return _OfferManagementSection.rejected;
    }
    if (_isOfferPublished(data)) {
      return _OfferManagementSection.published;
    }
    if (_isOfferPending(data)) {
      return _OfferManagementSection.pending;
    }
    return _OfferManagementSection.pending;
  }

  String _offerLocation(Map<String, dynamic> data) {
    final v = (data['location'] ?? data['city'] ?? data['serviceArea'] ?? '')
        .toString()
        .trim();
    return v.isEmpty ? 'Lieu non précisé' : v;
  }

  String _offerCategory(Map<String, dynamic> data) {
    final v =
        (data['category'] ?? data['subCategory'] ?? data['subcategory'] ?? '')
            .toString()
            .trim();
    return v.isEmpty ? 'Catégorie non précisée' : v;
  }

  String _offerTitle(Map<String, dynamic> data) {
    final value = (data['title'] ?? 'Sans titre').toString().trim();
    return value.isEmpty ? 'Sans titre' : value;
  }

  DateTime? _dateFromDynamic(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatOfferDate(Map<String, dynamic> data) {
    final date = _dateFromDynamic(
          data['createdAt'] ?? data['updatedAt'] ?? data['archivedAt'],
        ) ??
        DateTime.now();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  int _offerSortValue(Map<String, dynamic> data) {
    final date = _dateFromDynamic(
      data['updatedAt'] ??
          data['createdAt'] ??
          data['archivedAt'] ??
          data['deletedAt'],
    );
    return date?.millisecondsSinceEpoch ?? 0;
  }

  String? _offerStatusDetails(Map<String, dynamic> data) {
    if (_isOfferRejected(data)) {
      final moderation = data['moderation'];
      if (moderation is Map) {
        final message =
            (moderation['userMessage'] ?? moderation['reason'] ?? '')
                .toString()
                .trim();
        if (message.isNotEmpty) return message;
      }

      final fallback = (data['rejectionReason'] ??
              data['moderationReason'] ??
              data['rejectedReason'] ??
              '')
          .toString()
          .trim();
      if (fallback.isNotEmpty) return fallback;
      return 'Annonce à corriger avant nouvelle publication.';
    }

    if (_isOfferArchived(data)) {
      final reason = (data['deletedReason'] ?? data['archiveReason'] ?? '')
          .toString()
          .trim();
      if (reason.isNotEmpty) return reason;
    }

    return null;
  }

  bool _offerHasPhotos(Map<String, dynamic> data) {
    final media = data['media'];
    if (media is List && media.isNotEmpty) {
      return true;
    }

    final imageUrls = data['imageUrls'];
    if (imageUrls is List && imageUrls.isNotEmpty) {
      return true;
    }

    final imageUrl = (data['imageUrl'] ?? '').toString().trim();
    return imageUrl.isNotEmpty;
  }

  bool _offerMediaStillProcessing(Map<String, dynamic> data) {
    final raw =
        (data['mediaProcessingStatus'] ?? '').toString().trim().toLowerCase();
    if (raw == 'processing') {
      return true;
    }
    if (raw == 'completed' || raw == 'done') {
      return false;
    }

    return _isOfferPending(data) && _offerHasPhotos(data);
  }

  String? _offerPendingPhotoNotice(Map<String, dynamic> data) {
    if (!_isOfferPending(data) || !_offerHasPhotos(data)) {
      return null;
    }
    if (_offerMediaStillProcessing(data)) {
      return 'Photos en traitement. Publication automatique une fois les photos prêtes.';
    }
    return 'Annonce en cours de verification avant publication.';
  }

  String _sectionTitle(_OfferManagementSection section) {
    switch (section) {
      case _OfferManagementSection.pending:
        return 'En attente de validation';
      case _OfferManagementSection.published:
        return 'Publiées';
      case _OfferManagementSection.rejected:
        return 'Refusées';
      case _OfferManagementSection.archived:
        return 'Supprimées / archivées';
    }
  }

  String _sectionEmptyLabel(_OfferManagementSection section) {
    switch (section) {
      case _OfferManagementSection.pending:
        return 'Aucune annonce en attente de validation.';
      case _OfferManagementSection.published:
        return 'Aucune annonce publiée pour le moment.';
      case _OfferManagementSection.rejected:
        return 'Aucune annonce refusée.';
      case _OfferManagementSection.archived:
        return 'Aucune annonce supprimée ou archivée.';
    }
  }

  String _statusLabel(_OfferManagementSection section) {
    switch (section) {
      case _OfferManagementSection.pending:
        return 'En attente';
      case _OfferManagementSection.published:
        return 'Publiée';
      case _OfferManagementSection.rejected:
        return 'Refusée';
      case _OfferManagementSection.archived:
        return 'Archivée';
    }
  }

  Color _statusColor(_OfferManagementSection section) {
    switch (section) {
      case _OfferManagementSection.pending:
        return const Color(0xFFE67E22);
      case _OfferManagementSection.published:
        return kPrestoBlue;
      case _OfferManagementSection.rejected:
        return const Color(0xFFC0392B);
      case _OfferManagementSection.archived:
        return const Color(0xFF6B7280);
    }
  }

  bool _canEditOffer(_OfferManagementSection section) {
    return section == _OfferManagementSection.pending ||
        section == _OfferManagementSection.rejected;
  }

  bool _canDeleteOffer(_OfferManagementSection section) {
    return section != _OfferManagementSection.archived;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadOffersByOwnerField(
    String field,
  ) async {
    try {
      // Charger depuis les deux collections et fusionner
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection(_kListingsCollection)
            .where(field, isEqualTo: widget.userId)
            .limit(120)
            .get(),
        FirebaseFirestore.instance
            .collection(_kOffersCollection)
            .where(field, isEqualTo: widget.userId)
            .limit(120)
            .get(),
      ]);
      final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final snap in results) {
        for (final doc in snap.docs) {
          byId.putIfAbsent(doc.id, () => doc);
        }
      }
      return byId.values.toList(growable: false);
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
          .map(
            (doc) => _ManagedOfferItem(
              offerId: doc.id,
              data: doc.data(),
              section: _resolveSection(doc.data()),
            ),
          )
          .toList(growable: false)
        ..sort(
          (a, b) => _offerSortValue(b.data).compareTo(_offerSortValue(a.data)),
        );

      if (!mounted) return;

      setState(() {
        _offers = docs;
        _isLoading = false;
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

    if (_offers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: const Text(
          'Tu n’as pas encore d’annonce à gérer.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final sections = {
      for (final section in _OfferManagementSection.values)
        section: _offers.where((item) => item.section == section).toList(),
    };

    final visibleSections = <_OfferManagementSection>[
      _OfferManagementSection.pending,
      _OfferManagementSection.published,
      _OfferManagementSection.rejected,
      if ((sections[_OfferManagementSection.archived] ?? const []).isNotEmpty)
        _OfferManagementSection.archived,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTitle) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Gérer mes annonces',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kPrestoBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_offers.length}',
                  style: const TextStyle(
                    color: kPrestoBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: const Text(
            'Classe tes annonces par statut et gère les actions disponibles sans quitter ton compte.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...visibleSections.expand((section) {
          final items = sections[section] ?? const <_ManagedOfferItem>[];
          return [
            _buildOfferSection(section, items),
            const SizedBox(height: 14),
          ];
        }).toList()
          ..removeLast(),
      ],
    );
  }

  Widget _buildOfferSection(
    _OfferManagementSection section,
    List<_ManagedOfferItem> items,
  ) {
    if (section == _OfferManagementSection.published) {
      return _buildPublishedOfferSection(items);
    }

    if (section == _OfferManagementSection.rejected) {
      return _buildRejectedOfferSection(items);
    }

    if (section == _OfferManagementSection.archived) {
      return _buildArchivedOfferSection(items);
    }

    final color = _statusColor(section);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _sectionTitle(section),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              _sectionEmptyLabel(section),
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            )
          else ...[
            if (section == _OfferManagementSection.pending) ...[
              _buildPendingQuickList(items),
              const SizedBox(height: 12),
            ],
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildOfferTile(item),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPublishedOfferSection(List<_ManagedOfferItem> items) {
    final color = _statusColor(_OfferManagementSection.published);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                setState(() {
                  _publishedSectionExpanded = !_publishedSectionExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Publiées',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _publishedSectionExpanded
                                ? 'Masquer la liste'
                                : 'Ouvrir le menu pour consulter la liste',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${items.length}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedRotation(
                      turns: _publishedSectionExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: color,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _publishedSectionExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: items.isEmpty
                  ? Text(
                      _sectionEmptyLabel(_OfferManagementSection.published),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        const Text(
                          'Retrouve ici toutes les annonces déjà en ligne et ouvre leur fiche quand tu veux les consulter.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildOfferTile(item),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedOfferSection(List<_ManagedOfferItem> items) {
    final color = _statusColor(_OfferManagementSection.rejected);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                setState(() {
                  _rejectedSectionExpanded = !_rejectedSectionExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Refusées',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _rejectedSectionExpanded
                                ? 'Masquer la liste'
                                : 'Ouvrir le menu pour consulter la liste',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${items.length}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedRotation(
                      turns: _rejectedSectionExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: color,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _rejectedSectionExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: items.isEmpty
                  ? Text(
                      _sectionEmptyLabel(_OfferManagementSection.rejected),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        const Text(
                          'Consulte les motifs de refus puis modifie l’annonce pour la republier dans de meilleures conditions.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildOfferTile(item),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedOfferSection(List<_ManagedOfferItem> items) {
    final color = _statusColor(_OfferManagementSection.archived);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                setState(() {
                  _archivedSectionExpanded = !_archivedSectionExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Supprimées / archivées',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _archivedSectionExpanded
                                ? 'Masquer la liste'
                                : 'Ouvrir le menu pour consulter la liste',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${items.length}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedRotation(
                      turns: _archivedSectionExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: color,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _archivedSectionExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: items.isEmpty
                  ? Text(
                      _sectionEmptyLabel(_OfferManagementSection.archived),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        const Text(
                          'Retrouve ici les annonces retirées de la diffusion et ouvre leur fiche quand tu en as besoin.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildOfferTile(item),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingQuickList(List<_ManagedOfferItem> items) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD4A6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Text(
              'Accès rapide aux annonces en attente',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF8A3B00),
              ),
            ),
          ),
          ...List.generate(items.length, (index) {
            final item = items[index];
            final isLast = index == items.length - 1;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openOfferDetails(item),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _offerTitle(item.data),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _formatOfferDate(item.data),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Color(0xFF8A3B00),
                          ),
                        ],
                      ),
                      if (!isLast) ...[
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _openOfferDetails(_ManagedOfferItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OfferDetailsPage(
          offer: _buildOfferDetailsOffer(
            offerId: item.offerId,
            data: item.data,
          ),
          currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
        ),
      ),
    );
  }

  num? _numericFromDynamic(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;

    final normalized = value
        .toString()
        .trim()
        .replaceAll('€', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    if (normalized.isEmpty) return null;

    return num.tryParse(normalized);
  }

  String _offerSubCategory(Map<String, dynamic> data) {
    return ((data['subCategory'] ?? data['subcategory']) ?? '')
        .toString()
        .trim();
  }

  String _offerBudgetType(Map<String, dynamic> data) {
    final raw = (data['budgetType'] ?? '').toString().trim();
    return raw == 'À négocier' ? raw : 'Fixe';
  }

  String _offerPhoneCountryCode(Map<String, dynamic> data) {
    final rawPhone = (data['phone'] ?? '').toString().trim();
    if (rawPhone.isEmpty) return '+33';

    const countryCodes = ['+590', '+596', '+594', '+262', '+689', '+33'];
    for (final code in countryCodes) {
      if (rawPhone.startsWith(code)) {
        return code;
      }
    }

    return '+33';
  }

  String _offerPhoneLocalNumber(Map<String, dynamic> data) {
    final rawPhone = (data['phone'] ?? '').toString().trim();
    if (rawPhone.isEmpty) return '';

    final countryCode = _offerPhoneCountryCode(data);
    final phoneWithoutCode = rawPhone.startsWith(countryCode)
        ? rawPhone.substring(countryCode.length)
        : rawPhone;

    return phoneWithoutCode.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Widget _buildOfferTile(_ManagedOfferItem item) {
    final data = item.data;
    final statusColor = _statusColor(item.section);
    final isArchived = item.section == _OfferManagementSection.archived;
    final isBusy = _busyOfferId == item.offerId;
    final canEdit = _canEditOffer(item.section) && !isBusy;
    final canDelete = _canDeleteOffer(item.section) && !isBusy;
    final details = _offerStatusDetails(data);
    final pendingPhotoNotice = _offerPendingPhotoNotice(data);
    final mediaIsProcessing = _offerMediaStillProcessing(data);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _offerTitle(data),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(item.section),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildMetaChip(Icons.category_outlined, _offerCategory(data)),
              _buildMetaChip(Icons.event_outlined, _formatOfferDate(data)),
              _buildMetaChip(Icons.place_outlined, _offerLocation(data)),
            ],
          ),
          if (pendingPhotoNotice != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFC78F)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF7A00),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      mediaIsProcessing
                          ? Icons.sync_rounded
                          : Icons.hourglass_top_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pendingPhotoNotice,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Color(0xFF8A3B00),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (details != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                details,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (isArchived)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onPressed: () => _openOfferDetails(item),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Voir le détail'),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onPressed: canEdit
                        ? () => _showEditOfferDialog(context, item)
                        : null,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Modifier'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      disabledForegroundColor: const Color(0xFF6B7280),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onPressed: canDelete ? () => _deleteOffer(item) : null,
                    icon: isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.delete_outline, size: 18),
                    label: Text(isBusy ? 'Suppression...' : 'Supprimer'),
                  ),
                ),
              ],
            ),
          if (!canEdit &&
              item.section == _OfferManagementSection.published) ...[
            const SizedBox(height: 8),
            const Text(
              'Modification indisponible pour une annonce déjà publiée.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditOfferDialog(
    BuildContext context,
    _ManagedOfferItem item,
  ) async {
    final data = item.data;
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: _offerTitle(data));
    final descController = TextEditingController(
      text: (data['description'] ?? '').toString().trim(),
    );
    final locationController = TextEditingController(
      text: ((data['location'] ?? data['city']) ?? '').toString().trim(),
    );
    final postalCodeController = TextEditingController(
      text: ((data['postalCode'] ?? data['cp']) ?? '').toString().trim(),
    );
    final phoneController = TextEditingController(
      text: _offerPhoneLocalNumber(data),
    );
    final budgetValue = _numericFromDynamic(
        data['budget'] ?? data['price'] ?? data['budgetValue']);
    final budgetController = TextEditingController(
      text: budgetValue == null
          ? ''
          : (budgetValue == budgetValue.roundToDouble()
              ? budgetValue.toInt().toString()
              : budgetValue.toString()),
    );
    final availabilityController = TextEditingController(
      text: (data['availability'] ?? '').toString().trim(),
    );
    final averageDelayController = TextEditingController(
      text: (data['averageDelay'] ?? '').toString().trim(),
    );
    final serviceAreaController = TextEditingController(
      text: (data['serviceArea'] ?? '').toString().trim(),
    );
    final scheduleController = TextEditingController(
      text: (data['schedule'] ?? '').toString().trim(),
    );
    final paymentMethodController = TextEditingController(
      text: (data['paymentMethod'] ?? '').toString().trim(),
    );
    final serviceTypeController = TextEditingController(
      text: (data['serviceType'] ?? '').toString().trim(),
    );

    final rawCategory = (data['category'] ?? '').toString().trim();
    final canonicalCategory = canonicalizeOfferCategory(rawCategory);
    var selectedCategory =
        canonicalCategory ?? (rawCategory.isEmpty ? null : rawCategory);
    var selectedSubCategory = _offerSubCategory(data);
    var selectedBudgetType = _offerBudgetType(data);
    var selectedMissionDelay =
        ((data['missionDelay'] ?? data['averageDelay']) ?? '')
            .toString()
            .trim();
    if (selectedMissionDelay == 'Délai non précisé') {
      selectedMissionDelay = '';
    }
    var selectedPhoneCountryCode = _offerPhoneCountryCode(data);
    var canTravel = (data['canTravel'] as bool?) ?? true;
    var isUrgent =
        ((data['isUrgent'] as bool?) ?? (data['urgent'] as bool?)) ?? false;
    var isSaving = false;

    InputDecoration buildDecoration(String label) {
      return InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    const missionDelayOptions = <String>[
      'Immédiat',
      'Dans la journée',
      'Demain',
      'Sous 48h',
      'Cette semaine',
      'À convenir',
    ];

    final budgetTypes = const <String>['Fixe', 'À négocier'];

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final categoryOptions = [
              ...kCategorySubcategories.keys,
              if (selectedCategory != null &&
                  !kCategorySubcategories.keys.contains(selectedCategory))
                selectedCategory!,
            ];
            final availableSubCategories = [
              if (selectedSubCategory.isNotEmpty &&
                  !(kCategorySubcategories[selectedCategory] ??
                          const <String>[])
                      .contains(selectedSubCategory))
                selectedSubCategory,
              ...(kCategorySubcategories[selectedCategory] ?? const <String>[]),
            ];
            final missionOptions = [
              ...missionDelayOptions,
              if (selectedMissionDelay.isNotEmpty &&
                  !missionDelayOptions.contains(selectedMissionDelay))
                selectedMissionDelay,
            ];
            final pendingPhotoNotice = _offerPendingPhotoNotice(data);
            final overlayTheme = dialogContext.prestoOverlayTheme;

            return Dialog(
              backgroundColor: overlayTheme.surfaceColor,
              surfaceTintColor: overlayTheme.surfaceTintColor,
              insetPadding: const EdgeInsets.all(16),
              shape: overlayTheme.dialogShape,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Modifier l’annonce',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_sectionTitle(item.section)} · créée le ${_formatOfferDate(data)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: isSaving
                                    ? null
                                    : () => Navigator.of(dialogContext).pop(),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          if (pendingPhotoNotice != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E6),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFFFC78F)),
                              ),
                              child: Text(
                                pendingPhotoNotice,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: Color(0xFF8A3B00),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: titleController,
                            decoration: buildDecoration('Titre *'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Titre obligatoire';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedCategory,
                                  decoration: buildDecoration('Catégorie *'),
                                  items: categoryOptions
                                      .map(
                                        (category) => DropdownMenuItem<String>(
                                          value: category,
                                          child: Text(category),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: isSaving
                                      ? null
                                      : (value) {
                                          setDialogState(() {
                                            selectedCategory = value;
                                            final validSubCategories =
                                                kCategorySubcategories[value] ??
                                                    const <String>[];
                                            if (!validSubCategories.contains(
                                                selectedSubCategory)) {
                                              selectedSubCategory = '';
                                            }
                                          });
                                        },
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Catégorie obligatoire';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedSubCategory.isEmpty
                                      ? ''
                                      : selectedSubCategory,
                                  decoration: buildDecoration('Sous-catégorie'),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: '',
                                      child: Text('Aucune'),
                                    ),
                                    ...availableSubCategories.map(
                                      (subCategory) => DropdownMenuItem<String>(
                                        value: subCategory,
                                        child: Text(subCategory),
                                      ),
                                    ),
                                  ],
                                  onChanged: isSaving
                                      ? null
                                      : (value) {
                                          setDialogState(() {
                                            selectedSubCategory =
                                                (value ?? '').trim();
                                          });
                                        },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: descController,
                            decoration:
                                buildDecoration('Description détaillée *'),
                            minLines: 5,
                            maxLines: 8,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Description obligatoire';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: locationController,
                                  decoration: buildDecoration('Ville / lieu *'),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Ville obligatoire';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: postalCodeController,
                                  decoration: buildDecoration('Code postal'),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          PhoneInputFieldCompact(
                            controller: phoneController,
                            labelText: 'Téléphone',
                            hintText: '612345678',
                            initialCountryCode: selectedPhoneCountryCode,
                            onCountryCodeChanged: (code) {
                              selectedPhoneCountryCode = code;
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: selectedBudgetType,
                                  decoration:
                                      buildDecoration('Budget / tarification'),
                                  items: budgetTypes
                                      .map(
                                        (budgetType) =>
                                            DropdownMenuItem<String>(
                                          value: budgetType,
                                          child: Text(budgetType),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: isSaving
                                      ? null
                                      : (value) {
                                          if (value == null) return;
                                          setDialogState(() {
                                            selectedBudgetType = value;
                                            if (selectedBudgetType ==
                                                'À négocier') {
                                              budgetController.clear();
                                            }
                                          });
                                        },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: budgetController,
                                  decoration: buildDecoration('Montant (€)'),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  enabled: selectedBudgetType == 'Fixe',
                                  validator: (value) {
                                    if (selectedBudgetType != 'Fixe') {
                                      return null;
                                    }
                                    final normalized = (value ?? '')
                                        .trim()
                                        .replaceAll(' ', '')
                                        .replaceAll(',', '.');
                                    if (normalized.isEmpty) {
                                      return 'Montant obligatoire';
                                    }
                                    if (num.tryParse(normalized) == null) {
                                      return 'Montant invalide';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedMissionDelay.isEmpty
                                      ? null
                                      : selectedMissionDelay,
                                  decoration: buildDecoration(
                                    'Délai pour effectuer la mission',
                                  ),
                                  items: missionOptions
                                      .map(
                                        (delay) => DropdownMenuItem<String>(
                                          value: delay,
                                          child: Text(delay),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: isSaving
                                      ? null
                                      : (value) {
                                          setDialogState(() {
                                            selectedMissionDelay =
                                                (value ?? '').trim();
                                          });
                                        },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFFD1D5DB),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: SwitchListTile.adaptive(
                                    value: isUrgent,
                                    onChanged: isSaving
                                        ? null
                                        : (value) {
                                            setDialogState(() {
                                              isUrgent = value;
                                            });
                                          },
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
                                      'Annonce urgente',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: availabilityController,
                            decoration: buildDecoration('Disponibilité'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: averageDelayController,
                            decoration: buildDecoration('Délai affiché'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: serviceAreaController,
                            decoration: buildDecoration('Zone d’intervention'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: scheduleController,
                            decoration: buildDecoration('Horaires'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: paymentMethodController,
                            decoration: buildDecoration('Mode de paiement'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: serviceTypeController,
                            decoration: buildDecoration('Type de service'),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFD1D5DB),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SwitchListTile.adaptive(
                              value: canTravel,
                              onChanged: isSaving
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        canTravel = value;
                                      });
                                    },
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Peut se déplacer',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isSaving
                                      ? null
                                      : () => Navigator.of(dialogContext).pop(),
                                  child: const Text('Annuler'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  onPressed: isSaving
                                      ? null
                                      : () async {
                                          Navigator.of(dialogContext).pop();
                                          await _deleteOffer(item);
                                        },
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Supprimer'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrestoOrange,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: isSaving
                                      ? null
                                      : () async {
                                          if (!(formKey.currentState
                                                  ?.validate() ??
                                              false)) {
                                            return;
                                          }

                                          final newBudgetText =
                                              budgetController.text.trim();
                                          final parsedBudget =
                                              newBudgetText.isEmpty
                                                  ? null
                                                  : num.tryParse(
                                                      newBudgetText.replaceAll(
                                                          ',', '.'),
                                                    );
                                          final existingBudget =
                                              _numericFromDynamic(
                                            data['budget'] ??
                                                data['price'] ??
                                                data['budgetValue'],
                                          );
                                          final effectiveBudget =
                                              selectedBudgetType == 'À négocier'
                                                  ? 0.0
                                                  : (parsedBudget ??
                                                      existingBudget);
                                          final trimmedCategory =
                                              (selectedCategory ?? '').trim();
                                          final trimmedLocation =
                                              locationController.text.trim();
                                          final trimmedPostalCode =
                                              postalCodeController.text.trim();
                                          final trimmedMissionDelay =
                                              selectedMissionDelay.trim();
                                          final trimmedAverageDelay =
                                              averageDelayController.text
                                                  .trim();
                                          final trimmedSubCategory =
                                              selectedSubCategory.trim();
                                          final trimmedAvailability =
                                              availabilityController.text
                                                  .trim();
                                          final trimmedServiceArea =
                                              serviceAreaController.text.trim();
                                          final trimmedSchedule =
                                              scheduleController.text.trim();
                                          final trimmedPaymentMethod =
                                              paymentMethodController.text
                                                  .trim();
                                          final trimmedServiceType =
                                              serviceTypeController.text.trim();
                                          final trimmedPhoneNumber =
                                              phoneController.text.trim();
                                          final fullPhone = trimmedPhoneNumber
                                                  .isEmpty
                                              ? ''
                                              : '${selectedPhoneCountryCode.trim()} $trimmedPhoneNumber'
                                                  .trim();

                                          final indexed = buildOfferIndexFields(
                                            category: trimmedCategory,
                                            city: trimmedLocation,
                                            postalCode: trimmedPostalCode,
                                            budget: effectiveBudget,
                                          );

                                          setDialogState(() => isSaving = true);

                                          try {
                                            final listingsRef =
                                                FirebaseFirestore.instance
                                                    .collection(
                                                        _kListingsCollection)
                                                    .doc(item.offerId);
                                            final offersRef = FirebaseFirestore
                                                .instance
                                                .collection(_kOffersCollection)
                                                .doc(item.offerId);
                                            final listingsSnap =
                                                await listingsRef.get();
                                            final offersSnap =
                                                listingsSnap.exists
                                                    ? null
                                                    : await offersRef.get();
                                            if (!listingsSnap.exists &&
                                                !(offersSnap?.exists ??
                                                    false)) {
                                              throw StateError(
                                                'Annonce introuvable',
                                              );
                                            }

                                            final targetRef =
                                                listingsSnap.exists
                                                    ? listingsRef
                                                    : offersRef;
                                            final update = <String, dynamic>{
                                              'title':
                                                  titleController.text.trim(),
                                              'description':
                                                  descController.text.trim(),
                                              'category': indexed['category'] ??
                                                  trimmedCategory,
                                              'location': indexed['location'] ??
                                                  trimmedLocation,
                                              'city': indexed['city'] ??
                                                  trimmedLocation,
                                              'budgetType': selectedBudgetType,
                                              'canTravel': canTravel,
                                              'urgent': isUrgent,
                                              'isUrgent': isUrgent,
                                              'updatedAt':
                                                  FieldValue.serverTimestamp(),
                                              'postalCode':
                                                  trimmedPostalCode.isEmpty
                                                      ? FieldValue.delete()
                                                      : trimmedPostalCode,
                                              'cp': trimmedPostalCode.isEmpty
                                                  ? FieldValue.delete()
                                                  : trimmedPostalCode,
                                              'phone': fullPhone.isEmpty
                                                  ? FieldValue.delete()
                                                  : fullPhone,
                                              'missionDelay':
                                                  trimmedMissionDelay.isEmpty
                                                      ? FieldValue.delete()
                                                      : trimmedMissionDelay,
                                              'averageDelay': trimmedAverageDelay
                                                      .isNotEmpty
                                                  ? trimmedAverageDelay
                                                  : (trimmedMissionDelay.isEmpty
                                                      ? FieldValue.delete()
                                                      : trimmedMissionDelay),
                                              'availability':
                                                  trimmedAvailability.isEmpty
                                                      ? FieldValue.delete()
                                                      : trimmedAvailability,
                                              'serviceArea':
                                                  trimmedServiceArea.isEmpty
                                                      ? (trimmedLocation.isEmpty
                                                          ? FieldValue.delete()
                                                          : trimmedLocation)
                                                      : trimmedServiceArea,
                                              'schedule':
                                                  trimmedSchedule.isEmpty
                                                      ? FieldValue.delete()
                                                      : trimmedSchedule,
                                              'paymentMethod':
                                                  trimmedPaymentMethod.isEmpty
                                                      ? FieldValue.delete()
                                                      : trimmedPaymentMethod,
                                              'serviceType':
                                                  trimmedServiceType.isEmpty
                                                      ? FieldValue.delete()
                                                      : trimmedServiceType,
                                              'subCategory':
                                                  trimmedSubCategory.isEmpty
                                                      ? FieldValue.delete()
                                                      : trimmedSubCategory,
                                              'subcategory':
                                                  trimmedSubCategory.isEmpty
                                                      ? FieldValue.delete()
                                                      : trimmedSubCategory,
                                              'categoryId':
                                                  indexed['categoryId'] ??
                                                      FieldValue.delete(),
                                              'cityId': indexed['cityId'] ??
                                                  FieldValue.delete(),
                                              'cityCategoryKey':
                                                  indexed['cityCategoryKey'] ??
                                                      FieldValue.delete(),
                                              'dept': indexed['dept'] ??
                                                  FieldValue.delete(),
                                            };

                                            if (effectiveBudget != null) {
                                              update['budget'] =
                                                  effectiveBudget;
                                              update['price'] =
                                                  effectiveBudget.toDouble();
                                              update['budgetValue'] =
                                                  (indexed['budgetValue'] ??
                                                          effectiveBudget)
                                                      .toDouble();
                                            }

                                            await targetRef.update(update);

                                            if (dialogContext.mounted) {
                                              Navigator.of(dialogContext).pop();
                                            }
                                            await _loadOffers();
                                            if (!mounted || !context.mounted) {
                                              return;
                                            }
                                            showSuccessSnackBar(
                                              context,
                                              'Annonce mise à jour ✅',
                                            );
                                          } catch (e) {
                                            if (dialogContext.mounted) {
                                              setDialogState(
                                                () => isSaving = false,
                                              );
                                            }
                                            if (!mounted || !context.mounted) {
                                              return;
                                            }
                                            showErrorSnackBar(
                                              context,
                                              'Erreur lors de la mise à jour',
                                            );
                                          }
                                        },
                                  icon: isSaving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: Text(
                                    isSaving
                                        ? 'Enregistrement...'
                                        : 'Modifier l’annonce',
                                  ),
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
            );
          },
        );
      },
    );
  }

  Future<void> _deleteOffer(_ManagedOfferItem item) async {
    final title = _offerTitle(item.data);
    final reason = await _showDeleteOfferDialog(context);
    if (reason == null || !mounted) return;

    setState(() => _busyOfferId = item.offerId);

    try {
      // Déterminer la collection correcte (listings ou offers legacy)
      final listingsRef = FirebaseFirestore.instance
          .collection(_kListingsCollection)
          .doc(item.offerId);
      final listingsSnap = await listingsRef.get();
      final isListing = listingsSnap.exists;

      final doc = isListing
          ? listingsSnap
          : await FirebaseFirestore.instance
              .collection(_kOffersCollection)
              .doc(item.offerId)
              .get();

      final latestData = doc.data() ?? item.data;
      final shouldKeepVisibleWithJobDone =
          _isOfferJobDoneDeletionReason(reason);

      debugPrint('Suppression offre ${item.offerId} avec motif: $reason');

      if (isListing) {
        final callable = prestoFirebaseFunctions.httpsCallable(
          'deleteListing',
          options: HttpsCallableOptions(
            timeout: const Duration(seconds: 30),
          ),
        );
        await callable.call<dynamic>({
          'listingId': item.offerId,
          'reason': reason,
        });
      } else {
        final imageUrls =
            (latestData['imageUrls'] as List<dynamic>? ?? const [])
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList();

        if (!shouldKeepVisibleWithJobDone) {
          for (final url in imageUrls) {
            try {
              final ref = FirebaseStorage.instance.refFromURL(url);
              await ref.delete();
            } catch (_) {
              // Best-effort: une image manquante ne doit pas bloquer la suppression.
            }
          }
        }

        if (shouldKeepVisibleWithJobDone) {
          final visibleUntil = Timestamp.fromDate(
            DateTime.now().add(kOfferJobDoneOverlayDuration),
          );

          await FirebaseFirestore.instance
              .collection(_kOffersCollection)
              .doc(item.offerId)
              .update({
            'status': 'sold',
            'isActive': true,
            'isPublished': false,
            'deletedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'deletedReason': reason,
            'archiveReason': reason,
            'jobDoneOverlayVisible': true,
            'jobDoneOverlayVisibleUntil': visibleUntil,
            'removeFromBrowseAt': visibleUntil,
          });
        } else {
          await FirebaseFirestore.instance
              .collection(_kOffersCollection)
              .doc(item.offerId)
              .delete();
        }
      }

      if (!mounted) return;

      await _loadOffers();
      if (!mounted) return;
      if (shouldKeepVisibleWithJobDone) {
        showSuccessSnackBar(
          context,
          'Annonce "$title" marquée comme réalisée. Elle restera visible 10 h avec jobfait.',
        );
      } else {
        showSuccessSnackBar(context, 'Annonce "$title" supprimée');
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      debugPrint(
          'Erreur callable suppression offre ${item.offerId}: ${e.code} ${e.message}');
      final message = e.code == 'permission-denied'
          ? 'Suppression refusée. Cette annonce n’est pas reconnue comme vous appartenant.'
          : e.code == 'not-found'
              ? 'Annonce introuvable.'
              : 'Erreur lors de la suppression';
      showErrorSnackBar(context, message);
    } catch (e) {
      if (!mounted) return;
      debugPrint('Erreur suppression offre ${item.offerId}: $e');
      final message = e is FirebaseException && e.code == 'permission-denied'
          ? 'Suppression refusée par les règles Firestore.'
          : 'Erreur lors de la suppression';
      showErrorSnackBar(context, message);
    } finally {
      if (mounted) {
        setState(() => _busyOfferId = null);
      }
    }
  }

  Future<String?> _showDeleteOfferDialog(BuildContext context) async {
    String? selectedReason;
    const reasons = [
      'J’ai fait une erreur dans l’annonce',
      kOfferDeleteReasonFoundProvider,
      kOfferDeleteReasonFoundOnIliPresto,
    ];
    final overlayTheme = context.prestoOverlayTheme;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final canSubmit =
                selectedReason != null && selectedReason!.trim().isNotEmpty;

            return AlertDialog(
              backgroundColor: overlayTheme.surfaceColor,
              surfaceTintColor: overlayTheme.surfaceTintColor,
              shape: overlayTheme.dialogShape,
              title: const Text('Supprimer cette annonce ?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pour continuer, veuillez sélectionner le motif de suppression.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    decoration: InputDecoration(
                      labelText: 'Motif principal',
                      border: OutlineInputBorder(
                        borderRadius: overlayTheme.popupRadius,
                      ),
                    ),
                    dropdownColor: overlayTheme.surfaceColor,
                    borderRadius: overlayTheme.popupRadius,
                    items: reasons
                        .map(
                          (reason) => DropdownMenuItem<String>(
                            value: reason,
                            child: Text(reason),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedReason = value);
                    },
                  ),
                  if (!canSubmit) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Veuillez sélectionner les champs obligatoires.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.resolveWith<Color>((states) {
                      if (states.contains(MaterialState.disabled)) {
                        return const Color(0xFFE5E7EB);
                      }
                      return const Color(0xFFDC2626);
                    }),
                    foregroundColor:
                        MaterialStateProperty.resolveWith<Color>((states) {
                      if (states.contains(MaterialState.disabled)) {
                        return const Color(0xFF6B7280);
                      }
                      return Colors.white;
                    }),
                  ),
                  onPressed: canSubmit
                      ? () => Navigator.of(dialogContext).pop(selectedReason)
                      : null,
                  child: const Text('Supprimer'),
                ),
              ],
            );
          },
        );
      },
    );
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
  late final ScrollController _scrollController;
  late final Ticker _ticker;
  bool _isUserDragging = false;
  Duration _lastElapsed = Duration.zero;
  static const double _pixelsPerSecond = 44.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _ticker = createTicker(_onTick)..start();
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
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_isUserDragging || !_scrollController.hasClients) {
      _lastElapsed = elapsed;
      return;
    }

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
    const cornerAccentSize = 42.0;

    return GestureDetector(
      onTap: () => widget.onOfferTap?.call(doc),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: IgnorePointer(
              child: Container(
                width: cornerAccentSize,
                height: cornerAccentSize,
                decoration: const BoxDecoration(
                  color: kPrestoBlue,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0x551A73E8),
                width: 1.1,
              ),
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final duplicatedOffers = widget.offers.length > 1
        ? [...widget.offers, ...widget.offers]
        : widget.offers;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _isUserDragging = true;
        } else if (notification is ScrollEndNotification) {
          _isUserDragging = false;
        }
        return false;
      },
      child: SizedBox(
        height: 52,
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: duplicatedOffers.length,
          addAutomaticKeepAlives: false,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) => RepaintBoundary(
            child: _buildOfferCard(duplicatedOffers[index]),
          ),
        ),
      ),
    );
  }
}
