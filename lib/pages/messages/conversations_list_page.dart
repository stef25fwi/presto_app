import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../services/messaging_service.dart';
import 'conversation_page.dart';

/// On redéfinit juste la couleur orange Prestō ici
const kPrestoOrange = Color(0xFFFF6600);

/// Page liste des conversations avec recherche, tri par date et badges d'alertes
class ConversationsListPage extends StatefulWidget {
  const ConversationsListPage({super.key});

  @override
  State<ConversationsListPage> createState() => _ConversationsListPageState();
}

class _ConversationsListPageState extends State<ConversationsListPage> {
  final TextEditingController _searchController = TextEditingController();
  final MessagingService _messagingService = MessagingService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: kPrestoOrange,
          foregroundColor: Colors.white,
          title: const Text(
            "Mes messages",
            style: kPrestoAppBarTitleStyle,
          ),
        ),
        body: const Center(
          child: Text(
            'Veuillez vous connecter pour voir vos messages',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        title: const Text(
          "Mes messages",
          style: kPrestoAppBarTitleStyle,
        ),
        actions: [
          StreamBuilder<int>(
            stream: _getTotalUnreadStream(),
            builder: (context, snapshot) {
              final totalUnread = snapshot.data ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _BellBadge(totalUnread: totalUnread),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: "Rechercher dans vos conversations",
                prefixIcon: const Icon(Icons.search),
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
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: kPrestoOrange),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messagingService.getConversationsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erreur: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
                    ),
                  );
                }

                final conversations = snapshot.data!.docs;

                // Filtre par recherche
                final searchQuery = _searchController.text.trim().toLowerCase();
                final filteredConversations = conversations.where((doc) {
                  if (searchQuery.isEmpty) return true;

                  final data = doc.data();
                  final lastMessage = (data['lastMessage'] ?? '').toString().toLowerCase();

                  return lastMessage.contains(searchQuery);
                }).toList();

                if (filteredConversations.isEmpty) {
                  return const Center(
                    child: Text(
                      "Aucune conversation trouvée",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filteredConversations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = filteredConversations[index];
                    final data = doc.data();

                    final participants = List<String>.from(data['participants'] ?? []);
                    final otherUserId = participants.firstWhere(
                      (id) => id != currentUserId,
                      orElse: () => '',
                    );

                    final lastMessage = data['lastMessage'] ?? '';
                    final lastMessageAt = (data['lastMessageAt'] as Timestamp?)?.toDate();
                    final unreadMap = data['unreadCount'] as Map<String, dynamic>?;
                    final unreadCount = unreadMap?[currentUserId] as int? ?? 0;

                    return FutureBuilder<Map<String, dynamic>?>(
                      future: _messagingService.getUserInfo(otherUserId),
                      builder: (context, userSnapshot) {
                        final userName = userSnapshot.data?['displayName'] ??
                            userSnapshot.data?['name'] ??
                            'Utilisateur';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: kPrestoOrange.withOpacity(0.15),
                            foregroundColor: kPrestoOrange,
                            child: Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          title: Text(
                            userName,
                            style: TextStyle(
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            lastMessage.isEmpty
                                ? 'Aucun message'
                                : lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (lastMessageAt != null)
                                Text(
                                  _formatTimestamp(lastMessageAt),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              if (unreadCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade600,
                                    borderRadius: BorderRadius.circular(12),
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
                          ),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ConversationPage(
                                  conversationId: doc.id,
                                  otherUserName: userName,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<int> _getTotalUnreadStream() async* {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      yield 0;
      return;
    }

    await for (final snapshot in _messagingService.getConversationsStream()) {
      int total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final unreadMap = data['unreadCount'] as Map<String, dynamic>?;
        final unread = unreadMap?[currentUserId] as int? ?? 0;
        total += unread;
      }
      yield total;
    }
  }
}

class _BellBadge extends StatelessWidget {
  const _BellBadge({required this.totalUnread});

  final int totalUnread;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none),
          tooltip: "Nouveaux messages",
        ),
        if (totalUnread > 0)
          Positioned(
            right: 6,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$totalUnread',
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
  }
}

String _formatTimestamp(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dateOnly = DateTime(date.year, date.month, date.day);

  if (dateOnly == today) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}