import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'models/admin_notification_log_model.dart';
import 'services/admin_notification_monitor_service.dart';
import 'widgets/admin_messaging_app_bar.dart';

class AdminNotificationsMonitorPage extends StatefulWidget {
  final bool showAppBar;

  const AdminNotificationsMonitorPage({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<AdminNotificationsMonitorPage> createState() =>
      _AdminNotificationsMonitorPageState();
}

class _AdminNotificationsMonitorPageState
    extends State<AdminNotificationsMonitorPage> {
  final AdminNotificationMonitorService _service =
      AdminNotificationMonitorService();
  final TextEditingController _controller = TextEditingController();
  final List<AdminNotificationLogModel> _items = <AdminNotificationLogModel>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  String _query = '';
  String? _statusFilter;
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
      final page = await _service.fetchNotificationsPage(
        pageSize: 40,
        startAfter: reset ? null : _lastDocument,
        deliveryStatus: _statusFilter,
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
    final notifications = _items.where((item) {
      final query = _query.trim().toLowerCase();
      if (query.isEmpty) return true;
      return item.title.toLowerCase().contains(query) ||
          item.body.toLowerCase().contains(query) ||
          item.deliveryStatus.toLowerCase().contains(query) ||
          item.routeName.toLowerCase().contains(query) ||
          item.conversationId.toLowerCase().contains(query);
    }).toList(growable: false);
    final sentCount = notifications.where((item) {
      final status = item.deliveryStatus.toLowerCase();
      return status.contains('sent') || status.contains('envoy');
    }).length;
    final failedCount = notifications.where((item) {
      final status = item.deliveryStatus.toLowerCase();
      return status.contains('failed') || status.contains('error');
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: widget.showAppBar
          ? const AdminMessagingAppBar(title: 'Notifications messagerie')
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Recherche par titre, statut, route, conversation…',
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
                  selected: _statusFilter == null,
                  onSelected: (_) {
                    setState(() => _statusFilter = null);
                    _refresh();
                  },
                ),
                ...const ['sent', 'delivered', 'failed'].map(
                  (status) => FilterChip(
                    label: Text(status),
                    selected: _statusFilter == status,
                    onSelected: (_) {
                      setState(() => _statusFilter = status);
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
              _NotificationsErrorState(onRetry: _refresh)
            else if (notifications.isEmpty)
              const Center(
                child: Text(
                  'Aucune notification messagerie récente.',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else ...[
              _NotificationSummaryCard(
                total: notifications.length,
                sent: sentCount,
                failed: failedCount,
              ),
              const SizedBox(height: 16),
              ...notifications.map(
                (item) => Container(
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
                        item.title.isEmpty
                            ? 'Notification sans titre'
                            : item.title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(item.body.isEmpty ? 'Aucun corps.' : item.body),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _NotificationTag(label: item.deliveryStatus),
                          if (item.conversationId.isNotEmpty)
                            _NotificationTag(
                                label: 'Conv. ${item.conversationId}'),
                          if (item.routeName.isNotEmpty)
                            _NotificationTag(label: item.routeName),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
                    label: Text(
                      _loadingMore ? 'Chargement…' : 'Charger la page suivante',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationSummaryCard extends StatelessWidget {
  final int total;
  final int sent;
  final int failed;

  const _NotificationSummaryCard({
    required this.total,
    required this.sent,
    required this.failed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        'Notifications messagerie: $total • envoyées: $sent • erreurs: $failed',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _NotificationTag extends StatelessWidget {
  final String label;

  const _NotificationTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF0F766E),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NotificationsErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _NotificationsErrorState({required this.onRetry});

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
