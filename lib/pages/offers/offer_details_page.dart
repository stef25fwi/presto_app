import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../services/firebase_functions_region.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:presto_app/app/presto_overlay_theme.dart';
import 'package:presto_app/constants.dart';
import 'package:presto_app/pages/account_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:presto_app/data/marketplace/favorite_repository.dart';
import 'package:presto_app/data/marketplace/report_repository.dart';
import 'package:presto_app/models/marketplace_enums.dart';
import 'package:presto_app/models/marketplace_report.dart';
import 'package:presto_app/services/admin_access_resolver.dart';
import 'package:presto_app/services/app_route_parser.dart';
import 'package:presto_app/services/conversation_service.dart';
import 'package:presto_app/services/marketplace_human_verification.dart';
import 'package:presto_app/services/user_profile_bootstrap_service.dart';
import 'package:presto_app/utils/runtime_action_logger.dart';
import 'package:presto_app/widgets/offer_network_image.dart';
import 'dart:async';
import 'package:presto_app/pages/offers/widgets/animated_payment_info_pill.dart';
import 'package:presto_app/pages/offers/widgets/payment_info_popup.dart';
import 'package:presto_app/pages/fiche_pro_page.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

enum OfferActionType { booking, contact }

String _extractOfferDetailImageUrl(dynamic entry) {
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

List<String> _collectOfferDetailImageUrls({
  dynamic imageUrls,
  dynamic media,
  dynamic imageUrl,
  dynamic thumbnailUrl,
}) {
  final orderedUrls = <String>[];

  void addUrl(dynamic value) {
    final url = _extractOfferDetailImageUrl(value);
    if (url.isEmpty || orderedUrls.contains(url)) {
      return;
    }
    orderedUrls.add(url);
  }

  // Prioriser media[] : c'est la source normalisée la plus fiable côté listing.
  if (media is List) {
    for (final entry in media) {
      addUrl(entry);
    }
  }

  if (imageUrls is List) {
    for (final entry in imageUrls) {
      addUrl(entry);
    }
  }

  addUrl(imageUrl);
  addUrl(thumbnailUrl);

  return orderedUrls;
}

class PracticalInfo {
  final String category;
  final String serviceArea;
  final bool canTravel;
  final String schedule;
  final String missionDelay;
  final String averageDelay;
  final String paymentMethod;
  final String serviceType;

  const PracticalInfo({
    required this.category,
    required this.serviceArea,
    required this.canTravel,
    required this.schedule,
    required this.missionDelay,
    required this.averageDelay,
    required this.paymentMethod,
    required this.serviceType,
  });
}

class Advertiser {
  final String id;
  final String name;
  final bool verified;
  final double? rating;
  final int offersCount;
  final int reviewsCount;
  final String seniorityLabel;
  final String city;
  final String bio;
  final String avatarUrl;
  final bool isOnline;
  final String lastSeenLabel;

  const Advertiser({
    required this.id,
    required this.name,
    required this.verified,
    required this.rating,
    required this.offersCount,
    this.reviewsCount = 0,
    required this.seniorityLabel,
    required this.city,
    required this.bio,
    required this.avatarUrl,
    required this.isOnline,
    required this.lastSeenLabel,
  });
}

String _normalizeBudgetDisplayText(String value) {
  return value
      .toLowerCase()
      .replaceAll('à', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _isNegotiableBudgetValue(Object? value) {
  final raw = (value ?? '').toString().trim();
  if (raw.isEmpty) return false;

  final normalized = _normalizeBudgetDisplayText(raw);

  return normalized.contains('negocier') ||
      normalized.contains('negociable') ||
      normalized.contains('negotiate') ||
      normalized.contains('negotiable') ||
      normalized == 'a negocier' ||
      normalized == 'à négocier';
}

num? _asBudgetNumber(Object? value) {
  if (value == null) return null;
  if (value is num) return value;

  final raw = value.toString().trim();
  if (raw.isEmpty) return null;

  final cleaned = raw
      .replaceAll('€', '')
      .replaceAll('EUR', '')
      .replaceAll('eur', '')
      .replaceAll(',', '.')
      .trim();

  return num.tryParse(cleaned);
}

bool _shouldHideBudgetOnOfferDetails(Map<String, dynamic> data) {
  final possibleLabels = <Object?>[
    data['budgetLabel'],
    data['budgetText'],
    data['budgetType'],
    data['budgetMode'],
    data['priceLabel'],
    data['priceType'],
    data['priceMode'],
    data['budget'],
    data['price'],
  ];

  for (final value in possibleLabels) {
    if (_isNegotiableBudgetValue(value)) {
      return true;
    }
  }

  final possibleAmounts = <Object?>[
    data['budgetAmount'],
    data['budget'],
    data['price'],
    data['amount'],
  ];

  for (final value in possibleAmounts) {
    final amount = _asBudgetNumber(value);
    if (amount != null && amount <= 0) {
      return true;
    }
  }

  return false;
}

class Offer {
  final String id;
  final String listingId;
  final String title;
  final double price;
  final String category;
  final String categoryId;
  final String city;
  final String cityId;
  final String postalCode;
  final bool isUrgent;
  final String publishedAtLabel;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final String availability;
  final String shortDescription;
  final String description;
  final String phone;
  final List<String> imageUrls;
  final List<Map<String, dynamic>> media;
  final String thumbnailUrl;
  final List<String> statusBadges;
  final String status;
  final String moderationStatus;
  final String visibility;
  final String mediaProcessingStatus;
  final bool isMarketplace;
  final PracticalInfo practicalInfo;
  final Advertiser advertiser;
  final OfferActionType actionType;
  final List<Offer> similarOffers;

  const Offer({
    required this.id,
    String? listingId,
    required this.title,
    required this.price,
    required this.category,
    this.categoryId = '',
    required this.city,
    this.cityId = '',
    this.postalCode = '',
    this.isUrgent = false,
    required this.publishedAtLabel,
    this.publishedAt,
    this.createdAt,
    required this.availability,
    required this.shortDescription,
    required this.description,
    required this.phone,
    required this.imageUrls,
    this.media = const <Map<String, dynamic>>[],
    this.thumbnailUrl = '',
    required this.statusBadges,
    this.status = '',
    this.moderationStatus = '',
    this.visibility = '',
    this.mediaProcessingStatus = '',
    this.isMarketplace = false,
    required this.practicalInfo,
    required this.advertiser,
    required this.actionType,
    required this.similarOffers,
  }) : listingId = listingId ?? id;
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class OfferDetailsPage extends StatelessWidget {
  final Object? offer;
  final String currentUserId;
  final VoidCallback? onBackToConsult;

  const OfferDetailsPage({
    super.key,
    this.offer,
    this.currentUserId = 'buyer_demo_001',
    this.onBackToConsult,
  });

  @override
  Widget build(BuildContext context) {
    return PrestoOfferDetailsPage(
      offer: offer,
      currentUserId: currentUserId,
      onBackToConsult: onBackToConsult,
    );
  }
}

class PrestoOfferDetailsPage extends StatefulWidget {
  final Object? offer;
  final String currentUserId;
  final VoidCallback? onBackToConsult;

  const PrestoOfferDetailsPage({
    super.key,
    this.offer,
    required this.currentUserId,
    this.onBackToConsult,
  });

  @override
  State<PrestoOfferDetailsPage> createState() => _PrestoOfferDetailsPageState();
}

class _PrestoOfferDetailsPageState extends State<PrestoOfferDetailsPage> {
  static const Color _headerOrange = Color(0xFFFF6600);
  static const SystemUiOverlayStyle _statusBarStyle = SystemUiOverlayStyle(
    statusBarColor: _headerOrange,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );
  static final FavoriteRepository _favoriteRepository = FavoriteRepository();
  static final ReportRepository _reportRepository = ReportRepository();
  static const MarketplaceHumanVerification _verification =
      MarketplaceHumanVerification();
  final AdminAccessResolver _adminAccessResolver = AdminAccessResolver();

  Future<Map<String, dynamic>?>? _marketplaceFuture;
  bool _isAdminViewer = false;
  bool _isDeletingListingAsAdmin = false;

  @override
  void initState() {
    super.initState();
    _initMarketplaceFuture();
    unawaited(_loadAdminAccess());
  }

  @override
  void didUpdateWidget(PrestoOfferDetailsPage old) {
    super.didUpdateWidget(old);
    if (widget.offer != old.offer) {
      _initMarketplaceFuture();
    }
  }

  void _initMarketplaceFuture() {
    final listingId = _extractMarketplaceListingId(widget.offer);
    _marketplaceFuture = (listingId.isNotEmpty &&
            _shouldHydrateMarketplaceOffer(widget.offer, listingId))
        ? _fetchMarketplaceOffer(listingId)
        : null;
  }

  Future<void> _loadAdminAccess() async {
    try {
      final state = await _adminAccessResolver.resolveAdminAccess(
        returnOnLocalAdminEvidence: true,
      );
      if (!mounted) return;
      setState(() {
        _isAdminViewer = state.effectiveIsAdmin;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAdminViewer = false;
      });
    }
  }

  Future<void> _confirmAdminDeleteOffer(
    BuildContext context,
    _OfferUiData data,
  ) async {
    if (_isDeletingListingAsAdmin || data.offerId.trim().isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Suppression admin'),
        content: Text(
          'Confirmer la suppression de l\'annonce "${data.title}" ?\n\n'
          'L\'auteur recevra un message de l\'équipe ilipresto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD14343),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isDeletingListingAsAdmin = true;
    });

    try {
      final callable = prestoFirebaseFunctions.httpsCallable(
        'deleteListing',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      await callable.call<dynamic>({
        'listingId': data.offerId,
        'reason': 'admin_deleted_by_team',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Annonce supprimée. L\'auteur a été informé par l\'équipe ilipresto.',
          ),
        ),
      );
      Navigator.of(context).maybePop();
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final message = error.code == 'permission-denied'
          ? 'Suppression admin refusée.'
          : error.code == 'not-found'
              ? 'Annonce introuvable.'
              : 'Erreur lors de la suppression admin.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la suppression admin.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingListingAsAdmin = false;
        });
      }
    }
  }

  String _extractMarketplaceListingId(Object? source) {
    final dynamic dynamicSource = source;
    final rawId = ((source is Map
                ? source['listingId'] ?? source['offerId'] ?? source['id']
                : _OfferUiData._read(() => dynamicSource?.listingId) ??
                    _OfferUiData._read(() => dynamicSource?.offerId) ??
                    _OfferUiData._read(() => dynamicSource?.id)) ??
            '')
        .toString()
        .trim();
    if (rawId.isEmpty) {
      return '';
    }

    return rawId;
  }

  List<String> _collectImageUrls({
    dynamic imageUrls,
    dynamic media,
    dynamic imageUrl,
    dynamic thumbnailUrl,
  }) {
    return _collectOfferDetailImageUrls(
      imageUrls: imageUrls,
      media: media,
      imageUrl: imageUrl,
      thumbnailUrl: thumbnailUrl,
    );
  }

  Object? _mergeMarketplaceOffer(
    Object? source,
    Map<String, dynamic>? fetchedData,
    String listingId,
  ) {
    if (fetchedData == null || fetchedData.isEmpty) {
      return source;
    }

    final merged = <String, dynamic>{
      if (source is Map)
        ...Map<String, dynamic>.from(source.cast<dynamic, dynamic>()),
      ...fetchedData,
      'id': listingId,
      'offerId': listingId,
      'listingId': listingId,
      'isMarketplace': true,
    };

    final imageUrls = _collectImageUrls(
      imageUrls: merged['imageUrls'],
      media: merged['media'],
      imageUrl: merged['imageUrl'],
      thumbnailUrl: merged['thumbnailUrl'],
    );
    if (imageUrls.isNotEmpty) {
      merged['imageUrls'] = imageUrls;
    }

    return merged;
  }

  bool _shouldHydrateMarketplaceOffer(Object? source, String listingId) {
    if (listingId.isEmpty) {
      return false;
    }

    if (source == null) {
      return true;
    }

    if (source is! Map) {
      return true;
    }

    final dynamicSource = Map<String, dynamic>.from(
      source.cast<dynamic, dynamic>(),
    );
    final title = (dynamicSource['title'] ?? '').toString().trim();
    final description =
        (dynamicSource['description'] ?? dynamicSource['detail'] ?? '')
            .toString()
            .trim();
    final advertiserId =
        (dynamicSource['userId'] ?? dynamicSource['advertiserId'] ?? '')
            .toString()
            .trim();
    final imageUrls = _collectImageUrls(
      imageUrls: dynamicSource['imageUrls'],
      media: dynamicSource['media'],
      imageUrl: dynamicSource['imageUrl'],
      thumbnailUrl: dynamicSource['thumbnailUrl'],
    );

    return title.isEmpty ||
        description.isEmpty ||
        advertiserId.isEmpty ||
        imageUrls.isEmpty;
  }

  Future<Map<String, dynamic>?> _fetchMarketplaceOffer(String listingId) async {
    if (listingId.isEmpty) {
      return null;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('listings')
        .doc(listingId)
        .get();
    return snapshot.data();
  }

  String _toE164Like(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('+')) {
      final digits = trimmed.replaceAll(RegExp(r'\D'), '');
      return digits.isEmpty ? trimmed : '+$digits';
    }

    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.length == 10 && digits.startsWith('0')) {
      return '+33${digits.substring(1)}';
    }
    if (digits.length == 9 &&
        (digits.startsWith('6') || digits.startsWith('7'))) {
      return '+33$digits';
    }
    return digits;
  }

  Future<User?> _resolveSignedInUser() async {
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    if (currentUser != null) {
      return currentUser;
    }
    // Auth state is fully settled by the time the user interacts with a button.
    // Waiting on authStateChanges() here would block for up to 5 s when the
    // user is simply not signed in, delaying the auth popup unnecessarily.
    return null;
  }

  Future<User?> _ensureSignedInForOfferAction(
    BuildContext context, {
    required String area,
    required String offerId,
    required String title,
    required String description,
  }) async {
    final user = await _resolveSignedInUser();
    if (user != null) {
      return user;
    }
    if (!context.mounted) return null;

    final overlayTheme = context.prestoOverlayTheme;
    final startInSignup = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: overlayTheme.surfaceColor,
      shape: overlayTheme.sheetShape,
      builder: (sheetContext) {
        final bottom = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(6, 16, 6, bottom + 20),
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _headerOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(sheetContext).pop(false),
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
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: const Text('Je crée mon compte'),
              ),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(null),
                child: const Text('Plus tard'),
              ),
            ],
          ),
        );
      },
    );

    if (startInSignup == null || !context.mounted) {
      logRuntimeAction(
        area: area,
        action: 'auth-handoff-cancelled',
        details: <String, Object?>{'offerId': offerId},
      );
      return null;
    }

    logRuntimeAction(
      area: area,
      action: 'auth-handoff-opened',
      details: <String, Object?>{
        'offerId': offerId,
        'startInSignup': startInSignup,
      },
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AccountPage(startInSignup: startInSignup),
      ),
    );

    if (!context.mounted) {
      return null;
    }

    final resolvedUser = await _resolveSignedInUser();
    logRuntimeAction(
      area: area,
      action:
          resolvedUser == null ? 'auth-handoff-failed' : 'auth-handoff-success',
      details: <String, Object?>{
        'offerId': offerId,
        'userId': resolvedUser?.uid,
      },
    );
    return resolvedUser;
  }

  Future<void> _openInternalMessaging(
    BuildContext context,
    _OfferUiData data,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    User? authUser = FirebaseAuth.instance.currentUser;
    var me =
        authUser?.uid.isNotEmpty == true ? authUser!.uid : widget.currentUserId;

    logRuntimeAction(
      area: 'messaging',
      action: 'open-from-offer',
      details: <String, Object?>{
        'offerId': data.offerId,
        'advertiserId': data.advertiserId,
        'currentUserId': me,
      },
    );

    if (me.isEmpty || me == 'buyer_demo_001') {
      logRuntimeAction(
        area: 'messaging',
        action: 'blocked-auth',
        details: <String, Object?>{'offerId': data.offerId},
      );
      final signedInUser = await _ensureSignedInForOfferAction(
        context,
        area: 'messaging',
        offerId: data.offerId,
        title: 'Connectez-vous pour contacter l’annonceur',
        description:
            'Connectez-vous ou créez votre compte pour ouvrir la messagerie et reprendre cet échange.',
      );
      if (signedInUser == null) return;
      if (!context.mounted) return;
      authUser = signedInUser;
      me = signedInUser.uid;
    }

    if (data.advertiserId.isEmpty) {
      logRuntimeAction(
        area: 'messaging',
        action: 'blocked-missing-advertiser',
        details: <String, Object?>{'offerId': data.offerId},
      );
      messenger?.showSnackBar(
        const SnackBar(content: Text("Annonceur introuvable.")),
      );
      return;
    }

    if (data.advertiserId == me) {
      logRuntimeAction(
        area: 'messaging',
        action: 'blocked-self-message',
        details: <String, Object?>{'offerId': data.offerId},
      );
      messenger?.showSnackBar(
        const SnackBar(
          content: Text("Vous ne pouvez pas vous envoyer un message."),
        ),
      );
      return;
    }

    final currentUserName = authUser?.displayName?.trim().isNotEmpty == true
        ? authUser!.displayName!.trim()
        : (authUser?.email ?? 'Utilisateur');
    final initialDraftText =
        'Bonjour ${data.advertiserName}, je vous contacte au sujet de votre annonce "${data.title}".';

    try {
      unawaited(
        UserProfileBootstrapService.prepareProfileFirestoreAccess(
          user: authUser,
          forceRefreshAppCheckToken: true,
          requireAppCheckToken: false,
        ),
      );
    } catch (error) {
      logRuntimeAction(
        area: 'messaging',
        action: 'blocked-app-check-before-open',
        details: <String, Object?>{'offerId': data.offerId, 'error': error},
      );
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            UserProfileBootstrapService.userFacingProfileSyncMessage(error),
          ),
        ),
      );
      return;
    }

    final resolvedConversationId = await ConversationService.ensureConversation(
      offerId: data.offerId,
      offerTitle: data.title,
      currentUserId: me,
      otherUserId: data.advertiserId,
      currentUserName: currentUserName,
      otherUserName: data.advertiserName,
    );

    if (!context.mounted) return;
    final targetRoute = buildMessagesRoute(
      conversationId: resolvedConversationId,
      initialDraftText: initialDraftText,
    );
    logRuntimeAction(
      area: 'messaging',
      action: 'open-route',
      details: <String, Object?>{
        'route': targetRoute,
        'conversationId': resolvedConversationId,
        'offerId': data.offerId,
      },
    );
    navigator.pushNamed(targetRoute);
  }

  Future<void> _callPhone(BuildContext context, String phone) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (phone.trim().isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(content: Text("Aucun numéro disponible.")),
      );
      return;
    }

    final dial = _toE164Like(phone);
    final uri = Uri(scheme: 'tel', path: dial.isNotEmpty ? dial : phone.trim());
    final ok = await canLaunchUrl(uri);
    if (!ok) {
      if (!context.mounted) return;
      messenger?.showSnackBar(
        const SnackBar(
          content: Text("Impossible de lancer l'appel sur cet appareil."),
        ),
      );
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<String> _resolveCallablePhoneForOffer(_OfferUiData data) async {
    if (!data.isMarketplace || data.offerId.trim().isEmpty) {
      return data.phone.trim();
    }

    try {
      final callable = prestoFirebaseFunctions.httpsCallable(
        'getListingContactPhone',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'listingId': data.offerId,
      });
      final payload = result.data;
      final hidePhone = payload['hidePhone'] == true;
      if (hidePhone) {
        return '';
      }
      return (payload['phone'] ?? '').toString().trim();
    } on FirebaseFunctionsException {
      return data.phone.trim();
    } catch (_) {
      return data.phone.trim();
    }
  }

  Future<void> _openExternalShareTarget(
    BuildContext context, {
    required Uri uri,
    required String errorMessage,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await canLaunchUrl(uri);
    if (!context.mounted) return;
    if (!ok) {
      messenger?.showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showShareOptionsSheet(
    BuildContext context,
    _OfferUiData data,
  ) async {
    final overlayTheme = context.prestoOverlayTheme;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final detailPath = data.isMarketplace ? 'listings' : 'offers';
    final offerUrl = '${prestoPublicAppOrigin()}/#/$detailPath/${data.offerId}';
    final shareText = '${data.title} - ${data.city}\n$offerUrl';

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: overlayTheme.surfaceColor,
      shape: overlayTheme.sheetShape,
      builder: (sheetContext) {
        Future<void> copyLink() async {
          await Clipboard.setData(ClipboardData(text: offerUrl));
          if (!sheetContext.mounted) return;
          Navigator.of(sheetContext).pop();
          if (!context.mounted) return;
          messenger?.showSnackBar(
            const SnackBar(content: Text('Lien de l\'annonce copié.')),
          );
        }

        Future<void> openInstagram() async {
          await Clipboard.setData(ClipboardData(text: shareText));
          if (!sheetContext.mounted) return;
          Navigator.of(sheetContext).pop();
          await _openExternalShareTarget(
            context,
            uri: Uri.parse('https://www.instagram.com/'),
            errorMessage: 'Impossible d\'ouvrir Instagram.',
          );
          if (!context.mounted) return;
          messenger?.showSnackBar(
            const SnackBar(
              content: Text('Texte copié. Collez-le dans Instagram.'),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Container(
            color: overlayTheme.surfaceColor,
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Partager l\'annonce',
                  textAlign: TextAlign.center,
                  style: kPrestoSectionTitleStyle,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: overlayTheme.selectionFillColor,
                    borderRadius: overlayTheme.popupRadius,
                    border: Border.all(color: overlayTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          offerUrl,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: copyLink,
                        tooltip: 'Copier le lien',
                        icon: const Icon(
                          Icons.content_copy_rounded,
                          size: 20,
                          color: Color(0xFF111827),
                        ),
                        visualDensity: VisualDensity.compact,
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 14,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 0.8,
                  children: [
                    _ShareOptionTile(
                      icon: const FaIcon(
                        FontAwesomeIcons.whatsapp,
                        color: Colors.white,
                        size: 22,
                      ),
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await _openExternalShareTarget(
                          context,
                          uri: Uri.parse(
                            'https://wa.me/?text=${Uri.encodeComponent(shareText)}',
                          ),
                          errorMessage: 'Impossible d\'ouvrir WhatsApp.',
                        );
                      },
                    ),
                    _ShareOptionTile(
                      icon: const FaIcon(
                        FontAwesomeIcons.facebookF,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: 'Facebook',
                      color: const Color(0xFF1877F2),
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await _openExternalShareTarget(
                          context,
                          uri: Uri.parse(
                            'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(offerUrl)}',
                          ),
                          errorMessage: 'Impossible d\'ouvrir Facebook.',
                        );
                      },
                    ),
                    _ShareOptionTile(
                      icon: const FaIcon(
                        FontAwesomeIcons.instagram,
                        color: Colors.white,
                        size: 22,
                      ),
                      label: 'Instagram',
                      color: const Color(0xFFE1306C),
                      onTap: openInstagram,
                    ),
                    _ShareOptionTile(
                      icon: const FaIcon(
                        FontAwesomeIcons.envelope,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: 'Mail',
                      color: const Color(0xFF0459D9),
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await _openExternalShareTarget(
                          context,
                          uri: Uri(
                            scheme: 'mailto',
                            queryParameters: {
                              'subject': data.title,
                              'body': shareText,
                            },
                          ),
                          errorMessage:
                              'Impossible d\'ouvrir l\'application mail.',
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showContactOptionsSheet(
    BuildContext context,
    _OfferUiData data,
  ) async {
    final overlayTheme = context.prestoOverlayTheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      backgroundColor: overlayTheme.surfaceColor,
      shape: overlayTheme.sheetShape,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            color: overlayTheme.surfaceColor,
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Proposer mes services',
                  textAlign: TextAlign.center,
                  style: kPrestoSectionTitleStyle,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _openInternalMessaging(context, data);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6A00),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Envoyer un message'),
                  ),
                ),
                // Pour les listings marketplace, le numéro peut rester stocké
                // côté contact privé et être résolu au clic via callable.
                if (!data.hidePhone &&
                    (data.phone.trim().isNotEmpty ||
                        (data.isMarketplace &&
                            data.offerId.trim().isNotEmpty))) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        // Connexion requise avant de composer, cohérent avec la
                        // révélation du numéro par l'œil.
                        final signedInUser =
                            await _ensureSignedInForOfferAction(
                          context,
                          area: 'offer_call',
                          offerId: data.offerId,
                          title: 'Connectez-vous pour appeler l\'annonceur',
                          description:
                              'La connexion est nécessaire pour afficher et composer le numéro de cette annonce.',
                        );
                        if (signedInUser == null) return;
                        if (!context.mounted) return;
                        if (data.offerId.isNotEmpty) {
                          FirebaseFirestore.instance
                              .collection('listings')
                              .doc(data.offerId)
                              .update({
                            'phoneViewCount': FieldValue.increment(1),
                          }).ignore();
                        }
                        final phone = await _resolveCallablePhoneForOffer(data);
                        if (!context.mounted) return;
                        await _callPhone(context, phone);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0459D9),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.call_outlined),
                      label: const Text('Appeler'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    _OfferUiData data,
    bool isFavorite,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

    logRuntimeAction(
      area: 'favorites',
      action: 'toggle-from-offer',
      details: <String, Object?>{
        'offerId': data.offerId,
        'userId': uid,
        'isFavorite': isFavorite,
        'isMarketplace': data.isMarketplace,
      },
    );

    if (uid.isEmpty) {
      logRuntimeAction(
        area: 'favorites',
        action: 'blocked-auth',
        details: <String, Object?>{'offerId': data.offerId},
      );
      final signedInUser = await _ensureSignedInForOfferAction(
        context,
        area: 'favorites',
        offerId: data.offerId,
        title: 'Connectez-vous pour enregistrer cette annonce',
        description:
            'Vos favoris seront synchronisés avec votre compte pour retrouver cette annonce plus tard.',
      );
      if (signedInUser == null) return;
      if (!context.mounted) return;
      uid = signedInUser.uid.trim();
    }

    final offerId = data.offerId.trim();
    if (offerId.isEmpty) {
      logRuntimeAction(area: 'favorites', action: 'blocked-missing-offer');
      messenger?.showSnackBar(
        const SnackBar(content: Text('Annonce introuvable.')),
      );
      return;
    }

    try {
      final active = await _favoriteRepository.toggleFavorite(offerId);

      logRuntimeAction(
        area: 'favorites',
        action: 'toggle-success',
        details: <String, Object?>{
          'offerId': offerId,
          'active': active,
          'source': data.isMarketplace ? 'marketplace' : 'canonical-callable',
        },
      );

      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            active
                ? 'Annonce ajoutée aux favoris.'
                : 'Annonce retirée des favoris.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      logRuntimeAction(
        area: 'favorites',
        action: 'toggle-failure',
        details: <String, Object?>{
          'offerId': offerId,
          'errorType': e.runtimeType,
          'message': e,
          'code': e.code,
        },
      );
      if (!context.mounted) return;
      final isLegacyUnavailable = !data.isMarketplace &&
          (e.code == 'not-found' || e.code == 'failed-precondition');
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            isLegacyUnavailable
                ? 'Cette annonce legacy n\'a pas encore ete migree vers Marketplace. Les favoris ne sont disponibles que sur les listings canoniques.'
                : 'Erreur lors de la mise à jour du favori : $e',
          ),
        ),
      );
    } catch (e) {
      logRuntimeAction(
        area: 'favorites',
        action: 'toggle-failure',
        details: <String, Object?>{
          'offerId': offerId,
          'errorType': e.runtimeType,
          'message': e,
        },
      );
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour du favori : $e')),
      );
    }
  }

  Future<void> _showReportSheet(BuildContext context, _OfferUiData data) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

    logRuntimeAction(
      area: 'offers',
      action: 'report-open',
      details: <String, Object?>{
        'offerId': data.offerId,
        'userId': uid,
        'isMarketplace': data.isMarketplace,
      },
    );

    if (uid.isEmpty) {
      logRuntimeAction(
        area: 'offers',
        action: 'report-blocked-auth',
        details: <String, Object?>{'offerId': data.offerId},
      );
      final signedInUser = await _ensureSignedInForOfferAction(
        context,
        area: 'offers',
        offerId: data.offerId,
        title: 'Connectez-vous pour signaler cette annonce',
        description:
            'Votre signalement sera associé à votre compte pour que nous puissions le traiter correctement.',
      );
      if (signedInUser == null) return;
      if (!context.mounted) return;
      uid = signedInUser.uid.trim();
    }

    if (!data.isMarketplace || data.offerId.trim().isEmpty) {
      logRuntimeAction(
        area: 'offers',
        action: 'report-blocked-unsupported',
        details: <String, Object?>{
          'offerId': data.offerId,
          'isMarketplace': data.isMarketplace,
        },
      );
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'Le signalement est disponible uniquement pour Marketplace.',
          ),
        ),
      );
      return;
    }

    if (data.advertiserId.trim().isNotEmpty &&
        data.advertiserId.trim() == uid) {
      logRuntimeAction(
        area: 'offers',
        action: 'report-blocked-self',
        details: <String, Object?>{'offerId': data.offerId},
      );
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Vous ne pouvez pas signaler votre propre annonce.'),
        ),
      );
      return;
    }

    final overlayTheme = context.prestoOverlayTheme;
    final reason = await showModalBottomSheet<ListingReportReasonCode>(
      context: context,
      backgroundColor: overlayTheme.surfaceColor,
      shape: overlayTheme.sheetShape,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(6, 16, 6, 8),
                child: Text(
                  'Signaler l\'annonce',
                  textAlign: TextAlign.center,
                  style: kPrestoSectionTitleStyle,
                ),
              ),
              ...ListingReportReasonCode.values.map(
                (entry) => ListTile(
                  tileColor: overlayTheme.surfaceColor,
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(_reportReasonLabel(entry)),
                  onTap: () => Navigator.of(sheetContext).pop(entry),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (reason == null) {
      logRuntimeAction(
        area: 'offers',
        action: 'report-cancelled',
        details: <String, Object?>{'offerId': data.offerId},
      );
      return;
    }

    if (!context.mounted) {
      return;
    }

    String? reasonText;
    if (reason == ListingReportReasonCode.other) {
      final controller = TextEditingController();
      try {
        reasonText = await showDialog<String>(
          context: context,
          builder: (dialogContext) {
            final overlayTheme = dialogContext.prestoOverlayTheme;
            return AlertDialog(
              backgroundColor: overlayTheme.surfaceColor,
              surfaceTintColor: overlayTheme.surfaceTintColor,
              shape: overlayTheme.dialogShape,
              title: const Text('Précisez le motif'),
              content: TextField(
                controller: controller,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Décrivez brièvement le problème',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(controller.text.trim()),
                  child: const Text('Envoyer'),
                ),
              ],
            );
          },
        );
      } finally {
        controller.dispose();
      }

      if (!context.mounted) {
        return;
      }
    }

    try {
      final recaptchaToken = await _verification.obtainToken(
        MarketplaceHumanVerificationAction.listingReport,
      );
      final ok = await _reportRepository.reportListing(
        ListingReportDraft(
          listingId: data.offerId,
          reasonCode: reason,
          reasonText:
              (reasonText ?? '').trim().isEmpty ? null : reasonText!.trim(),
        ),
        recaptchaToken: recaptchaToken,
      );

      logRuntimeAction(
        area: 'offers',
        action: ok ? 'report-success' : 'report-rejected',
        details: <String, Object?>{
          'offerId': data.offerId,
          'reason': reason.name,
        },
      );

      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Signalement envoyé. Merci pour votre retour.'
                : 'Le signalement n\'a pas pu être envoyé.',
          ),
        ),
      );
    } catch (e) {
      logRuntimeAction(
        area: 'offers',
        action: 'report-failure',
        details: <String, Object?>{
          'offerId': data.offerId,
          'errorType': e.runtimeType,
          'message': e,
        },
      );
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Erreur lors du signalement : $e')),
      );
    }
  }

  String _reportReasonLabel(ListingReportReasonCode reason) {
    return switch (reason) {
      ListingReportReasonCode.spam => 'Spam',
      ListingReportReasonCode.fraud => 'Fraude',
      ListingReportReasonCode.inappropriate => 'Contenu inapproprié',
      ListingReportReasonCode.duplicate => 'Doublon',
      ListingReportReasonCode.wrongCategory => 'Mauvaise catégorie',
      ListingReportReasonCode.fakeListing => 'Annonce trompeuse',
      ListingReportReasonCode.harassment => 'Harcèlement',
      ListingReportReasonCode.other => 'Autre motif',
    };
  }

  Widget _buildFavoriteAction(BuildContext context, _OfferUiData data) {
    final authUser = FirebaseAuth.instance.currentUser;
    final uid = authUser?.uid.trim() ?? '';

    if (uid.isEmpty) {
      return IconButton(
        tooltip: 'Ajouter aux favoris',
        onPressed: () => _toggleFavorite(context, data, false),
        icon: const Icon(Icons.favorite_border_rounded),
        color: Colors.white,
        splashRadius: 20,
      );
    }

    return StreamBuilder<Set<String>>(
      stream: _favoriteRepository.watchFavoriteListingIds(uid),
      builder: (context, snapshot) {
        final favoriteIds = snapshot.data ?? const <String>{};
        final isFavorite = data.offerId.trim().isNotEmpty &&
            favoriteIds.contains(data.offerId.trim());

        return IconButton(
          tooltip: isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
          onPressed: () => _toggleFavorite(context, data, isFavorite),
          icon: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          ),
          color: isFavorite ? const Color(0xFFE53935) : Colors.white,
          splashRadius: 20,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget buildPage(Object? resolvedOffer) {
      const bg = Color(0xFFF6EFEC);
      final data = _OfferUiData.fromOffer(resolvedOffer);
      final screenWidth = MediaQuery.sizeOf(context).width;
      final isCompactMobile = screenWidth <= 360;
      final sectionGap = isCompactMobile ? 12.0 : 14.0;

      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          systemOverlayStyle: _statusBarStyle,
          leading: IconButton(
            tooltip: 'Retour',
            onPressed: () {
              if (widget.onBackToConsult != null) {
                widget.onBackToConsult!();
                return;
              }
              Navigator.of(context).maybePop();
            },
            icon: const Icon(Icons.arrow_back),
          ),
          backgroundColor: _headerOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleSpacing: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Détail annonce',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kPrestoAppBarTitleStyle,
          ),
          actions: [
            IconButton(
              tooltip: 'Partager',
              onPressed: () => _showShareOptionsSheet(context, data),
              icon: const Icon(Icons.share_outlined),
              color: Colors.white,
              splashRadius: 20,
            ),
            if (data.isMarketplace)
              IconButton(
                tooltip: 'Signaler',
                onPressed: () => _showReportSheet(context, data),
                icon: const Icon(Icons.flag_outlined),
                color: Colors.white,
                splashRadius: 20,
              ),
            _buildFavoriteAction(context, data),
            const SizedBox(width: 6),
          ],
        ),
        body: Stack(
          children: [
            const _BackgroundDecor(),
            SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  6,
                  isCompactMobile ? 10 : 12,
                  6,
                  isCompactMobile ? 14 : 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroCard(data: data, compact: isCompactMobile),
                    SizedBox(height: sectionGap),
                    _PracticalInfoCard(
                      data: data,
                      compact: isCompactMobile,
                      onContactTap: () =>
                          _showContactOptionsSheet(context, data),
                      onAdminDeleteTap: _isAdminViewer && data.isMarketplace
                          ? () => _confirmAdminDeleteOffer(context, data)
                          : null,
                    ),
                    SizedBox(height: sectionGap),
                    const _OfferDetailsAdMobBannerSpace(),
                    const SizedBox(height: 12),
                    _AdvertiserContactCard(
                      data: data,
                      compact: isCompactMobile,
                      onContactTap: () =>
                          _showContactOptionsSheet(context, data),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_marketplaceFuture == null) {
      return buildPage(widget.offer);
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _marketplaceFuture,
      builder: (context, snapshot) {
        final listingId = _extractMarketplaceListingId(widget.offer);
        final mergedOffer = _mergeMarketplaceOffer(
          widget.offer,
          snapshot.data,
          listingId,
        );
        return buildPage(mergedOffer);
      },
    );
  }
}

class _ListingViewTracker {
  static final Set<String> _countedListingIds = <String>{};
  static final String _sessionViewerKey =
      'session-${DateTime.now().millisecondsSinceEpoch}-${identityHashCode(_countedListingIds)}';

  static Future<void> trackOnce({
    required String listingId,
    required bool isMarketplace,
  }) async {
    final id = listingId.trim();

    if (id.isEmpty || !isMarketplace) return;

    if (!_countedListingIds.add(id)) {
      debugPrint('[listing-views] déjà comptée session listingId=$id');
      return;
    }

    try {
      final callable = prestoFirebaseFunctions.httpsCallable(
        'incrementListingView',
        options: HttpsCallableOptions(timeout: Duration(seconds: 10)),
      );

      await callable.call<dynamic>({
        'listingId': id,
        'viewerKey': _sessionViewerKey,
        'source': 'offer_details_page',
      });

      debugPrint('[listing-views] increment-ok listingId=$id');
    } catch (error) {
      _countedListingIds.remove(id);
      debugPrint('[listing-views] increment-failed listingId=$id error=$error');
    }
  }
}

class _OfferUiData {
  final String offerId;
  final bool isMarketplace;
  final String listingStatus;
  final String moderationStatus;
  final String mediaProcessingStatus;
  final int mediaCount;
  final DateTime? publishedAt;
  final String title;
  final String detail;
  final String city;
  final String postalCode;
  final bool isUrgent;
  final String category;
  final String description;
  final String phone;
  final String publishedAtLabel;
  final String availability;
  final double price;
  final OfferActionType actionType;
  final List<String> statusBadges;

  final String advertiserId;
  final String advertiserName;
  final String advertiserRole;
  final String advertiserAvatarUrl;
  final double advertiserRating;
  final int advertiserReviewCount;
  final bool verified;

  final String serviceArea;
  final bool canTravel;
  final String schedule;
  final String missionDelay;
  final String averageDelay;
  final String paymentMethod;
  final String serviceType;
  final List<String> imageUrls;
  final int viewCount;
  final int phoneViewCount;
  final bool hidePhone;
  final bool hideBudget;

  const _OfferUiData({
    required this.offerId,
    required this.isMarketplace,
    required this.listingStatus,
    required this.moderationStatus,
    required this.mediaProcessingStatus,
    required this.mediaCount,
    required this.publishedAt,
    required this.title,
    required this.detail,
    required this.city,
    required this.postalCode,
    required this.isUrgent,
    required this.category,
    required this.description,
    required this.phone,
    required this.publishedAtLabel,
    required this.availability,
    required this.price,
    required this.actionType,
    required this.statusBadges,
    required this.advertiserId,
    required this.advertiserName,
    required this.advertiserRole,
    required this.advertiserAvatarUrl,
    required this.advertiserRating,
    required this.advertiserReviewCount,
    required this.verified,
    required this.serviceArea,
    required this.canTravel,
    required this.schedule,
    required this.missionDelay,
    required this.averageDelay,
    required this.paymentMethod,
    required this.serviceType,
    this.imageUrls = const [],
    this.viewCount = 0,
    this.phoneViewCount = 0,
    this.hidePhone = false,
    this.hideBudget = false,
  });

  String get sanitizedTitle {
    var out = title.trim();
    if (out.isEmpty) return 'Annonce';
    final cityTrim = city.trim();
    final postalTrim = postalCode.trim();

    if (cityTrim.isNotEmpty) {
      out = out.replaceAll(
        RegExp(RegExp.escape(cityTrim), caseSensitive: false),
        ' ',
      );
    }
    if (postalTrim.isNotEmpty) {
      out = out.replaceAll(
        RegExp('\\b${RegExp.escape(postalTrim)}\\b', caseSensitive: false),
        ' ',
      );
    }

    out = out
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s*[-–|/]\s*$'), '')
        .trim();
    return out.isEmpty ? title.trim() : out;
  }

  bool get hasPhotos => mediaCount > 0;

  bool get isListingActive {
    final status = listingStatus.trim().toLowerCase();
    return status == 'active' || status == 'published';
  }

  bool get showPendingPhotoNotice {
    return isMarketplace && hasPhotos && !isListingActive;
  }

  bool get isMediaStillProcessing {
    return mediaProcessingStatus.trim().toLowerCase() == 'processing';
  }

  String get publishedAtExactLabel {
    final value = publishedAt;
    if (value == null) return publishedAtLabel;
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/$year à $hour:$minute';
  }

  factory _OfferUiData.fromOffer(Object? offer) {
    final dynamic o = offer;
    dynamic readValue(String key, [dynamic Function()? getter]) {
      if (o is Map) {
        return o[key];
      }
      return getter == null ? null : _read(getter);
    }

    dynamic readNestedValue(
      dynamic source,
      String key, [
      dynamic Function()? getter,
    ]) {
      if (source is Map) {
        return source[key];
      }
      return getter == null ? null : _read(getter);
    }

    final dynamic advertiser = readValue('advertiser', () => o.advertiser);
    final dynamic practical = readValue('practicalInfo', () => o.practicalInfo);

    final offerId = _asString(
      readValue('id', () => o.id) ??
          readValue('offerId') ??
          readValue('listingId'),
      fallback: '',
    );
    final marketplaceFlag = readValue('isMarketplace', () => o.isMarketplace);
    final isMarketplace = marketplaceFlag is bool
        ? marketplaceFlag
        : _asString(
              readValue('categoryId', () => o.categoryId),
              fallback: '',
            ).isNotEmpty ||
            _asString(
              readValue('cityId', () => o.cityId),
              fallback: '',
            ).isNotEmpty ||
            _asString(
              readValue('visibility', () => o.visibility),
              fallback: '',
            ).isNotEmpty;
    final listingStatus = _asString(
      readValue('status', () => o.status),
      fallback: '',
    );
    final moderationStatus = _asString(
      readValue('moderationStatus', () => o.moderationStatus),
      fallback: '',
    );
    final rawMedia = readValue('media', () => o.media);
    final rawImageUrls = readValue('imageUrls', () => o.imageUrls);
    final mediaCount = rawMedia is List
        ? rawMedia.length
        : rawImageUrls is List
            ? rawImageUrls.length
            : 0;
    final mediaProcessingStatus = _asString(
      readValue('mediaProcessingStatus'),
      fallback: (!listingStatus.trim().toLowerCase().contains('active') &&
              !listingStatus.trim().toLowerCase().contains('published') &&
              mediaCount > 0)
          ? 'processing'
          : 'completed',
    );
    final title = _asString(
      readValue('title', () => o.title),
      fallback: 'Montage meuble',
    );
    final publishedAt = _asDateTime(
      readValue('publishedAt', () => o.publishedAt) ??
          readValue('createdAt', () => o.createdAt) ??
          readValue('updatedAt', () => o.updatedAt),
    );
    final detail = _asString(
      readValue('shortDescription', () => o.shortDescription) ??
          readValue('detail'),
      fallback: '',
    );
    final city = _asString(
      readValue('city', () => o.city) ?? readValue('location'),
      fallback: '',
    );
    final postalCode = _asString(
      readValue('postalCode', () => o.postalCode) ?? readValue('cp'),
      fallback: '',
    );
    final category = _asString(
      readValue('category', () => o.category),
      fallback: '',
    );

    final fullDescription = _asString(
      readValue('description', () => o.description),
      fallback: '',
    );
    final phone = _asString(readValue('phone', () => o.phone), fallback: '');
    final publishedAtLabel = _asString(
      readValue('publishedAtLabel', () => o.publishedAtLabel),
      fallback: 'Publication récente',
    );
    final availability = _asString(
      readValue('availability', () => o.availability),
      fallback: 'Disponibilité à confirmer',
    );
    final actionTypeRaw = readValue('actionType', () => o.actionType);
    final actionType = actionTypeRaw is OfferActionType
        ? actionTypeRaw
        : OfferActionType.contact;
    final statusBadges = _asStringList(
      readValue('statusBadges', () => o.statusBadges),
    );
    final urgentRaw =
        readValue('isUrgent', () => o.isUrgent) ?? readValue('urgent');
    final isUrgent = urgentRaw is bool
        ? urgentRaw
        : statusBadges.any((badge) => badge.toLowerCase().contains('urgent'));

    final price = _asDouble(
      readValue('price', () => o.price) ?? readValue('budget'),
      fallback: 0,
    );

    final advertiserId = _asString(
      readNestedValue(advertiser, 'id', () => advertiser.id) ??
          readValue('userId', () => o.userId) ??
          readValue('uid', () => o.uid) ??
          readValue('ownerId', () => o.ownerId),
      fallback: '',
    );
    final advertiserName = _asString(
      readNestedValue(advertiser, 'name', () => advertiser.name) ??
          readValue('pseudo') ??
          readValue('displayName') ??
          readValue('ownerName') ??
          readValue('name') ??
          readValue('userName'),
      fallback: 'Annonceur iliprestō',
    );
    final advertiserRole = _asString(
      readNestedValue(advertiser, 'bio', () => advertiser.bio) ??
          readValue('bio'),
      fallback: 'Bricoleur expérimenté',
    );
    final advertiserAvatarUrl = _asString(
      readNestedValue(advertiser, 'avatarUrl', () => advertiser.avatarUrl) ??
          readNestedValue(advertiser, 'photoUrl') ??
          readNestedValue(advertiser, 'photoURL') ??
          readNestedValue(advertiser, 'profilePhotoUrl') ??
          readNestedValue(advertiser, 'imageUrl') ??
          readValue('avatarUrl') ??
          readValue('photoUrl') ??
          readValue('photoURL') ??
          readValue('profilePhotoUrl') ??
          readValue('imageUrl'),
      fallback: '',
    );
    final advertiserRating = _asDouble(
      readNestedValue(advertiser, 'rating', () => advertiser.rating) ??
          readValue('rating'),
      fallback: 0.0,
    );
    final advertiserReviewCount = _asInt(
      readNestedValue(
            advertiser,
            'reviewsCount',
            () => advertiser.reviewsCount,
          ) ??
          readNestedValue(
            advertiser,
            'reviewCount',
            () => advertiser.reviewCount,
          ) ??
          readValue('reviewsCount'),
      fallback: 0,
    );
    final verified = _asBool(
      readNestedValue(advertiser, 'verified', () => advertiser.verified) ??
          readValue('verified'),
      fallback: true,
    );

    final serviceArea = _asString(
      readNestedValue(practical, 'serviceArea', () => practical.serviceArea),
      fallback: city,
    );
    final canTravel = _asBool(
      readNestedValue(practical, 'canTravel', () => practical.canTravel),
      fallback: true,
    );
    final schedule = _asString(
      readNestedValue(practical, 'schedule', () => practical.schedule),
      fallback: 'Horaires à convenir',
    );
    final missionDelay = _asString(
      readNestedValue(
            practical,
            'missionDelay',
            () => practical.missionDelay,
          ) ??
          readValue('missionDelay', () => o.missionDelay) ??
          readValue('averageDelay', () => o.averageDelay),
      fallback: 'Délai non précisé',
    );
    final averageDelay = _asString(
      readNestedValue(
            practical,
            'averageDelay',
            () => practical.averageDelay,
          ) ??
          readValue('averageDelay', () => o.averageDelay),
      fallback: '30 min en moyenne',
    );
    final paymentMethod = _asString(
      readNestedValue(
        practical,
        'paymentMethod',
        () => practical.paymentMethod,
      ),
      fallback: 'Paiement à convenir',
    );
    final serviceType = _asString(
      readNestedValue(practical, 'serviceType', () => practical.serviceType),
      fallback: 'Prestation ponctuelle',
    );

    final rawImageUrlsList = _collectOfferDetailImageUrls(
      imageUrls: rawImageUrls,
      media: rawMedia,
      imageUrl: readValue('imageUrl'),
      thumbnailUrl: readValue('thumbnailUrl', () => o.thumbnailUrl),
    );

    final uiData = _OfferUiData(
      offerId: offerId,
      isMarketplace: isMarketplace,
      listingStatus: listingStatus,
      moderationStatus: moderationStatus,
      mediaProcessingStatus: mediaProcessingStatus,
      mediaCount: mediaCount,
      publishedAt: publishedAt,
      title: title,
      detail: detail,
      city: city,
      postalCode: postalCode,
      isUrgent: isUrgent,
      category: category,
      description: fullDescription,
      phone: phone,
      publishedAtLabel: publishedAtLabel,
      availability: availability,
      price: price,
      actionType: actionType,
      statusBadges: statusBadges,
      advertiserId: advertiserId,
      advertiserName: advertiserName,
      advertiserRole: advertiserRole,
      advertiserAvatarUrl: advertiserAvatarUrl,
      advertiserRating: advertiserRating,
      advertiserReviewCount: advertiserReviewCount,
      verified: verified,
      serviceArea: serviceArea,
      canTravel: canTravel,
      schedule: schedule,
      missionDelay: missionDelay,
      averageDelay: averageDelay,
      paymentMethod: paymentMethod,
      serviceType: serviceType,
      imageUrls: rawImageUrlsList.cast<String>(),
      viewCount: _asInt(readValue('viewCount'), fallback: 0),
      phoneViewCount: _asInt(
        readValue('phoneViewCount') ??
            readValue('phoneViews') ??
            readValue('contactViews'),
        fallback: 0,
      ),
      hidePhone: readValue('hidePhone') == true,
      hideBudget: o is Map
          ? _shouldHideBudgetOnOfferDetails(Map<String, dynamic>.from(o))
          : price <= 0,
    );

    unawaited(
      _ListingViewTracker.trackOnce(
        listingId: uiData.offerId,
        isMarketplace: uiData.isMarketplace,
      ),
    );

    return uiData;
  }

  static dynamic _read(dynamic Function() getter) {
    try {
      return getter();
    } catch (_) {
      return null;
    }
  }

  static String _asString(dynamic value, {required String fallback}) {
    if (value == null) return fallback;
    final s = value.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static double _asDouble(dynamic value, {required double fallback}) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static int _asInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static bool _asBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    return fallback;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toLocal();
    }
    return null;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }
}

class _BackgroundDecor extends StatelessWidget {
  const _BackgroundDecor();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFFF6EFEC))),
        Positioned(
          left: -60,
          bottom: 120,
          child: IgnorePointer(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1976F3).withValues(alpha: 0.12),
                    const Color(0xFF1976F3).withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final _OfferUiData data;
  final bool compact;

  const _HeroCard({required this.data, this.compact = false});

  void _openGallery(BuildContext context, int initialIndex) {
    if (data.imageUrls.isEmpty) return;
    _showPhotoGalleryPopup(
      context,
      imageUrls: data.imageUrls,
      initialIndex: initialIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    const card = Colors.white;
    const textPrimary = Color(0xFF111B4A);
    const textMuted = Color(0xFF6B708D);
    const divider = Color(0xFFECE6E3);
    const orange2 = Color(0xFFFF7A00);
    final locationLine = data.postalCode.trim().isEmpty
        ? data.city
        : '${data.city} ${data.postalCode}';
    final detailsLine = data.detail.trim().isNotEmpty
        ? data.detail.trim()
        : data.description.trim();
    final hasPhotos = data.imageUrls.isNotEmpty;
    final mainPhotoUrl = hasPhotos ? data.imageUrls.first : '';

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        border: Border.all(color: const Color(0xFFF0E7E4), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Photo principale ──
          if (hasPhotos)
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(compact ? 20 : 24),
              ),
              child: SizedBox(
                width: double.infinity,
                height: compact ? 180 : 220,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _OfferImage(
                      rawUrl: mainPhotoUrl,
                      fit: BoxFit.cover,
                      loadingChild: Container(
                        color: const Color(0xFFF3F4F6),
                        child: const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFFFF6A00),
                            ),
                          ),
                        ),
                      ),
                      errorChild: Container(
                        color: const Color(0xFFF3F4F6),
                        child: const Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 48,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ),
                    _PhotoGalleryTapOverlay(
                      onTap: () => _openGallery(context, 0),
                    ),
                  ],
                ),
              ),
            ),
          // ── Miniatures additionnelles ──
          if (data.imageUrls.length > 1)
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 16,
                compact ? 8 : 10,
                compact ? 12 : 16,
                0,
              ),
              child: SizedBox(
                height: compact ? 56 : 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: data.imageUrls.length,
                  separatorBuilder: (_, __) => SizedBox(width: compact ? 6 : 8),
                  itemBuilder: (context, index) {
                    final isSelected = index == 0;
                    return Container(
                      width: compact ? 56 : 64,
                      height: compact ? 56 : 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(compact ? 10 : 12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF6A00)
                              : const Color(0xFFE5E7EB),
                          width: isSelected ? 2.5 : 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          (compact ? 10 : 12) - 1,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _OfferImage(
                              rawUrl: data.imageUrls[index],
                              fit: BoxFit.cover,
                              errorChild: Container(
                                color: const Color(0xFFF3F4F6),
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: Color(0xFF9CA3AF),
                                  size: 20,
                                ),
                              ),
                            ),
                            _PhotoGalleryTapOverlay(
                              onTap: () => _openGallery(context, index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          // ── Contenu texte ──
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 15 : 18,
              hasPhotos ? (compact ? 10 : 12) : (compact ? 15 : 18),
              compact ? 15 : 18,
              compact ? 15 : 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.sanitizedTitle.toUpperCase(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 17 : 18,
                    height: 1.0,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: compact ? 6 : 7),
                Text(
                  locationLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 12.5 : 13,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                    letterSpacing: -0.1,
                  ),
                ),
                SizedBox(height: compact ? 4 : 5),
                Text(
                  data.publishedAtExactLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 12 : 12.5,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                    color: textMuted,
                    letterSpacing: -0.05,
                  ),
                ),
                Builder(
                  builder: (context) {
                    final me = FirebaseAuth.instance.currentUser?.uid ?? '';
                    final isOwner = me.isNotEmpty && me == data.advertiserId;
                    if (!isOwner) return const SizedBox.shrink();
                    return Padding(
                      padding: EdgeInsets.only(top: compact ? 4 : 5),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 2,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.visibility_outlined,
                                size: 13,
                                color: Color(0xFF6B708D),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${data.viewCount} vue${data.viewCount > 1 ? "s" : ""}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B708D),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (data.phoneViewCount > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 13,
                                  color: Color(0xFF6B708D),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${data.phoneViewCount} contact${data.phoneViewCount > 1 ? "s" : ""}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B708D),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
                SizedBox(height: compact ? 10 : 12),
                Text(
                  detailsLine,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: compact ? 14 : 15,
                    height: 1.28,
                    fontWeight: FontWeight.w500,
                    color: textPrimary.withValues(alpha: 0.9),
                  ),
                ),
                if (data.showPendingPhotoNotice) ...[
                  SizedBox(height: compact ? 10 : 12),
                  _PendingPhotoNotice(
                    compact: compact,
                    isProcessing: data.isMediaStillProcessing,
                    moderationStatus: data.moderationStatus,
                  ),
                ],
                SizedBox(height: compact ? 10 : 12),
                Container(height: 1, color: divider),
                SizedBox(height: compact ? 10 : 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (data.isUrgent) ...[
                              _UrgentBadge(compact: compact),
                              if (!data.hideBudget)
                                SizedBox(width: compact ? 8 : 10),
                            ],
                            if (!data.hideBudget)
                              Text(
                                '${data.price.toStringAsFixed(0)} €',
                                style: TextStyle(
                                  fontSize: compact ? 28 : 30,
                                  height: 1.0,
                                  fontWeight: FontWeight.w800,
                                  color: orange2,
                                  letterSpacing: -0.6,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingPhotoNotice extends StatelessWidget {
  final bool compact;
  final bool isProcessing;
  final String moderationStatus;

  const _PendingPhotoNotice({
    required this.compact,
    required this.isProcessing,
    required this.moderationStatus,
  });

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFFFC78F);
    const background = Color(0xFFFFF3E6);
    const accent = Color(0xFFFF7A00);
    const titleColor = Color(0xFF8A3B00);
    const bodyColor = Color(0xFF7A4A21);

    final normalizedModeration = moderationStatus.trim().toLowerCase();
    final message = isProcessing
        ? 'Photos en traitement. Publication automatique une fois les photos prêtes.'
        : normalizedModeration == 'manual_review' ||
                normalizedModeration == 'pending'
            ? 'Annonce en cours de vérification avant publication.'
            : 'Cette annonce reste temporairement hors ligne avant publication.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 14,
        compact ? 10 : 12,
        compact ? 12 : 14,
        compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 28 : 32,
            height: compact ? 28 : 32,
            decoration: const BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isProcessing ? Icons.sync_rounded : Icons.hourglass_top_rounded,
              size: compact ? 16 : 18,
              color: Colors.white,
            ),
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isProcessing
                      ? 'Photos en traitement'
                      : 'Annonce en attente de validation',
                  style: TextStyle(
                    fontSize: compact ? 12.5 : 13.5,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                SizedBox(height: compact ? 4 : 5),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: compact ? 11.5 : 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: bodyColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoGalleryTapOverlay extends StatelessWidget {
  final VoidCallback onTap;

  const _PhotoGalleryTapOverlay({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.08),
          highlightColor: Colors.white.withValues(alpha: 0.04),
        ),
      ),
    );
  }
}

// ─── Photo gallery ───────────────────────────────────────────────────────────

Future<void> _showPhotoGalleryPopup(
  BuildContext context, {
  required List<String> imageUrls,
  required int initialIndex,
}) {
  if (imageUrls.isEmpty) return Future<void>.value();
  final safeIndex = initialIndex.clamp(0, imageUrls.length - 1);
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Fermer',
    barrierColor: Colors.black87,
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, __) {
      return _PhotoGalleryPopup(imageUrls: imageUrls, initialIndex: safeIndex);
    },
  );
}

class _PhotoGalleryPopup extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _PhotoGalleryPopup({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_PhotoGalleryPopup> createState() => _PhotoGalleryPopupState();
}

class _PhotoGalleryPopupState extends State<_PhotoGalleryPopup> {
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.imageUrls.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: _OfferImage(
                        rawUrl: widget.imageUrls[index],
                        fit: BoxFit.contain,
                        errorChild: const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.black26,
                          size: 64,
                        ),
                        loadingChild: const SizedBox.shrink(),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 10,
              left: 6,
              right: 6,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_currentPage + 1} / ${widget.imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close_rounded),
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

final Map<String, Future<String?>> _offerImageUrlCache =
    <String, Future<String?>>{};

Future<String?> _resolveOfferImageUrl(String rawUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) {
    return Future<String?>.value(null);
  }
  if (trimmed.startsWith('http://') ||
      trimmed.startsWith('https://') ||
      trimmed.startsWith('data:image/')) {
    return Future<String?>.value(trimmed);
  }
  if (trimmed.startsWith('//')) {
    return Future<String?>.value('https:$trimmed');
  }

  final cached = _offerImageUrlCache[trimmed];
  if (cached != null) {
    return cached;
  }

  final future = () async {
    try {
      if (trimmed.startsWith('gs://')) {
        final resolved =
            await FirebaseStorage.instance.refFromURL(trimmed).getDownloadURL();
        if (resolved.trim().isEmpty) {
          _offerImageUrlCache.remove(trimmed);
          return null;
        }
        return resolved;
      }

      final normalizedPath =
          trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
      if (normalizedPath.isEmpty) {
        _offerImageUrlCache.remove(trimmed);
        return null;
      }

      final resolved = await FirebaseStorage.instance
          .ref()
          .child(normalizedPath)
          .getDownloadURL();
      if (resolved.trim().isEmpty) {
        _offerImageUrlCache.remove(trimmed);
        return null;
      }
      return resolved;
    } catch (_) {
      // Ne pas retourner un path Storage brut à Image.network.
      _offerImageUrlCache.remove(trimmed);
      return null;
    }
  }();

  _offerImageUrlCache[trimmed] = future;
  return future;
}

class _OfferImage extends StatelessWidget {
  final String rawUrl;
  final BoxFit fit;
  final Widget errorChild;
  final Widget? loadingChild;

  const _OfferImage({
    required this.rawUrl,
    required this.fit,
    required this.errorChild,
    this.loadingChild,
  });

  static bool _isDirectUrl(String url) {
    return url.startsWith('https://') ||
        url.startsWith('http://') ||
        url.startsWith('data:image/') ||
        url.startsWith('//');
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = rawUrl.trim();

    // URL déjà résolue — pas de FutureBuilder, pas de clignotement
    if (trimmed.isEmpty) return errorChild;
    if (_isDirectUrl(trimmed)) {
      final url = trimmed.startsWith('//') ? 'https:$trimmed' : trimmed;
      return OfferNetworkImage(
        url: url,
        fit: fit,
        errorChild: errorChild,
        loadingChild: loadingChild,
      );
    }

    // Chemin Storage → résolution async nécessaire
    return FutureBuilder<String?>(
      future: _resolveOfferImageUrl(rawUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return loadingChild ?? errorChild;
        }
        final resolvedUrl = (snapshot.data ?? '').trim();
        if (resolvedUrl.isEmpty) return errorChild;
        return OfferNetworkImage(
          url: resolvedUrl,
          fit: fit,
          errorChild: errorChild,
          loadingChild: loadingChild,
        );
      },
    );
  }
}

