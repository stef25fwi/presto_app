import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../utils/friendly_snackbar.dart';

const Color kPrestoOrange = Color(0xFFFF6600);
const Color kPrestoBlue = Color(0xFF1A73E8);

class MessagesManagementPage extends StatefulWidget {
  const MessagesManagementPage({super.key});

  @override
  State<MessagesManagementPage> createState() => _MessagesManagementPageState();
}

class _MessagesManagementPageState extends State<MessagesManagementPage> {
  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedFilter = 'all'; // all, unread, archived
  int _totalConversations = 0;
  int _unreadConversations = 0;
  int _archivedConversations = 0;
  int _totalMessages = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final allSnap = await _firestore.collection('conversations').count().get();
      final unreadSnap = await _firestore
          .collection('conversations')
          .where('unreadCount', isGreaterThan: 0)
          .count()
          .get();
      final archivedSnap = await _firestore
          .collection('conversations')
          .where('archived', isEqualTo: true)
          .count()
          .get();
      final messagesSnap = await _firestore.collection('messages').count().get();

      if (!mounted) return;
      setState(() {
        _totalConversations = allSnap.count ?? 0;
        _unreadConversations = unreadSnap.count ?? 0;
        _archivedConversations = archivedSnap.count ?? 0;
        _totalMessages = messagesSnap.count ?? 0;
      });
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, 'Erreur stats: $e');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildConversationsStream() {
    Query<Map<String, dynamic>> query = _firestore.collection('conversations');

    switch (_selectedFilter) {
      case 'unread':
        query = query.where('unreadCount', isGreaterThan: 0);
        break;
      case 'archived':
        query = query.where('archived', isEqualTo: true);
        break;
      case 'all':
      default:
        break;
    }

    return query
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .snapshots();
  }

  Future<void> _deleteConversation(String conversationId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer conversation'),
        content: const Text('Supprimer cette conversation et tous ses messages ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Supprimer tous les messages de la conversation
      final messagesSnap = await _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .get();

      for (final doc in messagesSnap.docs) {
        await doc.reference.delete();
      }

      // Supprimer la conversation
      await _firestore.collection('conversations').doc(conversationId).delete();

      if (!mounted) return;
      showSuccessSnackBar(context, 'Conversation supprimée');
      _loadStats();
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, 'Erreur suppression: $e');
    }
  }

  Future<void> _toggleArchive(String conversationId, bool archived) async {
    try {
      await _firestore.collection('conversations').doc(conversationId).update({
        'archived': !archived,
      });
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        archived ? 'Conversation restaurée' : 'Conversation archivée',
      );
      _loadStats();
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, 'Erreur: $e');
    }
  }

  Future<void> _markAsRead(String conversationId) async {
    try {
      await _firestore.collection('conversations').doc(conversationId).update({
        'unreadCount': 0,
      });
      if (!mounted) return;
      showSuccessSnackBar(context, 'Marqué comme lu');
      _loadStats();
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, 'Erreur: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        titleSpacing: 16,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Retour',
        ),
        title: const Text(
          'Gestion des messages',
          style: kPrestoAppBarTitleStyle,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStats,
            tooltip: 'Rafraîchir',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statistiques
              _buildStatsGrid(),
              const SizedBox(height: 24),

              // Filtres
              Text(
                'Filtrer par statut',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              _buildFilterButtons(),
              const SizedBox(height: 24),

              // Liste des conversations
              Text(
                'Conversations',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              _buildConversationsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 120,
      ),
      children: [
        _StatCard(
          label: 'Conversations',
          value: _totalConversations.toString(),
          color: kPrestoBlue,
          icon: Icons.chat_rounded,
        ),
        _StatCard(
          label: 'Non lues',
          value: _unreadConversations.toString(),
          color: Colors.orange,
          icon: Icons.mail_rounded,
        ),
        _StatCard(
          label: 'Archivées',
          value: _archivedConversations.toString(),
          color: Colors.grey,
          icon: Icons.archive_rounded,
        ),
        _StatCard(
          label: 'Messages',
          value: _totalMessages.toString(),
          color: kPrestoOrange,
          icon: Icons.message_rounded,
        ),
      ],
    );
  }

  Widget _buildFilterButtons() {
    final filters = [
      ('all', 'Toutes (${_totalConversations})', null),
      ('unread', 'Non lues (${_unreadConversations})', Colors.orange),
      ('archived', 'Archivées (${_archivedConversations})', Colors.grey),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter.$2),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedFilter = filter.$1);
              },
              backgroundColor: Colors.white,
              selectedColor: (filter.$3 ?? kPrestoBlue).withOpacity(0.2),
              side: BorderSide(
                color: isSelected
                    ? (filter.$3 ?? kPrestoBlue)
                    : Colors.black12,
                width: isSelected ? 2 : 1,
              ),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? (filter.$3 ?? kPrestoBlue)
                    : Colors.black87,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConversationsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _buildConversationsStream(),
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
              padding: const EdgeInsets.all(16),
              child: Text(
                'Erreur: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 48,
                    color: Colors.black26,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aucune conversation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();

            final participants = (data['participants'] as List?)
                    ?.cast<String>()
                    .take(2)
                    .join(', ') ??
                '—';
            final lastMessage = (data['lastMessage'] ?? '—') as String;
            final unreadCount = (data['unreadCount'] ?? 0) as int;
            final archived = data['archived'] ?? false;
            final updatedAt = data['updatedAt'] as Timestamp?;
            final messageCount = (data['messageCount'] ?? 0) as int;

            final dateStr = updatedAt != null
                ? updatedAt.toDate().toString().split('.')[0]
                : '—';

            return Container(
              decoration: BoxDecoration(
                color: unreadCount > 0 ? Colors.blue.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: unreadCount > 0 ? Colors.blue.shade200 : Colors.black12,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
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
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      participants,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if (unreadCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (archived)
                          Chip(
                            label: const Text(
                              'Archivé',
                              style: TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.grey.shade200,
                            side: BorderSide(color: Colors.grey.shade400),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 12, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.message_rounded,
                            size: 12, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text(
                          '$messageCount',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (unreadCount > 0)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _markAsRead(doc.id),
                              icon: const Icon(Icons.done_rounded, size: 16),
                              label: const Text('Marquer comme lu'),
                            ),
                          ),
                        if (unreadCount > 0) const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _toggleArchive(doc.id, archived as bool),
                            icon: Icon(
                              archived
                                  ? Icons.unarchive_rounded
                                  : Icons.archive_rounded,
                              size: 16,
                            ),
                            label: Text(
                              archived ? 'Restaurer' : 'Archiver',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _deleteConversation(doc.id),
                            icon: const Icon(Icons.delete_rounded, size: 16),
                            label: const Text('Supprimer'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 24, color: color),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
