import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:presto_app/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:presto_app/pages/messages/conversation_thread_page.dart';
import 'package:presto_app/services/conversation_service.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

enum OfferActionType { booking, contact }

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
  final double rating;
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
  final String title;
  final double price;
  final String category;
  final String city;
  final String postalCode;
  final bool isUrgent;
  final String publishedAtLabel;
  final String availability;
  final String shortDescription;
  final String description;
  final String phone;
  final List<String> imageUrls;
  final List<String> statusBadges;
  final PracticalInfo practicalInfo;
  final Advertiser advertiser;
  final OfferActionType actionType;
  final List<Offer> similarOffers;

  const Offer({
    required this.id,
    required this.title,
    required this.price,
    required this.category,
    required this.city,
    this.postalCode = '',
    this.isUrgent = false,
    required this.publishedAtLabel,
    required this.availability,
    required this.shortDescription,
    required this.description,
    required this.phone,
    required this.imageUrls,
    required this.statusBadges,
    required this.practicalInfo,
    required this.advertiser,
    required this.actionType,
    required this.similarOffers,
  });
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class OfferDetailsPage extends StatelessWidget {
  final Object? offer;
  final String currentUserId;

  const OfferDetailsPage({
    super.key,
    this.offer,
    this.currentUserId = 'buyer_demo_001',
  });

  @override
  Widget build(BuildContext context) {
    return PrestoOfferDetailsPage(
      offer: offer,
      currentUserId: currentUserId,
    );
  }
}

class PrestoOfferDetailsPage extends StatelessWidget {
  final Object? offer;
  final String currentUserId;

  static const Color _headerOrange = Color(0xFFFF6600);

  const PrestoOfferDetailsPage({
    super.key,
    this.offer,
    required this.currentUserId,
  });

