import 'package:flutter/material.dart';

import '../../pages/offers/offer_details_page.dart';
import 'models/admin_conversation_model.dart';
import 'services/admin_moderation_service.dart';
import 'widgets/admin_confirm_sensitive_action_dialog.dart';
import 'widgets/admin_conversation_status_badge.dart';
import 'widgets/admin_messaging_app_bar.dart';
import 'widgets/admin_risk_score_badge.dart';

class AdminConversationDetailPage extends StatefulWidget {
  final AdminConversationModel conversation;

  const AdminConversationDetailPage({super.key, required this.conversation});

  @override
  State<AdminConversationDetailPage> createState() =>
      _AdminConversationDetailPageState();
}

class _AdminConversationDetailPageState
    extends State<AdminConversationDetailPage> {
  final AdminModerationService _moderationService = AdminModerationService();
  bool _saving = false;

  Future<void> _updateStatus(String status, {String reason = ''}) async {
    setState(() => _saving = true);
    try {
      await _moderationService.updateConversationStatus(
        conversationId: widget.conversation.id,
        status: status,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Statut mis à jour: $status')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleWatchlist() async {
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (_) => AdminConfirmSensitiveActionDialog(
            title: widget.conversation.adminWatchlisted
                ? 'Retirer de la watchlist'
                : 'Ajouter à la watchlist',
            message:
                'Cette action sera journalisée dans l\'audit administrateur.',
            confirmLabel: widget.conversation.adminWatchlisted
                ? 'Retirer'
                : 'Ajouter',
          ),
        ) ??
        false;
    if (!confirm) return;
    setState(() => _saving = true);
    try {
      await _moderationService.markConversationWatchlisted(
        conversationId: widget.conversation.id,
        watchlisted: !widget.conversation.adminWatchlisted,
        reason: 'Action manuelle depuis le détail conversation admin',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.conversation.adminWatchlisted
                ? 'Conversation retirée de la watchlist.'
                : 'Conversation ajoutée à la watchlist.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openRelatedListing() {
    if (widget.conversation.contextId.trim().isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OfferDetailsPage(
          offer: <String, dynamic>{'id': widget.conversation.contextId},
          currentUserId: '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: const AdminMessagingAppBar(title: 'Détail conversation'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DetailCard(
            title: widget.conversation.contextTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.conversation.participantSummary),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AdminConversationStatusBadge(
                      status: widget.conversation.status,
                    ),
                    AdminRiskScoreBadge(score: widget.conversation.riskScore),
                    if (widget.conversation.adminWatchlisted)
                      const _StaticTag(label: 'Watchlist'),
                  ],
                ),
                const SizedBox(height: 12),
                Text('ID conversation: ${widget.conversation.id}'),
                Text('ID annonce/contexte: ${widget.conversation.contextId}'),
                Text('Région: ${widget.conversation.region}'),
                Text('Messages: ${widget.conversation.messageCount}'),
                Text('Signalements: ${widget.conversation.reportCount}'),
                Text(
                  'Dernière activité: ${widget.conversation.lastMessageAt ?? widget.conversation.updatedAt ?? widget.conversation.createdAt ?? 'inconnue'}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DetailCard(
            title: 'Actions admin',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _saving ? null : () => _updateStatus('active'),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Marquer active'),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _updateStatus('reported'),
                  icon: const Icon(Icons.flag_rounded),
                  label: const Text('Marquer signalée'),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _updateStatus('closed'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB42318),
                  ),
                  icon: const Icon(Icons.block_rounded),
                  label: const Text('Clore'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _toggleWatchlist,
                  icon: const Icon(Icons.visibility_rounded),
                  label: Text(
                    widget.conversation.adminWatchlisted
                        ? 'Retirer watchlist'
                        : 'Ajouter watchlist',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: widget.conversation.contextId.trim().isEmpty
                      ? null
                      : _openRelatedListing,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Ouvrir l\'annonce liée'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DetailCard(
            title: 'Résumé de conformité',
            child: const Text(
              'Cette vue admin n\'affiche pas le contenu privé des messages. Les décisions s\'appuient sur les métadonnées, les statuts, les scores de risque et les signalements.',
            ),
          ),
          if (_saving) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StaticTag extends StatelessWidget {
  final String label;

  const _StaticTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFD97706).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFD97706),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
