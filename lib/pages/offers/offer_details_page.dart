import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:presto_app/pages/messages/conversation_thread_page.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

enum OfferActionType { booking, contact }

class PracticalInfo {
  final String category;
  final String serviceArea;
  final bool canTravel;
  final String schedule;
  final String averageDelay;
  final String paymentMethod;
  final String serviceType;

  const PracticalInfo({
    required this.category,
    required this.serviceArea,
    required this.canTravel,
    required this.schedule,
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

  OfferDetailsPage({
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

    final convCol = FirebaseFirestore.instance.collection('conversations');
    final q = await convCol
        .where('participants', arrayContains: me)
        .where('offerId', isEqualTo: data.offerId)
        .limit(20)
        .get();

    String? conversationId;
    for (final doc in q.docs) {
      final parts = (doc.data()['participants'] as List<dynamic>? ?? [])
          .map((entry) => entry.toString())
          .toList();
      if (parts.contains(data.advertiserId)) {
        conversationId = doc.id;
        break;
      }
    }

    if (conversationId == null) {
      final created = await convCol.add({
        'offerId': data.offerId,
        'offerTitle': data.title,
        'participants': [me, data.advertiserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'unreadCount': {me: 0, data.advertiserId: 0},
      });
      conversationId = created.id;
    }
    final resolvedConversationId = conversationId;

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Partager l\'annonce',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ShareOptionTile(
                      icon: Icons.chat,
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
                      icon: Icons.facebook,
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
                      icon: Icons.camera_alt_outlined,
                      label: 'Instagram',
                      color: const Color(0xFFE1306C),
                      onTap: openInstagram,
                    ),
                    _ShareOptionTile(
                      icon: Icons.mail_outline,
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Proposer mes services',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
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
                      backgroundColor: const Color(0xFF0459D9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Envoyer un message'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _callPhone(context, data.phone);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0459D9),
                      side: const BorderSide(color: Color(0xFFD7DEE8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
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
        centerTitle: false,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Détail annonce',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Partager',
            onPressed: () => _showShareOptionsSheet(context, data),
            icon: const Icon(Icons.share_outlined),
            color: Colors.white,
            splashRadius: 20,
          ),
          IconButton(
            tooltip: 'Favori',
            onPressed: () {},
            icon: const Icon(Icons.favorite_border_rounded),
            color: Colors.white,
            splashRadius: 20,
          ),
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
                if (data.isUrgent)
                  Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFFFFA43A), Color(0xFFFF6A00)],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x2EFF8A00),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.priority_high_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'URGENT',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                    _DelayBadge(text: data.averageDelay, compact: compact),
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
    const blue = Color(0xFF0459D9);
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
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 18,
              compact ? 14 : 16,
              compact ? 16 : 18,
              compact ? 10 : 12,
            ),
            child: Row(
              children: [
                Text(
                  'Infos annonceur',
                  style: TextStyle(
                    color: blue,
                    fontSize: compact ? 20 : 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
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
                  Row(
                    children: [
                      _AdvertiserAvatar(
                        name: data.advertiserName,
                        avatarUrl: data.advertiserAvatarUrl,
                        compact: compact,
                      ),
                      SizedBox(width: compact ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: data.advertiserName,
                                    style: TextStyle(
                                      color: navy,
                                      fontSize: compact ? 17 : 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: compact ? 5 : 6),
                            Row(
                              children: [
                                Icon(Icons.star_rounded, color: orange, size: compact ? 15 : 18),
                                SizedBox(width: compact ? 4 : 5),
                                Text(
                                  data.advertiserRating.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: orange,
                                    fontSize: compact ? 14 : 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(width: compact ? 5 : 8),
                                Text(
                                  data.advertiserReviewCount > 0
                                      ? '(${data.advertiserReviewCount} avis)'
                                      : '(0 avis)',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: compact ? 13 : 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 10 : 14,
                          vertical: compact ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F7F2),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: const Color(0xFFDCEADB),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: data.verified ? green : muted,
                              size: compact ? 14 : 16,
                            ),
                            SizedBox(width: compact ? 5 : 6),
                            Text(
                              data.verified ? 'Profil vérifié' : 'Profil',
                              style: TextStyle(
                                color: navy,
                                fontSize: compact ? 12 : 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 10 : 14),
                  const Divider(height: 1, thickness: 1, color: line),
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
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: compact ? 12 : 14),
                    child: Row(
                      children: [
                        Icon(Icons.wallet_outlined, color: muted, size: compact ? 21 : 24),
                        SizedBox(width: compact ? 9 : 12),
                        Text(
                          'Délai pour effectuer la mission',
                          style: TextStyle(
                            color: muted,
                            fontSize: compact ? 15 : 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        _DelayBadge(text: data.averageDelay, compact: compact),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: line),
                  _InfoLine(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Mode de paiement',
                    value: data.paymentMethod,
                    compact: compact,
                  ),
                  _InfoLine(
                    icon: Icons.work_outline_rounded,
                    label: 'Type de prestation',
                    value: data.serviceType,
                    iconColor: blue,
                    showDivider: false,
                    compact: compact,
                  ),
                  SizedBox(height: compact ? 12 : 14),
                  _InlineCta(
                    label: 'Proposer mes services',
                    compact: compact,
                    onTap: onContactTap,
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

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final bool showDivider;
  final bool compact;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = const Color(0xFF6C7384),
    this.showDivider = true,
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
            children: [
              Icon(icon, color: iconColor, size: compact ? 20 : 22),
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
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, thickness: 1, color: line),
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
    const blue = Color(0xFF0459D9);
    const muted = Color(0xFF6F7282);

    final normalized = text.trim().isEmpty ? '30 min en moyenne' : text.trim();
    final parts = normalized.split(' en moyenne');
    final headline = parts.first.trim();
    final subline = normalized.contains('en moyenne') ? 'en moyenne' : '';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(compact ? 9 : 10),
        border: Border.all(
          color: const Color(0xFFDBE6FA),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            headline,
            style: TextStyle(
              color: blue,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          if (subline.isNotEmpty) ...[
            SizedBox(height: compact ? 0.5 : 1),
            Text(
              subline,
              style: TextStyle(
                color: muted,
                fontSize: compact ? 8 : 9,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ],
        ],
      ),
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
                Container(
                  width: compact ? 28 : 30,
                  height: compact ? 28 : 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(compact ? 7 : 8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.28),
                    ),
                  ),
                  child: Icon(
                    Icons.mail_outline_rounded,
                    color: Colors.white,
                    size: compact ? 16 : 18,
                  ),
                ),
                SizedBox(width: compact ? 8 : 10),
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
  final IconData icon;
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
    return SizedBox(
      width: 92,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvertiserAvatar extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final bool compact;

  const _AdvertiserAvatar({required this.name, required this.avatarUrl, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final initials = _buildInitials(name);

    return Container(
      width: compact ? 52 : 58,
      height: compact ? 52 : 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: compact ? 1.5 : 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: compact ? 6 : 8,
            offset: Offset(0, compact ? 2 : 3),
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7D25B), Color(0xFFC98E27)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl.isNotEmpty
          ? Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _AvatarFallback(initials: initials),
            )
          : _AvatarFallback(initials: initials),
    );
  }

  String _buildInitials(String value) {
    final parts = value
        .split(RegExp(r'\s+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'P';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
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
