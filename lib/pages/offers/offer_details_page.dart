import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_core.dart';
import '../../constants.dart';
import '../../features/messaging/conversation_service.dart';
import '../messages/conversation_thread_page.dart';

class OfferDetailsPage extends StatefulWidget {
  final Offer offer;
  final String currentUserId;

  OfferDetailsPage({
    super.key,
    Offer? offer,
    this.currentUserId = 'buyer_demo_001',
  }) : offer = offer ?? Offer.mock();

  @override
  State<OfferDetailsPage> createState() => _OfferDetailsPageState();
}

class _OfferDetailsPageState extends State<OfferDetailsPage> {
  final PageController _galleryController = PageController();
  final ConversationService _conversationService = ConversationService();

  int _currentImageIndex = 0;
  bool _phoneVisible = false;
  bool _isFavorite = false;
  bool _descriptionExpanded = false;
  bool _isLoading = true;
  Offer? _loadedOffer;

  @override
  void initState() {
    super.initState();
    _loadOfferFromFirestore();
    _loadFavoriteStatus();
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  void _togglePhoneVisibility() {
    setState(() => _phoneVisible = !_phoneVisible);
  }

  void _openAdvertiserProfile() {
    final offer = _loadedOffer ?? widget.offer;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdvertiserProfilePage(
          advertiser: offer.advertiser,
          featuredOffer: offer,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }

  Future<void> _loadFavoriteStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    final offerId = widget.offer.id.trim();

    if (user == null || offerId.isEmpty) {
      if (mounted) {
        setState(() => _isFavorite = false);
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final favoriteIds = (doc.data()?['favoriteOfferIds'] as List<dynamic>? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet();

      if (!mounted) return;
      setState(() => _isFavorite = favoriteIds.contains(offerId));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFavorite = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour enregistrer vos favoris.')),
      );
      await Navigator.of(context).pushNamed('/account');
      return;
    }

    final offerId = (_loadedOffer ?? widget.offer).id.trim();
    final offer = _loadedOffer ?? widget.offer;
    if (offerId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annonce introuvable.')),
      );
      return;
    }

    final nextValue = !_isFavorite;
    setState(() => _isFavorite = nextValue);

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      await userRef.set({
        'favoriteOfferIds': nextValue
            ? FieldValue.arrayUnion([offerId])
            : FieldValue.arrayRemove([offerId]),
        'favoriteOffersUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final favoriteRef = userRef.collection('favoriteOffers').doc(offerId);
      if (nextValue) {
        await favoriteRef.set({
          'offerId': offer.id,
          'title': offer.title,
          'city': offer.city,
          'category': offer.category,
          'price': offer.price,
          'imageUrl': offer.imageUrls.isNotEmpty ? offer.imageUrls.first : '',
          'addedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await favoriteRef.delete();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextValue
                ? 'Annonce ajoutée à vos favoris.'
                : 'Annonce retirée de vos favoris.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFavorite = !nextValue);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de mettre à jour les favoris.')),
      );
    }
  }

  Future<void> _startChat() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour envoyer un message.')),
      );
      await Navigator.of(context).pushNamed('/account');
      return;
    }

