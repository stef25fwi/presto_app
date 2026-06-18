import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app_core.dart';
import 'trust_score_models.dart';
import 'trust_score_service.dart';
import 'package:presto_app/utils/profile_avatar_resolver.dart';

enum FoundSomeoneOnIliPrestoAction {
  searchUser,
  rateLater,
  deleteWithoutReview,
}

class CloseOfferReasonDialog extends StatefulWidget {
  const CloseOfferReasonDialog({super.key});

  static const reasons = <String>[
    'J’ai trouvé quelqu’un sur iliprestō',
    'J’ai trouvé quelqu’un ailleurs',
    'Je n’ai plus besoin',
    'Je veux modifier l’annonce',
    'Autre raison',
  ];

  @override
  State<CloseOfferReasonDialog> createState() => _CloseOfferReasonDialogState();
}

class _CloseOfferReasonDialogState extends State<CloseOfferReasonDialog> {
  String? _selectedReason;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Pourquoi souhaitez-vous supprimer cette annonce ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final reason in CloseOfferReasonDialog.reasons)
            RadioListTile<String>(
              value: reason,
              groupValue: _selectedReason,
              activeColor: kPrestoOrange,
              contentPadding: EdgeInsets.zero,
              title: Text(reason),
              onChanged: (value) => setState(() => _selectedReason = value),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrestoOrange,
            foregroundColor: Colors.white,
          ),
          onPressed: _selectedReason == null
              ? null
              : () => Navigator.of(context).pop(_selectedReason),
          child: const Text('Continuer'),
        ),
      ],
    );
  }
}

class FoundSomeoneOnIliPrestoDialog extends StatelessWidget {
  const FoundSomeoneOnIliPrestoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Vous avez trouvé quelqu’un sur iliprestō ?'),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aidez la communauté à identifier les profils fiables.'),
            SizedBox(height: 12),
            Text(
              'Recherchez l’utilisateur qui a réalisé la tâche, puis attribuez une note sur 5 étoiles selon trois critères : communication, ponctualité et qualité de la tâche effectuée.',
            ),
            SizedBox(height: 12),
            Text(
              'Votre avis sera associé à cette annonce et pourra apparaître sur le profil de l’utilisateur concerné après vérification.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context)
              .pop(FoundSomeoneOnIliPrestoAction.deleteWithoutReview),
          child: const Text('Supprimer l’annonce sans avis'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context)
              .pop(FoundSomeoneOnIliPrestoAction.rateLater),
          child: const Text('Noter plus tard'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrestoOrange,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context)
              .pop(FoundSomeoneOnIliPrestoAction.searchUser),
          icon: const Icon(Icons.search_rounded),
          label: const Text('Rechercher un utilisateur'),
        ),
      ],
    );
  }
}

class EligibleResponderSearchSheet extends StatefulWidget {
  const EligibleResponderSearchSheet({
    super.key,
    required this.offerId,
    required this.service,
  });

  final String offerId;
  final TrustScoreService service;

  @override
  State<EligibleResponderSearchSheet> createState() =>
      _EligibleResponderSearchSheetState();
}

