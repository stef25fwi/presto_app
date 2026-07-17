import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../app_core.dart';
import '../services/firebase_functions_region.dart';
import '../utils/friendly_snackbar.dart';

part 'admin_photo_reviews_widgets.dart';

typedef AdminPhotoReviewDecision = Future<void> Function({
  required String reviewId,
  required String decision,
  String? reason,
});

class AdminPhotoReviewsPage extends StatefulWidget {
  final Stream<List<Map<String, dynamic>>>? reviewsStream;
  final AdminPhotoReviewDecision? onDecision;

  const AdminPhotoReviewsPage({
    super.key,
    this.reviewsStream,
    this.onDecision,
  });

  @override
  State<AdminPhotoReviewsPage> createState() => _AdminPhotoReviewsPageState();
}

class _AdminPhotoReviewsPageState extends State<AdminPhotoReviewsPage> {
  final Set<String> _busyReviewIds = <String>{};

  Stream<List<Map<String, dynamic>>> _watchReviews() {
    return FirebaseFirestore.instance
        .collection('listingPhotoReviews')
        .where('status', isEqualTo: 'pending')
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => <String, dynamic>{
                  ...document.data(),
                  '_reviewId': document.id,
                },
              )
              .toList(growable: false),
        );
  }

  Future<void> _callDecision({
    required String reviewId,
    required String decision,
    String? reason,
  }) async {
    final injectedDecision = widget.onDecision;
    if (injectedDecision != null) {
      await injectedDecision(
        reviewId: reviewId,
        decision: decision,
        reason: reason,
      );
      return;
    }

    final callable = prestoFirebaseFunctions.httpsCallable(
      'reviewListingPhoto',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    await callable.call(<String, dynamic>{
      'reviewId': reviewId,
      'decision': decision,
      'reason': reason,
    });
  }

  Future<void> _submitDecision({
    required String reviewId,
    required String decision,
    String? reason,
  }) async {
    if (_busyReviewIds.contains(reviewId)) {
      return;
    }

    setState(() => _busyReviewIds.add(reviewId));

    try {
      await _callDecision(
        reviewId: reviewId,
        decision: decision,
        reason: reason,
      );

      if (!mounted) return;
      showSuccessSnackBar(
        context,
        decision == 'approved' ? 'Photo acceptée' : 'Photo refusée',
      );
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
        setState(() => _busyReviewIds.remove(reviewId));
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
                      setDialogState(() => selected = value);
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
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: widget.reviewsStream ?? _watchReviews(),
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

          final reviews = (snapshot.data ?? const <Map<String, dynamic>>[])
              .map(_PhotoReviewItem.fromMap)
              .toList(growable: false)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (reviews.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = reviews[index];
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
                background: const _SwipeActionBackground(
                  color: Color(0xFF16A34A),
                  icon: Icons.check_rounded,
                  alignment: Alignment.centerLeft,
                  label: 'Accepter',
                ),
                secondaryBackground: const _SwipeActionBackground(
                  color: Color(0xFFDC2626),
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

  factory _PhotoReviewItem.fromMap(Map<String, dynamic> data) {
    final safeSearch = (data['safeSearch'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final summary = (safeSearch['summary'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final createdRaw = data['createdAt'];
    final createdAt = switch (createdRaw) {
      Timestamp value => value.toDate(),
      DateTime value => value,
      String value => DateTime.tryParse(value) ?? DateTime.now(),
      _ => DateTime.now(),
    };
    final listingId = (data['listingId'] ?? '').toString().trim();
    final rawTitle = (data['listingTitle'] ?? '').toString().trim();

    return _PhotoReviewItem(
      reviewId: (data['_reviewId'] ?? data['reviewId'] ?? '').toString().trim(),
      listingId: listingId,
      listingTitle: rawTitle.isEmpty ? listingId : rawTitle,
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