class _AdminDeleteListingButton extends StatelessWidget {
  final bool compact;
  final VoidCallback onTap;

  const _AdminDeleteListingButton({required this.compact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Supprimer l\'annonce',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 9,
            vertical: compact ? 5 : 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEFEF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFF3C3C3)),
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            size: compact ? 16 : 17,
            color: const Color(0xFFD14343),
          ),
        ),
      ),
    );
  }
}

class _PracticalInfoCard extends StatelessWidget {
  final _OfferUiData data;
  final bool compact;
  final VoidCallback onContactTap;
  final VoidCallback? onAdminDeleteTap;

  const _PracticalInfoCard({
    required this.data,
    this.compact = false,
    required this.onContactTap,
    this.onAdminDeleteTap,
  });

  Widget _paymentInfoPill(BuildContext context) {
    return AnimatedPaymentInfoPill(onTap: () => showPaymentInfoPopup(context));
  }

  @override
  Widget build(BuildContext context) {
    const blueSoft = Color(0xFFDCEBFF);
    const line = Color(0xFFE6E3E6);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 28 : 32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B8E86).withValues(alpha: 0.10),
            blurRadius: compact ? 18 : 22,
            offset: Offset(0, compact ? 8 : 10),
          ),
          BoxShadow(
            color: blueSoft.withValues(alpha: 0.55),
            blurRadius: compact ? 15 : 18,
            spreadRadius: 1,
            offset: Offset(0, compact ? 11 : 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFBFAFA),
              borderRadius: BorderRadius.circular(compact ? 20 : 24),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : 18,
                compact ? 12 : 16,
                compact ? 14 : 18,
                compact ? 14 : 18,
              ),
              child: Column(
                children: [
                  _InfoLine(
                    icon: Icons.handyman_outlined,
                    label: 'Catégorie',
                    value: data.category,
                    compact: compact,
                  ),
                  _InfoLine(
                    icon: Icons.map_outlined,
                    label: 'Zone d\'intervention',
                    value: data.serviceArea,
                    compact: compact,
                  ),
                  _InfoLine(
                    icon: Icons.access_time_rounded,
                    label: 'Horaires',
                    value: data.schedule,
                    compact: compact,
                  ),
                  if (data.missionDelay.isNotEmpty &&
                      data.missionDelay != 'Délai non précisé')
                    _InfoLine(
                      icon: Icons.access_time_rounded,
                      label: 'Délai d’intervention',
                      value: data.missionDelay,
                      compact: compact,
                      labelSuffix: onAdminDeleteTap == null
                          ? null
                          : _AdminDeleteListingButton(
                              compact: compact,
                              onTap: onAdminDeleteTap!,
                            ),
                    ),
                  if ((data.missionDelay.isEmpty ||
                          data.missionDelay == 'Délai non précisé') &&
                      onAdminDeleteTap != null)
                    _InfoLine(
                      icon: Icons.shield_outlined,
                      label: 'Action admin',
                      value: 'Supprimer cette annonce',
                      compact: compact,
                      labelSuffix: _AdminDeleteListingButton(
                        compact: compact,
                        onTap: onAdminDeleteTap!,
                      ),
                    ),
                  const Divider(height: 1, thickness: 1, color: line),
                  _InfoLine(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Mode de paiement',
                    value: 'À convenir',
                    compact: compact,
                    labelSuffix: _paymentInfoPill(context),
                  ),
                  _InfoLine(
                    icon: Icons.work_outline_rounded,
                    label: 'Type de prestation',
                    value: data.serviceType.toLowerCase().contains('ponct')
                        ? 'Ponctuelle'
                        : data.serviceType,
                    compact: compact,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferDetailsAdMobBannerSpace extends StatelessWidget {
  const _OfferDetailsAdMobBannerSpace();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Espace publicitaire AdMob',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56, maxHeight: 82),
          child: const Center(
            child: Text(
              'Espace publicitaire',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdvertiserContactCard extends StatelessWidget {
  final _OfferUiData data;
  final bool compact;
  final VoidCallback onContactTap;

  const _AdvertiserContactCard({
    required this.data,
    this.compact = false,
    required this.onContactTap,
  });

  Future<void> _openProfile(BuildContext context) async {
    final uid = data.advertiserId.trim();
    if (uid.isEmpty) return;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final accountType = (doc.data()?['accountType'] ?? '').toString();
    if (accountType != 'Entreprise') return;
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FicheProPage(uid: uid, isOwner: false)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const blueSoft = Color(0xFFDCEBFF);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 28 : 32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B8E86).withValues(alpha: 0.10),
            blurRadius: compact ? 18 : 22,
            offset: Offset(0, compact ? 8 : 10),
          ),
          BoxShadow(
            color: blueSoft.withValues(alpha: 0.55),
            blurRadius: compact ? 15 : 18,
            spreadRadius: 1,
            offset: Offset(0, compact ? 11 : 14),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFBFAFA),
          borderRadius: BorderRadius.circular(compact ? 20 : 24),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 18,
            compact ? 12 : 16,
            compact ? 14 : 18,
            compact ? 14 : 18,
          ),
          child: Column(
            children: [
              Semantics(
                button: true,
                label: 'Voir le profil de ${data.advertiserName}',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openProfile(context),
                    child: _AdvertiserHeaderLine(
                      advertiserName: data.advertiserName,
                      verified: data.verified,
                      compact: compact,
                    ),
                  ),
                ),
              ),
              _AdvertiserMetaLine(
                advertiserRating: data.advertiserRating,
                advertiserReviewCount: data.advertiserReviewCount,
                verified: data.verified,
                compact: compact,
              ),
              _MaskedPhoneInfoLine(
                phone: data.phone,
                offerId: data.offerId,
                hidePhone: data.hidePhone,
                compact: compact,
              ),
              SizedBox(height: compact ? 12 : 14),
              _InlineCta(
                label: 'Proposer mes services',
                compact: compact,
                onTap: onContactTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvertiserHeaderLine extends StatelessWidget {
  final String advertiserName;
  final bool verified;
  final bool compact;

  const _AdvertiserHeaderLine({
    required this.advertiserName,
    required this.verified,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF18233D);
    const muted = Color(0xFF6F7282);
    const green = Color(0xFF45B36B);
    const line = Color(0xFFE6E3E6);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: compact ? 34 : 38,
                height: compact ? 34 : 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2F7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  size: compact ? 20 : 22,
                  color: navy,
                ),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            advertiserName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: navy,
                              fontSize: compact ? 16 : 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.15,
                            ),
                          ),
                        ),
                        if (verified) ...[
                          SizedBox(width: compact ? 6 : 8),
                          Icon(
                            Icons.check_circle_rounded,
                            size: compact ? 16 : 18,
                            color: green,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: compact ? 4 : 5),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          color: muted,
                          size: compact ? 13 : 14,
                        ),
                        SizedBox(width: compact ? 4 : 5),
                        Text(
                          'Réponse en moins d\'une heure',
                          style: TextStyle(
                            color: muted,
                            fontSize: compact ? 12 : 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: line),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool compact;
  final Widget? labelSuffix;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.compact = false,
    this.labelSuffix,
  });

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF18233D);
    const muted = Color(0xFF6F7282);
    const line = Color(0xFFE6E3E6);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final shouldStack =
                  labelSuffix != null || constraints.maxWidth < 360;

              if (shouldStack) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      icon,
                      color: const Color(0xFF6C7384),
                      size: compact ? 20 : 22,
                    ),
                    SizedBox(width: compact ? 8 : 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: compact ? 7 : 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  color: muted,
                                  fontSize: compact ? 15 : 16,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.1,
                                ),
                              ),
                              if (labelSuffix != null) labelSuffix!,
                            ],
                          ),
                          SizedBox(height: compact ? 6 : 8),
                          Text(
                            value,
                            style: TextStyle(
                              color: navy,
                              fontSize: compact ? 15 : 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: const Color(0xFF6C7384),
                    size: compact ? 20 : 22,
                  ),
                  SizedBox(width: compact ? 8 : 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: muted,
                        fontSize: compact ? 15 : 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 10),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        value,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: navy,
                          fontSize: compact ? 15 : 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.15,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const Divider(height: 1, thickness: 1, color: line),
      ],
    );
  }
}

