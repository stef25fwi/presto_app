import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:presto_app/app/presto_overlay_theme.dart';
import 'package:presto_app/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:presto_app/data/marketplace/favorite_repository.dart';
import 'package:presto_app/data/marketplace/report_repository.dart';
import 'package:presto_app/models/marketplace_enums.dart';
import 'package:presto_app/models/marketplace_report.dart';
import 'package:presto_app/services/app_route_parser.dart';
import 'package:presto_app/services/conversation_service.dart';
import 'package:presto_app/services/marketplace_human_verification.dart';
import 'package:presto_app/utils/runtime_action_logger.dart';
import 'package:presto_app/widgets/offer_network_image.dart';

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

class PrestoOfferDetailsPage extends StatelessWidget {
  final Object? offer;
  final String currentUserId;
  final VoidCallback? onBackToConsult;

  static const Color _headerOrange = Color(0xFFFF6600);
  static final FavoriteRepository _favoriteRepository = FavoriteRepository();
  static final ReportRepository _reportRepository = ReportRepository();
  static const MarketplaceHumanVerification _verification =
      MarketplaceHumanVerification();

  const PrestoOfferDetailsPage({
    super.key,
    this.offer,
    required this.currentUserId,
    this.onBackToConsult,
  });

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
    Map<String, dynamic>? liveData,
    String listingId,
  ) {
    if (liveData == null || liveData.isEmpty) {
      return source;
    }

    final merged = <String, dynamic>{
      if (source is Map)
        ...Map<String, dynamic>.from(source.cast<dynamic, dynamic>()),
      ...liveData,
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

  String _toE164Like(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('+')) {
      final digits = trimmed.replaceAll(RegExp(r'\D'), '');
      return digits.isEmpty ? trimmed : '+$digits';
    }

    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.length == 10 && digits.startsWith('0'))
      return '+33${digits.substring(1)}';
    if (digits.length == 9 &&
        (digits.startsWith('6') || digits.startsWith('7'))) return '+33$digits';
    return digits;
  }

  Future<void> _openInternalMessaging(
    BuildContext context,
    _OfferUiData data,
  ) async {
    final authUser = FirebaseAuth.instance.currentUser;
    final me = authUser?.uid.isNotEmpty == true ? authUser!.uid : currentUserId;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Connectez-vous pour envoyer un message.")),
      );
      return;
    }

    if (data.advertiserId.isEmpty) {
      logRuntimeAction(
        area: 'messaging',
        action: 'blocked-missing-advertiser',
        details: <String, Object?>{
          'offerId': data.offerId,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
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
    Navigator.of(context).pushNamed(
      targetRoute,
    );
  }

  Future<void> _callPhone(BuildContext context, String phone) async {
    if (phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun numéro disponible.")),
      );
      return;
    }

    final dial = _toE164Like(phone);
    final uri = Uri(scheme: 'tel', path: dial.isNotEmpty ? dial : phone.trim());
    final ok = await canLaunchUrl(uri);
    if (!ok) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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
    final ok = await canLaunchUrl(uri);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showShareOptionsSheet(
      BuildContext context, _OfferUiData data) async {
    final overlayTheme = context.prestoOverlayTheme;
    final detailPath = data.isMarketplace ? 'listings' : 'offers';
    final offerUrl =
        'https://presto-app-74abe.web.app/#/$detailPath/${data.offerId}';
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
          ScaffoldMessenger.of(context).showSnackBar(
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Texte copié. Collez-le dans Instagram.')),
          );
        }

        return SafeArea(
          top: false,
          child: Container(
            color: overlayTheme.surfaceColor,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _callPhone(context, data.phone);
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
    final authUser = FirebaseAuth.instance.currentUser;
    final uid = authUser?.uid.trim() ?? '';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connectez-vous pour enregistrer vos favoris.'),
        ),
      );
      return;
    }

    final offerId = data.offerId.trim();
    if (offerId.isEmpty) {
      logRuntimeAction(
        area: 'favorites',
        action: 'blocked-missing-offer',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annonce introuvable.')),
      );
      return;
    }

    try {
      if (data.isMarketplace) {
        final active = await _favoriteRepository.toggleFavorite(offerId);
        logRuntimeAction(
          area: 'favorites',
          action: 'toggle-success',
          details: <String, Object?>{
            'offerId': offerId,
            'active': active,
            'source': 'marketplace',
          },
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              active
                  ? 'Annonce ajoutée aux favoris.'
                  : 'Annonce retirée des favoris.',
            ),
          ),
        );
        return;
      }

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final batch = FirebaseFirestore.instance.batch();

      batch.set(
        userRef,
        {
          'favoriteOfferIds': isFavorite
              ? FieldValue.arrayRemove([offerId])
              : FieldValue.arrayUnion([offerId]),
          'favoriteOffersUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (isFavorite) {
        batch.delete(userRef.collection('favoriteOffers').doc(offerId));
      } else {
        batch.set(
          userRef.collection('favoriteOffers').doc(offerId),
          _buildFavoriteOfferPayload(data),
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      logRuntimeAction(
        area: 'favorites',
        action: 'toggle-success',
        details: <String, Object?>{
          'offerId': offerId,
          'active': !isFavorite,
          'source': 'legacy-user-doc',
        },
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorite
                ? 'Annonce retirée des favoris.'
                : 'Annonce ajoutée aux favoris.',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour du favori : $e')),
      );
    }
  }

  Future<void> _showReportSheet(BuildContext context, _OfferUiData data) async {
    final authUser = FirebaseAuth.instance.currentUser;
    final uid = authUser?.uid.trim() ?? '';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connectez-vous pour signaler cette annonce.'),
        ),
      );
      return;
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
      ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
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
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
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
      ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
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
    final dynamic rawOffer = offer;
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

    if (data.isMarketplace) {
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
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
            color: Colors.white,
            splashRadius: 20,
          );
        },
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final favoriteIds =
            (snapshot.data?.data()?['favoriteOfferIds'] as List<dynamic>? ??
                    const [])
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toSet();

        final isFavorite = data.offerId.trim().isNotEmpty &&
            favoriteIds.contains(data.offerId.trim());

        return IconButton(
          tooltip: isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
          onPressed: () => _toggleFavorite(context, data, isFavorite),
          icon: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          ),
          color: Colors.white,
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
          leading: IconButton(
            tooltip: 'Retour',
            onPressed: () {
              if (onBackToConsult != null) {
                onBackToConsult!();
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
                  isCompactMobile ? 14 : 16,
                  isCompactMobile ? 10 : 12,
                  isCompactMobile ? 14 : 16,
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

    final listingId = _extractMarketplaceListingId(offer);
    if (listingId.isEmpty) {
      return buildPage(offer);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('listings')
          .doc(listingId)
          .snapshots(),
      builder: (context, snapshot) {
        final mergedOffer = _mergeMarketplaceOffer(
          offer,
          snapshot.data?.data(),
          listingId,
        );
        return buildPage(mergedOffer);
      },
    );
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
  });

  String get sanitizedTitle {
    var out = title.trim();
    if (out.isEmpty) return 'Annonce';
    final cityTrim = city.trim();
    final postalTrim = postalCode.trim();

    if (cityTrim.isNotEmpty) {
      out = out.replaceAll(
          RegExp(RegExp.escape(cityTrim), caseSensitive: false), ' ');
    }
    if (postalTrim.isNotEmpty) {
      out = out.replaceAll(
          RegExp('\\b${RegExp.escape(postalTrim)}\\b', caseSensitive: false),
          ' ');
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

    dynamic readNestedValue(dynamic source, String key,
        [dynamic Function()? getter]) {
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
        : _asString(readValue('categoryId', () => o.categoryId), fallback: '')
                .isNotEmpty ||
            _asString(readValue('cityId', () => o.cityId), fallback: '')
                .isNotEmpty ||
            _asString(readValue('visibility', () => o.visibility), fallback: '')
                .isNotEmpty;
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
    final title = _asString(readValue('title', () => o.title),
        fallback: 'Montage meuble');
    final publishedAt = _asDateTime(
      readValue('publishedAt', () => o.publishedAt) ??
          readValue('createdAt', () => o.createdAt) ??
          readValue('updatedAt', () => o.updatedAt),
    );
    final detail = _asString(
      readValue('shortDescription', () => o.shortDescription) ??
          readValue('detail'),
      fallback: '+ fixation TV',
    );
    final city = _asString(
      readValue('city', () => o.city) ?? readValue('location'),
      fallback: 'Les Abymes',
    );
    final postalCode = _asString(
      readValue('postalCode', () => o.postalCode) ?? readValue('cp'),
      fallback: '',
    );
    final category = _asString(readValue('category', () => o.category),
        fallback: 'Bricolage');

    final fullDescription = _asString(
      readValue('description', () => o.description),
      fallback:
          'Montage d\'un petit meuble + fixation d\'une\nTV au mur (support déjà acheté). Mur béton.\nPrévoir perceuse.',
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
    final statusBadges =
        _asStringList(readValue('statusBadges', () => o.statusBadges));
    final urgentRaw =
        readValue('isUrgent', () => o.isUrgent) ?? readValue('urgent');
    final isUrgent = urgentRaw is bool
        ? urgentRaw
        : statusBadges.any(
            (badge) => badge.toLowerCase().contains('urgent'),
          );

    final price = _asDouble(
      readValue('price', () => o.price) ?? readValue('budget'),
      fallback: 90,
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
          readValue('avatarUrl'),
      fallback: '',
    );
    final advertiserRating = _asDouble(
      readNestedValue(advertiser, 'rating', () => advertiser.rating) ??
          readValue('rating'),
      fallback: 0.0,
    );
    final advertiserReviewCount = _asInt(
      readNestedValue(
              advertiser, 'reviewsCount', () => advertiser.reviewsCount) ??
          readNestedValue(
              advertiser, 'reviewCount', () => advertiser.reviewCount) ??
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
              practical, 'missionDelay', () => practical.missionDelay) ??
          readValue('missionDelay', () => o.missionDelay) ??
          readValue('averageDelay', () => o.averageDelay),
      fallback: 'Délai non précisé',
    );
    final averageDelay = _asString(
      readNestedValue(
              practical, 'averageDelay', () => practical.averageDelay) ??
          readValue('averageDelay', () => o.averageDelay),
      fallback: '30 min en moyenne',
    );
    final paymentMethod = _asString(
      readNestedValue(
          practical, 'paymentMethod', () => practical.paymentMethod),
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

    return _OfferUiData(
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
    );
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
        const Positioned.fill(
          child: ColoredBox(color: Color(0xFFF6EFEC)),
        ),
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
                    const Color(0xFF1976F3).withOpacity(0.12),
                    const Color(0xFF1976F3).withOpacity(0.05),
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

class _TopHeader extends StatelessWidget {
  final String title;
  final bool compact;

  const _TopHeader({required this.title, required this.compact});

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF8A00);
    const blue = Color(0xFF1565D8);

    return SizedBox(
      height: compact ? 42 : 46,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: orange,
              size: compact ? 28 : 32,
            ),
            splashRadius: compact ? 18 : 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(width: compact ? 12 : 16),
          Expanded(
            child: Text(
              _truncatedTitle(title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: blue,
                fontSize: compact ? 24 : 27,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                height: 1.0,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              logRuntimeAction(
                area: 'offers',
                action: 'listing-alert-unavailable',
                details: <String, Object?>{
                  'title': title,
                },
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Les alertes sur annonce arrivent bientot.',
                  ),
                ),
              );
            },
            tooltip: 'Alertes bientot disponibles',
            icon: Icon(
              Icons.notifications_none_rounded,
              color: blue,
              size: compact ? 28 : 32,
            ),
            splashRadius: compact ? 18 : 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  String _truncatedTitle(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Montage me...';
    return trimmed.length > 12 ? '${trimmed.substring(0, 10)}...' : trimmed;
  }
}

class _HeroCard extends StatelessWidget {
  final _OfferUiData data;
  final bool compact;

  const _HeroCard({required this.data, this.compact = false});

  void _openGallery(BuildContext context, int initialIndex) {
    if (data.imageUrls.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenGalleryPage(
          imageUrls: data.imageUrls,
          initialIndex: initialIndex,
        ),
      ),
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
        border: Border.all(
          color: const Color(0xFFF0E7E4),
          width: 1,
        ),
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
            GestureDetector(
              onTap: () => _openGallery(context, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(compact ? 20 : 24),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: compact ? 180 : 220,
                  child: _OfferImage(
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
                        child: Icon(Icons.image_outlined,
                            size: 48, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // ── Miniatures additionnelles ──
          if (data.imageUrls.length > 1)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 16, compact ? 8 : 10, compact ? 12 : 16, 0),
              child: SizedBox(
                height: compact ? 56 : 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: data.imageUrls.length,
                  separatorBuilder: (_, __) => SizedBox(width: compact ? 6 : 8),
                  itemBuilder: (context, index) {
                    final isSelected = index == 0;
                    return GestureDetector(
                      onTap: () => _openGallery(context, index),
                      child: Container(
                        width: compact ? 56 : 64,
                        height: compact ? 56 : 64,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(compact ? 10 : 12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFF6A00)
                                : const Color(0xFFE5E7EB),
                            width: isSelected ? 2.5 : 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular((compact ? 10 : 12) - 1),
                          child: _OfferImage(
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
                SizedBox(height: compact ? 10 : 12),
                Text(
                  detailsLine,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: compact ? 14 : 15,
                    height: 1.28,
                    fontWeight: FontWeight.w500,
                    color: textPrimary.withOpacity(0.9),
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
                Container(
                  height: 1,
                  color: divider,
                ),
                SizedBox(height: compact ? 10 : 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
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
                        SizedBox(height: compact ? 6 : 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _DelayBadge(
                                text: data.averageDelay, compact: compact),
                            if (data.isUrgent) ...[
                              SizedBox(width: compact ? 6 : 8),
                              _UrgentBadge(compact: compact),
                            ],
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

class _HeroInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;

  const _HeroInfoChip({
    required this.icon,
    required this.label,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 52 : 58,
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDF6),
        borderRadius: BorderRadius.circular(29),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: compact ? 21 : 24,
            color: const Color(0xFF2B2F52),
          ),
          SizedBox(width: compact ? 8 : 10),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 16 : 18,
                height: 1,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2B2F52),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Photo gallery ───────────────────────────────────────────────────────────

class _PhotoThumbnailStrip extends StatelessWidget {
  final List<String> imageUrls;

  const _PhotoThumbnailStrip({
    required this.imageUrls,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    const double thumbSize = 76;
    const double borderRadius = 14;

    return SizedBox(
      height: thumbSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: imageUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _openFullScreenGallery(context, index),
            child: Container(
              width: thumbSize,
              height: thumbSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius - 1),
                child: _OfferImage(
                  rawUrl: imageUrls[index],
                  fit: BoxFit.cover,
                  errorChild: Container(
                    color: const Color(0xFFF3F4F6),
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: Color(0xFF9CA3AF),
                      size: 28,
                    ),
                  ),
                  loadingChild: Container(
                    color: const Color(0xFFF3F4F6),
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFF6A00),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openFullScreenGallery(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenGalleryPage(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _FullScreenGalleryPage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullScreenGalleryPage({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullScreenGalleryPage> createState() => _FullScreenGalleryPageState();
}

class _FullScreenGalleryPageState extends State<_FullScreenGalleryPage> {
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${_currentPage + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
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
                  color: Colors.white54,
                  size: 64,
                ),
                loadingChild: const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          );
        },
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _resolveOfferImageUrl(rawUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return loadingChild ?? errorChild;
        }

        final resolvedUrl = (snapshot.data ?? '').trim();
        if (resolvedUrl.isEmpty) {
          return errorChild;
        }

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

class _PracticalInfoCard extends StatelessWidget {
  final _OfferUiData data;
  final bool compact;
  final VoidCallback onContactTap;

  const _PracticalInfoCard({
    required this.data,
    this.compact = false,
    required this.onContactTap,
  });

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF18233D);
    const blueSoft = Color(0xFFDCEBFF);
    const muted = Color(0xFF6F7282);
    const line = Color(0xFFE6E3E6);
    const orange = Color(0xFFFF7B12);
    const green = Color(0xFF45B36B);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 28 : 32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B8E86).withOpacity(0.10),
            blurRadius: compact ? 18 : 22,
            offset: Offset(0, compact ? 8 : 10),
          ),
          BoxShadow(
            color: blueSoft.withOpacity(0.55),
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
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Déplacement possible',
                    value: data.canTravel ? 'Oui' : 'Non',
                    compact: compact,
                  ),
                  _InfoLine(
                    icon: Icons.access_time_rounded,
                    label: 'Horaires',
                    value: data.schedule,
                    compact: compact,
                  ),
                  _InfoLine(
                    icon: Icons.access_time_rounded,
                    label: 'Délai',
                    value: data.missionDelay,
                    compact: compact,
                  ),
                  const Divider(height: 1, thickness: 1, color: line),
                  _InfoLine(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Mode de paiement',
                    value: 'À convenir',
                    compact: compact,
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

class _AdvertiserContactCard extends StatelessWidget {
  final _OfferUiData data;
  final bool compact;
  final VoidCallback onContactTap;

  const _AdvertiserContactCard({
    required this.data,
    this.compact = false,
    required this.onContactTap,
  });

  @override
  Widget build(BuildContext context) {
    const blueSoft = Color(0xFFDCEBFF);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 28 : 32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B8E86).withOpacity(0.10),
            blurRadius: compact ? 18 : 22,
            offset: Offset(0, compact ? 8 : 10),
          ),
          BoxShadow(
            color: blueSoft.withOpacity(0.55),
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
              _AdvertiserHeaderLine(
                advertiserName: data.advertiserName,
                verified: data.verified,
                compact: compact,
              ),
              _AdvertiserMetaLine(
                advertiserRating: data.advertiserRating,
                advertiserReviewCount: data.advertiserReviewCount,
                verified: data.verified,
                compact: compact,
              ),
              _MaskedPhoneInfoLine(
                phone: data.phone,
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

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.compact = false,
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon,
                  color: const Color(0xFF6C7384), size: compact ? 20 : 22),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
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
                Text(
                  'Nouveau',
                  style: TextStyle(
                    color: navy,
                    fontSize: compact ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
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

  const _MaskedPhoneInfoLine({
    required this.phone,
    this.compact = false,
  });

  @override
  State<_MaskedPhoneInfoLine> createState() => _MaskedPhoneInfoLineState();
}

class _MaskedPhoneInfoLineState extends State<_MaskedPhoneInfoLine> {
  bool _isPhoneVisible = false;

  String _maskedLabel(String rawPhone) {
    final normalized = rawPhone.trim();
    if (normalized.isEmpty) return 'Non renseigné';

    final compact = normalized.replaceAll(RegExp(r'\s+'), ' ');
    final internationalPrefix =
        RegExp(r'^(\+\d{1,4})').firstMatch(compact)?.group(1);
    if (internationalPrefix != null && internationalPrefix.isNotEmpty) {
      return '$internationalPrefix ******';
    }

    final digitsOnly = compact.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length >= 4) {
      return '${digitsOnly.substring(0, 4)} ******';
    }
    if (digitsOnly.isNotEmpty) {
      return '$digitsOnly ******';
    }

    return '******';
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF18233D);
    const muted = Color(0xFF6F7282);
    const line = Color(0xFFE6E3E6);

    final hasPhone = widget.phone.trim().isNotEmpty;
    final displayedValue =
        _isPhoneVisible ? widget.phone.trim() : _maskedLabel(widget.phone);

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
                  child: Text(
                    displayedValue,
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
              SizedBox(width: widget.compact ? 4 : 6),
              IconButton(
                onPressed: hasPhone
                    ? () => setState(() => _isPhoneVisible = !_isPhoneVisible)
                    : null,
                tooltip:
                    _isPhoneVisible ? 'Masquer le numéro' : 'Voir le numéro',
                visualDensity: VisualDensity.compact,
                splashRadius: widget.compact ? 18 : 20,
                icon: Icon(
                  _isPhoneVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: hasPhone ? navy : muted,
                  size: widget.compact ? 20 : 22,
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

class _DelayBadge extends StatelessWidget {
  final String text;
  final bool compact;

  const _DelayBadge({required this.text, this.compact = false});

  @override
  Widget build(BuildContext context) {
    const headlineColor = Colors.white;
    const sublineColor = Color(0xFFFFF3E6);

    final normalized = text.trim().isEmpty ? '30 min en moyenne' : text.trim();
    final parts = normalized.split(' en moyenne');
    final headline = parts.first.trim();
    final subline = normalized.contains('en moyenne') ? 'en moyenne' : '';

    return _HeaderPillBadge(
      compact: compact,
      minWidth: compact ? 88 : 96,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFFB13B), Color(0xFFFF6A00)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x26FF7A00),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(
              text: headline,
              style: TextStyle(
                color: headlineColor,
                fontSize: compact ? 10.5 : 11,
                fontWeight: FontWeight.w800,
                height: 1,
                letterSpacing: 0.2,
              ),
            ),
            if (subline.isNotEmpty)
              TextSpan(
                text: '  $subline',
                style: TextStyle(
                  color: sublineColor,
                  fontSize: compact ? 8.5 : 9,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
          ],
        ),
      ),
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
      decoration: decoration.copyWith(
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _InlineCta extends StatelessWidget {
  final String label;
  final bool compact;
  final VoidCallback onTap;

  const _InlineCta(
      {required this.label, this.compact = false, required this.onTap});

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
            color: const Color(0xFF0A63E7).withOpacity(0.35),
            blurRadius: compact ? 15 : 18,
            offset: Offset(0, compact ? 7 : 8),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.35),
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
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                  ),
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

class _AvatarFallback extends StatelessWidget {
  final String initials;

  const _AvatarFallback({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7D25B), Color(0xFFC98E27)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            bottom: 0,
            left: 4,
            right: 4,
            child: Container(
              height: 13,
              decoration: const BoxDecoration(
                color: Color(0xFFDAA065),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Positioned(
            top: 7,
            left: 9,
            child: CircleAvatar(
              radius: 2,
              backgroundColor: Color(0xFF50371E),
            ),
          ),
          const Positioned(
            top: 7,
            right: 9,
            child: CircleAvatar(
              radius: 2,
              backgroundColor: Color(0xFF50371E),
            ),
          ),
          Positioned(
            top: 12,
            left: 9,
            right: 9,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5A31).withOpacity(0.85),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          if (initials.isNotEmpty)
            Align(
              alignment: const Alignment(0, 0.9),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.transparent,
                  fontSize: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
