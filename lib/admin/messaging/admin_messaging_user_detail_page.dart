import 'package:flutter/material.dart';

import 'models/admin_messaging_user_model.dart';
import 'services/admin_moderation_service.dart';
import 'widgets/admin_confirm_sensitive_action_dialog.dart';
import 'widgets/admin_messaging_app_bar.dart';
import 'widgets/admin_risk_score_badge.dart';
import 'widgets/admin_user_messaging_status_badge.dart';

typedef AdminUserMessagingStatusUpdater = Future<void> Function({
  required String userId,
  required String status,
  required String reason,
});

class AdminMessagingUserDetailPage extends StatefulWidget {
  final AdminMessagingUserModel user;
  final AdminUserMessagingStatusUpdater? updateUserMessagingStatus;

  const AdminMessagingUserDetailPage({
    super.key,
    required this.user,
    this.updateUserMessagingStatus,
  });

  @override
  State<AdminMessagingUserDetailPage> createState() =>
      _AdminMessagingUserDetailPageState();
}

class _AdminMessagingUserDetailPageState
    extends State<AdminMessagingUserDetailPage> {
  bool _saving = false;

  Future<void> _setUserStatus(String status) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AdminConfirmSensitiveActionDialog(
            title: 'Confirmer le changement de statut',
            message: 'Le changement de statut messagerie sera journalisé.',
          ),
        ) ??
        false;
    if (!confirm) return;
    setState(() => _saving = true);
    try {
      final updateStatus = widget.updateUserMessagingStatus ??
          AdminModerationService().updateUserMessagingStatus;
      await updateStatus(
        userId: widget.user.uid,
        status: status,
        reason: 'Action depuis la fiche utilisateur messagerie',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Statut utilisateur mis à jour: $status')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: const AdminMessagingAppBar(title: 'Fiche utilisateur messagerie'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _UserDetailCard(
            title: user.name,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email.isEmpty ? user.uid : user.email),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AdminUserMessagingStatusBadge(status: user.messagingStatus),
                    AdminRiskScoreBadge(score: user.riskScore),
                    _UserInfoTag(label: user.role),
                    _UserInfoTag(label: user.region),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Conversations ouvertes: ${user.openConversations}'),
                Text('Messages envoyés: ${user.messagesSent}'),
                Text('Messages reçus: ${user.messagesReceived}'),
                Text('Signalements reçus: ${user.reportsReceived}'),
                Text('Signalements envoyés: ${user.reportsSent}'),
                Text(
                  'Taux de réponse: ${user.responseRate.toStringAsFixed(0)} %',
                ),
                Text(
                  'Délai moyen: ${user.averageResponseHours.toStringAsFixed(1)} h',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _UserDetailCard(
            title: 'Actions admin',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _saving ? null : () => _setUserStatus('actif'),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Activer'),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _setUserStatus('restreint'),
                  icon: const Icon(Icons.remove_moderator_rounded),
                  label: const Text('Restreindre'),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _setUserStatus('suspendu'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                  ),
                  icon: const Icon(Icons.pause_circle_filled_rounded),
                  label: const Text('Suspendre'),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _setUserStatus('bloqué'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB42318),
                  ),
                  icon: const Icon(Icons.block_rounded),
                  label: const Text('Bloquer'),
                ),
              ],
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

class _UserDetailCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _UserDetailCard({required this.title, required this.child});

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

class _UserInfoTag extends StatelessWidget {
  final String label;

  const _UserInfoTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1D4ED8).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1D4ED8),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
