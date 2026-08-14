import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../services/firebase_functions_region.dart';

const _mailboxAddress = 'contact@ilipresto.fr';

class AdminContactMailWidget extends StatefulWidget {
  const AdminContactMailWidget({super.key});

  @override
  State<AdminContactMailWidget> createState() => _AdminContactMailWidgetState();
}

class _AdminContactMailWidgetState extends State<AdminContactMailWidget> {
  Timer? _refreshTimer;
  _InboxSummary _summary = const _InboxSummary.empty();
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_refresh(silent: true)),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _loading = true);
    }

    try {
      final result = await callPrestoFunction<dynamic>(
        functions: prestoFirebaseFunctions,
        name: 'adminGetInboundMailboxSummary',
        timeout: const Duration(seconds: 15),
        area: 'admin-inbox',
      );
      final summary = _InboxSummary.fromDynamic(result.data);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _openInbox() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AdminContactInboxSheet(),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final unread = _summary.unreadCount;
    final badgeText = unread > 99 ? '99+' : '$unread';

    return Semantics(
      button: true,
      label: unread > 0
          ? '$unread mail${unread > 1 ? 's' : ''} non lu${unread > 1 ? 's' : ''} sur $_mailboxAddress'
          : 'Aucun mail non lu sur $_mailboxAddress',
      child: Tooltip(
        message: 'Mails reçus sur $_mailboxAddress',
        child: Material(
          color: Colors.white,
          elevation: 6,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: _loading ? null : _openInbox,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.fromLTRB(12, 7, 9, 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  else
                    Icon(
                      _hasError ? Icons.mail_lock_outlined : Icons.mail_rounded,
                      size: 21,
                      color: _hasError
                          ? const Color(0xFFD93025)
                          : const Color(0xFF1A73E8),
                    ),
                  const SizedBox(width: 7),
                  const Text(
                    'Mails',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Container(
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      color: unread > 0
                          ? const Color(0xFFFF6600)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _hasError ? '!' : badgeText,
                      style: TextStyle(
                        color: unread > 0 || _hasError
                            ? Colors.white
                            : const Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminContactInboxSheet extends StatefulWidget {
  const _AdminContactInboxSheet();

  @override
  State<_AdminContactInboxSheet> createState() => _AdminContactInboxSheetState();
}

class _AdminContactInboxSheetState extends State<_AdminContactInboxSheet> {
  bool _loading = true;
  String? _error;
  List<_InboundMailItem> _items = const [];

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
      final result = await callPrestoFunction<dynamic>(
        functions: prestoFirebaseFunctions,
        name: 'adminListInboundEmails',
        timeout: const Duration(seconds: 20),
        parameters: const {'limit': 30},
        area: 'admin-inbox',
      );
      final data = _asStringMap(result.data);
      final rawItems = data['items'];
      final items = rawItems is List
          ? rawItems.map(_InboundMailItem.fromDynamic).toList(growable: false)
          : const <_InboundMailItem>[];
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is FirebaseFunctionsException
            ? 'Impossible de charger les mails (${error.code}).'
            : 'Impossible de charger les mails.';
      });
    }
  }

  Future<void> _markRead(_InboundMailItem item) async {
    if (item.isRead) return;
    try {
      await callPrestoFunction<dynamic>(
        functions: prestoFirebaseFunctions,
        name: 'adminMarkInboundEmailRead',
        timeout: const Duration(seconds: 15),
        parameters: {'emailId': item.id, 'isRead': true},
        area: 'admin-inbox',
      );
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((candidate) => candidate.id == item.id
                ? candidate.copyWith(isRead: true)
                : candidate)
            .toList(growable: false);
      });
    } catch (_) {
      // La lecture du message reste possible ; le prochain rafraîchissement
      // réessaiera d'afficher l'état réel côté serveur.
    }
  }

  Future<void> _openMail(_InboundMailItem item) async {
    await _markRead(item);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        title: Text(
          item.subject.isEmpty ? '(Sans objet)' : item.subject,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 520),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.senderLabel,
                  style: const TextStyle(
                    color: Color(0xFF1A73E8),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(item.receivedAt),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
                const Divider(height: 24),
                SelectableText(
                  item.body.isEmpty ? item.preview : item.body,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                if (item.attachmentCount > 0) ...[
                  const SizedBox(height: 18),
                  Text(
                    '${item.attachmentCount} pièce${item.attachmentCount > 1 ? 's' : ''} jointe${item.attachmentCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.82;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: 46,
              height: 5,
              margin: const EdgeInsets.only(top: 9, bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
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
                          _mailboxAddress,
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
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 38, color: Color(0xFFD93025)),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mark_email_read_outlined, size: 42, color: Color(0xFF0F9D58)),
              SizedBox(height: 12),
              Text(
                'Aucun mail reçu pour le moment.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _items[index];
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => _openMail(item),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: item.isRead
                        ? const Color(0xFFE5E7EB)
                        : const Color(0xFFFFB380),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: item.isRead
                            ? const Color(0xFFF3F4F6)
                            : const Color(0xFFFFF0E6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item.isRead ? Icons.drafts_outlined : Icons.mark_email_unread_rounded,
                        color: item.isRead
                            ? const Color(0xFF6B7280)
                            : const Color(0xFFFF6600),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.senderLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: const Color(0xFF111827),
                                    fontSize: 13,
                                    fontWeight: item.isRead
                                        ? FontWeight.w700
                                        : FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(item.receivedAt),
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.subject.isEmpty ? '(Sans objet)' : item.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF374151),
                              fontSize: 12.5,
                              fontWeight: item.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                          ),
                          if (item.preview.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11.5,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InboxSummary {
  final int unreadCount;

  const _InboxSummary({required this.unreadCount});
  const _InboxSummary.empty() : unreadCount = 0;

  factory _InboxSummary.fromDynamic(Object? value) {
    final data = _asStringMap(value);
    final unread = data['unreadCount'];
    return _InboxSummary(
      unreadCount: unread is num ? unread.toInt() : int.tryParse('$unread') ?? 0,
    );
  }
}

class _InboundMailItem {
  final String id;
  final String senderName;
  final String senderEmail;
  final String subject;
  final String preview;
  final String body;
  final int receivedAt;
  final bool isRead;
  final int attachmentCount;

  const _InboundMailItem({
    required this.id,
    required this.senderName,
    required this.senderEmail,
    required this.subject,
    required this.preview,
    required this.body,
    required this.receivedAt,
    required this.isRead,
    required this.attachmentCount,
  });

  factory _InboundMailItem.fromDynamic(Object? value) {
    final data = _asStringMap(value);
    int asInt(Object? input) => input is num ? input.toInt() : int.tryParse('$input') ?? 0;
    return _InboundMailItem(
      id: '${data['id'] ?? ''}',
      senderName: '${data['senderName'] ?? ''}'.trim(),
      senderEmail: '${data['senderEmail'] ?? ''}'.trim(),
      subject: '${data['subject'] ?? ''}'.trim(),
      preview: '${data['preview'] ?? ''}'.trim(),
      body: '${data['body'] ?? ''}'.trim(),
      receivedAt: asInt(data['receivedAt']),
      isRead: data['isRead'] == true,
      attachmentCount: asInt(data['attachmentCount']),
    );
  }

  String get senderLabel {
    if (senderName.isNotEmpty && senderEmail.isNotEmpty) {
      return '$senderName <$senderEmail>';
    }
    return senderName.isNotEmpty ? senderName : senderEmail;
  }

  _InboundMailItem copyWith({bool? isRead}) => _InboundMailItem(
        id: id,
        senderName: senderName,
        senderEmail: senderEmail,
        subject: subject,
        preview: preview,
        body: body,
        receivedAt: receivedAt,
        isRead: isRead ?? this.isRead,
        attachmentCount: attachmentCount,
      );
}

Map<String, dynamic> _asStringMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry('$key', val));
  }
  return const <String, dynamic>{};
}

String _formatDate(int millis) {
  if (millis <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
  final now = DateTime.now();
  final sameDay = date.year == now.year && date.month == now.month && date.day == now.day;
  String two(int value) => value.toString().padLeft(2, '0');
  if (sameDay) return '${two(date.hour)}:${two(date.minute)}';
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}