  String _toE164Like(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('+')) {
      final digits = trimmed.replaceAll(RegExp(r'\D'), '');
      return digits.isEmpty ? trimmed : '+$digits';
    }

    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.length == 10 && digits.startsWith('0')) return '+33${digits.substring(1)}';
    if (digits.length == 9 && (digits.startsWith('6') || digits.startsWith('7'))) return '+33$digits';
    return digits;
  }

  Future<void> _openInternalMessaging(
    BuildContext context,
    _OfferUiData data,
  ) async {
    final authUser = FirebaseAuth.instance.currentUser;
    final me = authUser?.uid.isNotEmpty == true ? authUser!.uid : currentUserId;

    if (me.isEmpty || me == 'buyer_demo_001') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connectez-vous pour envoyer un message.")),
      );
      return;
    }

    if (data.advertiserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Annonceur introuvable.")),
      );
      return;
    }

    if (data.advertiserId == me) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vous ne pouvez pas vous envoyer un message.")),
      );
      return;
    }

    final resolvedConversationId = await ConversationService.ensureConversation(
      offerId: data.offerId,
      offerTitle: data.title,
      currentUserId: me,
      otherUserId: data.advertiserId,
    );

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationThreadPage(
          conversationId: resolvedConversationId,
          offerTitle: data.title,
          currentUserId: me,
        ),
      ),
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
        const SnackBar(content: Text("Impossible de lancer l'appel sur cet appareil.")),
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

  Future<void> _showShareOptionsSheet(BuildContext context, _OfferUiData data) async {
    final offerUrl = 'https://presto-app-74abe.web.app/#/offers/${data.offerId}';
    final shareText = '${data.title} - ${data.city}\n$offerUrl';

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
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
            const SnackBar(content: Text('Texte copié. Collez-le dans Instagram.')),
          );
        }

        return SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
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
                          errorMessage: 'Impossible d\'ouvrir l\'application mail.',
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

  Future<void> _showContactOptionsSheet(BuildContext context, _OfferUiData data) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
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

    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connectez-vous pour enregistrer vos favoris.'),
        ),
      );
      return;
    }

    final offerId = data.offerId.trim();
    if (offerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annonce introuvable.')),
      );
      return;
    }

    try {
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour du favori : $e')),
      );
    }
  }

  Map<String, dynamic> _buildFavoriteOfferPayload(_OfferUiData data) {
    final dynamic rawOffer = offer;
    final imageUrls = (_OfferUiData._read(() => rawOffer.imageUrls) as List<dynamic>? ?? const [])
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

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final favoriteIds =
            (snapshot.data?.data()?['favoriteOfferIds'] as List<dynamic>? ?? const [])
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toSet();

        final isFavorite =
            data.offerId.trim().isNotEmpty && favoriteIds.contains(data.offerId.trim());

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
    const bg = Color(0xFFF6EFEC);
    final data = _OfferUiData.fromOffer(offer);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompactMobile = screenWidth <= 360;
    final sectionGap = isCompactMobile ? 12.0 : 14.0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
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
                isCompactMobile ? 20 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroCard(data: data, compact: isCompactMobile),
                  SizedBox(height: sectionGap),
                  _PracticalInfoCard(
                    data: data,
                    compact: isCompactMobile,
                    onContactTap: () => _showContactOptionsSheet(context, data),
                  ),
                  SizedBox(height: sectionGap),
                  _AdvertiserContactCard(
                    data: data,
                    compact: isCompactMobile,
                    onContactTap: () => _showContactOptionsSheet(context, data),
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

class _OfferUiData {
  final String offerId;
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

  const _OfferUiData({
    required this.offerId,
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
  });

  String get sanitizedTitle {
    var out = title.trim();
    if (out.isEmpty) return 'Annonce';
    final cityTrim = city.trim();
    final postalTrim = postalCode.trim();

    if (cityTrim.isNotEmpty) {
      out = out.replaceAll(RegExp(RegExp.escape(cityTrim), caseSensitive: false), ' ');
    }
    if (postalTrim.isNotEmpty) {
      out = out.replaceAll(RegExp('\\b${RegExp.escape(postalTrim)}\\b', caseSensitive: false), ' ');
    }

    out = out.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'\s*[-–|/]\s*$'), '').trim();
    return out.isEmpty ? title.trim() : out;
  }

  factory _OfferUiData.fromOffer(Object? offer) {
    final dynamic o = offer;
    final dynamic advertiser = _read(() => o.advertiser);
    final dynamic practical = _read(() => o.practicalInfo);

    final offerId = _asString(_read(() => o.id), fallback: '');
    final title = _asString(_read(() => o.title), fallback: 'Montage meuble');
    final detail = _asString(_read(() => o.shortDescription), fallback: '+ fixation TV');
    final city = _asString(_read(() => o.city), fallback: 'Les Abymes');
    final postalCode = _asString(_read(() => o.postalCode), fallback: '');
    final category = _asString(_read(() => o.category), fallback: 'Bricolage');

    final fullDescription = _asString(
      _read(() => o.description),
      fallback: 'Montage d\'un petit meuble + fixation d\'une\nTV au mur (support déjà acheté). Mur béton.\nPrévoir perceuse.',
    );
    final phone = _asString(_read(() => o.phone), fallback: '');
    final publishedAtLabel = _asString(
      _read(() => o.publishedAtLabel),
      fallback: 'Publication récente',
    );
    final availability = _asString(
      _read(() => o.availability),
      fallback: 'Disponibilité à confirmer',
    );
    final actionType = _read(() => o.actionType) is OfferActionType
        ? _read(() => o.actionType) as OfferActionType
        : OfferActionType.contact;
    final statusBadges = _asStringList(_read(() => o.statusBadges));
    final urgentRaw = _read(() => o.isUrgent);
    final isUrgent = urgentRaw is bool
      ? urgentRaw
      : statusBadges.any(
        (badge) => badge.toLowerCase().contains('urgent'),
        );

    final price = _asDouble(_read(() => o.price), fallback: 90);

    final advertiserId = _asString(
      _read(() => advertiser.id) ??
          _read(() => o.userId) ??
          _read(() => o.uid) ??
          _read(() => o.ownerId),
      fallback: '',
    );
    final advertiserName = _asString(_read(() => advertiser.name), fallback: 'Bastien');
    final advertiserRole = _asString(_read(() => advertiser.bio), fallback: 'Bricoleur expérimenté');
    final advertiserAvatarUrl = _asString(_read(() => advertiser.avatarUrl), fallback: '');
    final advertiserRating = _asDouble(_read(() => advertiser.rating), fallback: 4.9);
    final advertiserReviewCount = _asInt(
      _read(() => advertiser.reviewsCount) ?? _read(() => advertiser.reviewCount),
      fallback: 0,
    );
    final verified = _asBool(_read(() => advertiser.verified), fallback: true);

    final serviceArea = _asString(_read(() => practical.serviceArea), fallback: city);
    final canTravel = _asBool(_read(() => practical.canTravel), fallback: true);
    final schedule = _asString(_read(() => practical.schedule), fallback: 'Horaires à convenir');
    final missionDelay = _asString(
      _read(() => practical.missionDelay) ??
          _read(() => o.missionDelay) ??
          _read(() => o.averageDelay),
      fallback: 'Délai non précisé',
    );
    final averageDelay = _asString(_read(() => practical.averageDelay), fallback: '30 min en moyenne');
    final paymentMethod = _asString(_read(() => practical.paymentMethod), fallback: 'Paiement à convenir');
    final serviceType = _asString(_read(() => practical.serviceType), fallback: 'Prestation ponctuelle');

    return _OfferUiData(
      offerId: offerId,
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
            onPressed: () {},
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
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 15 : 18,
          compact ? 15 : 18,
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
                        _DelayBadge(text: data.averageDelay, compact: compact),
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
                  _InfoLine(
                    icon: Icons.person_outline_rounded,
                    label: 'Annonceur',
                    value: data.advertiserName,
                    compact: compact,
                  ),
                  SizedBox(height: compact ? 12 : 14),
                  Row(
                    children: [
                      Expanded(child: Divider(height: 1, thickness: 1, color: line)),
                      SizedBox(width: compact ? 7 : 10),
                      Icon(Icons.access_time_rounded, color: muted, size: compact ? 13 : 15),
                      SizedBox(width: compact ? 4 : 5),
                      Text(
                        'Réponse en moins d\'une heure',
                        style: TextStyle(
                          color: muted,
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: compact ? 7 : 10),
                      Expanded(child: Divider(height: 1, thickness: 1, color: line)),
                    ],
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
                    Text(
                      'Annonceur',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        fontSize: compact ? 14 : 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: compact ? 2 : 3),
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
              Icon(icon, color: const Color(0xFF6C7384), size: compact ? 20 : 22),
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
    final internationalPrefix = RegExp(r'^(\+\d{1,4})').firstMatch(compact)?.group(1);
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
    final displayedValue = _isPhoneVisible
        ? widget.phone.trim()
        : _maskedLabel(widget.phone);

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
                tooltip: _isPhoneVisible ? 'Masquer le numéro' : 'Voir le numéro',
                visualDensity: VisualDensity.compact,
                splashRadius: widget.compact ? 18 : 20,
                icon: Icon(
                  _isPhoneVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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

  const _InlineCta({required this.label, this.compact = false, required this.onTap});

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
            child: Row(
              children: [
                Expanded(
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
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: compact ? 14 : 16,
                ),
              ],
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