class _AdvertiserMetaLine extends StatelessWidget {
  final double advertiserRating;
  final int advertiserReviewCount;
  final bool verified;
  final bool compact;

  const _AdvertiserMetaLine({
    required this.advertiserRating,
    required this.advertiserReviewCount,
    required this.verified,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF18233D);
    const muted = Color(0xFF6F7282);
    const orange = Color(0xFFFF7B12);
    const green = Color(0xFF45B36B);
    const line = Color(0xFFE6E3E6);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: compact ? 26 : 30,
                height: compact ? 26 : 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2F7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  size: compact ? 16 : 18,
                  color: navy,
                ),
              ),
              SizedBox(width: compact ? 8 : 10),
              Text(
                'Profil',
                style: TextStyle(
                  color: muted,
                  fontSize: compact ? 15 : 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
              const Spacer(),
              if (verified) ...[
                Icon(
                  Icons.check_circle_rounded,
                  size: compact ? 15 : 17,
                  color: green,
                ),
                SizedBox(width: compact ? 4 : 5),
              ],
              if (advertiserRating > 0) ...[
                Icon(
                  Icons.star_rounded,
                  size: compact ? 15 : 17,
                  color: orange,
                ),
                SizedBox(width: compact ? 4 : 5),
                Text(
                  advertiserRating.toStringAsFixed(1),
                  style: TextStyle(
                    color: orange,
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: compact ? 6 : 8),
                Text(
                  advertiserReviewCount > 0
                      ? '($advertiserReviewCount avis)'
                      : '(0 avis)',
                  style: TextStyle(
                    color: navy,
                    fontSize: compact ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ] else ...[
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 9 : 11,
                    vertical: compact ? 4 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: green,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: green.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'Nouveau',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 12.5 : 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: line),
      ],
    );
  }
}

class _MaskedPhoneInfoLine extends StatefulWidget {
  final String phone;
  final bool compact;
  final bool hidePhone;
  final String offerId;

  const _MaskedPhoneInfoLine({
    required this.phone,
    required this.offerId,
    this.compact = false,
    this.hidePhone = false,
  });

  @override
  State<_MaskedPhoneInfoLine> createState() => _MaskedPhoneInfoLineState();
}

class _MaskedPhoneInfoLineState extends State<_MaskedPhoneInfoLine> {
  bool _isPhoneVisible = false;
  bool _isResolvingContact = false;
  String? _resolvedPhone;
  String? _resolvedDialingCode;

  @override
  void initState() {
    super.initState();
    _prefetchContactPreviewIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _MaskedPhoneInfoLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offerId != widget.offerId ||
        oldWidget.phone != widget.phone ||
        oldWidget.hidePhone != widget.hidePhone) {
      _resolvedPhone = null;
      _resolvedDialingCode = null;
      _isPhoneVisible = false;
      _prefetchContactPreviewIfNeeded();
    }
  }

  Future<void> _prefetchContactPreviewIfNeeded() async {
    if (widget.offerId.trim().isEmpty) return;
    if (widget.phone.trim().isNotEmpty && !widget.hidePhone) return;
    await _resolveListingContact(allowFullPhone: false);
  }

  Future<void> _resolveListingContact({required bool allowFullPhone}) async {
    if (_isResolvingContact || widget.offerId.trim().isEmpty) return;

    setState(() {
      _isResolvingContact = true;
    });

    try {
      final callable = prestoFirebaseFunctions.httpsCallable(
        'getListingContactPhone',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'listingId': widget.offerId,
      });

      final payload = result.data;
      final dialingCode = (payload['dialingCode'] ?? '').toString().trim();
      final phone = (payload['phone'] ?? '').toString().trim();

      if (!mounted) return;

      setState(() {
        if (dialingCode.isNotEmpty) {
          _resolvedDialingCode = dialingCode;
        }
        if (allowFullPhone && phone.isNotEmpty) {
          _resolvedPhone = phone;
        }
      });
    } on FirebaseFunctionsException {
      // L'échec de résolution ne doit pas casser l'UI contact.
    } catch (_) {
      // Best effort.
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingContact = false;
        });
      }
    }
  }

  String _effectivePhone() {
    final resolved = (_resolvedPhone ?? '').trim();
    if (resolved.isNotEmpty) return resolved;
    return widget.phone.trim();
  }

  Future<void> _handlePhoneVisibility() async {
    // L'utilisateur peut toujours remasquer un numéro déjà affiché.
    if (_isPhoneVisible) {
      if (!mounted) return;

      setState(() {
        _isPhoneVisible = false;
      });
      return;
    }

    // Le choix de l'annonceur reste prioritaire.
    if (widget.hidePhone) {
      return;
    }

    if (_effectivePhone().isEmpty) {
      await _resolveListingContact(allowFullPhone: true);
    }

    final effectivePhone = _effectivePhone();
    if (effectivePhone.isEmpty) {
      return;
    }

    // La révélation du numéro nécessite un compte connecté.
    if (FirebaseAuth.instance.currentUser == null) {
      final shouldConnect = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Connexion requise'),
            content: const Text(
              'Connectez-vous pour afficher le numéro de téléphone '
              'de cette annonce.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Se connecter'),
              ),
            ],
          );
        },
      );

      if (shouldConnect != true || !mounted) {
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const AccountPage(),
        ),
      );

      if (!mounted) {
        return;
      }

      // Double sécurité : la route ne doit jamais autoriser la révélation
      // si Firebase Auth ne contient finalement aucun utilisateur.
      if (FirebaseAuth.instance.currentUser == null) {
        return;
      }
    }

    if (!mounted || widget.hidePhone) {
      return;
    }

    setState(() {
      _isPhoneVisible = true;
    });

    // Increment the view counter asynchronously; ignore errors silently.
    if (widget.offerId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('listings')
          .doc(widget.offerId)
          .update({'phoneViewCount': FieldValue.increment(1)}).ignore();
    }
  }

  String _phoneIndicatif(String rawPhone) {
    final compact = rawPhone.trim().replaceAll(RegExp(r'[\s().-]+'), '');

    if (compact.isEmpty) {
      return '';
    }

    // Indicatifs internationaux principalement utilisés par iliprestō.
    const supportedDialingCodes = <String>[
      '+590', // Guadeloupe, Saint-Martin, Saint-Barthélemy
      '+596', // Martinique
      '+594', // Guyane
      '+262', // La Réunion et Mayotte
      '+508', // Saint-Pierre-et-Miquelon
      '+681', // Wallis-et-Futuna
      '+689', // Polynésie française
      '+687', // Nouvelle-Calédonie
      '+33', // France métropolitaine
    ];

    for (final dialingCode in supportedDialingCodes) {
      if (compact.startsWith(dialingCode)) {
        return dialingCode;
      }
    }

    // Repli pour un numéro international non encore répertorié.
    final fallback = RegExp(r'^(\+\d{1,3})').firstMatch(compact);
    if (fallback != null) return fallback.group(1)!;

    // Inférence depuis le format local (numéro sans préfixe +).
    const localPrefixToDialingCode = <String, String>{
      '0590': '+590', // Guadeloupe
      '0596': '+596', // Martinique
      '0594': '+594', // Guyane
      '0262': '+262', // La Réunion / Mayotte
      '0269': '+262', // Mayotte (variante)
      '0508': '+508', // Saint-Pierre-et-Miquelon
      '0681': '+681', // Wallis-et-Futuna
      '0689': '+689', // Polynésie française
      '0687': '+687', // Nouvelle-Calédonie
    };

    for (final entry in localPrefixToDialingCode.entries) {
      if (compact.startsWith(entry.key)) {
        return entry.value;
      }
    }

    // Numéro à 10 chiffres commençant par 0 → France métropolitaine.
    if (compact.length == 10 && compact.startsWith('0')) {
      return '+33';
    }
    // Numéro à 9 chiffres commençant par 6 ou 7 → France mobile.
    if (compact.length == 9 &&
        (compact.startsWith('6') || compact.startsWith('7'))) {
      return '+33';
    }

    return '';
  }

  String _indicatifOnly(String rawPhone) {
    final dialingCode = _phoneIndicatif(rawPhone);

    if (dialingCode.isEmpty) {
      if ((_resolvedDialingCode ?? '').isNotEmpty) {
        return '${_resolvedDialingCode!} ••••••';
      }
      return '••••••';
    }

    return '$dialingCode ••••••';
  }

  String _maskedLabel(String rawPhone) {
    final normalized = rawPhone.trim();

    if (normalized.isEmpty) {
      if ((_resolvedDialingCode ?? '').isNotEmpty) {
        return '${_resolvedDialingCode!} ••••••';
      }
      return 'Non renseigné';
    }

    final dialingCode = _phoneIndicatif(normalized);

    if (dialingCode.isEmpty) {
      return '••••••';
    }

    return '$dialingCode ••••••';
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF18233D);
    const muted = Color(0xFF6F7282);
    const line = Color(0xFFE6E3E6);

    final effectivePhone = _effectivePhone();
    final canRequestReveal = !widget.hidePhone &&
        (effectivePhone.isNotEmpty || widget.offerId.trim().isNotEmpty);

    final String displayedValue;
    if (widget.hidePhone) {
      displayedValue = _indicatifOnly(effectivePhone);
    } else {
      displayedValue =
          _isPhoneVisible ? effectivePhone : _maskedLabel(effectivePhone);
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: widget.compact ? 10 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.call_outlined,
                color: const Color(0xFF6C7384),
                size: widget.compact ? 20 : 22,
              ),
              SizedBox(width: widget.compact ? 8 : 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Téléphone',
                    style: TextStyle(
                      color: muted,
                      fontSize: widget.compact ? 15 : 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ),
              SizedBox(width: widget.compact ? 8 : 10),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    button: canRequestReveal,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap:
                            canRequestReveal ? _handlePhoneVisibility : null,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            displayedValue,
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: navy,
                              fontSize: widget.compact ? 15 : 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!widget.hidePhone) ...[
                SizedBox(width: widget.compact ? 4 : 6),
                IconButton(
                  onPressed: canRequestReveal ? _handlePhoneVisibility : null,
                  tooltip:
                      _isPhoneVisible ? 'Masquer le numéro' : 'Voir le numéro',
                  visualDensity: VisualDensity.compact,
                  splashRadius: widget.compact ? 18 : 20,
                  icon: Icon(
                    _isPhoneVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: canRequestReveal ? navy : muted,
                    size: widget.compact ? 20 : 22,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: line),
      ],
    );
  }
}

