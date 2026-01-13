import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'moderation_badge.dart';

enum OfferMenuAction { edit, delete }

class OfferCard extends StatelessWidget {
  final String offerId;
  final Map<String, dynamic> data;

  static const Color _kPrestoBlue = Color(0xFF2196F3);

  /// ✅ Mettre false dans "Je consulte les offres"
  /// ✅ Mettre true dans Profil / "Mes messages"
  final bool showActionsMenu;

  /// Callbacks (utilisés uniquement si showActionsMenu = true)
  final void Function(String offerId, Map<String, dynamic> data)? onEdit;
  final void Function(String offerId, String title)? onDelete;
  
  /// ✅ Callback pour rendre la carte cliquable
  final VoidCallback? onTap;

  const OfferCard({
    super.key,
    required this.offerId,
    required this.data,
    required this.showActionsMenu,
    this.onEdit,
    this.onDelete,
    this.onTap,
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
    // ✅ Utiliser 'location' (champ Firestore correct) au lieu de 'city'
    final location = (data['location'] ?? data['city'] ?? '').toString().trim();
    final category = (data['category'] ?? '').toString().trim();
    // ✅ Utiliser 'budget' (champ Firestore correct) au lieu de 'price'
    final budget = data['budget'] ?? data['price'];
    final bool isUrgent = data['urgent'] == true || data['isUrgent'] == true;

    final createdAt = data['createdAt'] ?? data['created_at'];
    final ageLabel = _ageLabelFromCreatedAt(createdAt);

    final subtitleLine = [
      if (location.isNotEmpty) location,
      if (category.isNotEmpty) category,
      if (budget != null && budget.toString().isNotEmpty) '${budget.toString()} €',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.all(0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border(
              left: BorderSide(
                color: _kPrestoBlue, // Bleu
                width: 10,
              ),
            ),
            boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
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
                  // ✅ Badge de modération
                  if (data['status'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: ModerationBadge(
                        status: data['status'] ?? 'approved',
                        userMessage: data['moderation']?['userMessage'],
                      ),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Publié il y a $ageLabel',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        if (isUrgent) ...[
                          const SizedBox(width: 10),
                          const _UrgentBlinkBadge(),
                        ],
                      ],
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
      ),
    );
  }
}

class _UrgentBlinkBadge extends StatefulWidget {
  const _UrgentBlinkBadge();

  @override
  State<_UrgentBlinkBadge> createState() => _UrgentBlinkBadgeState();
}

class _UrgentBlinkBadgeState extends State<_UrgentBlinkBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    )..repeat(reverse: true);
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeInOutCubic);
    _opacity = Tween<double>(begin: 0.18, end: 1.0).animate(curved);
    _scale = Tween<double>(begin: 0.96, end: 1.06).animate(curved);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const blue = OfferCard._kPrestoBlue;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          // Plus vif: fond et bord plus présents.
          color: blue.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: blue.withValues(alpha: 0.78),
            width: 1,
          ),
        ),
        child: const Text(
          'Urgent',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: blue,
          ),
        ),
      ),
    );
  }
}