class _EligibleResponderSearchSheetState
    extends State<EligibleResponderSearchSheet> {
  late final Future<List<EligibleResponderForReview>> _respondersFuture;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _respondersFuture = widget.service.getEligibleRespondersForReview(
      offerId: widget.offerId,
    );
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Rechercher un utilisateur',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pseudo',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: FutureBuilder<List<EligibleResponderForReview>>(
                future: _respondersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return const _TrustScoreEmptyState(
                      icon: Icons.error_outline_rounded,
                      text: 'Impossible de charger les répondants.',
                    );
                  }

                  final responders = (snapshot.data ?? const [])
                      .where((entry) =>
                          _query.isEmpty ||
                          entry.pseudo.toLowerCase().contains(_query) ||
                          entry.city.toLowerCase().contains(_query))
                      .toList(growable: false);

                  if (responders.isEmpty) {
                    return const _TrustScoreEmptyState(
                      icon: Icons.person_search_rounded,
                      text:
                          'Aucun utilisateur trouvé parmi les personnes ayant répondu à cette annonce.',
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: responders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final responder = responders[index];
                      return _ResponderTile(
                        responder: responder,
                        onTap: () => Navigator.of(context).pop(responder),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewFormDialog extends StatefulWidget {
  const ReviewFormDialog({
    super.key,
    required this.offerId,
    required this.offerTitle,
    required this.responder,
    required this.service,
  });

  final String offerId;
  final String offerTitle;
  final EligibleResponderForReview responder;
  final TrustScoreService service;

  @override
  State<ReviewFormDialog> createState() => _ReviewFormDialogState();
}

class _ReviewFormDialogState extends State<ReviewFormDialog> {
  final TextEditingController _commentController = TextEditingController();
  int? _communicationRating;
  int? _punctualityRating;
  int? _qualityRating;
  bool _confirmationChecked = false;
  bool _isSubmitting = false;
  String? _errorText;

  bool get _canSubmit =>
      !_isSubmitting &&
      _communicationRating != null &&
      _punctualityRating != null &&
      _qualityRating != null &&
      _confirmationChecked;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final result = await widget.service.submitVerifiedReview(
        offerId: widget.offerId,
        reviewedUserId: widget.responder.userId,
        communicationRating: _communicationRating!,
        punctualityRating: _punctualityRating!,
        qualityRating: _qualityRating!,
        comment: _commentController.text,
        confirmationChecked: _confirmationChecked,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = 'Impossible d’enregistrer cet avis pour le moment.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Noter l’utilisateur'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Votre avis sera lié à cette annonce et participera au Score Confiance de ce profil.',
            ),
            const SizedBox(height: 14),
            _SelectedResponderBlock(responder: widget.responder),
            const SizedBox(height: 16),
            StarRatingInput(
              label: 'Communication',
              helperText:
                  'L’utilisateur a-t-il répondu clairement et correctement ?',
              value: _communicationRating,
              onChanged: (value) =>
                  setState(() => _communicationRating = value),
            ),
            const SizedBox(height: 12),
            StarRatingInput(
              label: 'Ponctualité',
              helperText:
                  'L’utilisateur était-il à l’heure ou a-t-il respecté les délais ?',
              value: _punctualityRating,
              onChanged: (value) => setState(() => _punctualityRating = value),
            ),
            const SizedBox(height: 12),
            StarRatingInput(
              label: 'Qualité de la tâche effectuée',
              helperText:
                  'La prestation ou l’aide apportée était-elle satisfaisante ?',
              value: _qualityRating,
              onChanged: (value) => setState(() => _qualityRating = value),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _commentController,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Décrivez brièvement votre expérience.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            CheckboxListTile(
              value: _confirmationChecked,
              contentPadding: EdgeInsets.zero,
              activeColor: kPrestoBlue,
              title: const Text(
                'Je confirme que cet avis correspond à une expérience réelle liée à cette annonce.',
              ),
              onChanged: (value) =>
                  setState(() => _confirmationChecked = value == true),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(
                    const SubmitReviewResult(
                      reviewId: '',
                      status: 'rate_later',
                      averageRating: 0,
                    ),
                  ),
          child: const Text('Noter plus tard'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrestoOrange,
            foregroundColor: Colors.white,
          ),
          onPressed: _canSubmit ? _submit : null,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.verified_rounded),
          label: const Text('Publier l’avis'),
        ),
      ],
    );
  }
}

class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.label,
    required this.helperText,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String helperText;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, note sur 5',
      value: value == null ? 'Non renseignée' : '$value sur 5',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            helperText,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var index = 1; index <= 5; index++)
                IconButton(
                  tooltip: '$index sur 5',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onChanged(index),
                  icon: Icon(
                    index <= (value ?? 0)
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: index <= (value ?? 0)
                        ? const Color(0xFFFFA000)
                        : Colors.black26,
                    size: 30,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class TrustScoreCard extends StatefulWidget {
  const TrustScoreCard({
    super.key,
    required this.userId,
    this.service,
  });

  final String userId;
  final TrustScoreService? service;

  @override
  State<TrustScoreCard> createState() => _TrustScoreCardState();
}

class _TrustScoreCardState extends State<TrustScoreCard> {
  late TrustScoreService _service;
  late Future<TrustScoreProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? TrustScoreService();
    _profileFuture = _service.getUserTrustScore(userId: widget.userId);
  }

  @override
  void didUpdateWidget(covariant TrustScoreCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.service != widget.service) {
      _service = widget.service ?? TrustScoreService();
      _profileFuture = _service.getUserTrustScore(userId: widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kPrestoBlue.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FutureBuilder<TrustScoreProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _TrustScoreLoading();
          }
          if (snapshot.hasError) {
            return const _TrustScoreEmptyState(
              icon: Icons.error_outline_rounded,
              text: 'Impossible de charger les avis.',
            );
          }

          final profile = snapshot.data ??
              TrustScoreProfile(
                summary: TrustScoreSummary.empty(),
                latestReviews: const <VerifiedReviewPreview>[],
                ratingsPaidShowcaseEnabled: false,
              );
          return _TrustScoreContent(
            userId: widget.userId,
            service: _service,
            profile: profile,
            onRefresh: () {
              setState(() {
                _profileFuture =
                    _service.getUserTrustScore(userId: widget.userId);
              });
            },
          );
        },
      ),
    );
  }
}

