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

  static const prestoOrange = Color(0xFFFF6600);
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
                  "Dernières offres près de chez vous",
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
                      "Dernières offres près de chez vous",
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
                "Dernières offres près de chez vous",
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
          imageUrl:
              "https://images.unsplash.com/photo-1468327768560-75b778cbb551?auto=format&fit=crop&w=600&q=60",
          tags: const [
            _Tag(label: "Urgent", icon: Icons.local_fire_department, primary: true),
            _Tag(label: "Commence bientôt", icon: Icons.schedule),
          ],
        ),
        const SizedBox(height: 10),
        _OfferRow(
          title: "Aide déménagement (2h)",
          location: "Paris — Bientôt",
          imageUrl:
              "https://images.unsplash.com/photo-1603791440384-56cd371ee9a7?auto=format&fit=crop&w=600&q=60",
          tags: const [
            _Tag(label: "Commence bientôt", icon: Icons.schedule),
            _Tag(label: "Très demandé", icon: Icons.visibility),
          ],
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
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF2F7),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
  final String imageUrl;
  final List<_Tag> tags;

  const _OfferRow({
    required this.title,
    required this.location,
    required this.imageUrl,
    required this.tags,
  });

  static const prestoOrange = Color(0xFFFF6600);

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
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              imageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: tags.map((e) => _TagChip(tag: e)).toList(),
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

          const SizedBox(width: 6),

          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              size: 30,
              color: prestoOrange,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag {
  final String label;
  final IconData icon;
  final bool primary;

  const _Tag({required this.label, required this.icon, this.primary = false});
}

class _TagChip extends StatelessWidget {
  final _Tag tag;
  const _TagChip({required this.tag});

  static const prestoOrange = Color(0xFFFF6600);

  @override
  Widget build(BuildContext context) {
    final bg = tag.primary ? const Color(0xFFFFE6D6) : const Color(0xFFEFF2F7);
    final fg = tag.primary ? prestoOrange : const Color(0xFF3B4252);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tag.icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            tag.label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: fg,
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
  late AnimationController _animationController;

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
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_isHovered) {
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
    final title = (data['title'] ?? data['jobTitle'] ?? 'Sans titre').toString();
    final city = (data['city'] ?? data['location'] ?? '').toString().trim();
    final startText = (data['startText'] ?? data['startDateText'] ?? '')
        .toString()
        .trim();
    final locationText = [
      if (city.isNotEmpty) city,
      if (startText.isNotEmpty) startText,
    ].join(' — ');

    String? imageUrl;
    final rawImages = data['images'];
    if (rawImages is List && rawImages.isNotEmpty) {
      final first = rawImages.first;
      if (first is String && first.trim().isNotEmpty) {
        imageUrl = first.trim();
      }
    }
    imageUrl ??= (data['imageUrl'] ?? data['coverUrl'] ?? '').toString();
    if (imageUrl.isEmpty) {
      imageUrl =
          'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=600&q=60';
    }

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
            final category = (data['category'] ?? 'Catégorie non précisée').toString();
            final budget = data['budget'];
            final description = (data['description'] ?? '').toString();
            final phone =
                data['phone'] == null ? null : data['phone'].toString();

            final List<String> imageUrls = (data['imageUrls'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();

            // ignore: use_build_context_synchronously
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OfferDetailPage(
                  offerId: offerId,
                  title: title,
                  location: locationText.isEmpty ? 'Proche' : locationText,
                  category: category,
                  subcategory: (data['subcategory'] ?? '').toString(),
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
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                    ],
                  ),
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
        child: SizedBox(
          height: 140,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: duplicated.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) => _buildOfferCard(duplicated[index], index),
          ),
      ),
    );
  }
}
