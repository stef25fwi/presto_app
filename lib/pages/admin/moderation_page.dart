import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/friendly_snackbar.dart';

const Color kPrestoOrange = Color(0xFFFF6600);

class ModerationPage extends StatefulWidget {
  const ModerationPage({super.key});

  @override
  State<ModerationPage> createState() => _ModerationPageState();
}

class _ModerationPageState extends State<ModerationPage> {
  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _rejectedCount = 0;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // Nombre d'annonces rejetées
      final rejectedSnap = await _firestore
          .collection('offers')
          .where('moderation.status', isEqualTo: 'REJECTED')
          .get();

      // Nombre d'annonces en attente
      final pendingSnap = await _firestore
          .collection('offers')
          .where('moderation.status', isEqualTo: 'PENDING')
          .get();

      if (mounted) {
        setState(() {
          _rejectedCount = rejectedSnap.docs.length;
          _pendingCount = pendingSnap.docs.length;
        });
      }
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
          'Modération des annonces',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
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
              // Stats cards
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'En attente',
                      value: _pendingCount.toString(),
                      color: Colors.orange,
                      icon: Icons.hourglass_bottom_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Rejetées',
                      value: _rejectedCount.toString(),
                      color: Colors.red,
                      icon: Icons.close_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Pending offers
              Text(
                'Annonces en attente de validation',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore
                    .collection('offers')
                    .where('moderation.status', isEqualTo: 'PENDING')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(kPrestoOrange),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: const Center(
                        child: Text(
                          'Aucune annonce en attente',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data();
                      return _ModerationOfferCard(
                        offerId: doc.id,
                        data: data,
                        onApprove: () => _approveOffer(doc.id),
                        onReject: () => _rejectOffer(doc.id),
                        onRefresh: _loadStats,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),

              // Rejected offers
              Text(
                'Annonces rejetées',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore
                    .collection('offers')
                    .where('moderation.status', isEqualTo: 'REJECTED')
                    .orderBy('moderation.checkedAt', descending: true)
                    .limit(10)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(kPrestoOrange),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: const Center(
                        child: Text(
                          'Aucune annonce rejetée',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data();
                      return _RejectedOfferCard(data: data);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approveOffer(String offerId) async {
    try {
      await _firestore.collection('offers').doc(offerId).update({
        'moderation.status': 'APPROVED',
        'moderation.checkedAt': FieldValue.serverTimestamp(),
        'visibility.isPublic': true,
        'visibility.publishedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      if (!mounted) return;
      showSuccessSnackBar(context, 'Annonce approuvée ✅');
      _loadStats();
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, 'Erreur: $e');
    }
  }

  Future<void> _rejectOffer(String offerId) async {
    final reason = await _showRejectDialog();
    if (reason == null) return;

    try {
      final offerSnap = await _firestore.collection('offers').doc(offerId).get();
      final offerData = offerSnap.data() ?? {};
      final userId = offerData['userId'] ?? offerData['uid'];

      // Mettre l'annonce en attente de validation
      await _firestore.collection('offers').doc(offerId).update({
        'moderation.status': 'REJECTED',
        'moderation.checkedAt': FieldValue.serverTimestamp(),
        'moderation.reason': reason,
        'moderation.userMessage':
            'Votre annonce ne respecte pas nos conditions d\'utilisation. Raison: $reason',
        'visibility.isPublic': false,
        'status': 'pending_moderation',
      });

      // Envoyer un message interne
      if (userId != null) {
        await _firestore.collection('notifications').add({
          'userId': userId,
          'offerId': offerId,
          'type': 'MODERATION_WARNING',
          'title': 'Annonce non conforme',
          'message':
              'Votre annonce n\'a pas été publiée car elle ne respecte pas nos CGU. Raison: $reason',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Envoyer un mail
        // TODO: Implémenter l'envoi de mail via Cloud Function
      }

      if (!mounted) return;
      showSuccessSnackBar(context, 'Annonce rejetée et utilisateur notifié ✅');
      _loadStats();
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, 'Erreur: $e');
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Raison du rejet'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Ex: Contenu offensant, prix abusif, etc.',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    return result;
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModerationOfferCard extends StatelessWidget {
  final String offerId;
  final Map<String, dynamic> data;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRefresh;

  const _ModerationOfferCard({
    required this.offerId,
    required this.data,
    required this.onApprove,
    required this.onReject,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? 'Sans titre') as String;
    final description = (data['description'] ?? '') as String;
    final city = (data['city'] ?? 'Lieu non précisé') as String;
    final category = (data['category'] ?? 'Catégorie inconnue') as String;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$category • $city',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Text(
                  'En attente',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: onReject,
                  label: const Text('Rejeter'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 16),
                  onPressed: onApprove,
                  label: const Text('Approuver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RejectedOfferCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _RejectedOfferCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? 'Sans titre') as String;
    final moderationData = (data['moderation'] as Map<String, dynamic>?) ?? {};
    final reason = (moderationData['reason'] ?? 'Raison non précisée') as String;
    final userMessage = (moderationData['userMessage'] ?? '') as String;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Text(
                  'Rejetée',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Raison: $reason',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (userMessage.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              userMessage,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
