import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';
import 'conversation_thread_page.dart';

const kPrestoOrange = Color(0xFFFF6600);

class ConversationsListPage extends StatefulWidget {
  const ConversationsListPage({super.key});

  @override
  State<ConversationsListPage> createState() => _ConversationsListPageState();
}

class _ConversationsListPageState extends State<ConversationsListPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _extractDisplayName(Map<String, dynamic>? userData, String fallbackId) {
    if (userData == null) return fallbackId;
    final candidates = [
      userData['pseudo'],
      userData['displayName'],
      userData['username'],
      userData['fullName'],
      userData['name'],
      userData['email'],
    ];
    for (final candidate in candidates) {
      final value = (candidate ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return fallbackId;
  }

  Future<Map<String, String>> _loadContactNames(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String currentUserId,
  ) async {
    final ids = <String>{};
    for (final doc in docs) {
      final participants = (doc.data()['participants'] as List<dynamic>? ?? [])
          .map((entry) => entry.toString())
          .where((entry) => entry.isNotEmpty && entry != currentUserId);
      ids.addAll(participants);
    }

    final futures = ids.map((id) async {
      try {
        final snap = await FirebaseFirestore.instance.collection('users').doc(id).get();
        return MapEntry(id, _extractDisplayName(snap.data(), id));
      } catch (_) {
        return MapEntry(id, id);
      }
    });

    return Map<String, String>.fromEntries(await Future.wait(futures));
  }

  Future<void> _markConversationRead(String conversationId, String currentUserId) async {
    try {
      await FirebaseFirestore.instance.collection('conversations').doc(conversationId).update({
        'unreadCount.$currentUserId': 0,
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: kPrestoOrange,
          foregroundColor: Colors.white,
          title: const Text(
            'Mes messages',
            style: kPrestoAppBarTitleStyle,
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Connectez-vous pour accéder à vos conversations.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        title: const Text(
          'Mes messages',
          style: kPrestoAppBarTitleStyle,
        ),
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('conversations')
                .where('participants', arrayContains: userId)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              var totalUnread = 0;
              for (final doc in docs) {
                final unread = doc.data()['unreadCount'];
                if (unread is Map<String, dynamic>) {
                  final value = unread[userId];
                  if (value is int) totalUnread += value;
                }
              }

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_none),
                    tooltip: 'Nouveaux messages',
                  ),
                  if (totalUnread > 0)
                    Positioned(
                      right: 8,
                      top: 10,
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
                hintText: 'Rechercher une conversation',
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
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Erreur de chargement des conversations.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aucune conversation pour le moment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }

                return FutureBuilder<Map<String, String>>(
                  future: _loadContactNames(docs, userId),
                  builder: (context, namesSnapshot) {
                    final names = namesSnapshot.data ?? const <String, String>{};
                    final query = _searchController.text.trim().toLowerCase();

                    final filteredDocs = docs.where((doc) {
                      final data = doc.data();
                      final participants = (data['participants'] as List<dynamic>? ?? [])
                          .map((entry) => entry.toString())
                          .where((entry) => entry.isNotEmpty && entry != userId)
                          .toList();
                      final contactName = participants.isEmpty
                          ? 'Conversation'
                          : names[participants.first] ?? participants.first;
                      final offerTitle = (data['offerTitle'] ?? '').toString();
                      final lastMessage = (data['lastMessage'] ?? '').toString();
                      if (query.isEmpty) return true;
                      return contactName.toLowerCase().contains(query) ||
                          offerTitle.toLowerCase().contains(query) ||
                          lastMessage.toLowerCase().contains(query);
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return const Center(
                        child: Text(
                          'Aucune conversation trouvée',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filteredDocs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data();
                        final participants = (data['participants'] as List<dynamic>? ?? [])
                            .map((entry) => entry.toString())
                            .where((entry) => entry.isNotEmpty && entry != userId)
                            .toList();
                        final contactId = participants.isEmpty ? '' : participants.first;
                        final contactName = contactId.isEmpty
                            ? 'Conversation'
                            : names[contactId] ?? contactId;
                        final offerTitle = (data['offerTitle'] ?? 'Conversation').toString();
                        final lastMessage = (data['lastMessage'] ?? '').toString();
                        final unreadMap = data['unreadCount'];
                        final unreadCount = unreadMap is Map<String, dynamic>
                            ? ((unreadMap[userId] as int?) ?? 0)
                            : 0;
                        final lastMessageAt = data['lastMessageAt'];
                        final lastDate = lastMessageAt is Timestamp ? lastMessageAt.toDate() : null;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: kPrestoOrange.withOpacity(0.15),
                            foregroundColor: kPrestoOrange,
                            child: Text(
                              contactName.isNotEmpty ? contactName[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          title: Text(
                            contactName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                offerTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if (lastMessage.isNotEmpty)
                                Text(
                                  lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatTimestamp(lastDate),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              if (unreadCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                            await _markConversationRead(doc.id, userId);
                            if (!context.mounted) return;
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ConversationThreadPage(
                                  conversationId: doc.id,
                                  offerTitle: offerTitle,
                                  currentUserId: userId,
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