class ReviewListPreview extends StatelessWidget {
  const ReviewListPreview({
    super.key,
    required this.userId,
    required this.reviews,
    required this.service,
    required this.onChanged,
  });

  final String userId;
  final List<VerifiedReviewPreview> reviews;
  final TrustScoreService service;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const Text(
        'Aucun avis vérifié pour le moment.',
        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
      );
    }

    final canModerateOwnReviews =
        FirebaseAuth.instance.currentUser?.uid == userId;
    return Column(
      children: [
        for (final review in reviews) ...[
          _ReviewPreviewTile(
            review: review,
            canAct: canModerateOwnReviews,
            service: service,
            onChanged: onChanged,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class ReviewReportDialog extends StatefulWidget {
  const ReviewReportDialog({
    super.key,
    required this.reviewId,
    required this.service,
  });

  final String reviewId;
  final TrustScoreService service;

  @override
  State<ReviewReportDialog> createState() => _ReviewReportDialogState();
}

class _ReviewReportDialogState extends State<ReviewReportDialog> {
  static const reasons = <String>[
    'Avis mensonger',
    'Je ne reconnais pas cette expérience',
    'Propos insultants',
    'Données personnelles affichées',
    'Autre',
  ];

  final TextEditingController _detailsController = TextEditingController();
  String? _reason;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    await widget.service.reportReview(
      reviewId: widget.reviewId,
      reason: reason,
      details: _detailsController.text,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Signaler cet avis'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final reason in reasons)
              RadioListTile<String>(
                value: reason,
                groupValue: _reason,
                activeColor: kPrestoBlue,
                contentPadding: EdgeInsets.zero,
                title: Text(reason),
                onChanged: (value) => setState(() => _reason = value),
              ),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              maxLength: 800,
              decoration: InputDecoration(
                hintText: 'Détails facultatifs',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _reason == null || _isSubmitting ? null : _submit,
          child: const Text('Signaler'),
        ),
      ],
    );
  }
}

class ReviewReplyDialog extends StatefulWidget {
  const ReviewReplyDialog({
    super.key,
    required this.reviewId,
    required this.service,
  });

  final String reviewId;
  final TrustScoreService service;

  @override
  State<ReviewReplyDialog> createState() => _ReviewReplyDialogState();
}

class _ReviewReplyDialogState extends State<ReviewReplyDialog> {
  final TextEditingController _replyController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_replyController.text.trim().isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    await widget.service.replyToReview(
      reviewId: widget.reviewId,
      replyText: _replyController.text,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Répondre à cet avis'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: TextField(
        controller: _replyController,
        maxLength: 300,
        minLines: 3,
        maxLines: 5,
        decoration: InputDecoration(
          hintText:
              'Vous pouvez répondre à cet avis de manière courte et respectueuse.',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: const Text('Publier'),
        ),
      ],
    );
  }
}

class _TrustScoreContent extends StatelessWidget {
  const _TrustScoreContent({
    required this.userId,
    required this.service,
    required this.profile,
    required this.onRefresh,
  });

