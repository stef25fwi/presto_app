import 'package:flutter/material.dart';

/// On redéfinit juste la couleur orange Prestō ici
const kPrestoOrange = Color(0xFFFF6600);

class Conversation {
  Conversation({
    required this.id,
    required this.contactName,
    required this.messages,
    this.unreadCount = 0,
  });

  final String id;
  final String contactName;
  final List<Message> messages;
  int unreadCount;

  Message get latestMessage => messages.last;
}

class Message {
  const Message({
    required this.text,
    required this.sentAt,
    required this.isMine,
  });

  final String text;
  final DateTime sentAt;
  final bool isMine;
}

/// Page liste des conversations avec recherche, tri par date et badges d'alertes
class ConversationsListPage extends StatefulWidget {
  const ConversationsListPage({super.key});

  @override
  State<ConversationsListPage> createState() => _ConversationsListPageState();
}

class _ConversationsListPageState extends State<ConversationsListPage> {
  final TextEditingController _searchController = TextEditingController();
  late final List<Conversation> _conversations;

  @override
  void initState() {
    super.initState();
    _conversations = _seedConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _totalUnread => _conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);

  List<Conversation> get _filteredAndSorted {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _conversations.where((conversation) {
      if (query.isEmpty) return true;
      final inContact = conversation.contactName.toLowerCase().contains(query);
      final inMessages = conversation.messages.any(
        (message) => message.text.toLowerCase().contains(query),
      );
      return inContact || inMessages;
    }).toList();

    filtered.sort(
      (a, b) => b.latestMessage.sentAt.compareTo(a.latestMessage.sentAt),
    );

    return filtered;
  }

  void _markAsRead(String conversationId) {
    setState(() {
      final idx = _conversations.indexWhere((c) => c.id == conversationId);
      if (idx != -1) {
        _conversations[idx].unreadCount = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversations = _filteredAndSorted;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        title: const Text(
          "Mes messages",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _BellBadge(totalUnread: _totalUnread),
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
                hintText: "Rechercher un mot dans vos conversations",
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
            child: conversations.isEmpty
                ? const Center(
                    child: Text(
                      "Aucune conversation trouvée",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  )
                : ListView.separated(
                    itemCount: conversations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      final lastMessage = conversation.latestMessage;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: kPrestoOrange.withOpacity(0.15),
                          foregroundColor: kPrestoOrange,
                          child: Text(
                            conversation.contactName.isNotEmpty
                                ? conversation.contactName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(
                          conversation.contactName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          lastMessage.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatTimestamp(lastMessage.sentAt),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            if (conversation.unreadCount > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${conversation.unreadCount}',
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
                          _markAsRead(conversation.id);
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ConversationPage(conversation: conversation),
                            ),
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

class ConversationPage extends StatelessWidget {
  const ConversationPage({super.key, required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        title: Text(conversation.contactName),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              String? message;
              if (value == 'add') {
                message = 'Contact ajouté à votre carnet.';
              } else if (value == 'report') {
                message = 'Signalement transmis. Merci pour votre alerte.';
              }
              if (message != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'add',
                child: Text('Ajouter à mes contacts'),
              ),
              PopupMenuItem(
                value: 'report',
                child: Text('Signaler'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: conversation.messages.length,
              itemBuilder: (context, index) {
                final message = conversation.messages[index];
                final alignment = message.isMine ? Alignment.centerRight : Alignment.centerLeft;
                final bubbleColor = message.isMine ? kPrestoOrange.withOpacity(0.12) : Colors.grey.shade200;
                final textColor = message.isMine ? Colors.black : Colors.black87;

                return Align(
                  alignment: alignment,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            message.text,
                            style: TextStyle(color: textColor, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTimestamp(message.sentAt),
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      hintText: "Envoyer un message (bientôt disponible)",
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: null,
                  icon: const Icon(Icons.send),
                  color: kPrestoOrange,
                  tooltip: "Envoi bientôt disponible",
                ),
              ],
            ),
          ),
        ],
      ),
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

List<Conversation> _seedConversations() {
  return [
    Conversation(
      id: 'conv-1',
      contactName: 'Camille',
      unreadCount: 2,
      messages: const [
        Message(
          text: 'Hello ! Merci pour ton dernier retour.',
          sentAt: DateTime(2025, 1, 20, 9, 30),
          isMine: false,
        ),
        Message(
          text: "Dispo pour avancer sur la prestation ?",
          sentAt: DateTime(2025, 1, 20, 9, 34),
          isMine: false,
        ),
      ],
    ),
    Conversation(
      id: 'conv-2',
      contactName: 'Alexandre',
      unreadCount: 1,
      messages: const [
        Message(
          text: 'Parfait, je passe demain matin.',
          sentAt: DateTime(2025, 1, 19, 18, 12),
          isMine: true,
        ),
        Message(
          text: "Top, j'aurai les pièces.",
          sentAt: DateTime(2025, 1, 19, 19, 5),
          isMine: false,
        ),
      ],
    ),
    Conversation(
      id: 'conv-3',
      contactName: 'Sophie',
      unreadCount: 0,
      messages: const [
        Message(
          text: 'Merci pour la prestation, à bientôt !',
          sentAt: DateTime(2025, 1, 18, 14, 42),
          isMine: false,
        ),
        Message(
          text: 'Avec plaisir, bonne journée.',
          sentAt: DateTime(2025, 1, 18, 14, 55),
          isMine: true,
        ),
      ],
    ),
  ];
}