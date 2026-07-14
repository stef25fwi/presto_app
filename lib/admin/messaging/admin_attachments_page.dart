import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'models/admin_attachment_model.dart';
import 'services/admin_messaging_service.dart';
import 'services/admin_moderation_service.dart';
import 'widgets/admin_confirm_sensitive_action_dialog.dart';

class AdminAttachmentsPage extends StatefulWidget {
  const AdminAttachmentsPage({super.key});

  @override
  State<AdminAttachmentsPage> createState() => _AdminAttachmentsPageState();
}

class _AdminAttachmentsPageState extends State<AdminAttachmentsPage> {
  final AdminMessagingService _service = AdminMessagingService();
  final AdminModerationService _moderationService = AdminModerationService();
  final TextEditingController _controller = TextEditingController();
  final Set<String> _busyIds = <String>{};
  final List<AdminAttachmentModel> _items = <AdminAttachmentModel>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  String _query = '';
  String? _statusFilter;
  String? _fileTypeFilter;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadingInitial = true;
      _loadingMore = false;
      _hasMore = true;
      _error = null;
      _lastDocument = null;
      _items.clear();
    });
    await _loadMore(reset: true);
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loadingMore) return;
    if (!reset && !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final page = await _service.fetchAttachmentsPage(
        pageSize: 40,
        startAfter: reset ? null : _lastDocument,
        moderationStatus: _statusFilter,
        fileType: _fileTypeFilter,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          _items.addAll(page.items);
        }
        _lastDocument = page.lastDocument;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _loadingInitial = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _setStatus(
      AdminAttachmentModel attachment, String status) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AdminConfirmSensitiveActionDialog(
            title: 'Confirmer la modération',
            message: 'Le statut de la pièce jointe sera mis à jour et tracé.',
            confirmLabel: 'Valider',
          ),
        ) ??
        false;
    if (!confirm) return;
    setState(() => _busyIds.add(attachment.id));
    try {
      await _moderationService.updateAttachmentModerationStatus(
        attachmentId: attachment.id,
        status: status,
        reason: 'Action depuis la liste des pièces jointes',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pièce jointe mise à jour: $status')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(attachment.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final attachments = _items.where((attachment) {
      final query = _query.trim().toLowerCase();
      if (query.isEmpty) return true;
      return attachment.id.toLowerCase().contains(query) ||
          attachment.storagePath.toLowerCase().contains(query) ||
          attachment.conversationId.toLowerCase().contains(query) ||
          attachment.mimeType.toLowerCase().contains(query);
    }).toList(growable: false);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Recherche par chemin, conversation, mime type…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              onSubmitted: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Tous'),
                  selected: _statusFilter == null && _fileTypeFilter == null,
                  onSelected: (_) {
                    setState(() {
                      _statusFilter = null;
                      _fileTypeFilter = null;
                    });
                    _refresh();
                  },
                ),
                ...const ['approved', 'manual_review', 'deleted'].map(
                  (status) => FilterChip(
                    label: Text(status),
                    selected: _statusFilter == status,
                    onSelected: (_) {
                      setState(() {
                        _statusFilter = status;
                        _fileTypeFilter = null;
                      });
                      _refresh();
                    },
                  ),
                ),
                ...const ['image', 'voice', 'document', 'other'].map(
                  (fileType) => FilterChip(
                    label: Text(fileType),
                    selected: _fileTypeFilter == fileType,
                    onSelected: (_) {
                      setState(() {
                        _fileTypeFilter = fileType;
                        _statusFilter = null;
                      });
                      _refresh();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loadingInitial && _items.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _AttachmentErrorState(onRetry: _refresh)
            else if (attachments.isEmpty)
              const _AttachmentEmptyState()
            else
              ...attachments.map((attachment) {
                final busy = _busyIds.contains(attachment.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
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
                        attachment.storagePath.isEmpty
                            ? attachment.id
                            : attachment.storagePath,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${attachment.fileType} • ${attachment.mimeType} • ${_formatBytes(attachment.fileSize)}',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _AttachmentTag(label: attachment.moderationStatus),
                          _AttachmentTag(
                              label: '${attachment.reportCount} signalements'),
                          _AttachmentTag(
                              label: 'Conv. ${attachment.conversationId}'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => _setStatus(attachment, 'approved'),
                            child: const Text('Approuver'),
                          ),
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => _setStatus(attachment, 'manual_review'),
                            child: const Text('Mettre en revue'),
                          ),
                          FilledButton(
                            onPressed: busy
                                ? null
                                : () => _setStatus(attachment, 'deleted'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFB42318),
                            ),
                            child: const Text('Supprimer'),
                          ),
                        ],
                      ),
                      if (busy) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                );
              }),
            if (_hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: _loadingMore ? null : _loadMore,
                    icon: _loadingMore
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more_rounded),
                    label: Text(_loadingMore
                        ? 'Chargement…'
                        : 'Charger la page suivante'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentEmptyState extends StatelessWidget {
  const _AttachmentEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Aucune pièce jointe récente à superviser.',
        style: TextStyle(
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AttachmentTag extends StatelessWidget {
  final String label;

  const _AttachmentTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _AttachmentErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _AttachmentErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Réessayer le chargement'),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes o';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} Ko';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} Mo';
  return '${(mb / 1024).toStringAsFixed(1)} Go';
}
