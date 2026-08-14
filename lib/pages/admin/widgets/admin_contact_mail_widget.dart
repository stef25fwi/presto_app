import 'dart:async';

import 'package:flutter/material.dart';

import 'admin_contact_mail_models.dart';
import 'admin_contact_mail_service.dart';
import 'admin_contact_mailbox_sheet.dart';

class AdminContactMailWidget extends StatefulWidget {
  const AdminContactMailWidget({super.key});

  @override
  State<AdminContactMailWidget> createState() => _AdminContactMailWidgetState();
}

class _AdminContactMailWidgetState extends State<AdminContactMailWidget> {
  static const _service = AdminContactMailService();

  Timer? _refreshTimer;
  AdminContactInboxSummary _summary = const AdminContactInboxSummary.empty();
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
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final summary = await _service.loadSummary();
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
      builder: (_) => const AdminContactMailboxSheet(),
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
          ? '$unread mail${unread > 1 ? 's' : ''} non lu${unread > 1 ? 's' : ''} '
              'sur $adminContactMailboxAddress'
          : 'Aucun mail non lu sur $adminContactMailboxAddress',
      child: Tooltip(
        message: 'Mails reçus sur $adminContactMailboxAddress',
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
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
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
