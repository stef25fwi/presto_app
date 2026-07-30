part of '../ad_placeholder_images_admin_page.dart';

class _LatestPlaceholderReceivedCard extends StatelessWidget {
  const _LatestPlaceholderReceivedCard({
    required this.image,
    required this.totalCount,
    required this.activeCount,
    required this.onOpen,
  });

  final AdPlaceholderImage image;
  final int totalCount;
  final int activeCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final isActive = image.isVisible;

    return Container(
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFEFFAF3) : const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? const Color(0xFF8DD7A5) : const Color(0xFFFFD18A),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 96,
              height: 60,
              child: Image.network(
                image.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFF2F4F7),
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive
                      ? 'Dernière image reçue par la page : ACTIVE'
                      : 'Dernière image reçue par la page : MASQUÉE',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$activeCount image(s) active(s) sur $totalCount',
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID : ${image.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_full_rounded, size: 16),
                    label: const Text('Ouvrir l’image reçue'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
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
