import 'package:flutter/material.dart';
import 'package:presto_app/services/ad_placeholder_image_service.dart';
import 'package:presto_app/widgets/presto_tap_target.dart';

/// Vignette grille d'une image placeholder publicitaire, avec bascule de
/// visibilité, aperçu et actions d'édition/suppression.
///
/// Extrait de `pages/admin/ad_placeholder_images_admin_page.dart` pour
/// rester sous le budget de lignes d'un écran (voir
/// `tools/quality/check_flutter_architecture_size.py`).
class AdminPlaceholderImageTile extends StatelessWidget {
  const AdminPlaceholderImageTile({
    super.key,
    required this.image,
    required this.onTapImage,
    required this.onVisibilityChanged,
    required this.onDelete,
    required this.onEdit,
    this.activePosition,
    this.activeTotal = 0,
  });

  final AdPlaceholderImage image;
  final VoidCallback onTapImage;
  final ValueChanged<bool> onVisibilityChanged;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final int? activePosition;
  final int activeTotal;

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF6600);
    final selected = image.isVisible;
    final activeLabel = selected && activePosition != null && activeTotal > 0
        ? 'Active $activePosition/$activeTotal'
        : selected
            ? 'Affichée'
            : 'Masquée';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? orange : Colors.grey.shade300,
          width: selected ? 2.5 : 1,
        ),
        boxShadow: [
          if (selected)
            BoxShadow(
              color: orange.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PrestoTapTarget(
            semanticLabel: 'Agrandir ${image.title ?? "l'image"}',
            onTap: onTapImage,
            child: Image.network(
              image.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFFF2F4F7),
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          ),
          // Voile pour images masquées
          if (!selected) Container(color: Colors.white.withValues(alpha: 0.5)),
          // Icône zoom (centre)
          Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.zoom_in_rounded,
                  color: Colors.white, size: 24),
            ),
          ),
          // Checkbox visibilité (haut droite) - plus grand
          Positioned(
            top: 6,
            right: 6,
            child: PrestoTapTarget(
              toggled: selected,
              semanticLabel: activeLabel,
              shape: const CircleBorder(),
              onTap: () => onVisibilityChanged(!selected),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? orange : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? orange : Colors.grey.shade400,
                    width: 2.5,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
                child: selected
                    ? const Icon(Icons.check, size: 20, color: Colors.white)
                    : null,
              ),
            ),
          ),
          // Barre d'actions en bas (plus visible)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Badge état (bas gauche)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected ? orange : Colors.grey.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      activeLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Boutons d'action
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Bouton modifier
                      Tooltip(
                        message: 'Modifier',
                        child: Container(
                          decoration: BoxDecoration(
                            color: orange,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 16,
                              icon: const Icon(Icons.edit_rounded,
                                  color: Colors.white),
                              onPressed: onEdit,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Bouton supprimer
                      Tooltip(
                        message: 'Supprimer',
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade500,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 16,
                              icon: const Icon(Icons.delete_rounded,
                                  color: Colors.white),
                              onPressed: onDelete,
                            ),
                          ),
                        ),
                      ),
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
