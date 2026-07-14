import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'models/admin_audit_log_model.dart';
import 'services/admin_messaging_audit_service.dart';

class AdminMessagingAuditLogsPage extends StatefulWidget {
  const AdminMessagingAuditLogsPage({super.key});

  @override
  State<AdminMessagingAuditLogsPage> createState() =>
      _AdminMessagingAuditLogsPageState();
}

class _AdminMessagingAuditLogsPageState
    extends State<AdminMessagingAuditLogsPage> {
  final AdminMessagingAuditService _service = AdminMessagingAuditService();
  final TextEditingController _controller = TextEditingController();
  final List<AdminAuditLogModel> _items = <AdminAuditLogModel>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  String _query = '';
  String? _riskFilter;
  String? _actionFilter;
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
      final page = await _service.fetchLogsPage(
        pageSize: 40,
        startAfter: reset ? null : _lastDocument,
        riskLevel: _riskFilter,
        action: _actionFilter,
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

  @override
  Widget build(BuildContext context) {
    final logs = _items.where((log) {
      final query = _query.trim().toLowerCase();
      if (query.isEmpty) return true;
      return log.action.toLowerCase().contains(query) ||
          log.targetType.toLowerCase().contains(query) ||
          log.targetId.toLowerCase().contains(query) ||
          log.adminEmail.toLowerCase().contains(query) ||
          log.reason.toLowerCase().contains(query);
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
                hintText: 'Recherche par action, cible, admin, motif…',
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
                  selected: _riskFilter == null && _actionFilter == null,
                  onSelected: (_) {
                    setState(() {
                      _riskFilter = null;
                      _actionFilter = null;
                    });
                    _refresh();
                  },
                ),
                ...const ['high', 'medium', 'normal'].map(
                  (risk) => FilterChip(
                    label: Text(risk),
                    selected: _riskFilter == risk,
                    onSelected: (_) {
                      setState(() {
                        _riskFilter = risk;
                        _actionFilter = null;
                      });
                      _refresh();
                    },
                  ),
                ),
                ...const [
                  'update_conversation_status',
                  'update_message_report_status',
                  'update_user_messaging_status',
                ].map(
                  (action) => FilterChip(
                    label: Text(action),
                    selected: _actionFilter == action,
                    onSelected: (_) {
                      setState(() {
                        _actionFilter = action;
                        _riskFilter = null;
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
              _AuditErrorState(onRetry: _refresh)
            else if (logs.isEmpty)
              const Center(
                child: Text(
                  'Aucun log d\'audit messagerie récent.',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              ...logs.map((log) {
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
                        log.action,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text('Cible: ${log.targetType} • ${log.targetId}'),
                      Text(
                          'Admin: ${log.adminEmail.isEmpty ? log.adminId : log.adminEmail}'),
                      Text('Risque: ${log.riskLevel}'),
                      if (log.reason.isNotEmpty) Text('Motif: ${log.reason}'),
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

class _AuditErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _AuditErrorState({required this.onRetry});

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
