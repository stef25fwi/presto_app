import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../services/messaging_service.dart';
import '../../utils/friendly_snackbar.dart';

/// Page de conversation individuelle avec envoi/réception en temps réel
class ConversationPage extends StatefulWidget {
  const ConversationPage({
    super.key,
    this.conversationId,
    this.otherUserId,
    this.otherUserName,
  }) : assert(
          conversationId != null || otherUserId != null,
          'conversationId ou otherUserId requis',
        );

  final String? conversationId;
  final String? otherUserId;
  final String? otherUserName;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  static const Color kPrestoOrange = Color(0xFFFF6600);

  final MessagingService _messagingService = MessagingService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _conversationId;
  String? _otherUserId;
  String _otherUserName = 'Chargement...';
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (widget.conversationId != null) {
      _conversationId = widget.conversationId;

      // Récupère l'autre utilisateur depuis la conversation
      final doc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(_conversationId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final participants = List<String>.from(data?['participants'] ?? []);
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        _otherUserId = participants.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );

        if (_otherUserId != null && _otherUserId!.isNotEmpty) {
          final userInfo = await _messagingService.getUserInfo(_otherUserId!);
          _otherUserName =
              userInfo?['displayName'] ?? userInfo?['name'] ?? 'Utilisateur';
        }
      }
    } else if (widget.otherUserId != null) {
      _otherUserId = widget.otherUserId;
      _otherUserName = widget.otherUserName ?? 'Utilisateur';

      // Crée ou récupère la conversation
      _conversationId = await _messagingService.getOrCreateConversation(
        otherUserId: _otherUserId!,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }

    // Marque la conversation comme lue
    if (_conversationId != null) {
      await _messagingService.markConversationAsRead(_conversationId!);
    }

    // Scroll vers le bas après le premier build
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_conversationId == null || _isSending) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await _messagingService.sendMessage(
        conversationId: _conversationId!,
        text: text,
      );

      // Scroll vers le bas après l'envoi
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, 'Erreur lors de l\'envoi: $e');
      _messageController.text = text;
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: kPrestoOrange,
          foregroundColor: Colors.white,
          title: const Text('Chargement...', style: kPrestoAppBarTitleStyle),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
          ),
        ),
      );
    }

    if (_conversationId == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: kPrestoOrange,
          foregroundColor: Colors.white,
          title: const Text('Erreur', style: kPrestoAppBarTitleStyle),
        ),
        body: const Center(
          child: Text('Impossible de charger la conversation'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        title: Text(_otherUserName, style: kPrestoAppBarTitleStyle),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (!mounted) return;

              if (value == 'report') {
                await _messagingService.reportConversation(
                  conversationId: _conversationId!,
                  reason: 'Signalement utilisateur',
                );
                if (!mounted) return;
                showSuccessSnackBar(
                  context,
                  'Conversation signalée. Merci pour votre alerte.',
                );
              } else if (value == 'archive') {
                await _messagingService
                    .archiveConversation(_conversationId!);
                if (!mounted) return;
                showSuccessSnackBar(context, 'Conversation archivée');
                Navigator.of(context).pop();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Archiver'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Signaler'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messagingService.getMessagesStream(_conversationId!),
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

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucun message. Envoyez le premier !',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }

                // Scroll automatique quand de nouveaux messages arrivent
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    final isNearBottom =
                        _scrollController.position.pixels >=
                            _scrollController.position.maxScrollExtent - 100;

                    if (isNearBottom) {
                      _scrollToBottom();
                    }
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final data = message.data();
                    final text = data['text'] ?? '';
                    final senderId = data['senderId'] ?? '';
                    final sentAt = (data['sentAt'] as Timestamp?)?.toDate();

                    final currentUserId =
                        FirebaseAuth.instance.currentUser?.uid;
                    final isMine = senderId == currentUserId;

                    final alignment = isMine
                        ? Alignment.centerRight
                        : Alignment.centerLeft;
                    final bubbleColor = isMine
                        ? kPrestoOrange.withOpacity(0.12)
                        : Colors.grey.shade200;
                    final textColor =
                        isMine ? Colors.black : Colors.black87;

                    return Align(
                      alignment: alignment,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                text,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                ),
                              ),
                              if (sentAt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _formatTimestamp(sentAt),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
                    controller: _messageController,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Votre message...",
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            const BorderSide(color: kPrestoOrange, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: kPrestoOrange,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    color: Colors.white,
                    tooltip: "Envoyer",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
}
