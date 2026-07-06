import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/firestore_date_parser.dart';

class AdminMessagingModerationPage extends StatefulWidget {
  const AdminMessagingModerationPage({super.key});

  @override
  State<AdminMessagingModerationPage> createState() =>
      _AdminMessagingModerationPageState();
}

enum _ModerationLogFilter {
  all,
  pending,
  manualReview,
  rejected,
}

class _AdminMessagingModerationPageState
    extends State<AdminMessagingModerationPage> {
  _ModerationLogFilter _filter = _ModerationLogFilter.all;

  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream => FirebaseFirestore
      .instance
      .collectionGroup('messages')
      .orderBy('createdAt', descending: true)
      .limit(120)
      .snapshots();

  bool _matchesFilter(_ModerationLogEntry entry) {
    switch (_filter) {
      case _ModerationLogFilter.all:
        return true;
      case _ModerationLogFilter.pending:
        return entry.status == 'pending';
      case _ModerationLogFilter.manualReview:
        return entry.status == 'manual_review';
      case _ModerationLogFilter.rejected:
        return entry.status == 'rejected';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: const Text(
          'Modération messages',
          style: kPrestoAppBarTitleStyle,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Journal des messages passés en revue, masqués ou refusés.',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<_ModerationLogFilter>(
                    segments: const [
                      ButtonSegment(
                        value: _ModerationLogFilter.all,
                        label: Text('Tous'),
                      ),
                      ButtonSegment(
                        value: _ModerationLogFilter.pending,
                        label: Text('Pending'),
                      ),
                      ButtonSegment(
                        value: _ModerationLogFilter.manualReview,
                        label: Text('Revue'),
                      ),
                      ButtonSegment(
                        value: _ModerationLogFilter.rejected,
                        label: Text('Refusés'),
                      ),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (selection) {
                      setState(() => _filter = selection.first);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Impossible de charger le journal de modération : ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final entries = snapshot.data?.docs
                          .map(_ModerationLogEntry.fromDocument)
                          .where((entry) => entry.isModerated)
                          .where(_matchesFilter)
                          .toList(growable: false) ??
                      const <_ModerationLogEntry>[];

                  if (entries.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aucun message modéré récent pour ce filtre.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _ModerationLogCard(entry: entry);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModerationLogEntry {
  final String messageId;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String text;
  final String mode;
  final String status;
  final String visibility;
  final String reason;
  final String userMessage;
  final List<String> autoFlags;
  final int riskScore;
  final DateTime? createdAt;

  const _ModerationLogEntry({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.mode,
    required this.status,
    required this.visibility,
    required this.reason,
    required this.userMessage,
    required this.autoFlags,
    required this.riskScore,
    required this.createdAt,
  });

  bool get isModerated {
    return status == 'pending' ||
        status == 'manual_review' ||
        status == 'rejected' ||
        reason.isNotEmpty && reason != 'approved_automatically';
  }

  factory _ModerationLogEntry.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final moderation = (data['moderation'] is Map)
        ? Map<String, dynamic>.from(data['moderation'] as Map)
        : const <String, dynamic>{};
    final parentConversation = doc.reference.parent.parent;
    return _ModerationLogEntry(
      messageId: doc.id,
      conversationId: parentConversation?.id ?? '',
      senderId: ((data['senderId'] ?? data['sender_id']) ?? '').toString(),
      senderName:
          ((data['senderName'] ?? data['sender_name']) ?? '').toString(),
      text: ((data['text'] ?? data['body']) ?? '').toString(),
      mode: (moderation['mode'] ?? '').toString(),
      status: (moderation['status'] ?? '').toString(),
      visibility: (moderation['visibility'] ?? '').toString(),
      reason: (moderation['reason'] ?? '').toString(),
      userMessage: (moderation['userMessage'] ?? '').toString(),
      autoFlags: ((moderation['autoFlags'] as List?) ?? const <dynamic>[])
          .map((flag) => flag.toString())
          .where((flag) => flag.trim().isNotEmpty)
          .toList(growable: false),
      riskScore: (moderation['riskScore'] is num)
          ? (moderation['riskScore'] as num).round()
          : 0,
      createdAt: parseFirestoreDateTime(data['createdAt'] ?? data['created_at']),
    );
  }
}

class _ModerationLogCard extends StatelessWidget {
  final _ModerationLogEntry entry;

  const _ModerationLogCard({required this.entry});

  Color get _statusColor {
    switch (entry.status) {
      case 'rejected':
        return const Color(0xFFB42318);
      case 'manual_review':
        return const Color(0xFFB54708);
      case 'pending':
        return const Color(0xFF1D4ED8);
      default:
        return const Color(0xFF475467);
    }
  }

  Color get _statusBackground {
    switch (entry.status) {
      case 'rejected':
        return const Color(0xFFFEE4E2);
      case 'manual_review':
        return const Color(0xFFFFF3D6);
      case 'pending':
        return const Color(0xFFDBEAFE);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  String get _dateLabel {
    final date = entry.createdAt;
    if (date == null) return 'Date inconnue';
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final preview = entry.text.trim().isEmpty
        ? 'Message sans texte explicite'
        : entry.text.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.senderName.trim().isEmpty
                          ? entry.senderId
                          : entry.senderName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Conversation ${entry.conversationId} · $_dateLabel',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entry.status.isEmpty ? 'approved' : entry.status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            preview,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(label: 'Mode ${entry.mode.isEmpty ? 'hybrid' : entry.mode}'),
              _InfoChip(label: 'Visibilité ${entry.visibility.isEmpty ? 'visible' : entry.visibility}'),
              _InfoChip(label: 'Risk ${entry.riskScore}'),
            ],
          ),
          if (entry.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Raison: ${entry.reason}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
          if (entry.userMessage.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Message utilisateur: ${entry.userMessage}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                height: 1.35,
              ),
            ),
          ],
          if (entry.autoFlags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: entry.autoFlags
                  .map((flag) => _InfoChip(label: flag))
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }
}