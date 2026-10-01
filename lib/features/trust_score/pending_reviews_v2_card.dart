import 'package:flutter/material.dart';

import '../../app_core.dart';
import '../../services/app_route_parser.dart';
import 'trust_score_models.dart';
import 'trust_score_service.dart';
import 'trust_score_widgets.dart';

class PendingReviewsV2Card extends StatefulWidget {
  const PendingReviewsV2Card({
    super.key,
    this.service,
  });

  final TrustScoreService? service;

  @override
  State<PendingReviewsV2Card> createState() => _PendingReviewsV2CardState();
}

class _PendingReviewsV2CardState extends State<PendingReviewsV2Card> {
  late TrustScoreService _service;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? TrustScoreService();
    _future = _service.getPendingReviewTasks();
  }

  @override
  void didUpdateWidget(covariant PendingReviewsV2Card oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      _service = widget.service ?? TrustScoreService();
      _reload();
    }
  }

  void _reload() {
    setState(() => _future = _service.getPendingReviewTasks());
  }

  Future<void> _openRateLater(_PendingReviewTask task) async {
    final responder = await showModalBottomSheet<EligibleResponderForReview>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => EligibleResponderSearchSheet(
        offerId: task.offerId,
        service: _service,
      ),
    );
    if (responder == null || !mounted) return;

    final result = await showDialog<SubmitReviewResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReviewFormDialog(
        offerId: task.offerId,
        offerTitle: task.offerTitle,
        responder: responder,
        service: _service,
      ),
    );
    if (result == null || result.isRateLater || !mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isPublished
              ? 'Avis publié. Le Score Confiance a été recalculé.'
              : 'Avis enregistré. Il sera publié selon le flow de vérification.',
        ),
      ),
    );
  }

  Future<void> _openReciprocal(_PendingReviewTask task) async {
    final result = await showDialog<SubmitReviewResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReciprocalReviewDialog(
        task: task,
        service: _service,
      ),
    );
    if (result == null || !mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isPublished
              ? 'Les avis réciproques sont publiés.'
              : 'Votre avis a été enregistré.',
        ),
      ),
    );
  }

  Future<void> _openCorrection(_PendingReviewTask task) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReviewCorrectionDialog(
        task: task,
        service: _service,
      ),
    );
    if (changed == true && mounted) {
      _reload();
    }
  }

  Future<void> _dismissRateLater(_PendingReviewTask task) async {
    await _service.dismissPendingReviewTask(offerId: task.offerId);
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cette demande de notation a été retirée.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError;
        final tasks = (snapshot.data ?? const <Map<String, dynamic>>[])
            .map(_PendingReviewTask.fromMap)
            .where((task) => task.offerId.isNotEmpty || task.reviewId.isNotEmpty)
            .toList(growable: false);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kPrestoOrange.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: kPrestoOrange.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.rate_review_rounded,
                        color: kPrestoOrange),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Avis à donner',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Retrouvez ici les avis à compléter ou à corriger.',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualiser',
                    onPressed: isLoading ? null : _reload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (hasError)
                _PendingReviewInfo(
                  icon: Icons.error_outline_rounded,
                  text: 'Impossible de charger les avis à donner.',
                  actionLabel: 'Réessayer',
                  onAction: _reload,
                )
              else if (tasks.isEmpty)
                const _PendingReviewInfo(
                  icon: Icons.task_alt_rounded,
                  text: 'Aucun avis en attente. Tout est à jour.',
                )
              else
                ...tasks.map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PendingReviewTile(
                      task: task,
                      onPrimary: () {
                        switch (task.type) {
                          case 'reciprocal':
                            _openReciprocal(task);
                            break;
                          case 'correction':
                            _openCorrection(task);
                            break;
                          default:
                            _openRateLater(task);
                        }
                      },
                      onConversation: task.conversationId.isEmpty
                          ? null
                          : () => Navigator.of(context).pushNamed(
                                buildMessagesRoute(
                                  conversationId: task.conversationId,
                                ),
                              ),
                      onDismiss: task.type == 'rate_later'
                          ? () => _dismissRateLater(task)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PendingReviewTile extends StatelessWidget {
  const _PendingReviewTile({
    required this.task,
    required this.onPrimary,
    this.onConversation,
    this.onDismiss,
  });

  final _PendingReviewTask task;
  final VoidCallback onPrimary;
  final VoidCallback? onConversation;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final isReciprocal = task.type == 'reciprocal';
    final isCorrection = task.type == 'correction';
    final title = isCorrection
        ? 'Avis à corriger'
        : isReciprocal
            ? 'À votre tour de noter ${task.reviewedUserName.isEmpty ? 'l’annonceur' : task.reviewedUserName}'
            : 'Notation mise de côté';
    final subtitle = isCorrection
        ? task.correctionMessage
        : isReciprocal
            ? 'Vous avez reçu un avis lié à cette annonce. Votre avis réciproque permet de finaliser le flow.'
            : 'Vous aviez choisi « Noter plus tard ». Sélectionnez maintenant la personne qui a réalisé la mission.';
    final actionLabel = isCorrection
        ? 'Corriger l’avis'
        : isReciprocal
            ? 'Noter l’annonceur'
            : 'Noter maintenant';

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
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            task.offerTitle,
            style: const TextStyle(
              color: kPrestoBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrestoOrange,
                  foregroundColor: Colors.white,
                ),
                onPressed: onPrimary,
                icon: Icon(isCorrection
                    ? Icons.edit_rounded
                    : Icons.star_rounded),
                label: Text(actionLabel),
              ),
              if (onConversation != null)
                OutlinedButton.icon(
                  onPressed: onConversation,
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Conversation'),
                ),
              if (onDismiss != null)
                TextButton(
                  onPressed: onDismiss,
                  child: const Text('Ne pas noter'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReciprocalReviewDialog extends StatefulWidget {
  const _ReciprocalReviewDialog({
    required this.task,
    required this.service,
  });

  final _PendingReviewTask task;
  final TrustScoreService service;

  @override
  State<_ReciprocalReviewDialog> createState() =>
      _ReciprocalReviewDialogState();
}

class _ReciprocalReviewDialogState extends State<_ReciprocalReviewDialog> {
  final TextEditingController _commentController = TextEditingController();
  int? _communication;
  int? _punctuality;
  int? _clarity;
  int? _courtesy;
  int? _paymentRespect;
  bool _confirmed = false;
  bool _submitting = false;
  String? _error;

  bool get _canSubmit =>
      !_submitting &&
      _communication != null &&
      _punctuality != null &&
      _clarity != null &&
      _courtesy != null &&
      _paymentRespect != null &&
      _confirmed;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await widget.service.submitMutualVerifiedReview(
        offerId: widget.task.offerId,
        reviewedUserId: widget.task.reviewedUserId,
        reviewerRole: 'provider',
        reviewedRole: 'requester',
        criteria: <String, int>{
          'communication': _communication!,
          'punctuality': _punctuality!,
          'clarity': _clarity!,
          'courtesy': _courtesy!,
          'paymentRespect': _paymentRespect!,
        },
        comment: _commentController.text,
        confirmationChecked: _confirmed,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Impossible d’enregistrer cet avis pour le moment.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Noter l’annonceur'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.task.reviewedUserName.isEmpty
                  ? widget.task.offerTitle
                  : '${widget.task.reviewedUserName} · ${widget.task.offerTitle}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            StarRatingInput(
              label: 'Communication',
              helperText: 'Les échanges étaient-ils clairs et respectueux ?',
              value: _communication,
              onChanged: (value) => setState(() => _communication = value),
            ),
            const SizedBox(height: 10),
            StarRatingInput(
              label: 'Ponctualité',
              helperText: 'Les horaires et délais ont-ils été respectés ?',
              value: _punctuality,
              onChanged: (value) => setState(() => _punctuality = value),
            ),
            const SizedBox(height: 10),
            StarRatingInput(
              label: 'Clarté de la demande',
              helperText: 'La mission était-elle expliquée clairement ?',
              value: _clarity,
              onChanged: (value) => setState(() => _clarity = value),
            ),
            const SizedBox(height: 10),
            StarRatingInput(
              label: 'Courtoisie',
              helperText: 'La relation est-elle restée correcte et respectueuse ?',
              value: _courtesy,
              onChanged: (value) => setState(() => _courtesy = value),
            ),
            const SizedBox(height: 10),
            StarRatingInput(
              label: 'Respect des engagements',
              helperText: 'Les conditions convenues ont-elles été respectées ?',
              value: _paymentRespect,
              onChanged: (value) => setState(() => _paymentRespect = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Commentaire facultatif',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              activeColor: kPrestoBlue,
              title: const Text(
                'Je confirme que cet avis correspond à l’expérience réelle liée à cette annonce.',
              ),
              onChanged: (value) =>
                  setState(() => _confirmed = value == true),
            ),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrestoOrange,
            foregroundColor: Colors.white,
          ),
          onPressed: _canSubmit ? _submit : null,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.verified_rounded),
          label: const Text('Publier mon avis'),
        ),
      ],
    );
  }
}

