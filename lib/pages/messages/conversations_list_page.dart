import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';
import 'conversation_thread_page.dart';

const kPrestoOrange = Color(0xFFFF6600);
const kPrestoBlue = Color(0xFF1A73E8);
const kMessagesPageBackground = Color(0xFFFFFEFE);
const kWhatsappGreen = Color(0xFF25D366);

class ConversationsListPage extends StatefulWidget {
  const ConversationsListPage({super.key});

  @override
  State<ConversationsListPage> createState() => _ConversationsListPageState();
}

class _ConversationsListPageState extends State<ConversationsListPage> {
  final TextEditingController _searchController = TextEditingController();
  int _totalUnread = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isPermissionDenied(Object? error) {
    final text = (error ?? '').toString().toLowerCase();
    return text.contains('permission-denied') || text.contains('permission denied');
  }

  String _conversationTitle(Map<String, dynamic> data) {
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
      _conversationTitle(data),
      _conversationPreview(data, userId),
      (data['offerTitle'] ?? '').toString(),
      (data['lastMessage'] ?? '').toString(),
      (data['lastSenderName'] ?? '').toString(),
    ].join(' ').toLowerCase();
  }

  Future<void> _markConversationRead(String conversationId, String currentUserId) async {
    try {
      await FirebaseFirestore.instance.collection('conversations').doc(conversationId).update({
        'unreadCount.$currentUserId': 0,
      });
    } catch (_) {}
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: 'Rechercher une conversation',
            hintStyle: const TextStyle(
              fontSize: 14,
              color: Colors.black45,
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            prefixIcon: const Icon(
              Icons.search,
              color: kPrestoBlue,
              size: 22,
            ),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: kPrestoBlue, width: 1.5),
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
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.28),
            ),
          ),
          child: const Icon(
            Icons.forum_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mes messages',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kPrestoAppBarTitleStyle,
              ),
              Text(
                'Conversations recentes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFFFFF4EC),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
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
          backgroundColor: kPrestoOrange,
          foregroundColor: Colors.white,
          title: const Text(
            'Mes messages',
            style: kPrestoAppBarTitleStyle,
          ),
        ),
        body: Stack(
          children: [
            _buildWatermark(),
            _buildEmptyState('Connectez-vous pour accéder à la messagerie.'),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: kMessagesPageBackground,
      appBar: AppBar(
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 10,
        title: _buildMessagesAppBarTitle(),
        actions: [
          Stack(
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
              if (_totalUnread > 0)
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
                      '$_totalUnread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
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
                          ? 'Accès refusé à vos messages. Réouvrez la conversation après reconnexion.'
                          : 'Erreur de chargement des conversations.';
                      return _buildEmptyState(message);
                    }

                    final docs = snapshot.data?.docs ?? const [];
                    var computedUnread = 0;
                    for (final doc in docs) {
                      final unread = doc.data()['unreadCount'];
                      if (unread is Map<String, dynamic>) {
                        final value = unread[userId];
                        if (value is int) computedUnread += value;
                      }
                    }
                    if (computedUnread != _totalUnread) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _totalUnread = computedUnread);
                      });
                    }

                    final query = _searchController.text.trim().toLowerCase();
                    final filteredDocs = docs.where((doc) {
                      if (query.isEmpty) return true;
                      return _searchableConversationText(doc.data(), userId).contains(query);
                    }).toList(growable: false);

                    if (filteredDocs.isEmpty) {
                      return _buildEmptyState('Pas de conversation en cours.');
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 18),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data();
                        final title = _conversationTitle(data);
                        final offerTitle = (data['offerTitle'] ?? '').toString().trim();
                        final preview = _conversationPreview(data, userId);
                        final unreadMap = data['unreadCount'];
                        final unreadCount = unreadMap is Map<String, dynamic>
                            ? ((unreadMap[userId] as int?) ?? 0)
                            : 0;
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
                                await _markConversationRead(doc.id, userId);
                                if (!context.mounted) return;
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ConversationThreadPage(
                                      conversationId: doc.id,
                                      offerTitle: offerTitle.isEmpty ? title : offerTitle,
                                      currentUserId: userId,
                                    ),
                                  ),
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
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
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
