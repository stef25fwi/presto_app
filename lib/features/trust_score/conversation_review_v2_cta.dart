import 'package:flutter/material.dart';

import '../../app_core.dart';
import '../../pages/account/mes_avis_page.dart';
import 'trust_score_service.dart';

class ConversationReviewV2Cta extends StatefulWidget {
  const ConversationReviewV2Cta({
    super.key,
    required this.conversationId,
    this.service,
  });

  final String conversationId;
  final TrustScoreService? service;

  @override
  State<ConversationReviewV2Cta> createState() =>
      _ConversationReviewV2CtaState();
}

class _ConversationReviewV2CtaState extends State<ConversationReviewV2Cta> {
  late TrustScoreService _service;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? TrustScoreService();
    _future = _service.getPendingReviewTasks();
  }

  @override
  void didUpdateWidget(covariant ConversationReviewV2Cta oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId ||
        oldWidget.service != widget.service) {
      _service = widget.service ?? TrustScoreService();
      _future = _service.getPendingReviewTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversationId = widget.conversationId.trim();
    if (conversationId.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final matching = snapshot.data!.where((task) {
          return (task['conversationId'] ?? '').toString().trim() ==
              conversationId;
        }).toList(growable: false);
        if (matching.isEmpty) return const SizedBox.shrink();

        final hasReciprocal = matching.any(
          (task) => (task['type'] ?? '').toString() == 'reciprocal',
        );
        final hasCorrection = matching.any(
          (task) => (task['type'] ?? '').toString() == 'correction',
        );
        final message = hasCorrection
            ? 'Un avis lié à cette conversation doit être corrigé.'
            : hasReciprocal
                ? 'Vous pouvez maintenant noter l’annonceur de cette mission.'
                : 'Une notation liée à cette conversation est en attente.';

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(8, 6, 8, 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: kPrestoOrange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: kPrestoOrange.withValues(alpha: 0.24),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.star_rounded, color: kPrestoOrange),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kPrestoOrange,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () =>
                    Navigator.of(context).pushNamed(MesAvisPage.routeName),
                child: const Text('Noter'),
              ),
            ],
          ),
        );
      },
    );
  }
}
