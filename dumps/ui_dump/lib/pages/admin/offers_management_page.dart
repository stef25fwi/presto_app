import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../utils/friendly_snackbar.dart';

const Color kPrestoOrange = Color(0xFFFF6600);
const Color kPrestoBlue = Color(0xFF1A73E8);

class OffersManagementPage extends StatefulWidget {
  const OffersManagementPage({super.key});

  @override
  State<OffersManagementPage> createState() => _OffersManagementPageState();
}

class _OffersManagementPageState extends State<OffersManagementPage> {
  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String _selectedFilter = 'all'; // all, active, pending, rejected
  int _totalOffers = 0;
  int _activeOffers = 0;
  int _pendingOffers = 0;
  int _rejectedOffers = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // Total offers
      final allSnap = await _firestore.collection('offers').count().get();
      final activeSnap = await _firestore
          .collection('offers')
          .where('isActive', isEqualTo: true)
          .count()
          .get();
      final pendingSnap = await _firestore
          .collection('offers')
          .where('moderation.status', isEqualTo: 'PENDING')
          .count()
          .get();
      final rejectedSnap = await _firestore
          .collection('offers')
          .where('moderation.status', isEqualTo: 'REJECTED')
          .count()
          .get();

      if (!mounted) return;
      setState(() {
        _totalOffers = allSnap.count ?? 0;
        _activeOffers = activeSnap.count ?? 0;
        _pendingOffers = pendingSnap.count ?? 0;
        _rejectedOffers = rejectedSnap.count ?? 0;
      });
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, 'Erreur stats: $e');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildOffersStream() {
    Query<Map<String, dynamic>> query = _firestore.collection('offers');

    switch (_selectedFilter) {
      case 'active':
        query = query.where('isActive', isEqualTo: true);
        break;
      case 'pending':
        query = query.where('moderation.status', isEqualTo: 'PENDING');
        break;
      case 'rejected':
        query = query.where('moderation.status', isEqualTo: 'REJECTED');
        break;
      case 'all':
      default:
        // Pas de filtre spécifique
        break;
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  Future<void> _deleteOffer(String offerId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer annonce'),
        content: Text('Supprimer "$title" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('offers').doc(offerId).delete();
      if (!mounted) return;
      showSuccessSnackBar(context, 'Annonce supprimée');
      _loadStats();
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, 'Erreur suppression: $e');
    }
  }

  Future<void> _toggleActiveStatus(String offerId, bool currentStatus) async {
    try {
      await _firestore.collection('offers').doc(offerId).update({
        'isActive': !currentStatus,
      });
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        currentStatus ? 'Annonce désactivée' : 'Annonce activée',
      );
      _loadStats();
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, 'Erreur: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        titleSpacing: 16,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Retour',
        ),
        title: const Text(
          'Gestion des annonces',
          style: kPrestoAppBarTitleStyle,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStats,
            tooltip: 'Rafraîchir',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statistiques
              _buildStatsGrid(),
              const SizedBox(height: 24),

              // Filtres
              Text(
                'Filtrer par statut',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              _buildFilterButtons(),
              const SizedBox(height: 24),

              // Liste des annonces
              Text(
                'Annonces',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              _buildOffersList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 120,
      ),
      children: [
        _StatCard(
          label: 'Total',
          value: _totalOffers.toString(),
          color: kPrestoBlue,
          icon: Icons.article_rounded,
        ),
        _StatCard(
          label: 'Actives',
          value: _activeOffers.toString(),
          color: Colors.green,
          icon: Icons.check_circle_rounded,
        ),
        _StatCard(
          label: 'En attente',
          value: _pendingOffers.toString(),
          color: Colors.orange,
          icon: Icons.schedule_rounded,
        ),
        _StatCard(
          label: 'Rejetées',
          value: _rejectedOffers.toString(),
          color: Colors.red,
          icon: Icons.cancel_rounded,
        ),
      ],
    );
  }

  Widget _buildFilterButtons() {
    final filters = [
      ('all', 'Toutes ($_totalOffers)', null),
      ('active', 'Actives ($_activeOffers)', Colors.green),
      ('pending', 'En attente ($_pendingOffers)', Colors.orange),
      ('rejected', 'Rejetées ($_rejectedOffers)', Colors.red),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter.$2),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedFilter = filter.$1);
              },
              backgroundColor: Colors.white,
              selectedColor: (filter.$3 ?? kPrestoBlue).withOpacity(0.2),
              side: BorderSide(
                color: isSelected
                    ? (filter.$3 ?? kPrestoBlue)
                    : Colors.black12,
                width: isSelected ? 2 : 1,
              ),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? (filter.$3 ?? kPrestoBlue)
                    : Colors.black87,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOffersList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _buildOffersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Erreur: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_rounded,
                    size: 48,
                    color: Colors.black26,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aucune annonce',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final title = (data['title'] ?? 'Sans titre') as String;
            final category = (data['category'] ?? '—') as String;
            final city = (data['city'] ?? '—') as String;
            final isActive = data['isActive'] ?? false;
            final createdAt = data['createdAt'] as Timestamp?;
            final moderationStatus = data['moderation.status'] ?? 'N/A';

            final dateStr = createdAt != null
                ? createdAt.toDate().toString().split('.')[0]
                : '—';

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.category_rounded,
                                      size: 14, color: Colors.black54),
                                  const SizedBox(width: 4),
                                  Text(
                                    category,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.location_on_rounded,
                                      size: 14, color: Colors.black54),
                                  const SizedBox(width: 4),
                                  Text(
                                    city,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            isActive ? 'Actif' : 'Inactif',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isActive ? Colors.green.shade700 : Colors.grey.shade700,
                            ),
                          ),
                          backgroundColor:
                              isActive ? Colors.green.shade50 : Colors.grey.shade200,
                          side: BorderSide(
                            color: isActive ? Colors.green.shade300 : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 12, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (moderationStatus != 'N/A')
                          Chip(
                            label: Text(
                              moderationStatus,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: _getModerationColor(moderationStatus)
                                .withOpacity(0.2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _toggleActiveStatus(doc.id, isActive),
                            icon: Icon(
                              isActive
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 16,
                            ),
                            label: Text(
                              isActive ? 'Désactiver' : 'Activer',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _deleteOffer(doc.id, title),
                            icon: const Icon(Icons.delete_rounded, size: 16),
                            label: const Text('Supprimer'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getModerationColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 24, color: color),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
