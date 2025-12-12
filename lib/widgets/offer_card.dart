import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum OfferMenuAction { edit, delete }

class OfferCard extends StatelessWidget {
  final String offerId;
  final Map<String, dynamic> data;

  /// ✅ Mettre false dans "Je consulte les offres"
  /// ✅ Mettre true dans Profil / "Mes messages"
  final bool showActionsMenu;

  /// Callbacks (utilisés uniquement si showActionsMenu = true)
  final void Function(String offerId, Map<String, dynamic> data)? onEdit;
  final void Function(String offerId, String title)? onDelete;

  const OfferCard({
    super.key,
    required this.offerId,
    required this.data,
    required this.showActionsMenu,
    this.onEdit,
    this.onDelete,
  });

  String _ageLabelFromCreatedAt(dynamic createdAt) {
    if (createdAt == null) return '';

    DateTime dt;
    try {
      if (createdAt is Timestamp) {
        dt = createdAt.toDate();
      } else if (createdAt is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(createdAt);
      } else if (createdAt is String) {
        dt = DateTime.tryParse(createdAt) ?? DateTime.now();
      } else {
        return '';
      }
    } catch (_) {
      return '';
    }

    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} j';
  }

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? '').toString().trim();
    final city = (data['city'] ?? '').toString().trim();
    final category = (data['category'] ?? '').toString().trim();
    final price = data['price'];

    final createdAt = data['createdAt'] ?? data['created_at'];
    final ageLabel = _ageLabelFromCreatedAt(createdAt);

    final subtitleLine = [
      if (city.isNotEmpty) city,
      if (category.isNotEmpty) category,
      if (price != null && price.toString().isNotEmpty) '${price.toString()} €',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFCEEE2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE7D7C7)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône à gauche (comme ton cadenas)
            const Icon(Icons.work_outline, size: 22),

            const SizedBox(width: 12),

            // Contenu texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Annonce' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitleLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  if (ageLabel.isNotEmpty)
                    Text(
                      'Publié il y a $ageLabel',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),

            // ✅ Menu "..." : uniquement si showActionsMenu = true
            if (showActionsMenu)
              PopupMenuButton<OfferMenuAction>(
                icon: const Icon(Icons.more_horiz),
                onSelected: (action) {
                  if (action == OfferMenuAction.edit) {
                    if (onEdit != null) onEdit!(offerId, data);
                  } else if (action == OfferMenuAction.delete) {
                    if (onDelete != null) onDelete!(offerId, title);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: OfferMenuAction.edit,
                    child: Text('Modifier'),
                  ),
                  PopupMenuItem(
                    value: OfferMenuAction.delete,
                    child: Text('Supprimer'),
                  ),
                ],
              )
            else
              const SizedBox(width: 0), // ✅ supprime totalement le "..."
          ],
        ),
      ),
    );
  }
}
