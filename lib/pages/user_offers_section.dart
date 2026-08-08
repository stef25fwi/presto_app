import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../app/presto_overlay_theme.dart';
import '../app_core.dart';
import '../data/marketplace/favorite_repository.dart';
import '../features/trust_score/trust_score_models.dart';
import '../features/trust_score/trust_score_service.dart';
import '../features/trust_score/trust_score_widgets.dart';
import '../pages/offers/offer_details_page.dart';
import '../services/firebase_functions_region.dart';
import '../services/offer_indexing.dart';
import '../utils/friendly_snackbar.dart';
import '../utils/offer_helpers.dart';
import '../utils/runtime_action_logger.dart';
import '../services/public_offers_query_helpers.dart';
import '../widgets/offer_network_image.dart';
import '../widgets/phone_input_field.dart';
import '../app/app_runtime_config.dart' show kOfferDeleteReasonFoundOnIliPresto;
import '../services/offer_details_mapper.dart' show buildOfferDetailsOffer;

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
  static final FavoriteRepository _favoriteRepository = FavoriteRepository();
  static const String _kFavoriteLoadErrorMessage =
      'Impossible de charger vos favoris pour le moment. Reessayez dans quelques instants.';

  List<_FavoriteOfferItem> _offers = const [];
  bool _isLoading = true;
  String? _error;
  String? _selectedOfferId;
  StreamSubscription<Set<String>>? _favoritesSubscription;

  bool _isPermissionDeniedError(Object error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied';
    }

    final text = error.toString().toLowerCase();
    return text.contains('permission-denied') ||
        text.contains('permission denied');
  }

  void _debugFavoriteLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  @override
  void initState() {
    super.initState();
    _bindFavoritesWatcher();
    _loadFavorites();
  }

  @override
  void didUpdateWidget(covariant FavoriteOffersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId == widget.userId) {
      return;
    }
    _bindFavoritesWatcher();
    _loadFavorites();
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    super.dispose();
  }

  void _bindFavoritesWatcher() {
    _favoritesSubscription?.cancel();
    final userId = widget.userId.trim();
    if (userId.isEmpty) {
      _favoritesSubscription = null;
      return;
    }

    _favoritesSubscription =
        _favoriteRepository.watchFavoriteListingIds(userId).listen((_) {
      if (!mounted) return;
      _loadFavorites();
    });
  }

  Future<void> _loadFavorites() async {
    final userId = widget.userId.trim();
    if (userId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _offers = const [];
        _isLoading = false;
        _error = null;
        _selectedOfferId = null;
      });
      return;
    }

    try {
      final fs = FirebaseFirestore.instance;
      _debugFavoriteLog('[Favorites] uid: $userId');
      final favorites = await _favoriteRepository
          .loadFavoriteListingIdsWithLegacyFallback(userId);
      final favoriteIds = favorites.listingIds;
      final favoriteDates = favorites.favoriteDates;
      _debugFavoriteLog(
        '[Favorites] favoriteIds count: ${favoriteIds.length}',
      );

      if (favoriteIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _offers = const [];
          _isLoading = false;
          _error = null;
          _selectedOfferId = null;
        });
        return;
      }

      final orphanFavoriteIds = <String>[];
      final results = await Future.wait(
        favoriteIds.map(
          (id) => _loadFavoriteOfferItem(
            fs,
            offerId: id,
            addedAt: favoriteDates[id],
          ),
        ),
      );
      final items = <_FavoriteOfferItem>[];
      for (var i = 0; i < favoriteIds.length; i++) {
        final item = results[i];
        if (item == null) {
          orphanFavoriteIds.add(favoriteIds[i]);
          continue;
        }
        items.add(item);
      }

      for (final orphanFavoriteId in orphanFavoriteIds) {
        unawaited(_favoriteRepository.removeFavorite(userId, orphanFavoriteId));
      }

      _debugFavoriteLog('[Favorites] loaded offers count: ${items.length}');

      if (!mounted) return;
      setState(() {
        _offers = items;
        _isLoading = false;
        _error = null;

        final ids = items.map((item) => item.offerId).toSet();
        if (_selectedOfferId == null || !ids.contains(_selectedOfferId)) {
          _selectedOfferId = items.isNotEmpty ? items.first.offerId : null;
        }
      });
    } catch (error) {
      _debugFavoriteLog('[Favorites] error: $error');
      if (!mounted) return;
      setState(() {
        _error = _kFavoriteLoadErrorMessage;
        _isLoading = false;
      });
    }
  }

  Future<_FavoriteOfferItem?> _loadFavoriteOfferItem(
    FirebaseFirestore firestore, {
    required String offerId,
    required Timestamp? addedAt,
  }) async {
    final normalizedOfferId = offerId.trim();
    if (normalizedOfferId.isEmpty) {
      return null;
    }

    for (final collectionName in const <String>[
      kListingsCollection,
      'offers'
    ]) {
      try {
        final snapshot = await firestore
            .collection(collectionName)
            .doc(normalizedOfferId)
            .get();
        if (!snapshot.exists) {
          continue;
        }

        final data = snapshot.data() ?? const <String, dynamic>{};
        final isMarketplace = collectionName == kListingsCollection;
        final status = (data['status'] ?? '').toString().trim().toLowerCase();
        final visibility =
            (data['visibility'] ?? '').toString().trim().toLowerCase();

        if (isMarketplace && (status != 'active' || visibility != 'public')) {
          return null;
        }

        return _FavoriteOfferItem(
          offerId: snapshot.id,
          title: (data['title'] ?? 'Sans titre').toString().trim(),
          city: (data['location'] ?? data['city'] ?? 'Lieu non précisé')
              .toString()
              .trim(),
          category:
              (data['category'] ?? 'Catégorie non précisée').toString().trim(),
          price: (data['budget'] as num?)?.toDouble(),
          imageUrl: _primaryOfferImageUrl(data),
          addedAt: addedAt,
          rawData: data,
          isMarketplace: isMarketplace,
        );
      } catch (error) {
        if (_isPermissionDeniedError(error)) {
          continue;
        }
        _debugFavoriteLog(
          '[Favorites] load offer failed offerId=$normalizedOfferId collection=$collectionName error: $error',
        );
        return null;
      }
    }

    return null;
  }

  Future<void> _removeFavorite(String offerId) async {
    logRuntimeAction(
      area: 'favorites',
      action: 'remove-start',
      details: <String, Object?>{
        'offerId': offerId,
        'userId': widget.userId,
        'isMarketplace': _offers
            .where((o) => o.offerId == offerId)
            .firstOrNull
            ?.isMarketplace,
      },
    );
    try {
      await _favoriteRepository.removeFavorite(widget.userId, offerId);

      if (!mounted) return;
      showSuccessSnackBar(context, 'Annonce retirée des favoris');
      logRuntimeAction(
        area: 'favorites',
        action: 'remove-success',
        details: <String, Object?>{'offerId': offerId},
      );
      await _loadFavorites();
    } catch (e) {
      logRuntimeAction(
        area: 'favorites',
        action: 'remove-failure',
        details: <String, Object?>{
          'offerId': offerId,
          'errorType': e.runtimeType,
          'message': e,
        },
      );
      if (!mounted) return;
      showErrorSnackBar(
        context,
        'Impossible de retirer ce favori pour le moment.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.userId.trim();
    if (userId.isEmpty) {
      return _buildFavoriteInfoCard(
        icon: Icons.favorite_border_rounded,
        message: 'Connectez-vous pour voir vos favoris.',
      );
    }

    if (_isLoading) {
      return _buildFavoriteLoadingCard();
    }

    if (_error != null) {
      return _buildFavoriteErrorCard();
    }

    final docs = _offers;
    if (docs.isEmpty) {
      return _buildFavoriteInfoCard(
        icon: Icons.favorite_border_rounded,
        message: 'Vous n’avez pas encore ajoute d’annonces favorites.',
      );
    }

    final selectedId = _selectedOfferId;
    final selectedDoc = (selectedId == null)
        ? docs.first
        : docs.where((doc) => doc.offerId == selectedId).isNotEmpty
            ? docs.firstWhere((doc) => doc.offerId == selectedId)
            : docs.first;

    final selectedData = selectedDoc.rawData;
    final selectedTitle = selectedDoc.title;
    final selectedLocation = selectedDoc.city;
    final selectedCategory = selectedDoc.category;
    final selectedBudget = selectedDoc.price;

    String subtitle = '$selectedLocation · $selectedCategory';
    if (selectedBudget != null) {
      subtitle += ' · ${selectedBudget.toStringAsFixed(0)} €';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTitle) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mes annonces favorites',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Actualiser',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  unawaited(_loadFavorites());
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kPrestoOrange.withValues(alpha: 0.10),
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
                      ? SizedBox(
                          width: 72,
                          height: 72,
                          child: OfferNetworkImage(
                            url: selectedDoc.imageUrl,
                            fit: BoxFit.cover,
                            cacheWidth: 240,
                            errorChild: _buildFavoritePlaceholder(),
                            loadingChild: _buildFavoritePlaceholder(),
                          ),
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
                        offer: buildOfferDetailsOffer(
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

  Widget _buildFavoriteLoadingCard() {
    return Container(
      constraints: const BoxConstraints(minHeight: 112, maxHeight: 140),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
        ),
      ),
    );
  }

  Widget _buildFavoritePlaceholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        color: Colors.black38,
      ),
    );
  }

  Widget _buildFavoriteErrorCard() {
    return Container(
      constraints: const BoxConstraints(minHeight: 132, maxHeight: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1C0C0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Row(
            children: [
              Icon(Icons.favorite_border_rounded, color: Color(0xFFD14343)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mes annonces favorites',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _error ?? _kFavoriteLoadErrorMessage,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8A1F1F),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  unawaited(_loadFavorites());
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteInfoCard({
    required IconData icon,
    required String message,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112, maxHeight: 140),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDF1),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: const Color(0xFFE53935)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _primaryOfferImageUrl(Map<String, dynamic> data) {
    final thumbnailUrl = (data['thumbnailUrl'] ?? '').toString().trim();
    if (thumbnailUrl.isNotEmpty) return thumbnailUrl;

    final imageUrl = (data['imageUrl'] ?? '').toString().trim();
    if (imageUrl.isNotEmpty) return imageUrl;

    final imageUrls = data['imageUrls'];
    if (imageUrls is List) {
      for (final entry in imageUrls) {
        final value = entry.toString().trim();
        if (value.isNotEmpty) return value;
      }
    }

    final media = data['media'];
    if (media is List) {
      for (final entry in media) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry.cast<dynamic, dynamic>());
        final candidate = ((map['thumbnailUrl'] ?? map['downloadUrl']) ?? '')
            .toString()
            .trim();
        if (candidate.isNotEmpty) return candidate;
      }
    }

    return '';
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
  // true = annonce dans la collection 'listings' (marketplace)
  final bool isMarketplace;

  const _FavoriteOfferItem({
    required this.offerId,
    required this.title,
    required this.city,
    required this.category,
    required this.price,
    required this.imageUrl,
    required this.addedAt,
    required this.rawData,
    this.isMarketplace = false,
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
  final TrustScoreService _trustScoreService = TrustScoreService();

  Set<String> _knownPublishedIds = {};
  bool _initialLoadDone = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _offersStream;

  void _logUserOffersLoad(
    String action, {
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    logRuntimeAction(
      area: 'user_offers',
      action: 'load.$action',
      details: details,
    );
  }

  bool _isPermissionDeniedError(Object error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied';
    }

    final text = error.toString().toLowerCase();
    return text.contains('permission-denied') ||
        text.contains('permission denied');
  }

  bool _isOfferPublished(Map<String, dynamic> data) {
    if (isOfferArchivedLike(data)) return false;

    final isPublished = data['isPublished'];
    if (isPublished is bool && isPublished) return true;

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
    return isOfferArchivedLike(data);
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

  int? _offerPendingCountdownSeconds(Map<String, dynamic> data) {
    if (!_isOfferPending(data)) {
      return null;
    }

    final submittedAt = _dateFromDynamic(
      data['submittedAt'] ?? data['updatedAt'] ?? data['createdAt'],
    );
    if (submittedAt == null) {
      return null;
    }

    final elapsed = DateTime.now().difference(submittedAt).inSeconds;
    if (elapsed < 0 || elapsed >= 30) {
      return null;
    }

    return 30 - elapsed;
  }

  String? _offerPendingPhotoNotice(Map<String, dynamic> data) {
    if (!_isOfferPending(data) || !_offerHasPhotos(data)) {
      return null;
    }
    final moderationStatus =
        (data['moderationStatus'] ?? '').toString().trim().toLowerCase();
    final pendingHumanReviewCount = (data['pendingHumanReviewCount'] is num)
        ? (data['pendingHumanReviewCount'] as num).toInt()
        : 0;

    if (moderationStatus == 'manual_review' || pendingHumanReviewCount > 0) {
      return 'En attente de validation admin. Une ou plusieurs photos nécessitent une vérification manuelle avant publication.';
    }
    if (_offerMediaStillProcessing(data)) {
      return 'Vérification du texte et conversion des images en cours. L’annonce sera publiée automatiquement dès que tout est prêt.';
    }
    return 'Annonce en cours de vérification avant publication. Le délai de 30 secondes est indicatif et la publication reste pilotée par la modération.';
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
    return section == _OfferManagementSection.rejected;
  }

  bool _canDeleteOffer(_OfferManagementSection section) {
    return section != _OfferManagementSection.archived;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadOffersByOwnerField(
    String field,
  ) async {
    try {
      // Prod marketplace contract:
      // listings est la source normale. offers legacy est un backfill lecture seule,
      // désactivé en prod par kEnableLegacyPublicOffersBackfill.
      final futures =
          <Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>[
        FirebaseFirestore.instance
            .collection(kListingsCollection)
            .where(field, isEqualTo: widget.userId)
            .limit(120)
            .get()
            .then((snap) => snap.docs),
      ];

      if (kEnableLegacyPublicOffersBackfill) {
        futures.add(
          loadLegacyPublicOffersByOwner(
            ownerField: field,
            ownerId: widget.userId,
            limit: 120,
            source: 'user_offers_section_legacy_$field',
          ),
        );
      }

      final results = await Future.wait(futures);
      final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final docs in results) {
        for (final doc in docs) {
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
    _bindOffersStream();
    unawaited(_loadOffers());
  }

  @override
  void didUpdateWidget(covariant UserOffersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId == widget.userId) {
      return;
    }
    _knownPublishedIds = {};
    _initialLoadDone = false;
    _bindOffersStream();
    unawaited(_loadOffers());
  }

  @override
  void dispose() {
    _offersStream?.cancel();
    super.dispose();
  }

  void _bindOffersStream() {
    _offersStream?.cancel();
    final userId = widget.userId.trim();
    if (userId.isEmpty) {
      _offersStream = null;
      return;
    }

    _offersStream = FirebaseFirestore.instance
        .collection(kListingsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      _onOffersSnapshot(snapshot);
    }, onError: (_) {});
  }

  void _onOffersSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final currentPublishedIds = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (_resolveSection(data) == _OfferManagementSection.published) {
        currentPublishedIds.add(doc.id);
      }
    }

    if (_initialLoadDone) {
      final newlyPublished = currentPublishedIds.difference(_knownPublishedIds);
      if (newlyPublished.isNotEmpty && mounted) {
        showPrestoSnackBar(context, 'Votre annonce est publiee !');
        unawaited(_loadOffers());
      }
    }

    _knownPublishedIds = currentPublishedIds;
  }

  Future<void> _loadOffers() async {
    final userId = widget.userId.trim();
    _logUserOffersLoad(
      'start',
      details: <String, Object?>{'userId': userId},
    );

    if (userId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _offers = [];
          _error = null;
        });
      }
      _logUserOffersLoad(
        'success',
        details: const <String, Object?>{'count': 0, 'reason': 'empty-user'},
      );
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

      final publishedIds = docs
          .where((d) => d.section == _OfferManagementSection.published)
          .map((d) => d.offerId)
          .toSet();

      if (!_initialLoadDone) {
        _knownPublishedIds = publishedIds;
        _initialLoadDone = true;
      }

      setState(() {
        _offers = docs;
        _isLoading = false;
        _error = null;
      });
      _logUserOffersLoad(
        'success',
        details: <String, Object?>{
          'count': docs.length,
          'userId': userId,
        },
      );
    } catch (e) {
      _logUserOffersLoad(
        'error',
        details: <String, Object?>{
          'userId': userId,
          'errorType': e.runtimeType.toString(),
          'message': e.toString(),
        },
      );
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
                unawaited(_loadOffers());
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
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
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
                  color: kPrestoBlue.withValues(alpha: 0.10),
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
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
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
        border: Border.all(
          color: color.withValues(alpha: 0.24),
          width: 1.4,
        ),
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
                  color: color.withValues(alpha: 0.10),
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
        border: Border.all(
          color: color.withValues(alpha: 0.24),
          width: 1.4,
        ),
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
                        color: color.withValues(alpha: 0.10),
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
                          'Quand une annonce quitte "En attente de validation", elle est publiée et apparaît ici dans la liste des annonces publiées.',
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
        border: Border.all(
          color: color.withValues(alpha: 0.24),
          width: 1.4,
        ),
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
                        color: color.withValues(alpha: 0.10),
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
        border: Border.all(
          color: color.withValues(alpha: 0.24),
          width: 1.4,
        ),
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
                        color: color.withValues(alpha: 0.10),
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
    logRuntimeAction(
      area: 'offers',
      action: 'open-detail',
      details: <String, Object?>{
        'offerId': item.offerId,
        'source': 'account-managed-offers',
      },
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OfferDetailsPage(
          offer: buildOfferDetailsOffer(
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

  BoxDecoration _offerTileDecoration() {
    return BoxDecoration(
      color: const Color(0xFFFDFDFD),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.black.withValues(alpha: 0.1),
        width: 1.4,
      ),
    );
  }

  String _primaryManagedOfferImageUrl(Map<String, dynamic> data) {
    final thumbnailUrl = (data['thumbnailUrl'] ?? '').toString().trim();
    if (thumbnailUrl.isNotEmpty) return thumbnailUrl;

    final imageUrl = (data['imageUrl'] ?? '').toString().trim();
    if (imageUrl.isNotEmpty) return imageUrl;

    final imageUrls = data['imageUrls'];
    if (imageUrls is List) {
      for (final entry in imageUrls) {
        final value = entry.toString().trim();
        if (value.isNotEmpty) return value;
      }
    }

    final media = data['media'];
    if (media is List) {
      for (final entry in media) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry.cast<dynamic, dynamic>());
        final candidate = ((map['thumbnailUrl'] ?? map['downloadUrl']) ?? '')
            .toString()
            .trim();
        if (candidate.isNotEmpty) return candidate;
      }
    }

    return '';
  }

  Widget _buildOfferPhotoPreview(Map<String, dynamic> data) {
    final imageUrl = _primaryManagedOfferImageUrl(data);
    if (imageUrl.isEmpty) {
      return Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          color: Color(0xFF9CA3AF),
          size: 28,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 84,
        height: 84,
        child: OfferNetworkImage(
          url: imageUrl,
          fit: BoxFit.cover,
          cacheWidth: 300,
          errorChild: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F5),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              color: Color(0xFF9CA3AF),
              size: 28,
            ),
          ),
          loadingChild: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F5),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_outlined,
              color: Color(0xFF9CA3AF),
              size: 28,
            ),
          ),
        ),
      ),
    );
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
    final pendingCountdown = _offerPendingCountdownSeconds(data);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _offerTileDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOfferPhotoPreview(data),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _offerTitle(data),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildMetaChip(
                            Icons.category_outlined, _offerCategory(data)),
                        _buildMetaChip(
                            Icons.event_outlined, _formatOfferDate(data)),
                        _buildMetaChip(
                            Icons.place_outlined, _offerLocation(data)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
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
                  if (pendingCountdown != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFFFC78F)),
                      ),
                      child: Text(
                        '${pendingCountdown}s',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
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
                color: statusColor.withValues(alpha: 0.08),
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
          else if (item.section == _OfferManagementSection.pending)
            SizedBox(
              width: double.infinity,
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
          if (!canEdit && item.section == _OfferManagementSection.pending) ...[
            const SizedBox(height: 8),
            const Text(
              'Pendant la validation, cette annonce ne peut pas etre modifiee. Vous pouvez uniquement la supprimer.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
                                tooltip: 'Fermer',
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
                                  initialValue: selectedCategory,
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
                                  initialValue: selectedSubCategory.isEmpty
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
                                  initialValue: selectedBudgetType,
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
                                  initialValue: selectedMissionDelay.isEmpty
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton.icon(
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
                                            averageDelayController.text.trim();
                                        final trimmedSubCategory =
                                            selectedSubCategory.trim();
                                        final trimmedAvailability =
                                            availabilityController.text.trim();
                                        final trimmedServiceArea =
                                            serviceAreaController.text.trim();
                                        final trimmedSchedule =
                                            scheduleController.text.trim();
                                        final trimmedPaymentMethod =
                                            paymentMethodController.text.trim();
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
                                          final listingsRef = FirebaseFirestore
                                              .instance
                                              .collection(kListingsCollection)
                                              .doc(item.offerId);
                                          final listingsSnap =
                                              await listingsRef.get();
                                          if (!listingsSnap.exists) {
                                            throw StateError(
                                              'Annonce legacy non modifiable depuis l’UI : migration listings requise',
                                            );
                                          }
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
                                            'schedule': trimmedSchedule.isEmpty
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
                                            update['budget'] = effectiveBudget;
                                            update['price'] =
                                                effectiveBudget.toDouble();
                                            update['budgetValue'] =
                                                (indexed['budgetValue'] ??
                                                        effectiveBudget)
                                                    .toDouble();
                                          }

                                          await listingsRef.update(update);

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
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
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
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: isSaving
                                    ? null
                                    : () => Navigator.of(dialogContext).pop(),
                                child: const Text('Annuler'),
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

    if (reason == kOfferDeleteReasonFoundOnIliPresto) {
      await _handleFoundOnIliPrestoReviewFlow(item, title, reason);
      return;
    }

    setState(() => _busyOfferId = item.offerId);

    try {
      final listingsRef = FirebaseFirestore.instance
          .collection(kListingsCollection)
          .doc(item.offerId);
      final listingsSnap = await listingsRef.get();
      if (!listingsSnap.exists) {
        throw StateError(
          'Annonce legacy non supprimable depuis l’UI : migration listings requise',
        );
      }

      final shouldKeepVisibleWithJobDone = isOfferJobDoneDeletionReason(reason);

      debugPrint('Suppression offre ${item.offerId} avec motif: $reason');

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

  Future<void> _handleFoundOnIliPrestoReviewFlow(
    _ManagedOfferItem item,
    String title,
    String reason,
  ) async {
    final action = await showDialog<FoundSomeoneOnIliPrestoAction>(
      context: context,
      builder: (_) => const FoundSomeoneOnIliPrestoDialog(),
    );
    if (action == null || !mounted) return;

    if (action == FoundSomeoneOnIliPrestoAction.searchUser) {
      final responder = await showModalBottomSheet<EligibleResponderForReview>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (_) => EligibleResponderSearchSheet(
          offerId: item.offerId,
          service: _trustScoreService,
        ),
      );
      if (responder == null || !mounted) return;

      final result = await showDialog<SubmitReviewResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ReviewFormDialog(
          offerId: item.offerId,
          offerTitle: title,
          responder: responder,
          service: _trustScoreService,
        ),
      );
      if (result == null || !mounted) return;

      if (result.isRateLater) {
        await _closeFoundOnIliPrestoWithoutReview(
          item: item,
          title: title,
          reason: reason,
          successMessage:
              'Annonce "$title" marquée comme réalisée. Vous pourrez noter plus tard.',
        );
        return;
      }

      await _loadOffers();
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        result.isPublished
            ? 'Merci, votre avis a bien été enregistré.'
            : 'Merci, votre avis a été envoyé en vérification avant publication.',
      );
      return;
    }

    final message = action == FoundSomeoneOnIliPrestoAction.rateLater
        ? 'Annonce "$title" marquée comme réalisée. Vous pourrez noter plus tard.'
        : 'Annonce "$title" supprimée sans avis.';
    await _closeFoundOnIliPrestoWithoutReview(
      item: item,
      title: title,
      reason: reason,
      successMessage: message,
    );
  }

  Future<void> _closeFoundOnIliPrestoWithoutReview({
    required _ManagedOfferItem item,
    required String title,
    required String reason,
    required String successMessage,
  }) async {
    setState(() => _busyOfferId = item.offerId);
    try {
      await _trustScoreService.closeOfferWithReason(
        offerId: item.offerId,
        reason: reason,
        jobDone: true,
      );
      if (!mounted) return;
      await _loadOffers();
      if (!mounted) return;
      showSuccessSnackBar(context, successMessage);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      debugPrint(
        'Erreur clôture offre ${item.offerId}: ${e.code} ${e.message}',
      );
      showErrorSnackBar(
        context,
        'Impossible de clôturer cette annonce pour le moment.',
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Erreur clôture offre ${item.offerId}: $e');
      showErrorSnackBar(
        context,
        'Impossible de clôturer cette annonce pour le moment.',
      );
    } finally {
      if (mounted) {
        setState(() => _busyOfferId = null);
      }
    }
  }

  Future<String?> _showDeleteOfferDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (_) => const CloseOfferReasonDialog(),
    );
  }
}
