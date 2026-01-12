import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
          final items = docs.take(2).toList(growable: false);

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

              if (snapshot.connectionState == ConnectionState.waiting)
                const _OffersSkeleton()
              else if (items.isEmpty)
                Text(
                  "Aucune offre pour le moment.",
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                ..._buildOfferRowsFromDocs(items),
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

  List<Widget> _buildOfferRowsFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final rows = <Widget>[];
    for (var i = 0; i < docs.length; i++) {
      final data = docs[i].data();

      final title = (data['title'] ?? data['jobTitle'] ?? 'Offre').toString();
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
      if (imageUrl.trim().isEmpty) {
        imageUrl =
            'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=600&q=60';
      }

      rows.add(
        _OfferRow(
          title: title,
          location: locationText.isEmpty ? 'Proche de vous' : locationText,
          imageUrl: imageUrl,
          tags: const [
            _Tag(label: 'Nouveau', icon: Icons.fiber_new_rounded, primary: true),
          ],
        ),
      );
      if (i != docs.length - 1) {
        rows.add(const SizedBox(height: 10));
      }
    }
    return rows;
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: tags.map((e) => _TagChip(tag: e)).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  location,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Container(
            width: 56,
            height: 56,
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
