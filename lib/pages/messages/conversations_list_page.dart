import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants.dart';
import '../../services/conversation_service.dart';
import '../../services/inbox_counts.dart';
import '../../services/conversation_state.dart';
import '../../utils/friendly_snackbar.dart';
import 'conversation_thread_page.dart';

const kPrestoOrange = Color(0xFFFF6600);
const kPrestoBlue = Color(0xFF1A73E8);
const kMessagesPageBackground = Color(0xFFFFFEFE);
const kWhatsappGreen = Color(0xFF25D366);
const kMessagesStatusBarStyle = SystemUiOverlayStyle(
  statusBarColor: kPrestoBlue,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

class ConversationsListPage extends StatefulWidget {
  final String? initialConversationId;

  const ConversationsListPage({
    super.key,
    this.initialConversationId,
  });

  @override
  State<ConversationsListPage> createState() => _ConversationsListPageState();
}

class _ConversationsListPageState extends State<ConversationsListPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _didHandleInitialConversation = false;
  int _conversationLimit = 50;
  bool _showArchivedOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isPermissionDenied(Object? error) {
    final text = (error ?? '').toString().toLowerCase();
    return text.contains('permission-denied') || text.contains('permission denied');
  }

  String _conversationTitle(Map<String, dynamic> data, String userId) {
    final participantNames = data['participantNames'];
    if (participantNames is Map) {
      for (final entry in participantNames.entries) {
        if (entry.key.toString() == userId) continue;
        final value = (entry.value ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
    }

    final candidates = [
      data['otherUserName'],
      data['participantName'],
      data['participantDisplayName'],
      data['offerTitle'],
    ];
    for (final candidate in candidates) {
      final value = (candidate ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return 'Conversation';
  }

  String _conversationPreview(Map<String, dynamic> data, String userId) {
    final lastMessage = (data['lastMessage'] ?? '').toString().trim();
    final lastSenderId = (data['lastSenderId'] ?? '').toString().trim();
    final offerTitle = (data['offerTitle'] ?? '').toString().trim();

    if (lastMessage.isNotEmpty) {
      if (lastSenderId == userId) {
        return 'Vous : $lastMessage';
      }
      return lastMessage;
    }

    if (offerTitle.isNotEmpty) {
      return offerTitle;
    }

    return 'Touchez pour ouvrir la conversation';
  }

  String _searchableConversationText(Map<String, dynamic> data, String userId) {
    return [
      _conversationTitle(data, userId),
      _conversationPreview(data, userId),
      (data['offerTitle'] ?? '').toString(),
      (data['lastMessage'] ?? '').toString(),
      (data['lastSenderName'] ?? '').toString(),
    ].join(' ').toLowerCase();
  }

  Future<void> _markConversationRead(String conversationId, String currentUserId) async {
    try {
      await ConversationService.markAsRead(conversationId: conversationId);
    } catch (_) {}
  }

  Future<void> _handleConversationAction({
    required String conversationId,
    required _ConversationMenuAction action,
  }) async {
    try {
      switch (action) {
        case _ConversationMenuAction.archive:
          await ConversationService.archiveConversation(conversationId: conversationId);
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation archivee.');
          return;
        case _ConversationMenuAction.unarchive:
          await ConversationService.unarchiveConversation(conversationId: conversationId);
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation restauree.');
          return;
        case _ConversationMenuAction.block:
          await ConversationService.blockConversation(conversationId: conversationId);
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation bloquee.');
          return;
        case _ConversationMenuAction.unblock:
          await ConversationService.unblockConversation(conversationId: conversationId);
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation debloquee.');
          return;
      }
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Action impossible sur cette conversation : $error');
    }
  }

  Future<void> _openConversation(
    BuildContext context,
    String conversationId,
    Map<String, dynamic> data,
    String userId,
  ) async {
    final title = _conversationTitle(data, userId);
    final offerTitle = (data['offerTitle'] ?? '').toString().trim();

    // Fire-and-forget : ne pas bloquer la navigation sur le réseau
    _markConversationRead(conversationId, userId);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationThreadPage(
          conversationId: conversationId,
          offerTitle: offerTitle.isEmpty ? title : offerTitle,
          currentUserId: userId,
        ),
      ),
    );
  }

  void _maybeOpenInitialConversation(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String userId,
  ) {
    final initialConversationId = widget.initialConversationId?.trim() ?? '';
    if (_didHandleInitialConversation || initialConversationId.isEmpty) return;

    final match = docs.where((doc) => doc.id == initialConversationId).toList();

    if (match.isEmpty) {
      if (docs.length >= _conversationLimit) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _conversationLimit += 50);
        });
        return;
      }

      _didHandleInitialConversation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showErrorSnackBar(context, 'Conversation introuvable ou inaccessible.');
      });
      return;
    }

    _didHandleInitialConversation = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _openConversation(context, match.first.id, match.first.data(), userId);
    });
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Rechercher une conversation',
          prefixIcon: const Icon(Icons.search_rounded, color: kPrestoBlue),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: kPrestoBlue, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: kPrestoBlue, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildWatermark() {
    return IgnorePointer(
      child: Center(
        child: Transform.rotate(
          angle: -0.18,
          child: Text(
            'ilipresto',
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: Colors.grey.withOpacity(0.07),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 42,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: kPrestoBodyTextStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesAppBarTitle() {
    return const Text(
      'Mes messages',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: kPrestoAppBarTitleStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;

    if (userId == null) {
      return Scaffold(
        backgroundColor: kMessagesPageBackground,
        appBar: AppBar(
          systemOverlayStyle: kMessagesStatusBarStyle,
          backgroundColor: kPrestoOrange,
          foregroundColor: Colors.white,
          title: const Text(
            'Mes messages',
            style: kPrestoAppBarTitleStyle,
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            _buildWatermark(),
            _buildEmptyState('Connexion / inscription pour accéder à la messagerie.'),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: kMessagesPageBackground,
      appBar: AppBar(
        systemOverlayStyle: kMessagesStatusBarStyle,
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: _buildMessagesAppBarTitle(),
        actions: [
          IconButton(
            onPressed: () => setState(() => _showArchivedOnly = !_showArchivedOnly),
            icon: Icon(_showArchivedOnly ? Icons.inbox_outlined : Icons.archive_outlined),
            tooltip: _showArchivedOnly ? 'Afficher la boite principale' : 'Afficher les conversations archivees',
          ),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
            builder: (context, snapshot) {
              final inboxCounts =
                  (snapshot.data?.data()?['inboxCounts'] as Map<String, dynamic>?) ??
                  const <String, dynamic>{};
              final unreadMessages = readInboxCount(
                inboxCounts,
                type: InboxCountType.unreadMessages,
              );

              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.mark_chat_unread_outlined),
                      tooltip: 'Nouveaux messages',
                    ),
                  ),
                  if (unreadMessages > 0)
                    Positioned(
                      right: 6,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: kWhatsappGreen,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '$unreadMessages',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildWatermark(),
          Column(
            children: [
              _buildSearchField(),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('conversations')
                      .where('participants', arrayContains: userId)
                      .orderBy('lastMessageAt', descending: true)
                      .limit(_conversationLimit)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      final message = _isPermissionDenied(snapshot.error)
                          ? 'Pas de conversation en cours.'
                          : 'Erreur de chargement des conversations.';
                      return _buildEmptyState(message);
                    }

                    final docs = snapshot.data?.docs ?? const [];
                    _maybeOpenInitialConversation(context, docs, userId);

                    final query = _searchController.text.trim().toLowerCase();
                    final visibleDocs = docs.where((doc) {
                      return shouldShowConversation(
                        data: doc.data(),
                        userId: userId,
                        showArchivedOnly: _showArchivedOnly,
                      );
                    }).toList(growable: false);

                    final filteredDocs = visibleDocs.where((doc) {
                      if (query.isEmpty) return true;
                      return _searchableConversationText(doc.data(), userId).contains(query);
                    }).toList(growable: false);

                    if (filteredDocs.isEmpty) {
                      return _buildEmptyState(
                        _showArchivedOnly
                            ? 'Aucune conversation archivee.'
                            : 'Pas de conversation en cours.',
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 18),
                      itemCount: filteredDocs.length + (docs.length >= _conversationLimit ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == filteredDocs.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: TextButton.icon(
                                onPressed: () => setState(() => _conversationLimit += 50),
                                icon: const Icon(Icons.history_rounded, size: 16),
                                label: const Text('Charger les conversations plus anciennes'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF6B7280),
                                  textStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        final doc = filteredDocs[index];
                        final data = doc.data();
                        final offerTitle = (data['offerTitle'] ?? '').toString().trim();
                        final title = _conversationTitle(data, userId);
                        final preview = _conversationPreview(data, userId);
                        final unreadMap = data['unreadCount'];
                        final unreadCount = unreadMap is Map<String, dynamic>
                            ? ((unreadMap[userId] as int?) ?? 0)
                            : 0;
                        final archived = isConversationArchivedForUser(data, userId);
                        final blocked = isConversationBlocked(data);
                        final blockedForUser = isConversationBlockedForUser(data, userId);
                        final lastMessageAt = data['lastMessageAt'];
                        final lastDate = lastMessageAt is Timestamp ? lastMessageAt.toDate() : null;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Material(
                            color: Colors.white.withOpacity(0.96),
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () async {
                                await _openConversation(
                                  context,
                                  doc.id,
                                  data,
                                  userId,
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.035),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 27,
                                          backgroundColor: const Color(0xFFEAF2FF),
                                          foregroundColor: kPrestoBlue,
                                          child: Text(
                                            title.isNotEmpty ? title[0].toUpperCase() : '?',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 18,
                                            ),
                                          ),
                                      ),
                                        Positioned(
                                          right: 1,
                                          bottom: 1,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: unreadCount > 0
                                                  ? kWhatsappGreen
                                                  : const Color(0xFFD1D5DB),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: kPrestoCardTitleStyle.copyWith(
                                              fontWeight: unreadCount > 0
                                                  ? FontWeight.w800
                                                  : FontWeight.w700,
                                              color: const Color(0xFF111827),
                                            ),
                                          ),
                                          if (offerTitle.isNotEmpty && offerTitle != title) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              offerTitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: kPrestoMetaTextStyle.copyWith(
                                                color: const Color(0xFF6B7280),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 5),
                                          Text(
                                            preview,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: kPrestoBodyTextStyle.copyWith(
                                              color: unreadCount > 0
                                                  ? const Color(0xFF111827)
                                                  : const Color(0xFF6B7280),
                                              fontWeight: unreadCount > 0
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (archived || blocked) ...[
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: [
                                                if (archived)
                                                  _ConversationStateChip(
                                                    label: 'Archivee',
                                                    color: const Color(0xFF6B7280),
                                                  ),
                                                if (blocked)
                                                  _ConversationStateChip(
                                                    label: blockedForUser ? 'Bloquee par vous' : 'Bloquee',
                                                    color: const Color(0xFFB91C1C),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        PopupMenuButton<_ConversationMenuAction>(
                                          tooltip: 'Actions conversation',
                                          onSelected: (action) => _handleConversationAction(
                                            conversationId: doc.id,
                                            action: action,
                                          ),
                                          itemBuilder: (context) => [
                                            PopupMenuItem<_ConversationMenuAction>(
                                              value: archived
                                                  ? _ConversationMenuAction.unarchive
                                                  : _ConversationMenuAction.archive,
                                              child: Text(archived ? 'Restaurer' : 'Archiver'),
                                            ),
                                            PopupMenuItem<_ConversationMenuAction>(
                                              value: blockedForUser
                                                  ? _ConversationMenuAction.unblock
                                                  : _ConversationMenuAction.block,
                                              child: Text(blockedForUser ? 'Debloquer' : 'Bloquer'),
                                            ),
                                          ],
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.more_horiz_rounded,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatTimestamp(lastDate),
                                          style: kPrestoMetaTextStyle.copyWith(
                                            color: unreadCount > 0
                                                ? kWhatsappGreen
                                                : const Color(0xFF9CA3AF),
                                            fontWeight: unreadCount > 0
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                        if (unreadCount > 0) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: kWhatsappGreen,
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              '$unreadCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _ConversationMenuAction {
  archive,
  unarchive,
  block,
  unblock,
}

class _ConversationStateChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ConversationStateChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatTimestamp(DateTime? date) {
  if (date == null) return '--:--';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dateOnly = DateTime(date.year, date.month, date.day);

  if (dateOnly == today) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}
