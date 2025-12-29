import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ------------------------------------------------------------
/// HOME HERO SECTION
/// - Mobile: slider normal
/// - Tablet/Desktop: split left (5 latest offers) + right (premium slider)
/// ------------------------------------------------------------
class HomeHeroSection extends StatefulWidget {
  const HomeHeroSection({
    super.key,
    this.breakpoint = 900,
    this.offersCollection = 'offers',
    this.offersOrderField = 'createdAt', // ⚠️ adapte si besoin: "timestamp" etc.
    this.limit = 5,
    required this.onTapOffer,
    required this.onCtaPressed,
  });

  /// Width >= breakpoint => split layout
  final double breakpoint;

  /// Firestore collection name
  final String offersCollection;

  /// Firestore field used for ordering latest offers
  final String offersOrderField;

  /// Number of offers shown on the left
  final int limit;

  /// Click on offer tile => open detail
  final void Function(String offerId) onTapOffer;

  /// CTA on hero slides
  final VoidCallback onCtaPressed;

  @override
  State<HomeHeroSection> createState() => _HomeHeroSectionState();
}

class _HomeHeroSectionState extends State<HomeHeroSection> {
  final PageController _pageController = PageController();
  int _current = 0;

  List<_HeroSlideData> _slides = const [];
  bool _loadingSlides = true;

