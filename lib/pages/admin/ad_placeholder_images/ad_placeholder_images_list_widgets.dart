part of '../ad_placeholder_images_admin_page.dart';

// ── Tile liste de réordre ────────────────────────────────────────────────────

class _ReorderTile extends StatelessWidget {
  const _ReorderTile({
    super.key,
    required this.image,
    required this.index,
    required this.onTapImage,
  });

  final AdPlaceholderImage image;
  final int index;
  final VoidCallback onTapImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Poignée drag
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child:
                Icon(Icons.drag_handle_rounded, color: Colors.grey, size: 26),
          ),
          // Aperçu image
          GestureDetector(
            onTap: onTapImage,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 72,
                height: 50,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      image.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFF2F4F7),
                        child: Icon(Icons.broken_image_outlined, size: 20),
                      ),
                    ),
                    const Center(
                      child: Icon(Icons.zoom_in_rounded,
                          color: Colors.white70, size: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Numéro d'ordre + état
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Position ${index + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: image.isVisible
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    image.isVisible ? 'Affichée' : 'Masquée',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: image.isVisible
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                    ),
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

// ── État vide ────────────────────────────────────────────────────────────────

class _EmptyPlaceholderAdminState extends StatelessWidget {
  const _EmptyPlaceholderAdminState();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.collections_outlined, size: 44, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Aucune image pour le moment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              'Ajoute des images via le bouton "Ajouter" en haut à droite '
              'ou le bouton orange en bas. En attendant, les images assets actuelles restent visibles.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderToolChip extends StatelessWidget {
  const _PlaceholderToolChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF475569)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
