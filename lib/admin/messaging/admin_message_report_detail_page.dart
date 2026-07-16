import 'package:flutter/material.dart';

import 'models/admin_message_report_model.dart';
import 'services/admin_moderation_service.dart';
import 'widgets/admin_confirm_sensitive_action_dialog.dart';
import 'widgets/admin_messaging_app_bar.dart';
import 'widgets/admin_report_priority_badge.dart';

typedef AdminMessageReportStatusUpdater = Future<void> Function({
  required String reportId,
  required String status,
  required String decision,
  required String reason,
});

class AdminMessageReportDetailPage extends StatefulWidget {
  final AdminMessageReportModel report;
  final AdminMessageReportStatusUpdater? updateReportStatus;

  const AdminMessageReportDetailPage({
    super.key,
    required this.report,
    this.updateReportStatus,
  });

  @override
  State<AdminMessageReportDetailPage> createState() =>
      _AdminMessageReportDetailPageState();
}

class _AdminMessageReportDetailPageState
    extends State<AdminMessageReportDetailPage> {
  bool _saving = false;

  Future<void> _setStatus(String status, {String decision = ''}) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AdminConfirmSensitiveActionDialog(
            title: 'Confirmer la décision',
            message: 'La décision sera tracée dans l\'audit administrateur.',
            confirmLabel: 'Valider',
          ),
        ) ??
        false;
    if (!confirm) return;
    setState(() => _saving = true);
    try {
      final updateStatus = widget.updateReportStatus ??
          AdminModerationService().updateReportStatus;
      await updateStatus(
        reportId: widget.report.id,
        status: status,
        decision: decision,
        reason: 'Traitement depuis le détail signalement',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signalement mis à jour: $status')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: const AdminMessagingAppBar(title: 'Détail signalement'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReportDetailCard(
            title: widget.report.reason,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AdminReportPriorityBadge(priority: widget.report.priority),
                    _ReportTag(label: widget.report.status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.report.description.trim().isEmpty
                      ? 'Aucune description complémentaire.'
                      : widget.report.description,
                ),
                const SizedBox(height: 12),
                Text('Conversation: ${widget.report.conversationId}'),
                Text('Message: ${widget.report.messageId}'),
                Text('Signalé par: ${widget.report.reportedBy}'),
                Text('Utilisateur visé: ${widget.report.reportedUserId}'),
                Text(
                  'Assigné à: ${widget.report.assignedTo.isEmpty ? 'non assigné' : widget.report.assignedTo}',
                ),
                Text(
                  'Décision admin: ${widget.report.adminDecision.isEmpty ? 'aucune' : widget.report.adminDecision}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ReportDetailCard(
            title: 'Décisions',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _setStatus('en revue', decision: 'manual_review'),
                  icon: const Icon(Icons.manage_search_rounded),
                  label: const Text('Passer en revue'),
                ),
                FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () =>
                          _setStatus('résolu', decision: 'resolved_no_action'),
                  icon: const Icon(Icons.task_alt_rounded),
                  label: const Text('Clore sans action'),
                ),
                FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _setStatus('résolu', decision: 'action_taken'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB42318),
                  ),
                  icon: const Icon(Icons.gavel_rounded),
                  label: const Text('Clore avec action'),
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

class _ReportDetailCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ReportDetailCard({required this.title, required this.child});

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

class _ReportTag extends StatelessWidget {
  final String label;

  const _ReportTag({required this.label});

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