class _UrgentBadge extends StatelessWidget {
  final bool compact;

  const _UrgentBadge({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return _HeaderPillBadge(
      compact: compact,
      minWidth: compact ? 88 : 96,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFFA43A), Color(0xFFFF6A00)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x2EFF8A00),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        'URGENT',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: compact ? 10.5 : 11,
          height: 1,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _HeaderPillBadge extends StatelessWidget {
  final bool compact;
  final double minWidth;
  final EdgeInsetsGeometry padding;
  final BoxDecoration decoration;
  final Widget child;

  const _HeaderPillBadge({
    required this.compact,
    required this.minWidth,
    required this.padding,
    required this.decoration,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: minWidth),
      height: compact ? 26 : 28,
      padding: padding,
      decoration: decoration.copyWith(borderRadius: BorderRadius.circular(999)),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _InlineCta extends StatelessWidget {
  final String label;
  final bool compact;
  final VoidCallback onTap;

  const _InlineCta({
    required this.label,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 56 : 62,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF49A6FF), Color(0xFF0058DF)],
        ),
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A63E7).withValues(alpha: 0.35),
            blurRadius: compact ? 15 : 18,
            offset: Offset(0, compact ? 7 : 8),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.35),
            blurRadius: compact ? 5 : 6,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 17 : 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareOptionTile extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareOptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: icon),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