  final String userId;
  final TrustScoreService service;
  final TrustScoreProfile profile;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final summary = profile.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Score Confiance iliprestō',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            IconButton(
              tooltip: 'En savoir plus sur les avis vérifiés',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const _TrustScoreInfoDialog(),
              ),
              icon: const Icon(Icons.info_outline_rounded, color: kPrestoBlue),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (summary.hasPublishedReviews) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.star_rounded,
                  color: Color(0xFFFFA000), size: 34),
              const SizedBox(width: 8),
              Text(
                '${trustScoreRatingText(summary.average)} / 5',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: kPrestoBlue,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Basé sur ${summary.publishedReviewsCount} avis vérifiés',
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const _VerifiedBadge(),
          const SizedBox(height: 12),
          _ScoreDetailLine(
            label: 'Communication',
            value: summary.communicationAverage,
          ),
          _ScoreDetailLine(
              label: 'Ponctualité', value: summary.punctualityAverage),
          _ScoreDetailLine(
            label: 'Qualité',
            value: summary.qualityAverage,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: summary.badges
                .map(
                  (badge) => Chip(
                    label: Text(trustScoreBadgeLabel(badge)),
                    backgroundColor: kPrestoBlue.withOpacity(0.08),
                    side: BorderSide(color: kPrestoBlue.withOpacity(0.18)),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          ReviewListPreview(
            userId: userId,
            reviews: profile.latestReviews,
            service: service,
            onChanged: onRefresh,
          ),
        ] else ...[
          const _TrustScoreEmptyState(
            icon: Icons.verified_user_outlined,
            text: 'Aucun avis vérifié pour le moment.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Les avis apparaissent uniquement après une expérience réelle liée à une annonce iliprestō.',
            style:
                TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

class _ReviewPreviewTile extends StatelessWidget {
  const _ReviewPreviewTile({
    required this.review,
    required this.canAct,
    required this.service,
    required this.onChanged,
  });

  final VerifiedReviewPreview review;
  final bool canAct;
  final TrustScoreService service;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded,
                  color: Color(0xFFFFA000), size: 20),
              const SizedBox(width: 4),
              Text(
                '${trustScoreRatingText(review.averageRating)} / 5',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              const _SmallVerifiedBadge(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            review.offerTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (review.createdAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _formatDate(review.createdAt!),
                style: const TextStyle(color: Colors.black45, fontSize: 12),
              ),
            ),
          if ((review.comment ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(review.comment!),
            ),
          if (canAct) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final changed = await showDialog<bool>(
                      context: context,
                      builder: (_) => ReviewReplyDialog(
                        reviewId: review.reviewId,
                        service: service,
                      ),
                    );
                    if (changed == true) onChanged();
                  },
                  icon: const Icon(Icons.reply_rounded),
                  label: const Text('Répondre'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final changed = await showDialog<bool>(
                      context: context,
                      builder: (_) => ReviewReportDialog(
                        reviewId: review.reviewId,
                        service: service,
                      ),
                    );
                    if (changed == true) onChanged();
                  },
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Signaler'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ResponderTile extends StatelessWidget {
  const _ResponderTile({required this.responder, required this.onTap});

  final EligibleResponderForReview responder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            _ResponderAvatar(responder: responder),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    responder.pseudo,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if (responder.city.isNotEmpty)
                    Text(
                      responder.city,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  if (responder.responseAt != null)
                    Text(
                      'Réponse le ${_formatDate(responder.responseAt!)}',
                      style:
                          const TextStyle(color: Colors.black45, fontSize: 12),
                    ),
                  const SizedBox(height: 5),
                  const _ResponderBadge(),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _SelectedResponderBlock extends StatelessWidget {
  const _SelectedResponderBlock({required this.responder});

  final EligibleResponderForReview responder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPrestoBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _ResponderAvatar(responder: responder),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  responder.pseudo,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (responder.city.isNotEmpty) Text(responder.city),
                if (responder.responseAt != null)
                  Text(
                    'Réponse le ${_formatDate(responder.responseAt!)}',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponderAvatar extends StatelessWidget {
  const _ResponderAvatar({required this.responder});

  final EligibleResponderForReview responder;

  @override
  Widget build(BuildContext context) {
    final photoUrl = responder.photoUrl;
    return CircleAvatar(
      radius: 24,
      backgroundColor: kPrestoBlue.withOpacity(0.12),
      backgroundImage:
          photoUrl == null ? null : profileAvatarImageProvider(photoUrl),
      child: photoUrl == null
          ? Text(
              responder.pseudo.isEmpty
                  ? '?'
                  : responder.pseudo[0].toUpperCase(),
              style: const TextStyle(
                color: kPrestoBlue,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }
}

class _ScoreDetailLine extends StatelessWidget {
  const _ScoreDetailLine({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            trustScoreRatingText(value),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kPrestoBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: Colors.white, size: 16),
          SizedBox(width: 6),
          Text(
            'Avis vérifié iliprestō',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SmallVerifiedBadge extends StatelessWidget {
  const _SmallVerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kPrestoBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Avis vérifié',
        style: TextStyle(
          color: kPrestoBlue,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ResponderBadge extends StatelessWidget {
  const _ResponderBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kPrestoBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'A répondu à cette annonce',
        style: TextStyle(
          color: kPrestoBlue,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TrustScoreLoading extends StatelessWidget {
  const _TrustScoreLoading();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 10),
        Text('Chargement du Score Confiance...'),
      ],
    );
  }
}

class _TrustScoreEmptyState extends StatelessWidget {
  const _TrustScoreEmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: kPrestoBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustScoreInfoDialog extends StatelessWidget {
  const _TrustScoreInfoDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Comment fonctionne le Score Confiance iliprestō ?'),
      content: const SingleChildScrollView(
        child: Text(
          'Le Score Confiance iliprestō repose sur des avis liés à des annonces réelles. Un utilisateur ne peut être noté que s’il a répondu à une annonce et que l’annonceur indique avoir trouvé quelqu’un via iliprestō.\n\n'
          'Les avis sont calculés à partir de trois critères : communication, ponctualité et qualité de la tâche effectuée.\n\n'
          'Chaque avis peut être signalé en cas de doute ou de contenu abusif.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