    final offer = _loadedOffer ?? widget.offer;
    final sellerId = offer.advertiser.id.trim();
    if (sellerId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annonceur introuvable.')),
      );
      return;
    }

    final conversation = await _conversationService.getOrCreateConversation(
      currentUserId: me.uid,
      otherUserId: sellerId,
    );
    final conversationId = conversation.conversationId;

    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .set({
      'offerId': offer.id,
      'offerTitle': offer.title,
    }, SetOptions(merge: true));

    if (conversation.isNew) {
      await _seedIntroMessage(
        conversationId: conversationId,
        offer: offer,
        currentUser: me,
        sellerId: sellerId,
      );
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationThreadPage(
          conversationId: conversationId,
          offerTitle: offer.title,
          currentUserId: me.uid,
        ),
      ),
    );
  }

  Future<void> _seedIntroMessage({
    required String conversationId,
    required Offer offer,
    required User currentUser,
    required String sellerId,
  }) async {
    final conversationRef =
        FirebaseFirestore.instance.collection('conversations').doc(conversationId);
    final introText = _buildIntroMessage(offer);
    final senderName = (currentUser.displayName ?? currentUser.email ?? 'Utilisateur')
        .trim();

    final batch = FirebaseFirestore.instance.batch();
    final messageRef = conversationRef.collection('messages').doc();

    batch.set(messageRef, {
      'text': introText,
      'senderId': currentUser.uid,
      'senderName': senderName.isEmpty ? 'Utilisateur' : senderName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(conversationRef, {
      'lastMessage': introText,
      'lastSenderId': currentUser.uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCount.${currentUser.uid}': 0,
      'unreadCount.$sellerId': FieldValue.increment(1),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  String _buildIntroMessage(Offer offer) {
    final category = offer.category.toLowerCase();
    final title = offer.title.trim();

    if (category.contains('jardin')) {
      return 'Bonjour, votre annonce "$title" m\'interesse. Pouvez-vous intervenir cette semaine pour du jardinage ?';
    }

    if (category.contains('menage') || category.contains('nettoyage')) {
      return 'Bonjour, je suis interesse par "$title". Avez-vous des disponibilites rapides pour une intervention menage/nettoyage ?';
    }

    if (category.contains('bricolage') || category.contains('travaux')) {
      return 'Bonjour, votre annonce "$title" m\'interesse. Pouvez-vous me confirmer vos disponibilites et un delai estimatif ?';
    }

    if (category.contains('transport') || category.contains('livraison')) {
      return 'Bonjour, je souhaite en savoir plus sur "$title". Etes-vous disponible pour une prestation prochainement ?';
    }

    return 'Bonjour, je suis interesse par votre annonce "$title". Est-elle toujours disponible ?';
  }

  Future<void> _loadOfferFromFirestore() async {
    final baseOffer = widget.offer;

    if (baseOffer.id.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _loadedOffer = baseOffer;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final offerDoc = await FirebaseFirestore.instance
          .collection('offers')
          .doc(baseOffer.id)
          .get();

      Offer mergedOffer = baseOffer;
      final data = offerDoc.data();
      if (offerDoc.exists && data != null) {
        mergedOffer = _mergeOfferFromMap(baseOffer, offerDoc.id, data);
      }

      final sellerIdCandidates = <String>[
        mergedOffer.advertiser.id.trim(),
        (data?['userId'] ?? '').toString().trim(),
        (data?['uid'] ?? '').toString().trim(),
      ].where((e) => e.isNotEmpty).toList();

      if (sellerIdCandidates.isNotEmpty) {
        final sellerId = sellerIdCandidates.first;
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(sellerId)
            .get();

        final offersCount = await _countSellerOffers(sellerId);
        mergedOffer = mergedOffer.copyWith(
          advertiser: _mergeAdvertiserFromUser(
            mergedOffer.advertiser.copyWith(id: sellerId),
            userDoc.data(),
            offersCount,
            mergedOffer.city,
          ),
        );
      }

      final similar = await _loadSimilarOffers(mergedOffer);
      if (mounted) {
        setState(() {
          _loadedOffer = mergedOffer.copyWith(similarOffers: similar);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadedOffer = baseOffer;
          _isLoading = false;
        });
      }
    }
  }

  Future<int> _countSellerOffers(String sellerId) async {
    final col = FirebaseFirestore.instance.collection('offers');
    final a = await col.where('userId', isEqualTo: sellerId).get();
    final b = await col.where('uid', isEqualTo: sellerId).get();
    final ids = <String>{...a.docs.map((d) => d.id), ...b.docs.map((d) => d.id)};
    return ids.length;
  }

  Future<List<Offer>> _loadSimilarOffers(Offer offer) async {
    final snap = await FirebaseFirestore.instance
        .collection('offers')
        .where('category', isEqualTo: offer.category)
        .limit(6)
        .get();

    final similar = <Offer>[];
    for (final doc in snap.docs) {
      if (doc.id == offer.id) continue;
      final data = doc.data();
      final imageUrls = (data['imageUrls'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();

      similar.add(
        Offer._mini(
          id: doc.id,
          title: (data['title'] ?? 'Annonce similaire').toString(),
          city: (data['location'] ?? data['city'] ?? offer.city).toString(),
          price: ((data['budget'] as num?)?.toDouble() ?? 0),
          imageUrl: imageUrls.isNotEmpty ? imageUrls.first : '',
          advertiser: offer.advertiser,
        ),
      );
    }

    return similar;
  }

  Offer _mergeOfferFromMap(Offer base, String id, Map<String, dynamic> data) {
    final title = (data['title'] ?? '').toString().trim();
    final location = (data['location'] ?? data['city'] ?? '').toString().trim();
    final category = (data['category'] ?? '').toString().trim();
    final description = (data['description'] ?? '').toString().trim();
    final images = (data['imageUrls'] as List<dynamic>? ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return base.copyWith(
      id: id,
      title: title.isEmpty ? base.title : title,
      city: location.isEmpty ? base.city : location,
      category: category.isEmpty ? base.category : category,
      description: description.isEmpty ? base.description : description,
      shortDescription: description.isEmpty
          ? base.shortDescription
          : description,
      phone: (data['phone'] ?? base.phone).toString(),
      price: (data['budget'] as num?)?.toDouble() ?? base.price,
      imageUrls: images.isEmpty ? base.imageUrls : images,
      actionType: ((data['actionType'] ?? '').toString() == 'booking')
          ? OfferActionType.booking
          : OfferActionType.contact,
    );
  }

  Advertiser _mergeAdvertiserFromUser(
    Advertiser base,
    Map<String, dynamic>? userData,
    int offersCount,
    String fallbackCity,
  ) {
    final data = userData ?? const <String, dynamic>{};
    final pseudo = ((data['pseudo'] ?? data['displayName']) ?? '').toString();
    final name = pseudo.trim().isEmpty ? base.name : pseudo.trim();
    final city = (data['city'] ?? fallbackCity).toString();
    final createdAt = data['createdAt'];
    String seniority = base.seniorityLabel;
    if (createdAt is Timestamp) {
      seniority = 'Membre depuis ${createdAt.toDate().year}';
    }

    final status = (data['status'] ?? '').toString().toLowerCase();
    final isOnline = status == 'online';
    final lastSeenLabel = _buildLastSeenLabel(data['lastSeenAt']);

    return base.copyWith(
      name: name,
      city: city,
      bio: (data['bio'] ?? base.bio).toString(),
      verified: (data['verified'] as bool?) ?? base.verified,
      avatarUrl: (data['avatarUrl'] ?? data['photoUrl'] ?? base.avatarUrl)
          .toString(),
      rating: (data['rating'] as num?)?.toDouble() ?? base.rating,
      offersCount: offersCount > 0 ? offersCount : base.offersCount,
      seniorityLabel: seniority,
      isOnline: isOnline,
      lastSeenLabel: lastSeenLabel,
    );
  }

  String _buildLastSeenLabel(dynamic rawLastSeen) {
    if (rawLastSeen is! Timestamp) {
      return 'Activite recente';
    }

    final diff = DateTime.now().difference(rawLastSeen.toDate());
    if (diff.inMinutes < 1) return 'Actif a l\'instant';
    if (diff.inMinutes < 60) return 'Actif il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Actif il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Actif il y a ${diff.inDays} j';
    return 'Actif il y a plus d\'une semaine';
  }

  Future<void> _callSeller() async {
    final normalized = _normalizePhone(widget.offer.phone);
    if (normalized.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numero indisponible.')),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: normalized);
    final ok = await canLaunchUrl(uri);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de lancer l appel.')),
      );
      return;
    }

    await launchUrl(uri);
  }

  Future<void> _copyPhone() async {
    final raw = widget.offer.phone.trim();
    if (raw.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: raw));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Numero copie dans le presse-papiers.')),
    );
  }

  String _offerDeepLink(Offer offer) {
    return 'https://presto-app-74abe.web.app/offers/${offer.id}';
  }

  String _offerShareText(Offer offer) {
    final priceText = offer.price > 0 ? ' - ${offer.price.toStringAsFixed(0)} EUR' : '';
    final locationText = offer.city.trim().isEmpty ? '' : ' a ${offer.city.trim()}';
    return 'Découvrez cette annonce sur ilipresto: ${offer.title}$locationText$priceText\n${_offerDeepLink(offer)}';
  }

  Future<bool> _launchFirstAvailable(
    List<Uri> uris, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    for (final uri in uris) {
      try {
        if (await canLaunchUrl(uri)) {
          final launched = await launchUrl(uri, mode: mode);
          if (launched) return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<void> _copyShareText(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _shareToWhatsApp(Offer offer) async {
    final encoded = Uri.encodeComponent(_offerShareText(offer));
    final opened = await _launchFirstAvailable([
      Uri.parse('whatsapp://send?text=$encoded'),
      Uri.parse('https://wa.me/?text=$encoded'),
    ]);

    if (!opened) {
      await _copyShareText(
        _offerShareText(offer),
        'Lien copié. Collez-le dans WhatsApp.',
      );
    }
  }

  Future<void> _shareToWhatsAppStatus(Offer offer) async {
    final shareText = _offerShareText(offer);
    await Clipboard.setData(ClipboardData(text: shareText));
    await _launchFirstAvailable([
      Uri.parse('whatsapp://app'),
      Uri.parse('https://www.whatsapp.com/'),
    ]);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Texte copié. Collez-le dans votre statut WhatsApp.'),
      ),
    );
  }

  Future<void> _shareToFacebook(Offer offer) async {
    final link = Uri.encodeComponent(_offerDeepLink(offer));
    final quote = Uri.encodeComponent(_offerShareText(offer));
    final opened = await _launchFirstAvailable([
      Uri.parse('fb://facewebmodal/f?href=https://www.facebook.com/sharer/sharer.php?u=$link&quote=$quote'),
      Uri.parse('https://www.facebook.com/sharer/sharer.php?u=$link&quote=$quote'),
    ]);

    if (!opened) {
      await _copyShareText(
        _offerShareText(offer),
        'Lien copié. Partagez-le sur Facebook.',
      );
    }
  }

  Future<void> _shareToInstagram(Offer offer) async {
    final shareText = _offerShareText(offer);
    await Clipboard.setData(ClipboardData(text: shareText));
    await _launchFirstAvailable([
      Uri.parse('instagram://app'),
      Uri.parse('https://www.instagram.com/'),
    ]);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lien copié. Collez-le dans Instagram.'),
      ),
    );
  }

  Future<void> _shareByMail(Offer offer) async {
    final uri = Uri.parse(
      'mailto:?subject=${Uri.encodeComponent('Annonce ilipresto: ${offer.title}')}&body=${Uri.encodeComponent(_offerShareText(offer))}',
    );
    final opened = await _launchFirstAvailable(
      [uri],
      mode: LaunchMode.platformDefault,
    );

    if (!opened) {
      await _copyShareText(
        _offerShareText(offer),
        'Lien copié. Utilisez votre application mail pour partager.',
      );
    }
  }

  Future<void> _shareOffer() async {
    final offer = _loadedOffer ?? widget.offer;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Partager cette annonce',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  offer.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ShareActionButton(
                      label: 'WhatsApp',
                      backgroundColor: const Color(0xFF25D366),
                      logoUrl:
                          'https://upload.wikimedia.org/wikipedia/commons/6/6b/WhatsApp.svg',
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await _shareToWhatsApp(offer);
                      },
                    ),
                    _ShareActionButton(
                      label: 'Statut WhatsApp',
                      backgroundColor: const Color(0xFF128C7E),
                      logoUrl:
                          'https://upload.wikimedia.org/wikipedia/commons/6/6b/WhatsApp.svg',
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await _shareToWhatsAppStatus(offer);
                      },
                    ),
                    _ShareActionButton(
                      label: 'Facebook',
                      backgroundColor: const Color(0xFF1877F2),
                      logoUrl:
                          'https://upload.wikimedia.org/wikipedia/commons/b/b9/2023_Facebook_icon.svg',
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await _shareToFacebook(offer);
                      },
                    ),
                    _ShareActionButton(
                      label: 'Instagram',
                      backgroundColor: const Color(0xFFE1306C),
                      logoUrl:
                          'https://upload.wikimedia.org/wikipedia/commons/a/a5/Instagram_icon.png',
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await _shareToInstagram(offer);
                      },
                    ),
                    _ShareActionButton(
                      label: 'Mail',
                      backgroundColor: const Color(0xFF4B5563),
                      logoUrl:
                          'https://upload.wikimedia.org/wikipedia/commons/4/4e/Gmail_Icon.png',
                      fallbackIcon: const Icon(
                        Icons.mail_outline,
                        color: Colors.white,
                        size: 22,
                      ),
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await _shareByMail(offer);
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

  void _reportOffer() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        const reasons = <String>[
          'Contenu trompeur',
          'Prix suspect',
          'Spam ou doublon',
          'Comportement inapproprie',
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Signaler cette annonce',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                ...reasons.map(
                  (reason) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.flag_outlined),
                    title: Text(reason),
                    onTap: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('Signalement envoye: $reason')),
                      );
                    },
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
    final offer = _loadedOffer ?? widget.offer;
    final hasImages = offer.imageUrls.isNotEmpty;
    final topPadding = hasImages ? 12.0 : 6.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        leading: const BackButton(),
        title: Text(
          offer.title,
          style: kPrestoAppBarTitleStyle,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: _isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
            onPressed: _toggleFavorite,
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.white : Colors.white,
            ),
          ),
          IconButton(
            tooltip: 'Partager',
            onPressed: _shareOffer,
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'Signaler',
            onPressed: _reportOffer,
            icon: const Icon(Icons.flag_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, topPadding, 12, 116),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading || hasImages) ...[
                    _GalleryCard(
                      pageController: _galleryController,
                      imageUrls: offer.imageUrls,
                      currentIndex: _currentImageIndex,
                      onPageChanged: (v) => setState(() => _currentImageIndex = v),
                      badges: offer.statusBadges,
                      heroTag: 'offer-image-${offer.id}',
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _MainInfoCard(offer: offer, isLoading: _isLoading),
                  const SizedBox(height: 12),
                  _PracticalInfoCard(
                    isLoading: _isLoading,
                    practicalInfo: offer.practicalInfo,
                  ),
                  const SizedBox(height: 12),
                  _ContactAdvertiserCard(
                    isLoading: _isLoading,
                    advertiser: offer.advertiser,
                    displayPhone: _phoneVisible
                        ? offer.phone
                        : _maskPhoneForDisplay(offer.phone),
                    phoneVisible: _phoneVisible,
                    onTogglePhone: _togglePhoneVisibility,
                    onCopy: _copyPhone,
                    onOpenProfile: _openAdvertiserProfile,
                  ),
                  const SizedBox(height: 14),
                  _SimilarOffersSection(
                    isLoading: _isLoading,
                    offers: offer.similarOffers,
                    onTapOffer: (other) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OfferDetailsPage(
                            offer: other,
                            currentUserId: widget.currentUserId,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _StickyBottomBar(
        offer: offer,
        onMessage: _startChat,
        onCall: _callSeller,
        onPrimaryAction: _startChat,
      ),
    );
  }
}

class _GalleryCard extends StatelessWidget {
  final PageController pageController;
  final List<String> imageUrls;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final List<String> badges;
  final String heroTag;
  final bool isLoading;

  const _GalleryCard({
    required this.pageController,
    required this.imageUrls,
    required this.currentIndex,
    required this.onPageChanged,
    required this.badges,
    required this.heroTag,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _SkeletonBox(height: 232, radius: 18);
    }

    return Container(
      height: 232,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: pageController,
              itemCount: imageUrls.isEmpty ? 1 : imageUrls.length,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) {
                if (imageUrls.isEmpty) {
                  return const _MissingImagePlaceholder();
                }

                return Hero(
                  tag: '$heroTag-$index',
                  child: Image.network(
                    imageUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _MissingImagePlaceholder(),
                  ),
                );
              },
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: badges
                        .map((badge) => _StatusBadge(label: badge))
                        .toList(growable: false),
                  ),
                  _PageIndicator(
                    itemCount: imageUrls.isEmpty ? 1 : imageUrls.length,
                    currentIndex: currentIndex,
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

class _MainInfoCard extends StatelessWidget {
  final Offer offer;
  final bool isLoading;

  const _MainInfoCard({required this.offer, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _SkeletonBox(height: 180, radius: 16);
    }

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            offer.title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${offer.price.toStringAsFixed(0)} €',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: kPrestoOrange,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (offer.category.isNotEmpty)
                _MetaPill(icon: Icons.category_outlined, text: offer.category),
              if (offer.city.isNotEmpty)
                _MetaPill(icon: Icons.location_on_outlined, text: offer.city),
              if (offer.statusBadges.any(
                (b) => b.toLowerCase().contains('urgent'),
              ))
                _MetaPill(
                  icon: Icons.bolt,
                  text: 'Urgent',
                  color: const Color(0xFFB91C1C),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            offer.shortDescription,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  final bool isLoading;
  final String description;
  final bool expanded;
  final VoidCallback onToggleExpand;

  const _DescriptionCard({
    required this.isLoading,
    required this.description,
    required this.expanded,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _SkeletonBox(height: 154, radius: 18);
    }

    final hasDescription = description.trim().isNotEmpty;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description complete',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (!hasDescription)
            const Text(
              'Aucune description detaillee fournie pour cette annonce.',
              style: TextStyle(color: Color(0xFF6B7280), height: 1.45),
            )
          else ...[
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 230),
              crossFadeState:
                  expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: Text(
                description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              secondChild: Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onToggleExpand,
              icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(expanded ? 'Voir moins' : 'Voir plus'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PracticalInfoCard extends StatelessWidget {
  final bool isLoading;
  final PracticalInfo practicalInfo;

  const _PracticalInfoCard({
    required this.isLoading,
    required this.practicalInfo,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _SkeletonBox(height: 252, radius: 16);
    }

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations pratiques',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _InfoLine(
            icon: Icons.category_outlined,
            label: 'Categorie',
            value: practicalInfo.category,
          ),
          _InfoLine(
            icon: Icons.map_outlined,
            label: 'Zone d intervention',
            value: practicalInfo.serviceArea,
          ),
          _InfoLine(
            icon: Icons.directions_car_outlined,
            label: 'Deplacement possible',
            value: practicalInfo.canTravel ? 'Oui' : 'Non',
          ),
          _InfoLine(
            icon: Icons.schedule_outlined,
            label: 'Horaires',
            value: practicalInfo.schedule,
          ),
          _InfoLine(
            icon: Icons.timelapse_outlined,
            label: 'Delai moyen',
            value: practicalInfo.averageDelay,
          ),
          _InfoLine(
            icon: Icons.payments_outlined,
            label: 'Mode de paiement',
            value: practicalInfo.paymentMethod,
          ),
          _InfoLine(
            icon: Icons.work_outline,
            label: 'Type de prestation',
            value: practicalInfo.serviceType,
            hasDivider: false,
          ),
        ],
      ),
    );
  }
}

class _ContactAdvertiserCard extends StatelessWidget {
  final bool isLoading;
  final Advertiser advertiser;
  final String displayPhone;
  final bool phoneVisible;
  final VoidCallback onTogglePhone;
  final Future<void> Function() onCopy;
  final VoidCallback onOpenProfile;

  const _ContactAdvertiserCard({
    required this.isLoading,
    required this.advertiser,
    required this.displayPhone,
    required this.phoneVisible,
    required this.onTogglePhone,
    required this.onCopy,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _SkeletonBox(height: 248, radius: 16);
    }

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AdvertiserAvatar(avatarUrl: advertiser.avatarUrl, radius: 26),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: onOpenProfile,
                  borderRadius: BorderRadius.circular(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              advertiser.name,
                              style: const TextStyle(
                                  fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (advertiser.verified) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified,
                              size: 18,
                              color: Color(0xFF2563EB),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${advertiser.rating.toStringAsFixed(1)} • ${advertiser.offersCount} annonces • ${advertiser.city}',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onOpenProfile,
                icon: const Icon(Icons.person_outline),
                label: const Text('Voir le profil'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          if (advertiser.bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              advertiser.bio,
              style: const TextStyle(height: 1.4, color: Color(0xFF374151)),
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.phone_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayPhone,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: phoneVisible ? 'Masquer' : 'Afficher',
                  onPressed: onTogglePhone,
                  icon: Icon(phoneVisible ? Icons.visibility_off : Icons.visibility),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SimilarOffersSection extends StatelessWidget {
  final bool isLoading;
  final List<Offer> offers;
  final ValueChanged<Offer> onTapOffer;

  const _SimilarOffersSection({
    required this.isLoading,
    required this.offers,
    required this.onTapOffer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Autres annonces similaires',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 184,
          child: isLoading
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, __) => const SizedBox(
                    width: 220,
                    child: _SkeletonBox(height: 184, radius: 16),
                  ),
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemCount: 3,
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: offers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final offer = offers[i];
                    return _SimilarOfferTile(
                      offer: offer,
                      onTap: () => onTapOffer(offer),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _StickyBottomBar extends StatefulWidget {
  final Offer offer;
  final Future<void> Function() onMessage;
  final Future<void> Function() onCall;
  final Future<void> Function() onPrimaryAction;

  const _StickyBottomBar({
    required this.offer,
    required this.onMessage,
    required this.onCall,
    required this.onPrimaryAction,
  });

  @override
  State<_StickyBottomBar> createState() => _StickyBottomBarState();
}

class _StickyBottomBarState extends State<_StickyBottomBar> {
  bool _showContactActions = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: kPrestoBlue.withOpacity(0.18)),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _showContactActions
              ? Row(
                  key: const ValueKey('contact-actions'),
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: widget.onMessage,
                        style: FilledButton.styleFrom(
                          backgroundColor: kPrestoOrange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(56),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Envoyer un message'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: widget.onCall,
                        style: FilledButton.styleFrom(
                          backgroundColor: kPrestoBlue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(56),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        icon: const Icon(Icons.call_outlined),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Appeler'),
                        ),
                      ),
                    ),
                  ],
                )
              : SizedBox(
                  key: const ValueKey('propose-service'),
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() => _showContactActions = true);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrestoOrange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    icon: const Icon(Icons.send_outlined),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Proposer mes services'),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrestoBlue.withOpacity(0.10)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _MetaPill({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? const Color(0xFF4B5563);
    final bgColor = color != null
        ? color!.withOpacity(0.10)
        : kPrestoBlue.withOpacity(0.08);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: baseColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color != null ? color! : const Color(0xFF27364A),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareActionButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final String logoUrl;
  final Widget? fallbackIcon;
  final Future<void> Function() onTap;

  const _ShareActionButton({
    required this.label,
    required this.backgroundColor,
    required this.logoUrl,
    this.fallbackIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: 104,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x16000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  logoUrl,
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      fallbackIcon ?? const Icon(Icons.share, color: Colors.white, size: 22),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
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

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool hasDivider;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.hasDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF6B7280)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (hasDivider) const Divider(height: 18),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;

  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();
    Color bg = const Color(0x99000000);

    if (lower.contains('urgent')) bg = const Color(0xCCB91C1C);
    if (lower.contains('verifie')) bg = const Color(0xCC1A73E8);
    if (lower.contains('disponible')) bg = const Color(0xCC059669);
    if (lower.contains('nouveau')) bg = const Color(0xCCFF6600);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int itemCount;
  final int currentIndex;

  const _PageIndicator({
    required this.itemCount,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          itemCount,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: EdgeInsets.only(right: i == itemCount - 1 ? 0 : 5),
            width: i == currentIndex ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == currentIndex
                  ? Colors.white
                  : const Color(0x99FFFFFF),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingImagePlaceholder extends StatelessWidget {
  const _MissingImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined, size: 34),
            SizedBox(height: 6),
            Text(
              'Image indisponible',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvertiserAvatar extends StatelessWidget {
  final String avatarUrl;
  final double radius;

  const _AdvertiserAvatar({required this.avatarUrl, required this.radius});

  @override
  Widget build(BuildContext context) {
    if (avatarUrl.trim().isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFE5E7EB),
        child: Icon(Icons.person_outline, size: radius, color: const Color(0xFF6B7280)),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundImage: NetworkImage(avatarUrl),
      onBackgroundImageError: (_, __) {},
      child: const SizedBox.shrink(),
    );
  }
}

class _SkeletonBox extends StatefulWidget {
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.height,
    this.radius = 14,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = 0.25 + (0.25 * _controller.value);
        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class _SimilarOfferTile extends StatelessWidget {
  final Offer offer;
  final VoidCallback onTap;

  const _SimilarOfferTile({required this.offer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 14,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 94,
                width: double.infinity,
                child: offer.imageUrls.isEmpty
                    ? const _MissingImagePlaceholder()
                    : Image.network(
                        offer.imageUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _MissingImagePlaceholder(),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${offer.price.toStringAsFixed(0)} € • ${offer.city}',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
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

class AdvertiserProfilePage extends StatefulWidget {
  final Advertiser advertiser;
  final Offer? featuredOffer;
  final String currentUserId;

  const AdvertiserProfilePage({
    super.key,
    required this.advertiser,
    this.featuredOffer,
    this.currentUserId = '',
  });

  @override
  State<AdvertiserProfilePage> createState() => _AdvertiserProfilePageState();
}

class _AdvertiserProfilePageState extends State<AdvertiserProfilePage> {
  final ConversationService _conversationService = ConversationService();
  bool _showPhone = false;
  bool _isLoadingExtraData = true;
  List<Offer> _advertiserOffers = const [];
  List<_AdvertiserReviewData> _advertiserReviews = const [];

  @override
  void initState() {
    super.initState();
    _loadAdvertiserExtraData();
  }

  Advertiser get advertiser => widget.advertiser;
  Offer? get featuredOffer => widget.featuredOffer;

  String get _displayPhone {
    final phone = featuredOffer?.phone ?? '';
    if (phone.trim().isEmpty) return 'Numero non renseigne';
    return _showPhone ? phone : _maskPhoneForDisplay(phone);
  }

  String get _initials {
    final parts = advertiser.name
        .replaceAll('.', ' ')
        .split(' ')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'A';
    if (parts.length == 1) {
      final word = parts.first;
      return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  List<String> get _topBadges {
    final badges = <String>['Annonceur'];
    if (advertiser.verified) badges.add('Compte verifie');
    if (advertiser.isOnline) badges.add('En ligne');
    return badges;
  }

  List<String> get _availabilityTags {
    final offer = featuredOffer;
    if (offer == null) return const ['Reponse selon disponibilite'];
    return <String>{
      if (offer.availability.trim().isNotEmpty) offer.availability.trim(),
      if (offer.practicalInfo.averageDelay.trim().isNotEmpty)
        offer.practicalInfo.averageDelay.trim(),
      if (offer.practicalInfo.schedule.trim().isNotEmpty)
        offer.practicalInfo.schedule.trim(),
      if (offer.practicalInfo.paymentMethod.trim().isNotEmpty)
        offer.practicalInfo.paymentMethod.trim(),
    }.take(4).toList();
  }

  Future<void> _loadAdvertiserExtraData() async {
    final sellerId = advertiser.id.trim();
    if (sellerId.isEmpty) {
      if (!mounted) return;
      setState(() => _isLoadingExtraData = false);
      return;
    }

    try {
      final offers = await _loadSellerOffers(sellerId);
      final reviews = await _loadSellerReviews(sellerId);

      if (!mounted) return;
      setState(() {
        _advertiserOffers = offers;
        _advertiserReviews = reviews;
        _isLoadingExtraData = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _advertiserOffers = const [];
        _advertiserReviews = const [];
        _isLoadingExtraData = false;
      });
    }
  }

  Future<List<Offer>> _loadSellerOffers(String sellerId) async {
    final col = FirebaseFirestore.instance.collection('offers');
    final byUserId = await col.where('userId', isEqualTo: sellerId).limit(12).get();
    final byUid = await col.where('uid', isEqualTo: sellerId).limit(12).get();
    final byOwnerId = await col.where('ownerId', isEqualTo: sellerId).limit(12).get();

    final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
      for (final d in byUserId.docs) d.id: d,
      for (final d in byUid.docs) d.id: d,
      for (final d in byOwnerId.docs) d.id: d,
    };

    final offers = byId.values.map((doc) {
      final data = doc.data();
      final imageUrls = (data['imageUrls'] as List<dynamic>? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final title = (data['title'] ?? 'Annonce').toString();
      final category = (data['category'] ?? 'Service').toString();
      final city = (data['location'] ?? data['city'] ?? advertiser.city).toString();
      final price = (data['budget'] as num?)?.toDouble() ?? 0;
      final description = (data['description'] ?? '').toString();

      final featured = featuredOffer;
      final fallbackPractical = featured?.practicalInfo ??
          const PracticalInfo(
            category: 'Service',
            serviceArea: 'Zone locale',
            canTravel: true,
            schedule: 'Flexible',
            averageDelay: 'Selon disponibilite',
            paymentMethod: 'A convenir',
            serviceType: 'Ponctuelle',
          );

      return Offer(
        id: doc.id,
        title: title,
        price: price,
        category: category,
        city: city,
        publishedAtLabel: featured?.publishedAtLabel ?? 'Recente',
        availability: featured?.availability ?? 'Selon disponibilite',
        shortDescription: description.isEmpty
            ? (featured?.shortDescription ?? 'Annonce publiee par cet annonceur.')
            : description,
        description: description,
        phone: (data['phone'] ?? featured?.phone ?? '').toString(),
        imageUrls: imageUrls,
        statusBadges: (data['statusBadges'] as List<dynamic>? ?? const ['Active'])
            .map((e) => e.toString())
            .toList(),
        practicalInfo: fallbackPractical,
        advertiser: advertiser,
        actionType: OfferActionType.contact,
        similarOffers: const [],
      );
    }).toList();

    offers.sort((a, b) {
      final aIsFeatured = featuredOffer != null && a.id == featuredOffer!.id;
      final bIsFeatured = featuredOffer != null && b.id == featuredOffer!.id;
      if (aIsFeatured && !bIsFeatured) return -1;
      if (!aIsFeatured && bIsFeatured) return 1;
      return a.title.compareTo(b.title);
    });

    if (offers.isEmpty && featuredOffer != null) {
      return [featuredOffer!];
    }

    return offers;
  }

  Future<List<_AdvertiserReviewData>> _loadSellerReviews(String sellerId) async {
    final reviews = <_AdvertiserReviewData>[];
    final tried = <String>{};

    Future<void> addFromQuery(Query<Map<String, dynamic>> query, String key) async {
      if (tried.contains(key)) return;
      tried.add(key);
      final snap = await query.limit(20).get();
      for (final doc in snap.docs) {
        final data = doc.data();
        reviews.add(_AdvertiserReviewData.fromMap(doc.id, data));
      }
    }

    try {
      await addFromQuery(
        FirebaseFirestore.instance.collection('reviews').where('sellerId', isEqualTo: sellerId),
        'reviews:sellerId',
      );
      await addFromQuery(
        FirebaseFirestore.instance.collection('reviews').where('advertiserId', isEqualTo: sellerId),
        'reviews:advertiserId',
      );
      await addFromQuery(
        FirebaseFirestore.instance.collection('reviews').where('userId', isEqualTo: sellerId),
        'reviews:userId',
      );

      final nested = await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .collection('reviews')
          .limit(20)
          .get();
      for (final doc in nested.docs) {
        reviews.add(_AdvertiserReviewData.fromMap(doc.id, doc.data()));
      }
    } catch (_) {
      // Les collections d'avis peuvent ne pas exister selon l'environnement.
    }

    final byId = <String, _AdvertiserReviewData>{};
    for (final review in reviews) {
      byId[review.id] = review;
    }

    final list = byId.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<String> get _trustItems {
    return [
      advertiser.verified ? 'Compte verifie' : 'Compte non verifie',
      advertiser.isOnline ? 'Annonceur en ligne' : advertiser.lastSeenLabel,
      if (advertiser.rating > 0)
        'Note moyenne ${advertiser.rating.toStringAsFixed(1)} / 5',
      advertiser.seniorityLabel,
      '${advertiser.offersCount} annonce${advertiser.offersCount > 1 ? 's' : ''} publiee${advertiser.offersCount > 1 ? 's' : ''}',
    ];
  }

  Future<void> _startChat() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour envoyer un message.')),
      );
      await Navigator.of(context).pushNamed('/account');
      return;
    }

    final sellerId = advertiser.id.trim();
    if (sellerId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annonceur introuvable.')),
      );
      return;
    }

    final conversation = await _conversationService.getOrCreateConversation(
      currentUserId: me.uid,
      otherUserId: sellerId,
    );

    if (featuredOffer != null) {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversation.conversationId)
          .set({
        'offerId': featuredOffer!.id,
        'offerTitle': featuredOffer!.title,
      }, SetOptions(merge: true));
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationThreadPage(
          conversationId: conversation.conversationId,
          offerTitle: featuredOffer?.title ?? 'Conversation',
          currentUserId: me.uid,
        ),
      ),
    );
  }

  Future<void> _callAdvertiser() async {
    final phone = featuredOffer?.phone ?? '';
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numero indisponible.')),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: normalized);
    final ok = await canLaunchUrl(uri);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de lancer l appel.')),
      );
      return;
    }

    await launchUrl(uri);
  }

  Future<void> _shareProfile() async {
    final profileText = 'Profil annonceur ilipresto: ${advertiser.name} • '
        '${advertiser.city} • ${advertiser.rating.toStringAsFixed(1)} / 5';
    await Clipboard.setData(ClipboardData(text: profileText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil copie dans le presse-papiers.')),
    );
  }

  void _reportProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signalement du profil envoye.')),
    );
  }

  void _openFeaturedOffer() {
    final offer = featuredOffer;
    if (offer == null) return;
    _openOfferDetails(offer);
  }

  void _openOfferDetails(Offer offer) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OfferDetailsPage(
          offer: offer,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const pageBg = Color(0xFFF6F8FC);
    const textPrimary = Color(0xFF101828);
    const textSecondary = Color(0xFF667085);

    return Scaffold(
      backgroundColor: pageBg,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 200,
                backgroundColor: Colors.white,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                foregroundColor: textPrimary,
                title: Text(
                  'Profil annonceur',
                  style: kPrestoAppBarTitleStyle.copyWith(color: textPrimary),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFB067),
                              Color(0xFFFF7A00),
                              Color(0xFF1E5EFF),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.10),
                              Colors.black.withOpacity(0.35),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: -20,
                        top: 40,
                        child: _ProfileBlurBubble(
                          size: 120,
                          color: Colors.white.withOpacity(0.20),
                        ),
                      ),
                      Positioned(
                        right: -30,
                        top: 70,
                        child: _ProfileBlurBubble(
                          size: 150,
                          color: Colors.white.withOpacity(0.14),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 20,
                        child: SafeArea(
                          bottom: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Hero(
                                tag: 'advertiser_avatar_${advertiser.id}',
                                child: Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.18),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFFD7B0),
                                        Color(0xFFF3B374),
                                      ],
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  alignment: Alignment.center,
                                  child: advertiser.avatarUrl.trim().isNotEmpty
                                      ? Image.network(
                                          advertiser.avatarUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          errorBuilder: (_, __, ___) => _ProfileInitialsAvatar(
                                            initials: _initials,
                                          ),
                                        )
                                      : _ProfileInitialsAvatar(initials: _initials),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                advertiser.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 6,
                                children: _topBadges
                                    .map(
                                      (label) => _ProfileTopBadge(
                                        label: label,
                                        icon: label.contains('verifie')
                                            ? Icons.verified_rounded
                                            : label.contains('ligne')
                                                ? Icons.radio_button_checked_rounded
                                                : Icons.person_outline_rounded,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -18),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                        child: _AdvertiserProfileGlassIdentityCard(
                          city: advertiser.city,
                          area: featuredOffer?.practicalInfo.serviceArea ?? 'Zone locale',
                          rating: advertiser.rating,
                          reviewsCount: advertiser.offersCount,
                          memberSinceLabel: advertiser.seniorityLabel,
                          lastSeenLabel: advertiser.isOnline
                              ? 'En ligne maintenant'
                              : advertiser.lastSeenLabel,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                        child: _AdvertiserProfileStatsRow(
                          offersCount: advertiser.offersCount,
                          rating: advertiser.rating,
                          statusLabel: advertiser.isOnline ? 'En ligne' : 'Actif',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                        child: _AdvertiserProfileActionsCard(
                          displayPhone: _displayPhone,
                          hasPhone: (featuredOffer?.phone.trim().isNotEmpty ?? false),
                          showPhone: _showPhone,
                          onTogglePhone: () => setState(() => _showPhone = !_showPhone),
                          onMessage: _startChat,
                          onCall: _callAdvertiser,
                          onShare: _shareProfile,
                          onReport: _reportProfile,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                        child: _AdvertiserProfileSectionCard(
                          title: 'A propos',
                          icon: Icons.badge_outlined,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                advertiser.bio.trim().isEmpty
                                    ? 'Cet annonceur n’a pas encore ajoute de presentation.'
                                    : advertiser.bio,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.6,
                                  color: textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (featuredOffer != null) ...[
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _AdvertiserProfileInfoChip(
                                      label: featuredOffer!.city,
                                      icon: Icons.location_on_outlined,
                                    ),
                                    _AdvertiserProfileInfoChip(
                                      label: featuredOffer!.category,
                                      icon: Icons.work_outline_rounded,
                                    ),
                                    _AdvertiserProfileInfoChip(
                                      label: featuredOffer!.practicalInfo.serviceType,
                                      icon: Icons.build_circle_outlined,
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                        child: _AdvertiserProfileSectionCard(
                          title: 'Fiabilite',
                          icon: Icons.verified_user_outlined,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _trustItems
                                .map(
                                  (label) => _AdvertiserProfileTrustPill(
                                    label: label,
                                    active: !label.contains('non verifie'),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                        child: _AdvertiserProfileSectionCard(
                          title: 'Disponibilites',
                          icon: Icons.schedule_rounded,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availabilityTags
                                .map((label) => _AdvertiserProfileAvailabilityChip(label: label))
                                .toList(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                        child: _AdvertiserProfileAdsSection(
                          ads: _advertiserOffers,
                          isLoading: _isLoadingExtraData,
                          offersCount: advertiser.offersCount,
                          onOpenAd: _openOfferDetails,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                        child: _AdvertiserProfileReviewsSection(
                          reviews: _advertiserReviews,
                          isLoading: _isLoadingExtraData,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
                        child: _AdvertiserProfileSectionCard(
                          title: 'Conseils securite',
                          icon: Icons.shield_moon_outlined,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: const Color(0xFFF8FAFD),
                              border: Border.all(color: const Color(0xFFE7ECF3)),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _AdvertiserProfileSafetyRow(
                                  text: 'Privilegiez la messagerie ilipresto pour garder une trace des echanges.',
                                ),
                                SizedBox(height: 10),
                                _AdvertiserProfileSafetyRow(
                                  text: 'Ne versez jamais d’acompte sans verification minimale du profil.',
                                ),
                                SizedBox(height: 10),
                                _AdvertiserProfileSafetyRow(
                                  text: 'Comparez la fiche, la note et les delais avant de vous engager.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: _AdvertiserProfileStickyBar(
                onMessage: _startChat,
                onCall: _callAdvertiser,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInitialsAvatar extends StatelessWidget {
  final String initials;

  const _ProfileInitialsAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: Color(0xFF5F2E00),
        ),
      ),
    );
  }
}

class _AdvertiserProfileGlassIdentityCard extends StatelessWidget {
  final String city;
  final String area;
  final double rating;
  final int reviewsCount;
  final String memberSinceLabel;
  final String lastSeenLabel;

  const _AdvertiserProfileGlassIdentityCard({
    required this.city,
    required this.area,
    required this.rating,
    required this.reviewsCount,
    required this.memberSinceLabel,
    required this.lastSeenLabel,
  });

  @override
  Widget build(BuildContext context) {
    const textPrimary = Color(0xFF101828);
    const textSecondary = Color(0xFF667085);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white.withOpacity(0.86),
            border: Border.all(color: Colors.white.withOpacity(0.90)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 18, color: textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$city • $area',
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (rating > 0)
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 18),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          ' ($reviewsCount)',
                          style: const TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _AdvertiserProfileMiniMetaTile(
                      icon: Icons.calendar_month_outlined,
                      label: memberSinceLabel,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AdvertiserProfileMiniMetaTile(
                      icon: Icons.radio_button_checked_rounded,
                      label: lastSeenLabel,
                      accent: const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvertiserProfileStatsRow extends StatelessWidget {
  final int offersCount;
  final double rating;
  final String statusLabel;

  const _AdvertiserProfileStatsRow({
    required this.offersCount,
    required this.rating,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AdvertiserProfileStatCard(
            value: offersCount.toString(),
            label: 'Annonces',
            icon: Icons.campaign_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AdvertiserProfileStatCard(
            value: rating > 0 ? rating.toStringAsFixed(1) : '-',
            label: 'Note moyenne',
            icon: Icons.star_outline_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AdvertiserProfileStatCard(
            value: statusLabel,
            label: 'Presence',
            icon: Icons.bolt_rounded,
          ),
        ),
      ],
    );
  }
}

class _AdvertiserProfileActionsCard extends StatelessWidget {
  final String displayPhone;
  final bool hasPhone;
  final bool showPhone;
  final VoidCallback onTogglePhone;
  final Future<void> Function() onMessage;
  final Future<void> Function() onCall;
  final Future<void> Function() onShare;
  final VoidCallback onReport;

  const _AdvertiserProfileActionsCard({
    required this.displayPhone,
    required this.hasPhone,
    required this.showPhone,
    required this.onTogglePhone,
    required this.onMessage,
    required this.onCall,
    required this.onShare,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFE7ECF3);
    const textPrimary = Color(0xFF101828);
    const textSecondary = Color(0xFF667085);

    return _AdvertiserProfileSectionCard(
      title: 'Actions rapides',
      icon: Icons.flash_on_outlined,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _AdvertiserProfilePrimaryButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Envoyer un message',
                  onTap: onMessage,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AdvertiserProfileSecondaryButton(
                  icon: Icons.call_outlined,
                  label: 'Appeler',
                  onTap: hasPhone ? onCall : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFFF9FBFD),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFFFFF1E6),
                  ),
                  child: const Icon(
                    Icons.phone_iphone_rounded,
                    color: Color(0xFFFF7A00),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Numero de telephone',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayPhone,
                        style: const TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: hasPhone ? onTogglePhone : null,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: borderColor),
                  ),
                  icon: Icon(
                    showPhone ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AdvertiserProfileMiniActionTile(
                  icon: Icons.ios_share_rounded,
                  label: 'Partager',
                  onTap: onShare,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AdvertiserProfileMiniActionTile(
                  icon: Icons.flag_outlined,
                  label: 'Signaler',
                  onTap: () async => onReport(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdvertiserProfileAdsSection extends StatelessWidget {
  final List<Offer> ads;
  final bool isLoading;
  final int offersCount;
  final ValueChanged<Offer> onOpenAd;

  const _AdvertiserProfileAdsSection({
    required this.ads,
    required this.isLoading,
    required this.offersCount,
    required this.onOpenAd,
  });

  @override
  Widget build(BuildContext context) {
    final hasAds = ads.isNotEmpty;

    return _AdvertiserProfileSectionCard(
      title: 'Annonces publiees',
      icon: Icons.grid_view_rounded,
      trailing: TextButton(
        onPressed: hasAds ? () => onOpenAd(ads.first) : null,
        child: const Text('Voir tout'),
      ),
      child: isLoading
          ? const _SkeletonBox(height: 120, radius: 18)
          : !hasAds
          ? const Text(
              'Aucune annonce detaillee disponible pour le moment.',
              style: TextStyle(
                color: Color(0xFF667085),
                fontWeight: FontWeight.w600,
              ),
            )
          : Column(
              children: [
                for (final ad in ads.take(4)) ...[
                  _AdvertiserProfileAdCard(
                    offer: ad,
                    offersCount: offersCount,
                    onTap: () => onOpenAd(ad),
                  ),
                  if (ad != ads.take(4).last) const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _AdvertiserProfileReviewsSection extends StatelessWidget {
  final List<_AdvertiserReviewData> reviews;
  final bool isLoading;

  const _AdvertiserProfileReviewsSection({
    required this.reviews,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final average = reviews.isEmpty
        ? 0.0
        : reviews.map((e) => e.rating).reduce((a, b) => a + b) / reviews.length;

    return _AdvertiserProfileSectionCard(
      title: 'Avis clients',
      icon: Icons.reviews_outlined,
      child: isLoading
          ? const _SkeletonBox(height: 140, radius: 18)
          : reviews.isEmpty
              ? const Text(
                  'Aucun avis pour le moment.',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: const Color(0xFFF9FBFD),
                        border: Border.all(color: const Color(0xFFE7ECF3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: const Color(0xFFFFF4D8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              average.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF7A4A00),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${reviews.length} avis client${reviews.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                color: Color(0xFF101828),
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final review in reviews.take(6)) ...[
                      _AdvertiserProfileReviewCard(review: review),
                      if (review != reviews.take(6).last) const SizedBox(height: 12),
                    ],
                  ],
                ),
    );
  }
}

class _AdvertiserProfileStickyBar extends StatelessWidget {
  final Future<void> Function() onMessage;
  final Future<void> Function() onCall;

  const _AdvertiserProfileStickyBar({
    required this.onMessage,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withOpacity(0.96),
        border: Border.all(color: const Color(0xFFE7ECF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onMessage,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Envoyer un message',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  foregroundColor: Colors.white,
                  backgroundColor: kPrestoOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onCall,
                icon: const Icon(Icons.call_outlined, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Appeler',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  foregroundColor: Colors.white,
                  backgroundColor: kPrestoBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvertiserProfileSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _AdvertiserProfileSectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE7ECF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF0E1), Color(0xFFEAF1FF)],
                  ),
                ),
                child: Icon(icon, color: const Color(0xFF101828), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _AdvertiserProfileAdCard extends StatelessWidget {
  final Offer offer;
  final int offersCount;
  final VoidCallback onTap;

  const _AdvertiserProfileAdCard({
    required this.offer,
    required this.offersCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusLabel = offer.statusBadges.isNotEmpty ? offer.statusBadges.first : 'Active';
    final budgetLabel = offer.price > 0 ? '${offer.price.toStringAsFixed(0)} €' : 'Sur devis';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xFFFDFEFF),
          border: Border.all(color: const Color(0xFFE7ECF3)),
        ),
        child: Row(
          children: [
            Container(
              width: 92,
              height: 106,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFD3AF), Color(0xFFFFA254)],
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: offer.imageUrls.isNotEmpty
                  ? Image.network(
                      offer.imageUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildAdFallback(),
                    )
                  : _buildAdFallback(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 106,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            offer.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF101828),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: kPrestoOrange.withOpacity(0.10),
                          ),
                          child: Text(
                            statusLabel,
                            style: const TextStyle(
                              color: kPrestoOrange,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      offer.shortDescription.isNotEmpty ? offer.shortDescription : offer.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _AdvertiserProfileTinyMetaPill(
                          icon: Icons.work_outline_rounded,
                          label: offer.category,
                        ),
                        _AdvertiserProfileTinyMetaPill(
                          icon: Icons.location_on_outlined,
                          label: offer.city,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          budgetLabel,
                          style: const TextStyle(
                            color: kPrestoOrange,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        _AdvertiserProfileInlineInfo(
                          icon: Icons.campaign_outlined,
                          text: '$offersCount',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdFallback() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.work_outline_rounded, color: Colors.white, size: 24),
        ),
        Spacer(),
        Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'ilipresto',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _AdvertiserProfileReviewCard extends StatelessWidget {
  final _AdvertiserReviewData review;

  const _AdvertiserProfileReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFFDFEFF),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFEAF1FF), Color(0xFFFFF0E1)],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  review.authorInitials,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF101828),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.authorName,
                      style: const TextStyle(
                        color: Color(0xFF101828),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (index) => Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Icon(
                              index < review.rating.round()
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: const Color(0xFFFFB800),
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            review.dateLabel,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.relatedMission.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFEAFBF0),
                ),
                child: Text(
                  'Mission • ${review.relatedMission}',
                  style: const TextStyle(
                    color: Color(0xFF15803D),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            review.comment,
            style: const TextStyle(
              color: Color(0xFF344054),
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvertiserReviewData {
  final String id;
  final String authorName;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final String relatedMission;

  const _AdvertiserReviewData({
    required this.id,
    required this.authorName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.relatedMission,
  });

  String get authorInitials {
    final parts = authorName
        .replaceAll('.', ' ')
        .split(' ')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      final p = parts.first;
      return p.substring(0, p.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get dateLabel {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    return '$day/$month/${createdAt.year}';
  }

  factory _AdvertiserReviewData.fromMap(String id, Map<String, dynamic> data) {
    final createdAtRaw = data['createdAt'] ?? data['date'] ?? data['updatedAt'];
    DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else {
      createdAt = DateTime.now();
    }

    return _AdvertiserReviewData(
      id: id,
      authorName: (data['authorName'] ?? data['author'] ?? 'Utilisateur').toString(),
      rating: (data['rating'] as num?)?.toDouble() ?? 5,
      comment: (data['comment'] ?? data['text'] ?? '').toString().trim().isEmpty
          ? 'Avis utilisateur'
          : (data['comment'] ?? data['text']).toString(),
      createdAt: createdAt,
      relatedMission: (data['relatedMission'] ?? data['offerTitle'] ?? '').toString(),
    );
  }
}

class _AdvertiserProfileStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _AdvertiserProfileStatCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE7ECF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFF4F7FD),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF101828)),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF101828),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvertiserProfilePrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
  final bool compact;

  const _AdvertiserProfilePrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 48 : 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: compact ? 18 : 20),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 13 : 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: Colors.white,
          backgroundColor: kPrestoOrange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compact ? 16 : 18),
          ),
        ),
      ),
    );
  }
}

class _AdvertiserProfileSecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<void> Function()? onTap;
  final bool compact;

  const _AdvertiserProfileSecondaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 48 : 54,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: compact ? 18 : 20),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 13 : 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFD9E2F0)),
          foregroundColor: const Color(0xFF1E5EFF),
          backgroundColor: const Color(0xFFF8FAFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compact ? 16 : 18),
          ),
        ),
      ),
    );
  }
}

class _AdvertiserProfileGhostButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AdvertiserProfileGhostButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE1E8F2)),
          foregroundColor: const Color(0xFF101828),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }
}

class _AdvertiserProfileMiniActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  const _AdvertiserProfileMiniActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE7ECF3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF101828)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF101828),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTopBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const _ProfileTopBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.18),
        border: Border.all(color: Colors.white.withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvertiserProfileInfoChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _AdvertiserProfileInfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFFF7FAFC),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF667085)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF344054),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvertiserProfileTrustPill extends StatelessWidget {
  final String label;
  final bool active;

  const _AdvertiserProfileTrustPill({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final bg = active ? const Color(0xFFEFF8F2) : const Color(0xFFF7F8FA);
    final fg = active ? const Color(0xFF15803D) : const Color(0xFF667085);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AdvertiserProfileAvailabilityChip extends StatelessWidget {
  final String label;

  const _AdvertiserProfileAvailabilityChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF1E6), Color(0xFFEAF1FF)],
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF101828),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AdvertiserProfileTinyMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AdvertiserProfileTinyMetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFFF5F8FC),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF667085)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvertiserProfileInlineInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _AdvertiserProfileInlineInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF98A2B3)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF98A2B3),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AdvertiserProfileMiniMetaTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _AdvertiserProfileMiniMetaTile({
    required this.icon,
    required this.label,
    this.accent = const Color(0xFF667085),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF8FAFD),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF344054),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvertiserProfileSafetyRow extends StatelessWidget {
  final String text;

  const _AdvertiserProfileSafetyRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFEAF1FF),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 14,
            color: Color(0xFF1E5EFF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF344054),
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileBlurBubble extends StatelessWidget {
  final double size;
  final Color color;

  const _ProfileBlurBubble({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

enum OfferActionType {
  contact,
  booking,
}

class Offer {
  final String id;
  final String title;
  final double price;
  final String category;
  final String city;
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

  Offer copyWith({
    String? id,
    String? title,
    double? price,
    String? category,
    String? city,
    String? publishedAtLabel,
    String? availability,
    String? shortDescription,
    String? description,
    String? phone,
    List<String>? imageUrls,
    List<String>? statusBadges,
    PracticalInfo? practicalInfo,
    Advertiser? advertiser,
    OfferActionType? actionType,
    List<Offer>? similarOffers,
  }) {
    return Offer(
      id: id ?? this.id,
      title: title ?? this.title,
      price: price ?? this.price,
      category: category ?? this.category,
      city: city ?? this.city,
      publishedAtLabel: publishedAtLabel ?? this.publishedAtLabel,
      availability: availability ?? this.availability,
      shortDescription: shortDescription ?? this.shortDescription,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      imageUrls: imageUrls ?? this.imageUrls,
      statusBadges: statusBadges ?? this.statusBadges,
      practicalInfo: practicalInfo ?? this.practicalInfo,
      advertiser: advertiser ?? this.advertiser,
      actionType: actionType ?? this.actionType,
      similarOffers: similarOffers ?? this.similarOffers,
    );
  }

  factory Offer.fromMap(Map<String, dynamic> map) {
    return Offer(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? 'Annonce').toString(),
      price: (map['price'] as num?)?.toDouble() ?? 0,
      category: (map['category'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      publishedAtLabel: (map['publishedAtLabel'] ?? '').toString(),
      availability: (map['availability'] ?? '').toString(),
      shortDescription: (map['shortDescription'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      imageUrls: (map['imageUrls'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      statusBadges: (map['statusBadges'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      practicalInfo: PracticalInfo.fromMap(
        (map['practicalInfo'] as Map<String, dynamic>? ?? const {}),
      ),
      advertiser: Advertiser.fromMap(
        (map['advertiser'] as Map<String, dynamic>? ?? const {}),
      ),
      actionType: (map['actionType'] == 'booking')
          ? OfferActionType.booking
          : OfferActionType.contact,
      similarOffers: const [],
    );
  }

  factory Offer.mock() {
    final advertiser = Advertiser.mock();

    final similar1 = Offer._mini(
      id: 'OFF-992',
      title: 'Montage meuble IKEA en 24h',
      city: 'Toulouse',
      price: 65,
      imageUrl:
          'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=900&q=80',
      advertiser: advertiser,
    );

    final similar2 = Offer._mini(
      id: 'OFF-913',
      title: 'Nettoyage de jardin + evacuation',
      city: 'Blagnac',
      price: 90,
      imageUrl:
          'https://images.unsplash.com/photo-1466692476868-aef1dfb1e735?auto=format&fit=crop&w=900&q=80',
      advertiser: advertiser,
    );

    final similar3 = Offer._mini(
      id: 'OFF-741',
      title: 'Peinture salon 25m2',
      city: 'Colomiers',
      price: 220,
      imageUrl:
          'https://images.unsplash.com/photo-1562259949-e8e7689d7828?auto=format&fit=crop&w=900&q=80',
      advertiser: advertiser,
    );

    return Offer(
      id: 'OFF-31842',
      title: 'Debroussaillage complet + evacuation des dechets verts',
      price: 120,
      category: 'Jardinage',
      city: 'Montauban',
      publishedAtLabel: 'Publiee il y a 2 heures',
      availability: 'Disponible demain matin',
      shortDescription:
          'Intervention rapide pour remettre un jardin propre en demi-journee.',
      description:
          'Je cherche un prestataire equipe pour debroussailler un terrain de 650m2, '
          'avec evacuation des dechets verts comprise. Acces facile, stationnement devant '
          'la maison, et eau disponible sur place. Priorite a une intervention rapide '
          'avant la fin de semaine. Merci de preciser votre delai et votre experience.',
      phone: '06 73 12 48 45',
      imageUrls: const [
        'https://images.unsplash.com/photo-1466692476868-aef1dfb1e735?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1560749003-f4b1e17e2f0d?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1598902108854-10e335adac99?auto=format&fit=crop&w=1200&q=80',
      ],
      statusBadges: const ['Disponible', 'Urgent', 'Verifie', 'Nouveau'],
      practicalInfo: const PracticalInfo(
        category: 'Jardinage / Exterieur',
        serviceArea: 'Montauban + 20 km',
        canTravel: true,
        schedule: 'Lundi au samedi, 08:00 - 18:30',
        averageDelay: 'Intervention en 24h',
        paymentMethod: 'Especes, virement, Lydia',
        serviceType: 'Prestation ponctuelle',
      ),
      advertiser: advertiser,
      actionType: OfferActionType.contact,
      similarOffers: [similar1, similar2, similar3],
    );
  }

  factory Offer._mini({
    required String id,
    required String title,
    required String city,
    required double price,
    required String imageUrl,
    required Advertiser advertiser,
  }) {
    return Offer(
      id: id,
      title: title,
      price: price,
      category: 'Service',
      city: city,
      publishedAtLabel: 'Recente',
      availability: 'A definir',
      shortDescription: 'Annonce similaire',
      description: '',
      phone: '06 00 00 00 00',
      imageUrls: [imageUrl],
      statusBadges: const ['Disponible'],
      practicalInfo: const PracticalInfo(
        category: 'Service',
        serviceArea: 'Locale',
        canTravel: true,
        schedule: 'Flexible',
        averageDelay: 'Rapide',
        paymentMethod: 'A convenir',
        serviceType: 'Ponctuelle',
      ),
      advertiser: advertiser,
      actionType: OfferActionType.contact,
      similarOffers: const [],
    );
  }
}

class Advertiser {
  final String id;
  final String name;
  final bool verified;
  final double rating;
  final int offersCount;
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
    required this.seniorityLabel,
    required this.city,
    required this.bio,
    required this.avatarUrl,
    required this.isOnline,
    required this.lastSeenLabel,
  });

  Advertiser copyWith({
    String? id,
    String? name,
    bool? verified,
    double? rating,
    int? offersCount,
    String? seniorityLabel,
    String? city,
    String? bio,
    String? avatarUrl,
    bool? isOnline,
    String? lastSeenLabel,
  }) {
    return Advertiser(
      id: id ?? this.id,
      name: name ?? this.name,
      verified: verified ?? this.verified,
      rating: rating ?? this.rating,
      offersCount: offersCount ?? this.offersCount,
      seniorityLabel: seniorityLabel ?? this.seniorityLabel,
      city: city ?? this.city,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      lastSeenLabel: lastSeenLabel ?? this.lastSeenLabel,
    );
  }

  factory Advertiser.fromMap(Map<String, dynamic> map) {
    return Advertiser(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? 'Annonceur').toString(),
      verified: (map['verified'] as bool?) ?? false,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      offersCount: (map['offersCount'] as num?)?.toInt() ?? 0,
      seniorityLabel: (map['seniorityLabel'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      bio: (map['bio'] ?? '').toString(),
      avatarUrl: (map['avatarUrl'] ?? '').toString(),
      isOnline: (map['isOnline'] as bool?) ?? false,
      lastSeenLabel: (map['lastSeenLabel'] ?? 'Activite recente').toString(),
    );
  }

  factory Advertiser.mock() {
    return const Advertiser(
      id: 'seller_4302',
      name: 'Lucas M.',
      verified: true,
      rating: 4.8,
      offersCount: 37,
      seniorityLabel: 'Membre depuis 2021',
      city: 'Montauban',
      bio:
          'Entrepreneur polyvalent, specialise exterieur et petits travaux. '
          'Interventions rapides, ponctuelles, et materiel pro.',
      avatarUrl:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
      isOnline: true,
      lastSeenLabel: 'Actif a l\'instant',
    );
  }
}

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

  factory PracticalInfo.fromMap(Map<String, dynamic> map) {
    return PracticalInfo(
      category: (map['category'] ?? '').toString(),
      serviceArea: (map['serviceArea'] ?? '').toString(),
      canTravel: (map['canTravel'] as bool?) ?? false,
      schedule: (map['schedule'] ?? '').toString(),
      averageDelay: (map['averageDelay'] ?? '').toString(),
      paymentMethod: (map['paymentMethod'] ?? '').toString(),
      serviceType: (map['serviceType'] ?? '').toString(),
    );
  }
}

class ConversationDraft {
  final String conversationId;
  final String offerId;
  final String sellerId;
  final String buyerId;
  final DateTime createdAt;

  const ConversationDraft({
    required this.conversationId,
    required this.offerId,
    required this.sellerId,
    required this.buyerId,
    required this.createdAt,
  });
}

ConversationDraft startConversation({
  required String offerId,
  required String sellerId,
  required String buyerId,
}) {
  final now = DateTime.now();
  final convoId = 'conv_${offerId}_$sellerId\_$buyerId';

  return ConversationDraft(
    conversationId: convoId,
    offerId: offerId,
    sellerId: sellerId,
    buyerId: buyerId,
    createdAt: now,
  );
}

String _normalizePhone(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';

  if (trimmed.startsWith('+')) {
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? trimmed : '+$digits';
  }

  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10 && digits.startsWith('0')) {
    return '+33${digits.substring(1)}';
  }

  return digits;
}

String _maskPhoneForDisplay(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 2) return '** ** ** ** **';
  final tail = digits.substring(digits.length - 2);
  return '06 ** ** ** $tail';
}