class _ReviewCorrectionDialog extends StatefulWidget {
  const _ReviewCorrectionDialog({
    required this.task,
    required this.service,
  });

  final _PendingReviewTask task;
  final TrustScoreService service;

  @override
  State<_ReviewCorrectionDialog> createState() => _ReviewCorrectionDialogState();
}

class _ReviewCorrectionDialogState extends State<_ReviewCorrectionDialog> {
  late final TextEditingController _controller;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.task.comment);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.service.reviseReview(
        reviewId: widget.task.reviewId,
        comment: text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'La correction n’a pas pu être enregistrée.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Corriger l’avis'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.task.correctionMessage,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLength: 500,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: 'Avis corrigé',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('Renvoyer pour vérification'),
        ),
      ],
    );
  }
}

class _PendingReviewInfo extends StatelessWidget {
  const _PendingReviewInfo({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Icon(icon, color: kPrestoBlue, size: 30),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _PendingReviewTask {
  const _PendingReviewTask({
    required this.taskId,
    required this.type,
    required this.reviewId,
    required this.offerId,
    required this.offerTitle,
    required this.reviewedUserId,
    required this.reviewedUserName,
    required this.conversationId,
    required this.correctionMessage,
    required this.comment,
  });

  final String taskId;
  final String type;
  final String reviewId;
  final String offerId;
  final String offerTitle;
  final String reviewedUserId;
  final String reviewedUserName;
  final String conversationId;
  final String correctionMessage;
  final String comment;

  factory _PendingReviewTask.fromMap(Map<String, dynamic> data) {
    String read(String key) => (data[key] ?? '').toString().trim();
    return _PendingReviewTask(
      taskId: read('taskId'),
      type: read('type'),
      reviewId: read('reviewId'),
      offerId: read('offerId'),
      offerTitle: read('offerTitle').isEmpty
          ? 'Annonce iliprestō'
          : read('offerTitle'),
      reviewedUserId: read('reviewedUserId'),
      reviewedUserName: read('reviewedUserName'),
      conversationId: read('conversationId'),
      correctionMessage: read('correctionMessage'),
      comment: read('comment'),
    );
  }
}
