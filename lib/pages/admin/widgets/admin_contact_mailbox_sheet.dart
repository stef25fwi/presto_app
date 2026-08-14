import 'dart:async';

import 'package:flutter/material.dart';

import 'admin_contact_mail_detail_dialog.dart';
import 'admin_contact_mail_list_tile.dart';
import 'admin_contact_mail_models.dart';
import 'admin_contact_mail_service.dart';
import 'admin_contact_mail_states.dart';

const adminContactMailboxAddress = 'contact@ilipresto.fr';

class AdminContactMailboxSheet extends StatefulWidget {
  const AdminContactMailboxSheet({super.key});

  @override
  State<AdminContactMailboxSheet> createState() =>
      _AdminContactMailboxSheetState();
}

class _AdminContactMailboxSheetState extends State<AdminContactMailboxSheet> {
  static const _service = AdminContactMailService();

  bool _loading = true;
  String? _error;
  List<AdminContactMailItem> _items = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.listEmails();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de charger les mails.';
      });
    }
  }

  Future<void> _openMail(AdminContactMailItem item) async {
    if (!item.isRead) {
      try {
        await _service.markRead(item.id);
        if (mounted) {
          setState(() {
            _items = _items
                .map(
                  (candidate) => candidate.id == item.id
                      ? candidate.copyWith(isRead: true)
                      : candidate,
                )
                .toList(growable: false);
          });
        }
      } catch (_) {
        // Le prochain rafraîchissement réessaiera de récupérer l'état serveur.
      }
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AdminContactMailDetailDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const _DragHandle(),
            _InboxHeader(loading: _loading, onRefresh: _load),
            const Divider(height: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return AdminContactMailErrorState(message: _error!, onRetry: _load);
    }
    if (_items.isEmpty) return const AdminContactMailEmptyState();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _items[index];
          return AdminContactMailListTile(
            item: item,
            onTap: () => _openMail(item),
          );
        },
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) => Container(
        width: 46,
        height: 5,
        margin: const EdgeInsets.only(top: 9, bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(999),
        ),
      );
}

class _InboxHeader extends StatelessWidget {
  final bool loading;
  final VoidCallback onRefresh;

  const _InboxHeader({
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 10, 10),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Boîte de réception',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    adminContactMailboxAddress,
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Actualiser',
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'Fermer',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      );
}
