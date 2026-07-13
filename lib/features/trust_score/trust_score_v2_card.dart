import 'package:flutter/material.dart';

import '../../app_core.dart';
import 'trust_score_models.dart';
import 'trust_score_service.dart';

class TrustScoreV2Card extends StatefulWidget {
  const TrustScoreV2Card({
    super.key,
    required this.userId,
    this.service,
  });

  final String userId;
  final TrustScoreService? service;

  @override
  State<TrustScoreV2Card> createState() => _TrustScoreV2CardState();
}

class _TrustScoreV2CardState extends State<TrustScoreV2Card> {
  late TrustScoreService _service;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? TrustScoreService();
    _future = _service.getUserTrustScoreV2(userId: widget.userId);
  }

  @override
  void didUpdateWidget(covariant TrustScoreV2Card oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId || oldWidget.service != widget.service) {
      _service = widget.service ?? TrustScoreService();
      _future = _service.getUserTrustScoreV2(userId: widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _TrustScoreV2Shell(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return const _TrustScoreV2Shell(
            child: _TrustScoreV2EmptyState(
              icon: Icons.error_outline_rounded,
              text: 'Impossible de charger les avis.',
            ),
          );
        }

        final data = snapshot.data ?? const <String, dynamic>{};
        final score = _TrustScoreV2Summary.fromMap(
          _stringMap(data['trustScoreV2']),
        );
        final reviews = _reviewsFrom(data['latestReviews']);
        return _TrustScoreV2Shell(
          child: Column(
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
                    tooltip: 'Actualiser',
                    onPressed: () {
                      setState(() {
                        _future = _service.getUserTrustScoreV2(
                          userId: widget.userId,
                        );
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded, color: kPrestoBlue),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _GlobalTrustBlock(score: score),
              const SizedBox(height: 12),
              _RoleScoreTile(
                icon: Icons.handyman_rounded,
                title: 'Comme prestataire',
                subtitle: 'Qualité, ponctualité, communication',
                role: score.provider,
              ),
              const SizedBox(height: 10),
              _RoleScoreTile(
                icon: Icons.assignment_ind_rounded,
                title: 'Comme annonceur',
                subtitle: 'Clarté de la demande, respect, fiabilité',
                role: score.requester,
              ),
              const SizedBox(height: 14),
              const Text(
                'Derniers avis vérifiés',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (reviews.isEmpty)
                const _TrustScoreV2EmptyState(
                  icon: Icons.verified_user_outlined,
                  text:
                      'Aucun avis vérifié pour le moment. Les avis apparaissent uniquement après une expérience réelle liée à une annonce.',
                )
              else
                ...reviews.map(
                  (review) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReviewV2Tile(review: review),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TrustScoreV2Shell extends StatelessWidget {
  const _TrustScoreV2Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kPrestoBlue.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GlobalTrustBlock extends StatelessWidget {
  const _GlobalTrustBlock({required this.score});

  final _TrustScoreV2Summary score;

  @override
  Widget build(BuildContext context) {
    final hasReviews = score.globalReviewsCount > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPrestoBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: kPrestoBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasReviews
                      ? '${trustScoreRatingText(score.globalAverage)} / 5'
                      : 'Nouveau profil',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: kPrestoBlue,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${score.globalScore100}/100',
                  style: const TextStyle(
                    color: kPrestoBlue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasReviews
                ? 'Basé sur ${score.globalReviewsCount} avis vérifiés. La note fiable est pondérée pour éviter qu’un seul avis 5/5 surclasse un profil déjà confirmé.'
                : 'Le score se construit avec des avis vérifiés liés aux annonces et aux conversations iliprestō.',
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleScoreTile extends StatelessWidget {
  const _RoleScoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.role,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _RoleTrustScore role;

  @override
  Widget build(BuildContext context) {
    final hasReviews = role.reviewsCount > 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: kPrestoBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                hasReviews ? '${trustScoreRatingText(role.average)} / 5' : '—',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasReviews
                ? '${role.reviewsCount} avis · note fiable ${trustScoreRatingText(role.reliableAverage)} / 5 · ${role.score100}/100'
                : 'Aucun avis dans ce rôle.',
            style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
          ),
          if (role.badges.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: role.badges
                  .map(
                    (badge) => Chip(
                      label: Text(trustScoreBadgeLabel(badge)),
                      backgroundColor: kPrestoBlue.withValues(alpha: 0.08),
                      side: BorderSide(color: kPrestoBlue.withValues(alpha: 0.16)),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewV2Tile extends StatelessWidget {
  const _ReviewV2Tile({required this.review});

  final VerifiedReviewPreview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFFFA000), size: 20),
              const SizedBox(width: 4),
              Text(
                '${trustScoreRatingText(review.averageRating)} / 5',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kPrestoBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  review.roleLabel,
                  style: const TextStyle(
                    color: kPrestoBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(review.offerTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
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
          if ((review.replyText ?? '').trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrestoBlue.withValues(alpha: 0.12)),
              ),
              child: Text(
                'Réponse : ${review.replyText!}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrustScoreV2EmptyState extends StatelessWidget {
  const _TrustScoreV2EmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Icon(icon, color: Colors.black38, size: 34),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TrustScoreV2Summary {
  const _TrustScoreV2Summary({
    required this.provider,
    required this.requester,
    required this.globalAverage,
    required this.globalReviewsCount,
    required this.globalScore100,
  });

  final _RoleTrustScore provider;
  final _RoleTrustScore requester;
  final double globalAverage;
  final int globalReviewsCount;
  final int globalScore100;

  factory _TrustScoreV2Summary.fromMap(Map<String, dynamic> data) {
    final global = _stringMap(data['global']);
    return _TrustScoreV2Summary(
      provider: _RoleTrustScore.fromMap(_stringMap(data['provider'])),
      requester: _RoleTrustScore.fromMap(_stringMap(data['requester'])),
      globalAverage: _doubleValue(global['average']),
      globalReviewsCount: _intValue(global['reviewsCount']),
      globalScore100: _intValue(global['score100']),
    );
  }
}

class _RoleTrustScore {
  const _RoleTrustScore({
    required this.average,
    required this.reliableAverage,
    required this.score100,
    required this.reviewsCount,
    required this.badges,
  });

  final double average;
  final double reliableAverage;
  final int score100;
  final int reviewsCount;
  final List<String> badges;

  factory _RoleTrustScore.fromMap(Map<String, dynamic> data) {
    return _RoleTrustScore(
      average: _doubleValue(data['average']),
      reliableAverage: _doubleValue(data['reliableAverage']),
      score100: _intValue(data['score100']),
      reviewsCount: _intValue(data['reviewsCount']),
      badges: _stringList(data['badges']),
    );
  }
}

List<VerifiedReviewPreview> _reviewsFrom(dynamic value) {
  if (value is! List) return const <VerifiedReviewPreview>[];
  return value
      .map(_stringMap)
      .map(VerifiedReviewPreview.fromMap)
      .toList(growable: false);
}

Map<String, dynamic> _stringMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, rawValue) => MapEntry(key.toString(), rawValue));
  }
  return const <String, dynamic>{};
}

double _doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString()) ?? 0;
}

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
