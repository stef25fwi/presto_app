import 'dart:async';

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
        builder: (_) => AdvertiserProfilePage(advertiser: offer.advertiser),
      ),
    );
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

  Future<void> _shareOffer() async {
    final deepLink =
        'https://presto-app-74abe.web.app/offers/${widget.offer.id}';
    await Clipboard.setData(ClipboardData(text: deepLink));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lien de l annonce copie. Pret a partager.'),
      ),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        leading: const BackButton(),
        title: const Text(
          'Details de l offre',
          style: kPrestoAppBarTitleStyle,
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: _isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
            onPressed: () => setState(() => _isFavorite = !_isFavorite),
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
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GalleryCard(
                    pageController: _galleryController,
                    imageUrls: offer.imageUrls,
                    currentIndex: _currentImageIndex,
                    onPageChanged: (v) => setState(() => _currentImageIndex = v),
                    badges: offer.statusBadges,
                    heroTag: 'offer-image-${offer.id}',
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 14),
                  _MainInfoCard(offer: offer, isLoading: _isLoading),
                  const SizedBox(height: 14),
                  _PracticalInfoCard(
                    isLoading: _isLoading,
                    practicalInfo: offer.practicalInfo,
                  ),
                  const SizedBox(height: 14),
                  _ContactAdvertiserCard(
                    isLoading: _isLoading,
                    advertiser: offer.advertiser,
                    displayPhone: _phoneVisible
                        ? offer.phone
                        : _maskPhoneForDisplay(offer.phone),
                    phoneVisible: _phoneVisible,
                    onTogglePhone: _togglePhoneVisibility,
                    onCall: _callSeller,
                    onCopy: _copyPhone,
                    onMessage: _startChat,
                    onOpenProfile: _openAdvertiserProfile,
                  ),
                  const SizedBox(height: 16),
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
      return const _SkeletonBox(height: 250, radius: 20);
    }

    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
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
      return const _SkeletonBox(height: 188, radius: 18);
    }

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            offer.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${offer.price.toStringAsFixed(0)} €',
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              color: kPrestoOrange,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetaPill(icon: Icons.category_outlined, text: offer.category),
              _MetaPill(icon: Icons.location_on_outlined, text: offer.city),
              _MetaPill(icon: Icons.event_outlined, text: offer.publishedAtLabel),
              _MetaPill(icon: Icons.fingerprint, text: 'ID ${offer.id}'),
              _MetaPill(icon: Icons.schedule, text: offer.availability),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            offer.shortDescription,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4B5563),
              height: 1.4,
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
      return const _SkeletonBox(height: 270, radius: 18);
    }

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations pratiques',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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
  final Future<void> Function() onCall;
  final Future<void> Function() onCopy;
  final Future<void> Function() onMessage;
  final VoidCallback onOpenProfile;

  const _ContactAdvertiserCard({
    required this.isLoading,
    required this.advertiser,
    required this.displayPhone,
    required this.phoneVisible,
    required this.onTogglePhone,
    required this.onCall,
    required this.onCopy,
    required this.onMessage,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _SkeletonBox(height: 260, radius: 18);
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
                                fontSize: 17,
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
            ],
          ),
          const SizedBox(height: 10),
          Text(
            advertiser.bio.isEmpty
                ? 'Annonceur sans bio pour le moment.'
                : advertiser.bio,
            style: const TextStyle(height: 1.4, color: Color(0xFF374151)),
          ),
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onMessage,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Envoyer un message'),
              ),
              OutlinedButton.icon(
                onPressed: onCall,
                icon: const Icon(Icons.call_outlined),
                label: const Text('Appeler'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenProfile,
                icon: const Icon(Icons.person_outline),
                label: const Text('Voir le profil'),
              ),
            ],
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
                        label: const Text('Envoyer un message'),
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
                        label: const Text('Appeler'),
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
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Proposer mes services'),
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
        borderRadius: BorderRadius.circular(18),
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

  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: kPrestoBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF4B5563)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF27364A),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
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

class AdvertiserProfilePage extends StatelessWidget {
  final Advertiser advertiser;

  const AdvertiserProfilePage({
    super.key,
    required this.advertiser,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil annonceur')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AdvertiserAvatar(avatarUrl: advertiser.avatarUrl, radius: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    advertiser.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Ville: ${advertiser.city}'),
            Text('Anciennete: ${advertiser.seniorityLabel}'),
            Text('Note: ${advertiser.rating.toStringAsFixed(1)} / 5'),
            const SizedBox(height: 10),
            Text(advertiser.bio),
          ],
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
