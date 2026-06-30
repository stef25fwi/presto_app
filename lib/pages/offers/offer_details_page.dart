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
import 'package:presto_app/services/app_route_parser.dart';
import 'package:presto_app/services/conversation_service.dart';
import 'package:presto_app/services/marketplace_human_verification.dart';
import 'package:presto_app/services/user_profile_bootstrap_service.dart';
import 'package:presto_app/utils/runtime_action_logger.dart';
import 'package:presto_app/widgets/offer_network_image.dart';
import 'dart:async';
import 'package:presto_app/pages/offers/widgets/payment_info_popup.dart';
import 'package:presto_app/widgets/deleted_user_profile.dart';

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

String _firstOfferDetailPhotoField(dynamic data, List<String> keys) {
  if (data is! Map) return '';
  for (final key in keys) {
    final value = (data[key] ?? '').toString().trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  return '';
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

  Future<Map<String, dynamic>?>? _marketplaceFuture;

  @override
  void initState() {
    super.initState();
    _initMarketplaceFuture();
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

  String _extractImageUrl(dynamic entry) {
    return _extractOfferDetailImageUrl(entry);
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
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
        details: <String, Object?>{
          'offerId': offerId,
        },
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
        details: <String, Object?>{
          'offerId': data.offerId,
        },
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
        details: <String, Object?>{
          'offerId': data.offerId,
        },
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
        details: <String, Object?>{
          'offerId': data.offerId,
        },
      );
      messenger?.showSnackBar(
        const SnackBar(
            content: Text("Vous ne pouvez pas vous envoyer un message.")),
      );
      return;
    }

    final currentUserName = authUser?.displayName?.trim().isNotEmpty == true
        ? authUser!.displayName!.trim()
        : (authUser?.email ?? 'Utilisateur');
    final initialDraftText =
        'Bonjour ${data.advertiserName}, je vous contacte au sujet de votre annonce "${data.title}".';

    try {
      unawaited(UserProfileBootstrapService.prepareProfileFirestoreAccess(
        user: authUser,
        forceRefreshAppCheckToken: true,
        requireAppCheckToken: false,
      ));
    } catch (error) {
      logRuntimeAction(
        area: 'messaging',
        action: 'blocked-app-check-before-open',
        details: <String, Object?>{
          'offerId': data.offerId,
          'error': error,
        },
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
    navigator.pushNamed(
      targetRoute,
    );
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
            content: Text("Impossible de lancer l'appel sur cet appareil.")),
      );
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
      messenger?.showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showShareOptionsSheet(
      BuildContext context, _OfferUiData data) async {
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
                content: Text('Texte copié. Collez-le dans Instagram.')),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
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
      BuildContext context, _OfferUiData data) async {
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
                // Bouton « Appeler » masqué si l'annonceur a caché son numéro
                // (hidePhone) ou si le numéro est vide.
                if (!data.hidePhone && data.phone.trim().isNotEmpty) ...[
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
                            'phoneViewCount': FieldValue.increment(1)
                          }).ignore();
                        }
                        await _callPhone(context, data.phone);
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
        details: <String, Object?>{
          'offerId': data.offerId,
        },
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
      logRuntimeAction(
        area: 'favorites',
        action: 'blocked-missing-offer',
      );
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
        details: <String, Object?>{
          'offerId': data.offerId,
        },
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
              'Le signalement est disponible uniquement pour Marketplace.'),
        ),
      );
      return;
    }

    if (data.advertiserId.trim().isNotEmpty &&
        data.advertiserId.trim() == uid) {
      logRuntimeAction(
        area: 'offers',
        action: 'report-blocked-self',
        details: <String, Object?>{
          'offerId': data.offerId,
        },
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
        details: <String, Object?>{
          'offerId': data.offerId,
        },
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
                  onPressed: () => Navigator.of(dialogContext).pop(
                    controller.text.trim(),
                  ),
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

  Map<String, dynamic> _buildFavoriteOfferPayload(_OfferUiData data) {
    final dynamic rawOffer = widget.offer;
    final imageUrls = ((_OfferUiData._read(() => rawOffer['imageUrls']) ??
                    _OfferUiData._read(() => rawOffer.imageUrls))
                as List<dynamic>? ??
            const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final createdAt = _OfferUiData._read(() => rawOffer.createdAt);

    return {
      'offerId': data.offerId,
      'title': data.title,
      'location': data.city,
      'city': data.city,
      'postalCode': data.postalCode,
      'category': data.category,
      'description': data.description,
      'urgent': data.isUrgent,
      'budget': data.price,
      'price': data.price,
      'imageUrls': imageUrls,
      'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : '',
      'userId': data.advertiserId,
      'pseudo': data.advertiserName,
      'userName': data.advertiserName,
      'serviceArea': data.serviceArea,
      'canTravel': data.canTravel,
      'schedule': data.schedule,
      'missionDelay': data.missionDelay,
      'averageDelay': data.averageDelay,
      'paymentMethod': data.paymentMethod,
      'serviceType': data.serviceType,
      'phone': data.phone,
      'availability': data.availability,
      'verified': data.verified,
      'rating': data.advertiserRating,
      'reviewsCount': data.advertiserReviewCount,
      'bio': data.advertiserRole,
      'avatarUrl': data.advertiserAvatarUrl,
      'addedAt': FieldValue.serverTimestamp(),
      if (createdAt is Timestamp) 'createdAt': createdAt,
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

      return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _statusBarStyle,
      child: Scaffold(
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
      ),
    );