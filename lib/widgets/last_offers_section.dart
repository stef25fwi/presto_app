import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:presto_app/main.dart' show OfferDetailPage;

class LastOffersSection extends StatelessWidget {
  final VoidCallback? onSeeAll;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? offersStream;

  const LastOffersSection({
    super.key,
    this.onSeeAll,
    this.offersStream,
  });

  static const prestoBlue = Color(0xFF1A73E8);

  @override
  Widget build(BuildContext context) {
    if (offersStream != null) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: offersStream,
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? const [];
          // Prendre max 10 offres
          final items = docs.take(10).toList(growable: false);

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Dernières annonces publiées",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 12),
                _OffersSkeleton(),
              ],
            );
          }

          if (items.isEmpty) {
            return Text(
              "Aucune offre pour le moment.",
              style: TextStyle(
                color: Colors.black.withOpacity(0.6),
                fontWeight: FontWeight.w600,
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Dernières annonces publiées",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onSeeAll,
                    child: const Text(
                      "Voir tout >",
                      style: TextStyle(
                        color: prestoBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _AnimatedOffersCarousel(docs: items),
            ],
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                "Dernières annonces publiées",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            GestureDetector(
              onTap: onSeeAll,
              child: const Text(
                "Voir tout >",
                style: TextStyle(
                  color: prestoBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _OfferRow(
          title: "Jardinier cet après-midi",
          location: "Goyave — Bientôt",
          isUrgent: true,
        ),
        const SizedBox(height: 10),
        _OfferRow(
          title: "Aide déménagement (2h)",
          location: "Paris — Bientôt",
          isUrgent: false,
        ),
      ],
    );
  }

  // ignore: unused_element
  List<Widget> _buildOfferRowsFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    // This method is no longer used; _AnimatedOffersCarousel handles display
    return [];
  }
}

class _OffersSkeleton extends StatelessWidget {
  const _OffersSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _OfferSkeletonRow(),
        SizedBox(height: 10),
        _OfferSkeletonRow(),
      ],
    );
  }
}

class _OfferSkeletonRow extends StatelessWidget {
  const _OfferSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF2F7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF2F7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 12,
                  width: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF2F7),
                    borderRadius: BorderRadius.circular(999),
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

class _OfferRow extends StatelessWidget {
  final String title;
  final String location;
  final bool isUrgent;

  const _OfferRow({
    required this.title,
    required this.location,
    required this.isUrgent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isUrgent) ...[
                  const _UrgentTextBadge(),
                  const SizedBox(height: 6),
                ],
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  location,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.55),
                    fontWeight: FontWeight.w500,
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

class _UrgentTextBadge extends StatelessWidget {
  const _UrgentTextBadge();

  static const prestoOrange = Color(0xFFFF6600);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE6D6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 16, color: prestoOrange),
          SizedBox(width: 6),
          Text(
            'URGENT',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: prestoOrange,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// ANIMATED CAROUSEL - Auto-scrolling 10 offers on 2 rows
/// ============================================================================
class _AnimatedOffersCarousel extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  const _AnimatedOffersCarousel({required this.docs});

  @override
  State<_AnimatedOffersCarousel> createState() =>
      _AnimatedOffersCarouselState();
}

class _AnimatedOffersCarouselState extends State<_AnimatedOffersCarousel>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  bool _isHovered = false;
  bool _isTouching = false;
  late AnimationController _animationController;

  int? _readViewsCount(Map<String, dynamic> data) {
    final dynamic raw = data['viewsCount'] ??
        data['viewCount'] ??
        data['views'] ??
        data['consultations'] ??
        data['consultationsCount'] ??
        data['seenCount'];

    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_isHovered && !_isTouching) {
        // Scroll left-to-right
        if (_scrollController.hasClients) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          final currentScroll = _scrollController.offset;
          if (currentScroll >= maxScroll) {
            _scrollController.jumpTo(0);
          } else {
            _scrollController.jumpTo(currentScroll + 1);
          }
        }
      }
    });
  }

  Widget _buildOfferCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    int index,
  ) {
    final data = doc.data();
    final title =
        (data['title'] ?? data['jobTitle'] ?? 'Sans titre').toString();
    final city = (data['city'] ?? data['location'] ?? '').toString().trim();
    final startText =
        (data['startText'] ?? data['startDateText'] ?? '').toString().trim();
    final isUrgent = data['urgent'] == true || data['is_urgent'] == true;
    final viewsCount = _readViewsCount(data);
    final locationText = [
      if (city.isNotEmpty) city,
      if (startText.isNotEmpty) startText,
    ].join(' — ');

    final animation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(
        (index * 0.08).clamp(0.0, 1.0),
        ((index * 0.08) + 0.4).clamp(0.0, 1.0),
        curve: Curves.easeOut,
      ),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(animation),
        child: GestureDetector(
          onTap: () {
            final offerId = doc.id;
            final category =
                (data['category'] ?? 'Catégorie non précisée').toString();
            final budget = data['budget'];
            final description = (data['description'] ?? '').toString();
            final phone =
                data['phone'] == null ? null : data['phone'].toString();

            final List<String> imageUrls =
                (data['imageUrls'] as List<dynamic>? ?? [])
                    .map((e) => e.toString())
                    .toList();

            final sub =
              (data['subCategory'] ?? data['subcategory'] ?? '').toString().trim();

            // ignore: use_build_context_synchronously
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OfferDetailPage(
                  offerId: offerId,
                  title: title,
                  location: locationText.isEmpty ? 'Proche' : locationText,
                  category: category,
                  subcategory: sub.isEmpty ? null : sub,
                  budget: budget is num ? budget : null,
                  description: description.isEmpty ? null : description,
                  phone: phone,
                  imageUrls: imageUrls.isEmpty ? null : imageUrls,
                  annonceurId: (data['userId'] ?? '').toString(),
                ),
              ),
            );
          },
          child: Container(
            width: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isUrgent) ...[
                  const _UrgentTextBadge(),
                  const SizedBox(height: 4),
                ],
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  locationText.isEmpty ? 'Proche' : locationText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 12,
                      color: Colors.black.withOpacity(0.55),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${viewsCount ?? 0}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.black.withOpacity(0.55),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Duplicate for infinite scroll effect
    final duplicated = [...widget.docs, ...widget.docs];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Listener(
        onPointerDown: (_) {
          _isTouching = true;
        },
        onPointerUp: (_) {
          _isTouching = false;
        },
        onPointerCancel: (_) {
          _isTouching = false;
        },
        child: SizedBox(
          height: 102,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: duplicated.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) =>
                _buildOfferCard(duplicated[index], index),
          ),
        ),
      ),
    );
  }
}