  static const List<_HeroCopy> _copies = [
    _HeroCopy(
      title: 'Vous cherchez\nun photographe ?',
      subtitle: 'Ils sont des dizaines prêts à vous répondre !',
      cta: 'Publier une annonce',
      align: Alignment.centerRight,
    ),
    _HeroCopy(
      title: 'Trouvez quelqu’un\nen 1 minute.',
      subtitle: 'Jardinage, peinture, main-d’œuvre…',
      cta: 'Rechercher',
      align: Alignment.center,
    ),
    _HeroCopy(
      title: 'DJ / Sono\npour vos événements',
      subtitle: 'Comparez et contactez instantanément.',
      cta: 'Voir DJ / Sono',
      align: Alignment.centerRight,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSlidesFromAssets();
  }

  Future<void> _loadSlidesFromAssets() async {
    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest =
          json.decode(manifestJson) as Map<String, dynamic>;

      List<String> paths = manifest.keys
          .where((k) => k.startsWith('assets/slides/'))
          .where((k) {
            final lower = k.toLowerCase();
            if (lower.endsWith('/')) return false;
            if (lower.endsWith('.gitkeep')) return false;
            return lower.endsWith('.png') ||
                lower.endsWith('.jpg') ||
                lower.endsWith('.jpeg') ||
                lower.endsWith('.webp');
          })
          .toList()
        ..sort();

      // Fallback: si assets/slides est vide, on réutilise les 3 premières images du carousel.
      if (paths.isEmpty) {
        paths = const [
          'assets/carousel_home/01.png',
          'assets/carousel_home/02.png',
          'assets/carousel_home/03.png',
        ];
      }

      final slides = <_HeroSlideData>[];
      for (int i = 0; i < paths.length; i++) {
        final copy = _copies[i % _copies.length];
        slides.add(
          _HeroSlideData(
            title: copy.title,
            subtitle: copy.subtitle,
            cta: copy.cta,
            assetPath: paths[i],
            align: copy.align,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _slides = slides;
        _loadingSlides = false;
        if (_current >= _slides.length) _current = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _slides = const [
          _HeroSlideData(
            title: 'Vous cherchez\nun photographe ?',
            subtitle: 'Ils sont des dizaines prêts à vous répondre !',
            cta: 'Publier une annonce',
            assetPath: 'assets/carousel_home/01.png',
            align: Alignment.centerRight,
          ),
          _HeroSlideData(
            title: 'Trouvez quelqu’un\nen 1 minute.',
            subtitle: 'Jardinage, peinture, main-d’œuvre…',
            cta: 'Rechercher',
            assetPath: 'assets/carousel_home/02.png',
            align: Alignment.center,
          ),
          _HeroSlideData(
            title: 'DJ / Sono\npour vos événements',
            subtitle: 'Comparez et contactez instantanément.',
            cta: 'Voir DJ / Sono',
            assetPath: 'assets/carousel_home/03.png',
            align: Alignment.centerRight,
          ),
        ];
        _loadingSlides = false;
        if (_current >= _slides.length) _current = 0;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSlides) {
      return const SizedBox(height: 260);
    }
    if (_slides.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final isSplit = width >= widget.breakpoint;

        if (!isSplit) {
          // MOBILE / portrait: slider normal
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: _PremiumHeroSlider(
              slides: _slides,
              controller: _pageController,
              currentIndex: _current,
              onChanged: (i) => setState(() => _current = i),
              onCtaPressed: widget.onCtaPressed,
              aspectRatio: 16 / 9,
            ),
          );
        }

        // TABLET / DESKTOP: split
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT: 5 latest offers tiles
              Expanded(
                flex: 5,
                child: _LatestOffersTiles(
                  collection: widget.offersCollection,
                  orderField: widget.offersOrderField,
                  limit: widget.limit,
                  onTapOffer: widget.onTapOffer,
                ),
              ),
              const SizedBox(width: 18),

              // RIGHT: premium slider
              Expanded(
                flex: 8,
                child: _PremiumHeroSlider(
                  slides: _slides,
                  controller: _pageController,
                  currentIndex: _current,
                  onChanged: (i) => setState(() => _current = i),
                  onCtaPressed: widget.onCtaPressed,
                  aspectRatio: 21 / 9, // ultra premium paysage
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ------------------------------------------------------------
/// PREMIUM HERO SLIDER
/// - background image cover
/// - overlay gradient
/// - fade only on content (AnimatedSwitcher)
/// ------------------------------------------------------------
class _PremiumHeroSlider extends StatelessWidget {
  const _PremiumHeroSlider({
    required this.slides,
    required this.controller,
    required this.currentIndex,
    required this.onChanged,
    required this.onCtaPressed,
    required this.aspectRatio,
  });

  final List<_HeroSlideData> slides;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onCtaPressed;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    if (slides.isEmpty) {
      return const SizedBox.shrink();
    }
    final data = slides[currentIndex];

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          children: [
            // Background images
            PageView.builder(
              controller: controller,
              itemCount: slides.length,
              onPageChanged: onChanged,
              itemBuilder: (context, i) {
                final s = slides[i];
                return Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(s.assetPath),
                      fit: BoxFit.cover,
                      alignment: s.align,
                    ),
                  ),
                );
              },
            ),

            // Overlay for readability
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(0.50),
                      Colors.black.withOpacity(0.12),
                    ],
                  ),
                ),
              ),
            ),

