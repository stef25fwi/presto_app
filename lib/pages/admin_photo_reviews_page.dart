import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../app_core.dart';
import '../services/firebase_functions_region.dart';
import '../utils/friendly_snackbar.dart';

class AdminPhotoReviewsPage extends StatefulWidget {
  const AdminPhotoReviewsPage({super.key});

  @override
  State<AdminPhotoReviewsPage> createState() => _AdminPhotoReviewsPageState();
}

class _AdminPhotoReviewsPageState extends State<AdminPhotoReviewsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = prestoFirebaseFunctions;
  final Set<String> _busyReviewIds = <String>{};

  Future<void> _submitDecision({
    required String reviewId,
    required String decision,
    String? reason,
  }) async {
    if (_busyReviewIds.contains(reviewId)) {
      return;
    }

    setState(() {
      _busyReviewIds.add(reviewId);
    });

    try {
      final callable = _functions.httpsCallable(
        'reviewListingPhoto',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      await callable.call(<String, dynamic>{
        'reviewId': reviewId,
        'decision': decision,
        'reason': reason,
      });

      if (!mounted) return;
      if (decision == 'approved') {
        showSuccessSnackBar(context, 'Photo acceptée');
      } else {
        showSuccessSnackBar(context, 'Photo refusée');
      }
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        error.message ?? 'Impossible de traiter cette photo pour le moment.',
      );
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        'Impossible de traiter cette photo pour le moment.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyReviewIds.remove(reviewId);
        });
      }
    }
  }

  Future<String?> _askRejectionReason() async {
    const predefinedReasons = <String>[
      'Image inappropriée',
      'Image non conforme',
      'Texte interdit visible',
      'Contenu suspect',
      'Autre',
    ];
    final controller = TextEditingController();
    String selected = predefinedReasons.first;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Motif du refus'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    items: predefinedReasons
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selected = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Précision optionnelle',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final extra = controller.text.trim();
                    Navigator.of(dialogContext).pop(
                      extra.isEmpty ? selected : '$selected — $extra',
                    );
                  },
                  child: const Text('Refuser'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<bool> _handleSwipe({
    required _PhotoReviewItem item,
    required DismissDirection direction,
  }) async {
    if (_busyReviewIds.contains(item.reviewId)) {
      return false;
    }

    if (direction == DismissDirection.startToEnd) {
      await _submitDecision(
        reviewId: item.reviewId,
        decision: 'approved',
      );
      return false;
    }

    final reason = await _askRejectionReason();
    if (reason == null || reason.trim().isEmpty) {
      return false;
    }

    await _submitDecision(
      reviewId: item.reviewId,
      decision: 'rejected',
      reason: reason,
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Photos à valider'),
        backgroundColor: Colors.white,
        foregroundColor: kPrestoBlue,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('listingPhotoReviews')
            .where('status', isEqualTo: 'pending')
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Impossible de charger les photos à valider.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = (snapshot.data?.docs ?? const [])
              .map(_PhotoReviewItem.fromSnapshot)
              .toList(growable: false)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.verified_outlined, size: 56, color: kPrestoBlue),
                    SizedBox(height: 14),
                    Text(
                      'Aucune photo en attente de validation.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = docs[index];
              final isBusy = _busyReviewIds.contains(item.reviewId);
              return Dismissible(
                key: ValueKey<String>(item.reviewId),
                direction: isBusy
                    ? DismissDirection.none
                    : DismissDirection.horizontal,
                confirmDismiss: (direction) => _handleSwipe(
                  item: item,
                  direction: direction,
                ),
                background: _SwipeActionBackground(
                  color: const Color(0xFF16A34A),
                  icon: Icons.check_rounded,
                  alignment: Alignment.centerLeft,
                  label: 'Accepter',
                ),
                secondaryBackground: _SwipeActionBackground(
                  color: const Color(0xFFDC2626),
                  icon: Icons.close_rounded,
                  alignment: Alignment.centerRight,
                  label: 'Refuser',
                ),
                child: _PhotoReviewCard(
                  item: item,
                  isBusy: isBusy,
                  onApprove: () => _submitDecision(
                    reviewId: item.reviewId,
                    decision: 'approved',
                  ),
                  onReject: () async {
                    final reason = await _askRejectionReason();
                    if (reason == null || reason.trim().isEmpty) {
                      return;
                    }
                    await _submitDecision(
                      reviewId: item.reviewId,
                      decision: 'rejected',
                      reason: reason,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PhotoReviewItem {
  const _PhotoReviewItem({
    required this.reviewId,
    required this.listingId,
    required this.listingTitle,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.reason,
    required this.createdAt,
    required this.detectedText,
    required this.safeSearchSummary,
  });

  final String reviewId;
  final String listingId;
  final String listingTitle;
  final String imageUrl;
  final String thumbnailUrl;
  final String reason;
  final DateTime createdAt;
  final String detectedText;
  final String safeSearchSummary;

  factory _PhotoReviewItem.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final safeSearch = (data['safeSearch'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final summary = (safeSearch['summary'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final createdRaw = data['createdAt'];
    final createdAt =
        createdRaw is Timestamp ? createdRaw.toDate() : DateTime.now();

    return _PhotoReviewItem(
      reviewId: snapshot.id,
      listingId: (data['listingId'] ?? '').toString().trim(),
      listingTitle: ((data['listingTitle'] ?? '').toString().trim().isEmpty
              ? data['listingId']
              : data['listingTitle'])
          .toString()
          .trim(),
      imageUrl: (data['imageUrl'] ?? '').toString().trim(),
      thumbnailUrl: (data['thumbnailUrl'] ?? '').toString().trim(),
      reason: (data['reason'] ?? '').toString().trim(),
      createdAt: createdAt,
      detectedText: (data['detectedText'] ?? '').toString().trim(),
      safeSearchSummary: summary.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join(' · '),
    );
  }
}

class _PhotoReviewCard extends StatelessWidget {
  const _PhotoReviewCard({
    required this.item,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  final _PhotoReviewItem item;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final imageSource =
        item.imageUrl.isNotEmpty ? item.imageUrl : item.thumbnailUrl;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: imageSource.isEmpty
                    ? Container(
                        color: const Color(0xFFF3F4F6),
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_outlined),
                      )
                    : Image.network(
                        imageSource,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF3F4F6),
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              item.listingTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Glissez à droite pour accepter, à gauche pour refuser',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ReviewInfoPill(
                  icon: Icons.flag_outlined,
                  label: item.reason.isEmpty
                      ? 'Revue manuelle requise'
                      : item.reason,
                ),
                if (item.safeSearchSummary.isNotEmpty)
                  _ReviewInfoPill(
                    icon: Icons.shield_outlined,
                    label: item.safeSearchSummary,
                  ),
              ],
            ),
            if (item.detectedText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Texte OCR détecté',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(item.detectedText),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Refuser'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB42318),
                      side: const BorderSide(color: Color(0xFFFDA29B)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isBusy ? null : onApprove,
                    icon: isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Accepter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A73E8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
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

class _ReviewInfoPill extends StatelessWidget {
  const _ReviewInfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: kPrestoBlue),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.color,
    required this.icon,
    required this.alignment,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final Alignment alignment;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      child: Row(
        mainAxisAlignment: alignment == Alignment.centerLeft
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (alignment == Alignment.centerRight)
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (alignment == Alignment.centerRight) const SizedBox(width: 8),
          Icon(icon, color: Colors.white),
          if (alignment == Alignment.centerLeft) const SizedBox(width: 8),
          if (alignment == Alignment.centerLeft)
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}