            // ✅ Fade content only
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: _HeroSlideContent(
                    key: ValueKey('hero-$currentIndex'),
                    title: data.title,
                    subtitle: data.subtitle,
                    cta: data.cta,
                    onCtaPressed: onCtaPressed,
                  ),
                ),
              ),
            ),

            // Dots indicator
            Positioned(
              left: 20,
              bottom: 16,
              child: Row(
                children: List.generate(slides.length, (i) {
                  final active = i == currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.only(right: 6),
                    height: 6,
                    width: active ? 22 : 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(active ? 0.95 : 0.55),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSlideContent extends StatelessWidget {
  const _HeroSlideContent({
    super.key,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onCtaPressed,
  });

  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onCtaPressed;

  @override
  Widget build(BuildContext context) {
    final prestoOrange = Theme.of(context).colorScheme.primary;

    // Adapt text sizes slightly for smaller widths
    final w = MediaQuery.of(context).size.width;
    final titleSize = w < 1000 ? 30.0 : 40.0;
    final subSize = w < 1000 ? 16.0 : 18.0;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: titleSize,
                height: 1.05,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: subSize,
                height: 1.2,
                color: Colors.white.withOpacity(0.92),
              ),
            ),
            const SizedBox(height: 16),

            // CTA orange Prestō
            ElevatedButton(
              onPressed: onCtaPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: prestoOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                cta,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// LEFT COLUMN: Latest offers tiles
/// - Firestore: collection('offers').orderBy(orderField, desc).limit(5)
/// - Tiles are clickable
/// ------------------------------------------------------------
class _LatestOffersTiles extends StatelessWidget {
  const _LatestOffersTiles({
    required this.collection,
    required this.orderField,
    required this.limit,
    required this.onTapOffer,
  });

  final String collection;
  final String orderField;
  final int limit;
  final void Function(String offerId) onTapOffer;

  @override
  Widget build(BuildContext context) {
    final prestoOrange = Theme.of(context).colorScheme.primary;

    final query = FirebaseFirestore.instance
        .collection(collection)
        .orderBy(orderField, descending: true)
        .limit(limit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dernières annonces',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _TilesSkeleton(count: 5);
            }
            if (snap.hasError) {
              return _ErrorBox(
                text:
                    'Erreur Firestore. Vérifie que le champ "$orderField" existe et est indexé.',
              );
            }
            final docs = snap.data?.docs ?? const [];
            if (docs.isEmpty) {
              return const _EmptyBox();
            }

            return Column(
              children: docs.map((d) {
                final data = d.data();

                // ✅ Champs tolérants : adapte au besoin
                final title = (data['title'] ??
                        data['titre'] ??
                        data['jobTitle'] ??
                        'Annonce')
                    .toString();

                final city =
                    (data['city'] ?? data['ville'] ?? data['locationName'] ?? '')
                        .toString();

                final category =
                    (data['category'] ?? data['categorie'] ?? data['type'] ?? '')
                        .toString();

                final priceRaw = data['price'] ?? data['prix'];
                final priceText =
                    priceRaw == null ? '' : '${priceRaw.toString()}€';

                final meta = [
                  if (city.isNotEmpty) city,
                  if (category.isNotEmpty) category,
                ].join(' • ');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onTapOffer(d.id),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black.withOpacity(0.06)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Pastille
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: prestoOrange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _iconForCategory(category),
                              color: prestoOrange,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Texts
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  meta.isEmpty
                                      ? 'Localisation non précisée'
                                      : meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.black.withOpacity(0.60),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Price
                          if (priceText.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Text(
                              priceText,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: prestoOrange,
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.black.withOpacity(0.35),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  static IconData _iconForCategory(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('jardin')) return Icons.grass;
    if (c.contains('peint')) return Icons.format_paint;
    if (c.contains('dj') || c.contains('sono')) return Icons.music_note;
    if (c.contains('enfant') || c.contains('garde')) return Icons.child_care;
    if (c.contains('main') || c.contains('manoeuvre')) return Icons.handyman;
    return Icons.bolt;
  }
}

/// ------------------------------------------------------------
/// UI helpers
/// ------------------------------------------------------------
class _EmptyBox extends StatelessWidget {
  const _EmptyBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Text(
        'Aucune annonce récente pour le moment.',
        style: TextStyle(color: Colors.black.withOpacity(0.65)),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.30)),
      ),
      child: Text(
        text,
        style: TextStyle(color: Colors.red.withOpacity(0.85)),
      ),
    );
  }
}

class _TilesSkeleton extends StatelessWidget {
  const _TilesSkeleton({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (i) {
        return Container(
          height: 64,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
          ),
        );
      }),
    );
  }
}

/// Data class for hero slides
class _HeroSlideData {
  final String title;
  final String subtitle;
  final String cta;
  final String assetPath;
  final Alignment align;

  const _HeroSlideData({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.assetPath,
    required this.align,
  });
}

class _HeroCopy {
  final String title;
  final String subtitle;
  final String cta;
  final Alignment align;

  const _HeroCopy({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.align,
  });
}
